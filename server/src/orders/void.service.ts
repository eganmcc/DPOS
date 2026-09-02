import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
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
import { VoidOrderDto } from './dto';
import { ORDER_INCLUDE, OrderWithRelations, deriveEffectiveStatus } from './order.mapper';

export interface VoidResult {
  order: OrderWithRelations;
  /** true when the void already existed (idempotent retry) — nothing new was written. */
  replay: boolean;
}

/**
 * Full void of a completed sale (US3, T036).
 *
 * Append-only by construction (Constitution IV): the `Order` row, its lines and totals, and the
 * original `PAID` `CHARGE` payment are NEVER rewritten. A void writes:
 *   - one immutable `OrderVoid`      (UNIQUE(orderId) ⇒ at most one per order; effective VOIDED)
 *   - positive `VOID_RESTORE` inventory movements + the stock projection
 *   - a `REVERSAL` payment (`reversalType = VOID`) per captured charge
 *   - an `AuditLog` entry naming the actor
 * all inside ONE transaction (Constitution II). OWNER-gated at the controller (Constitution VI),
 * and idempotent via `UNIQUE(orderId)` / `UNIQUE(merchantId, clientVoidId)` (Constitution V).
 */
@Injectable()
export class VoidService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly payments: PaymentsService,
  ) {}

  async voidOrder(user: AuthUser, orderId: string, dto: VoidOrderDto): Promise<VoidResult> {
    const order = await this.findById(user.merchantId, orderId);
    if (!order) throw new NotFoundException('Order not found');

    // Idempotent replay #1: this order is already voided (UNIQUE(orderId)).
    if (order.voids.length > 0) return { order, replay: true };

    // Idempotent replay #2: this device key already produced a void (retry after a dropped reply).
    const replayed = await this.findVoidByClientVoidId(user.merchantId, dto.clientVoidId);
    if (replayed) {
      if (replayed.orderId !== order.id) {
        // The key is already spent on a different sale — voiding this one would be a silent
        // misattribution, so refuse rather than guess.
        throw new ConflictException('clientVoidId already used for another order');
      }
      return { order, replay: true };
    }

    if (order.status !== OrderStatus.COMPLETED) {
      throw new ConflictException('Only a COMPLETED order can be voided');
    }

    // Void is same-business-day only (Asia/Jakarta). Older sales must be corrected
    // with a refund instead — a full void of a past day would distort closed books.
    if (jakartaDayKey(order.createdAt) !== jakartaDayKey(new Date())) {
      throw new ConflictException({
        code: 'VOID_WINDOW_EXPIRED',
        message: 'Voids are only allowed on the same day — issue a refund instead',
      });
    }

    try {
      await this.prisma.$transaction(async (tx) => {
        // 1. The void itself — append-only; the order is left exactly as it was.
        const orderVoid = await tx.orderVoid.create({
          data: {
            merchantId: user.merchantId,
            outletId: order.outletId,
            orderId: order.id,
            clientVoidId: dto.clientVoidId ?? null,
            reason: dto.reason ?? null,
            voidedById: user.staffId,
          },
        });

        // 2. Stock restore — invert exactly what this sale deducted, from the ledger itself
        //    (the ledger is the source of truth; `trackInventory` may have changed since).
        const saleMovements = await tx.inventoryMovement.findMany({
          where: {
            merchantId: user.merchantId,
            refType: 'ORDER',
            refId: order.id,
            reason: InventoryReason.SALE,
          },
        });
        for (const m of saleMovements) {
          const restore = m.qtyDelta.negated();
          await tx.inventoryMovement.create({
            data: {
              merchantId: user.merchantId,
              outletId: m.outletId,
              variantId: m.variantId,
              qtyDelta: restore,
              reason: InventoryReason.VOID_RESTORE,
              refType: 'ORDER_VOID',
              refId: orderVoid.id,
              createdById: user.staffId,
            },
          });
          await tx.inventoryStock.upsert({
            where: { outletId_variantId: { outletId: m.outletId, variantId: m.variantId } },
            create: {
              merchantId: user.merchantId,
              outletId: m.outletId,
              variantId: m.variantId,
              quantityOnHand: restore,
            },
            update: { quantityOnHand: { increment: restore } },
          });
        }

        // 3. Money back out — a NEW payment per captured charge; originals stay immutable.
        const charges = order.payments.filter(
          (p) => p.direction === PaymentDirection.CHARGE && p.status === PaymentStatus.PAID,
        );
        for (const charge of charges) {
          const reversal = this.payments.reverse(charge.method, {
            amount: charge.amount,
            reversalType: ReversalType.VOID,
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

        // 4. Audit — who voided what, and the state either side of it (Constitution VI).
        await tx.auditLog.create({
          data: {
            merchantId: user.merchantId,
            outletId: order.outletId,
            actorId: user.staffId,
            action: 'VOID',
            entityType: 'Order',
            entityId: order.id,
            before: {
              status: order.status,
              effectiveStatus: deriveEffectiveStatus(order),
              grandTotal: order.grandTotal,
            },
            after: {
              status: order.status, // unchanged — the order is immutable
              effectiveStatus: 'VOIDED',
              orderVoidId: orderVoid.id,
              reason: dto.reason ?? null,
              restoredMovements: saleMovements.length,
              reversedPayments: charges.length,
            },
          },
        });
      });
    } catch (e) {
      // A concurrent void of the same order (or the same clientVoidId) lost the race: the unique
      // constraints hold the line, and the retry simply returns the winner's result.
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
        const existing = await this.findById(user.merchantId, orderId);
        if (existing?.voids.length) return { order: existing, replay: true };
      }
      throw e;
    }

    const updated = await this.findById(user.merchantId, orderId);
    return { order: updated!, replay: false };
  }

  private async findById(merchantId: string, id: string) {
    return this.prisma.order.findFirst({ where: { id, merchantId }, include: ORDER_INCLUDE });
  }

  /** The void a previously-recorded `clientVoidId` produced, if any. */
  private async findVoidByClientVoidId(merchantId: string, clientVoidId?: string) {
    if (!clientVoidId) return null;
    return this.prisma.orderVoid.findUnique({
      where: { merchantId_clientVoidId: { merchantId, clientVoidId } },
    });
  }
}

/** Calendar day in Asia/Jakarta (UTC+7) as YYYY-MM-DD — the business-day key. */
function jakartaDayKey(d: Date): string {
  return new Date(d.getTime() + 7 * 3600_000).toISOString().slice(0, 10);
}
