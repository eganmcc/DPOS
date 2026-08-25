import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { InventoryReason, Prisma, PaymentDirection } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { PaymentsService } from '../payments/payments.service';
import {
  computeOrder,
  ModifierInfo,
  OrderComputeInput,
  TaxRuleInfo,
  VariantInfo,
} from '../common/money';
import { AuthUser } from '../auth/auth.types';
import { OrderSubmitDto, OrderHistoryQuery } from './dto';
import { ORDER_INCLUDE, OrderWithRelations } from './order.mapper';

export interface CheckoutResult {
  order: OrderWithRelations;
  replay: boolean;
}

/** The bits of a ModifierGroup the selection rules need. */
interface ModifierGroupRules {
  id: string;
  productId: string;
  name: string;
  minSelect: number;
  maxSelect: number;
  required: boolean;
}

@Injectable()
export class OrdersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly payments: PaymentsService,
  ) {}

  /**
   * Complete a sale. Atomic (single transaction), idempotent on (merchantId, clientOrderId),
   * and server-authoritative for all amounts. Constitution II, III, V.
   */
  async checkout(user: AuthUser, dto: OrderSubmitDto): Promise<CheckoutResult> {
    // Idempotent replay: a retried submit returns the existing order untouched.
    const existing = await this.findByClientOrderId(user.merchantId, dto.clientOrderId);
    if (existing) {
      return { order: existing, replay: true };
    }

    const outlet = await this.prisma.outlet.findFirst({
      where: { id: dto.outletId, merchantId: user.merchantId },
    });
    if (!outlet) throw new NotFoundException('Outlet not found in this merchant');

    // Load & validate the variants (must belong to this merchant).
    const variantIds = [...new Set(dto.lines.map((l) => l.variantId))];
    const variants = await this.prisma.productVariant.findMany({
      where: { id: { in: variantIds }, product: { merchantId: user.merchantId } },
      include: { product: true },
    });
    if (variants.length !== variantIds.length) {
      throw new BadRequestException('One or more variants are invalid for this merchant');
    }
    const variantMap = new Map<string, VariantInfo>(
      variants.map((v) => [
        v.id,
        {
          id: v.id,
          productName: v.product.name,
          sku: v.sku,
          price: v.price,
          costPrice: v.costPrice,
          trackInventory: v.trackInventory,
        },
      ]),
    );

    // Load modifiers referenced by the lines, with their group + product so the
    // selection can be validated rather than merely priced.
    const modifierIds = [...new Set(dto.lines.flatMap((l) => l.modifierIds ?? []))];
    const modifiers = modifierIds.length
      ? await this.prisma.modifier.findMany({
          where: { id: { in: modifierIds }, group: { product: { merchantId: user.merchantId } } },
          include: { group: true },
        })
      : [];
    if (modifiers.length !== modifierIds.length) {
      // Previously unknown ids were silently dropped and the customer was
      // charged as if the modifier did not exist.
      throw new BadRequestException('One or more modifiers are invalid for this merchant');
    }
    const modifierMap = new Map<string, ModifierInfo>(
      modifiers.map((m) => [m.id, { id: m.id, name: m.name, priceDelta: m.priceDelta }]),
    );

    await this.validateModifierSelection(dto.lines, variants, modifiers);

    // Active tax rule for the outlet (zero tax if none configured).
    const taxRuleRow = await this.prisma.taxRule.findFirst({
      where: { merchantId: user.merchantId, outletId: dto.outletId, isActive: true },
    });
    const taxRule: TaxRuleInfo = taxRuleRow
      ? {
          label: taxRuleRow.label,
          rateBps: taxRuleRow.rateBps,
          serviceChargeBps: taxRuleRow.serviceChargeBps,
          serviceLabel: taxRuleRow.serviceLabel,
        }
      : { label: 'NONE', rateBps: 0, serviceChargeBps: null, serviceLabel: null };

    const computeInput: OrderComputeInput = {
      lines: dto.lines.map((l) => ({
        variantId: l.variantId,
        qty: l.qty,
        note: l.note,
        modifierIds: l.modifierIds,
        lineDiscount: l.lineDiscount ?? null,
      })),
      orderDiscount: dto.orderDiscount ?? null,
    };

    // SERVER-AUTHORITATIVE: recompute everything; any client totals are ignored.
    const computed = computeOrder(computeInput, variantMap, modifierMap, taxRule);

    // Backend-owned payment.
    const charge = this.payments.charge(dto.payment.method, computed.grandTotal, {
      tendered: dto.payment.tendered ?? null,
    });

    try {
      const orderId = await this.prisma.$transaction(async (tx) => {
        const order = await tx.order.create({
          data: {
            clientOrderId: dto.clientOrderId,
            merchantId: user.merchantId,
            outletId: dto.outletId,
            deviceId: dto.deviceId ?? null,
            cashierId: user.staffId,
            shiftId: dto.shiftId ?? null,
            type: dto.type,
            tableLabel: dto.tableLabel ?? null,
            status: 'COMPLETED',
            subtotal: computed.subtotal,
            discountTotal: computed.discountTotal,
            taxTotal: computed.taxTotal,
            serviceChargeTotal: computed.serviceChargeTotal,
            grandTotal: computed.grandTotal,
            taxLabelSnapshot: computed.taxLabelSnapshot,
            taxRateBpsSnapshot: computed.taxRateBpsSnapshot,
            serviceChargeLabelSnapshot: computed.serviceChargeLabelSnapshot,
            serviceChargeRateBpsSnapshot: computed.serviceChargeRateBpsSnapshot,
            closedAt: new Date(),
          },
        });

        // Lines (immutable snapshots). Track created line ids for LINE-scope discounts.
        const lineIds: string[] = [];
        for (const cl of computed.lines) {
          const line = await tx.orderLine.create({
            data: {
              orderId: order.id,
              variantId: cl.variantId,
              qty: cl.qty,
              productNameSnapshot: cl.productNameSnapshot,
              skuSnapshot: cl.skuSnapshot,
              unitPriceSnapshot: cl.unitPriceSnapshot,
              costPriceSnapshot: cl.costPriceSnapshot,
              selectedModifiersSnapshot: cl.selectedModifiersSnapshot as unknown as Prisma.InputJsonValue,
              lineDiscount: cl.lineDiscount,
              lineTotal: cl.lineTotal,
            },
          });
          lineIds.push(line.id);
        }

        // Discounts (audit-friendly; discountAmount is server-calculated).
        for (const d of computed.discounts) {
          await tx.orderDiscount.create({
            data: {
              orderId: order.id,
              orderLineId: d.scope === 'LINE' && d.lineIndex != null ? lineIds[d.lineIndex] : null,
              scope: d.scope,
              kind: d.kind,
              value: d.value,
              discountAmount: d.discountAmount,
              reason: d.reason ?? null,
              appliedById: user.staffId,
              approvedById: d.approvedById ?? null,
            },
          });
        }

        // Payment (CHARGE).
        await tx.payment.create({
          data: {
            merchantId: user.merchantId,
            orderId: order.id,
            direction: PaymentDirection.CHARGE,
            method: charge.method,
            amount: charge.amount,
            status: charge.status,
            providerRef: charge.providerRef ?? null,
            tendered: charge.tendered ?? null,
            change: charge.change ?? null,
            paidAt: new Date(),
          },
        });

        // Inventory: negative movement + stock projection, only for tracked variants.
        for (const cl of computed.lines) {
          if (!cl.trackInventory) continue;
          await tx.inventoryMovement.create({
            data: {
              merchantId: user.merchantId,
              outletId: dto.outletId,
              variantId: cl.variantId,
              qtyDelta: -cl.qty,
              reason: InventoryReason.SALE,
              refType: 'ORDER',
              refId: order.id,
              createdById: user.staffId,
            },
          });
          await tx.inventoryStock.upsert({
            where: { outletId_variantId: { outletId: dto.outletId, variantId: cl.variantId } },
            create: {
              merchantId: user.merchantId,
              outletId: dto.outletId,
              variantId: cl.variantId,
              quantityOnHand: -cl.qty,
            },
            update: { quantityOnHand: { decrement: cl.qty } },
          });
        }

        return order.id;
      });

      const order = await this.findById(user.merchantId, orderId);
      return { order: order!, replay: false };
    } catch (e) {
      // Concurrent duplicate submit — the unique (merchantId, clientOrderId) guards it.
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
        const order = await this.findByClientOrderId(user.merchantId, dto.clientOrderId);
        if (order) return { order, replay: true };
      }
      throw e;
    }
  }

  async findById(merchantId: string, id: string) {
    return this.prisma.order.findFirst({ where: { id, merchantId }, include: ORDER_INCLUDE });
  }

  /**
   * Transaction history for one outlet, newest first. Tenant-scoped (Constitution VI): the outlet
   * must belong to the caller's merchant or nothing is returned.
   */
  async findMany(merchantId: string, query: OrderHistoryQuery): Promise<OrderWithRelations[]> {
    const createdAt: Prisma.DateTimeFilter = {};
    if (query.from) createdAt.gte = startOfDay(query.from);
    if (query.to) createdAt.lt = dayAfter(query.to);

    return this.prisma.order.findMany({
      where: {
        merchantId,
        outletId: query.outletId,
        ...(query.from || query.to ? { createdAt } : {}),
      },
      include: ORDER_INCLUDE,
      orderBy: { createdAt: 'desc' },
      take: query.limit ?? 100,
    });
  }

  private async findByClientOrderId(merchantId: string, clientOrderId: string) {
    return this.prisma.order.findUnique({
      where: { merchantId_clientOrderId: { merchantId, clientOrderId } },
      include: ORDER_INCLUDE,
    });
  }

  /**
   * Enforce each product's modifier rules on the server.
   *
   * The app renders these constraints (single-select groups, required groups),
   * but the API is the authority: a stale build or a hand-rolled request must
   * not be able to attach "Less sugar" AND "Normal" to the same drink, or borrow
   * another product's modifiers.
   */
  private async validateModifierSelection(
    lines: { variantId: string; modifierIds?: string[] }[],
    variants: { id: string; productId: string }[],
    modifiers: { id: string; name: string; group: ModifierGroupRules }[],
  ): Promise<void> {
    const productIdByVariant = new Map(variants.map((v) => [v.id, v.productId]));
    const modifierById = new Map(modifiers.map((m) => [m.id, m]));

    // Every group belonging to the products in this order, so required groups
    // are caught even when the client sent nothing for them.
    const productIds = [...new Set(lines.map((l) => productIdByVariant.get(l.variantId)!))];
    const groups = await this.prisma.modifierGroup.findMany({
      where: { productId: { in: productIds } },
    });

    for (const line of lines) {
      const productId = productIdByVariant.get(line.variantId)!;
      const selected = line.modifierIds ?? [];

      if (new Set(selected).size !== selected.length) {
        throw new BadRequestException('Duplicate modifier on a line');
      }

      const countByGroup = new Map<string, number>();
      for (const id of selected) {
        const mod = modifierById.get(id)!;
        if (mod.group.productId !== productId) {
          throw new BadRequestException(
            `Modifier "${mod.name}" does not belong to the product on this line`,
          );
        }
        countByGroup.set(mod.group.id, (countByGroup.get(mod.group.id) ?? 0) + 1);
      }

      for (const group of groups.filter((g) => g.productId === productId)) {
        const count = countByGroup.get(group.id) ?? 0;
        if (count > group.maxSelect) {
          throw new BadRequestException(
            `"${group.name}" allows at most ${group.maxSelect} option(s), got ${count}`,
          );
        }
        const min = group.required ? Math.max(group.minSelect, 1) : group.minSelect;
        if (count < min) {
          throw new BadRequestException(
            `"${group.name}" requires at least ${min} option(s), got ${count}`,
          );
        }
      }
    }
  }
}

/** `YYYY-MM-DD` (device-local calendar day) → inclusive lower bound. */
function startOfDay(day: string): Date {
  return new Date(`${day}T00:00:00.000Z`);
}

/** `YYYY-MM-DD` → exclusive upper bound (start of the next day). */
function dayAfter(day: string): Date {
  const d = new Date(`${day}T00:00:00.000Z`);
  d.setUTCDate(d.getUTCDate() + 1);
  return d;
}
