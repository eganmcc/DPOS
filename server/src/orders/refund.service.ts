import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import {
  InventoryReason,
  OrderStatus,
  PaymentDirection,
  PaymentStatus,
  Prisma,
  ReversalType,
} from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { PaymentsService } from '../payments/payments.service';
import { AuthUser } from '../auth/auth.types';
import { RefundOrderDto } from './dto';
import { ORDER_INCLUDE, OrderWithRelations, deriveEffectiveStatus } from './order.mapper';
import { resolveCorrectionApprover } from './approval.util';

export interface RefundResult {
  order: OrderWithRelations;
  replay: boolean;
}

/**
 * Refund a completed sale — full or line-level partial (US: void/refund phase 2).
 *
 * Append-only like the void (Constitution IV): the original order/lines/charge are
 * never rewritten. A refund writes, in ONE transaction:
 *   - a `Refund` (+ `RefundLine` rows) recording amount and which lines/qty came back
 *   - `ADJUSTMENT` inventory movements (refType ORDER_REFUND) restoring refunded stock
 *   - a `REVERSAL` payment (`reversalType = REFUND`) for the money returned
 *   - an `AuditLog` entry
 * Multiple partial refunds are allowed up to the order's grand total; the effective
 * status becomes REFUNDED once the whole total has been returned.
 * OWNER/MANAGER-gated at the controller; idempotent via UNIQUE(merchantId, clientRefundId).
 */
@Injectable()
export class RefundService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly payments: PaymentsService,
  ) {}

  async refundOrder(user: AuthUser, orderId: string, dto: RefundOrderDto): Promise<RefundResult> {
    const order = await this.findById(user.merchantId, orderId);
    if (!order) throw new NotFoundException('Order not found');

    // Idempotent replay by device key.
    if (dto.clientRefundId) {
      const existing = await this.prisma.refund.findUnique({
        where: { merchantId_clientRefundId: { merchantId: user.merchantId, clientRefundId: dto.clientRefundId } },
      });
      if (existing) {
        if (existing.orderId !== order.id) {
          throw new ConflictException('clientRefundId already used for another order');
        }
        return { order, replay: true };
      }
    }

    if (order.status !== OrderStatus.COMPLETED) {
      throw new ConflictException('Only a completed sale can be refunded');
    }
    if (order.voids.length > 0) {
      throw new ConflictException('A voided sale cannot be refunded');
    }

    // How much of each line, and how much money, has already been refunded.
    const priorQtyByLine = new Map<string, number>();
    let alreadyRefunded = 0;
    for (const r of order.refunds) {
      alreadyRefunded += r.amount;
      for (const rl of r.lines) {
        priorQtyByLine.set(rl.orderLineId, (priorQtyByLine.get(rl.orderLineId) ?? 0) + Number(rl.qty));
      }
    }

    const subtotal = order.subtotal;
    const grandTotal = order.grandTotal;
    const remainingAmount = grandTotal - alreadyRefunded;
    if (remainingAmount <= 0) throw new ConflictException('This sale is already fully refunded');

    // Resolve which lines + quantities this refund covers.
    const lineById = new Map(order.lines.map((l) => [l.id, l]));
    const picks: { line: (typeof order.lines)[number]; qty: number }[] = [];

    if (dto.full) {
      for (const line of order.lines) {
        const remaining = Number(line.qty) - (priorQtyByLine.get(line.id) ?? 0);
        if (remaining > 0.0001) picks.push({ line, qty: remaining });
      }
    } else {
      if (!dto.lines || dto.lines.length === 0) {
        throw new BadRequestException('Select line items to refund, or choose a full refund');
      }
      for (const req of dto.lines) {
        if (req.qty <= 0) continue;
        const line = lineById.get(req.orderLineId);
        if (!line) throw new BadRequestException('A selected line does not belong to this order');
        const remaining = Number(line.qty) - (priorQtyByLine.get(line.id) ?? 0);
        if (req.qty > remaining + 0.0001) {
          throw new BadRequestException(`Cannot refund more than remains on "${line.productNameSnapshot}"`);
        }
        picks.push({ line, qty: req.qty });
      }
    }
    if (picks.length === 0) throw new BadRequestException('Nothing left to refund');

    // Money: full = the remaining total; partial = the picked lines' proportional share
    // of the grand total (so order discount + tax + service are refunded proportionally).
    const pickedBase = picks.reduce((s, p) => s + Math.round((p.line.lineTotal * p.qty) / Number(p.line.qty)), 0);
    let amount = dto.full
      ? remainingAmount
      : subtotal > 0
        ? Math.round((pickedBase * grandTotal) / subtotal)
        : pickedBase;
    if (amount <= 0) throw new BadRequestException('Refund amount must be greater than zero');
    if (amount > remainingAmount) amount = remainingAmount; // never refund more than remains
    const isFull = alreadyRefunded + amount >= grandTotal;

    // Only restore stock for variants that actually track inventory.
    const variantIds = [...new Set(picks.map((p) => p.line.variantId))];
    const variants = await this.prisma.productVariant.findMany({
      where: { id: { in: variantIds } },
      select: { id: true, trackInventory: true },
    });
    const tracks = new Map(variants.map((v) => [v.id, v.trackInventory]));

    // Owner/manager self-authorize; a cashier must present a manager PIN.
    const approvedById = await resolveCorrectionApprover(this.prisma, user, dto.approverPin);

    try {
      await this.prisma.$transaction(async (tx) => {
        const refund = await tx.refund.create({
          data: {
            merchantId: user.merchantId,
            outletId: order.outletId,
            orderId: order.id,
            clientRefundId: dto.clientRefundId ?? null,
            reason: dto.reason,
            amount,
            isFull,
            refundedById: user.staffId,
            approvedById,
          },
        });

        for (const p of picks) {
          const lineAmount =
            subtotal > 0
              ? Math.round((Math.round((p.line.lineTotal * p.qty) / Number(p.line.qty)) * grandTotal) / subtotal)
              : Math.round((p.line.lineTotal * p.qty) / Number(p.line.qty));
          await tx.refundLine.create({
            data: {
              refundId: refund.id,
              orderLineId: p.line.id,
              variantId: p.line.variantId,
              qty: p.qty,
              amount: lineAmount,
            },
          });

          if (tracks.get(p.line.variantId)) {
            await tx.inventoryMovement.create({
              data: {
                merchantId: user.merchantId,
                outletId: order.outletId,
                variantId: p.line.variantId,
                qtyDelta: p.qty,
                reason: InventoryReason.ADJUSTMENT,
                refType: 'ORDER_REFUND',
                refId: refund.id,
                createdById: user.staffId,
              },
            });
            await tx.inventoryStock.upsert({
              where: { outletId_variantId: { outletId: order.outletId, variantId: p.line.variantId } },
              create: {
                merchantId: user.merchantId,
                outletId: order.outletId,
                variantId: p.line.variantId,
                quantityOnHand: p.qty,
              },
              update: { quantityOnHand: { increment: p.qty } },
            });
          }
        }

        // Money back out — one REVERSAL/REFUND payment against the first captured charge.
        const charge = order.payments.find(
          (pmt) => pmt.direction === PaymentDirection.CHARGE && pmt.status === PaymentStatus.PAID,
        );
        if (charge) {
          const reversal = this.payments.reverse(charge.method, {
            amount,
            reversalType: ReversalType.REFUND,
            originalProviderRef: charge.providerRef,
          });
          await tx.payment.create({
            data: {
              merchantId: user.merchantId,
              orderId: order.id,
              direction: PaymentDirection.REVERSAL,
              reversalType: reversal.reversalType,
              reversesPaymentId: charge.id,
              method: reversal.method,
              amount: reversal.amount,
              status: reversal.status,
              providerRef: reversal.providerRef ?? null,
              paidAt: reversal.status === PaymentStatus.PAID ? new Date() : null,
            },
          });
        }

        await tx.auditLog.create({
          data: {
            merchantId: user.merchantId,
            outletId: order.outletId,
            actorId: user.staffId,
            action: 'REFUND',
            entityType: 'Order',
            entityId: order.id,
            before: {
              effectiveStatus: deriveEffectiveStatus(order),
              alreadyRefunded,
              grandTotal,
            },
            after: {
              refundId: refund.id,
              amount,
              isFull,
              reason: dto.reason,
              lines: picks.map((p) => ({ orderLineId: p.line.id, qty: p.qty })),
            },
          },
        });
      });
    } catch (e) {
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002' && dto.clientRefundId) {
        const existing = await this.findById(user.merchantId, orderId);
        if (existing) return { order: existing, replay: true };
      }
      throw e;
    }

    const updated = await this.findById(user.merchantId, orderId);
    return { order: updated!, replay: false };
  }

  private async findById(merchantId: string, id: string) {
    return this.prisma.order.findFirst({ where: { id, merchantId }, include: ORDER_INCLUDE });
  }
}
