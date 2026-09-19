import {
  BadRequestException,
  ConflictException,
  ForbiddenException,

  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InventoryReason, Prisma, PaymentDirection, PaymentMethod } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { acceptsOpenAmountLines, isUmiMerchant } from '../common/business-size';
import { isUmiRestrictedTender } from '../payments/tenders';
import { PaymentsService } from '../payments/payments.service';
import {
  computeOrder,
  ModifierInfo,
  OrderComputeInput,
  TaxRuleInfo,
  VariantInfo,
} from '../common/money';
import { AuthUser } from '../auth/auth.types';
import {
  LineDto,
  OrderSubmitDto,
  OrderHistoryQuery,
  OrderReviseDto,
  SettleOrderDto,
  CancelOrderDto,
} from './dto';
import { ORDER_INCLUDE, OrderWithRelations } from './order.mapper';
import { resolveCorrectionApprover } from './approval.util';

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

    // Open bill = confirm now, pay later (no payment in the request). Dine-in open
    // bills are keyed by table, so a table can hold only one open bill at a time.
    const isOpenBill = !dto.payment;
    const normTable = dto.tableLabel?.trim().toUpperCase() || null;
    if (isOpenBill && normTable) {
      const clash = await this.prisma.order.findFirst({
        where: {
          merchantId: user.merchantId,
          outletId: dto.outletId,
          status: 'AWAITING_PAYMENT',
          tableLabel: normTable,
        },
      });
      if (clash) throw new ConflictException(`Table ${normTable} already has an open bill`);
    }

    // A sale read off a paper nota carries that nota's own number (specs/009). One nota is one
    // sale: re-photographing a slip must never bill it twice, whether its first transaction is
    // still open or already paid. A voided or cancelled one no longer counts, so a corrected slip
    // can be recorded again. A nota with no readable number simply isn't deduplicated.
    // Two devices submitting the same nota in the same instant could both pass this check; that
    // window is accepted, as for the UMI item cap — the normal case is one phone reading one slip.
    const notaNumber = dto.notaNumber?.trim() || null;
    if (notaNumber) {
      const already = await this.prisma.order.findFirst({
        where: {
          merchantId: user.merchantId,
          outletId: dto.outletId,
          channel: 'POS',
          externalOrderRef: notaNumber,
          status: { in: ['AWAITING_PAYMENT', 'COMPLETED'] },
          voids: { none: {} },
        },
        select: { id: true, status: true },
      });
      if (already) {
        throw new ConflictException({
          code: 'NOTA_ALREADY_RECORDED',
          message: `Nota ${notaNumber} is already recorded.`,
          orderId: already.id,
          status: already.status,
        });
      }
    }

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
          isOpenAmount: v.product.isOpenAmount,
        },
      ]),
    );
    await this.assertOpenAmountLines(user, dto.lines, variantMap);

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
        amount: l.amount ?? null,
        label: l.label ?? null,
      })),
      orderDiscount: dto.orderDiscount ?? null,
    };

    // SERVER-AUTHORITATIVE: recompute everything; any client totals are ignored.
    const computed = computeOrder(computeInput, variantMap, modifierMap, taxRule);

    if (dto.payment) await this.assertTenderAllowed(user.merchantId, dto.payment.method);

    // Backend-owned payment — only when settling immediately. Open bills carry no
    // payment yet; the stock reservation below happens either way.
    const charge = dto.payment
      ? this.payments.charge(dto.payment.method, computed.grandTotal, {
          tendered: dto.payment.tendered ?? null,
          edc: dto.payment.edc ?? null,
          wallet: dto.payment.wallet ?? null,
        })
      : null;

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
            tableLabel: normTable,
            // The paper nota's own number and customer, when the sale was read from one. Text only.
            externalOrderRef: notaNumber,
            customerName: dto.customerName?.trim() || null,
            status: isOpenBill ? 'AWAITING_PAYMENT' : 'COMPLETED',
            subtotal: computed.subtotal,
            discountTotal: computed.discountTotal,
            taxTotal: computed.taxTotal,
            serviceChargeTotal: computed.serviceChargeTotal,
            grandTotal: computed.grandTotal,
            taxLabelSnapshot: computed.taxLabelSnapshot,
            taxRateBpsSnapshot: computed.taxRateBpsSnapshot,
            serviceChargeLabelSnapshot: computed.serviceChargeLabelSnapshot,
            serviceChargeRateBpsSnapshot: computed.serviceChargeRateBpsSnapshot,
            closedAt: isOpenBill ? null : new Date(),
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

        // Payment (CHARGE) — skipped for an open bill (settled later).
        if (charge) {
          await tx.payment.create({
            data: {
              merchantId: user.merchantId,
              orderId: order.id,
              direction: PaymentDirection.CHARGE,
              method: charge.method,
              amount: charge.amount,
              status: charge.status,
              providerRef: charge.providerRef ?? null,
              providerMeta: (charge.providerMeta ?? undefined) as Prisma.InputJsonValue | undefined,
              tendered: charge.tendered ?? null,
              change: charge.change ?? null,
              paidAt: new Date(),
            },
          });
        }

        // Inventory: for stock-tracked variants, decrement only if enough is on hand.
        // Aggregate per variant (a variant may appear on several lines) and use a
        // conditional update so an order can never oversell or drive stock negative;
        // insufficient stock rolls the whole sale back (Constitution: stock enforcement).
        const neededByVariant = new Map<string, number>();
        for (const cl of computed.lines) {
          if (!cl.trackInventory) continue;
          neededByVariant.set(cl.variantId, (neededByVariant.get(cl.variantId) ?? 0) + cl.qty);
        }
        for (const [variantId, qty] of neededByVariant) {
          const dec = await tx.inventoryStock.updateMany({
            where: { outletId: dto.outletId, variantId, quantityOnHand: { gte: qty } },
            data: { quantityOnHand: { decrement: qty } },
          });
          if (dec.count === 0) {
            const name =
              computed.lines.find((l) => l.variantId === variantId)?.productNameSnapshot ?? 'item';
            throw new BadRequestException(`Insufficient stock for ${name}`);
          }
          await tx.inventoryMovement.create({
            data: {
              merchantId: user.merchantId,
              outletId: dto.outletId,
              variantId,
              qtyDelta: -qty,
              reason: InventoryReason.SALE,
              refType: 'ORDER',
              refId: order.id,
              createdById: user.staffId,
            },
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

  /**
   * Card and e-wallet acceptance needs an acquirer relationship a one-person Ultra Mikro
   * business does not have, so UMI stays on cash and QRIS. Server-side because a hidden
   * button is not a rule (Constitution VI) — the app hides them as well, for a clean till.
   */
  private async assertTenderAllowed(merchantId: string, method: PaymentMethod): Promise<void> {
    if (!isUmiRestrictedTender(method)) return;
    if (await isUmiMerchant(this.prisma, merchantId)) {
      throw new ForbiddenException({
        code: "UMI_TENDER_NOT_AVAILABLE",
        message: "Ultra Mikro accepts cash and QRIS. Contact DPOS to enable card or e-wallet.",
        method,
      });
    }
  }

  /**
   * The gate on the one monetary value a client may originate (Constitution III, open-amount
   * lines, v1.8.0). Applied to BOTH order entry points — `checkout` and `revise` take the same
   * `LineDto[]` into the same `computeOrder`, so gating only one leaves the other as a back door.
   *
   * Every condition is decided here, from the database, never from a field in the request. And
   * every violation THROWS: an ignored `amount` would still price the sale correctly off the
   * catalog, which looks like success while hiding that a client tried to set a price at all —
   * and silence is how a narrow exception quietly becomes a general price override.
   */
  private async assertOpenAmountLines(
    user: AuthUser,
    lines: LineDto[],
    variants: Map<string, VariantInfo>,
  ): Promise<void> {
    const touchesOpenAmount = lines.some(
      (l) => l.amount != null || l.label != null || variants.get(l.variantId)?.isOpenAmount,
    );
    if (!touchesOpenAmount) return;

    if (!(await acceptsOpenAmountLines(this.prisma, user.merchantId))) {
      throw new ForbiddenException({
        code: 'OPEN_AMOUNT_NOT_AVAILABLE',
        message: 'This merchant sells from a catalog; a line price cannot be set by the client.',
      });
    }

    lines.forEach((l, idx) => {
      const v = variants.get(l.variantId);
      if (!v?.isOpenAmount) {
        if (l.amount != null) {
          throw new BadRequestException({
            code: 'AMOUNT_ON_CATALOG_LINE',
            message: `Line ${idx} set an amount on a catalog item, which is priced from the catalog.`,
          });
        }
        // A label would rename a catalog item in this sale's history (Constitution III, v1.9.0).
        if (l.label != null) {
          throw new BadRequestException({
            code: 'LABEL_ON_CATALOG_LINE',
            message: `Line ${idx} set a label on a catalog item, which is named by the catalog.`,
          });
        }
        return;
      }
      // An open-amount line with no amount would otherwise price off the placeholder and sell for
      // Rp 0 — the one failure here that loses money silently rather than loudly.
      if (l.amount == null) {
        throw new BadRequestException({
          code: 'OPEN_AMOUNT_REQUIRED',
          message: `Line ${idx} needs an amount.`,
        });
      }
      if (l.qty !== 1) {
        throw new BadRequestException({
          code: 'OPEN_AMOUNT_QTY_INVALID',
          message: `Line ${idx} must have qty 1; the keyed amount is the whole line.`,
        });
      }
      if (l.modifierIds?.length) {
        throw new BadRequestException({
          code: 'OPEN_AMOUNT_MODIFIERS_INVALID',
          message: `Line ${idx} cannot carry modifiers.`,
        });
      }
      // The cashier keys the net amount, so a discount on top would be counted twice.
      if (l.lineDiscount) {
        throw new BadRequestException({
          code: 'OPEN_AMOUNT_DISCOUNT_INVALID',
          message: `Line ${idx} cannot carry a discount; key the net amount.`,
        });
      }
    });
  }

  async findById(merchantId: string, id: string) {
    return this.prisma.order.findFirst({ where: { id, merchantId }, include: ORDER_INCLUDE });
  }

  /**
   * Settle an open bill: append a CHARGE and flip AWAITING_PAYMENT → COMPLETED.
   * Stock was already reserved at confirm time, so this never touches inventory.
   * Idempotent — a retry (or a concurrent settle) finds it COMPLETED and replays.
   */
  async settle(user: AuthUser, orderId: string, dto: SettleOrderDto): Promise<CheckoutResult> {
    const order = await this.findById(user.merchantId, orderId);
    if (!order) throw new NotFoundException('Order not found');
    if (order.status === 'COMPLETED') return { order, replay: true };
    if (order.status !== 'AWAITING_PAYMENT') {
      throw new ConflictException('Only an open bill can be settled');
    }

    await this.assertTenderAllowed(user.merchantId, dto.payment.method);

    // Charge against the order's stored, server-authoritative grand total.
    const charge = this.payments.charge(dto.payment.method, order.grandTotal, {
      tendered: dto.payment.tendered ?? null,
      edc: dto.payment.edc ?? null,
      wallet: dto.payment.wallet ?? null,
    });

    let raced = false;
    await this.prisma.$transaction(async (tx) => {
      // The conditional flip is the concurrency guard: exactly one settle wins.
      const flip = await tx.order.updateMany({
        where: { id: order.id, status: 'AWAITING_PAYMENT' },
        data: { status: 'COMPLETED', closedAt: new Date() },
      });
      if (flip.count === 0) {
        raced = true;
        return;
      }
      await tx.payment.create({
        data: {
          merchantId: user.merchantId,
          orderId: order.id,
          direction: PaymentDirection.CHARGE,
          method: charge.method,
          amount: charge.amount,
          status: charge.status,
          providerRef: charge.providerRef ?? null,
          providerMeta: (charge.providerMeta ?? undefined) as Prisma.InputJsonValue | undefined,
          tendered: charge.tendered ?? null,
          change: charge.change ?? null,
          paidAt: new Date(),
        },
      });
    });

    const settled = await this.findById(user.merchantId, orderId);
    if (raced) {
      if (settled && settled.status === 'COMPLETED') return { order: settled, replay: true };
      throw new ConflictException('Order already settled');
    }
    return { order: settled!, replay: false };
  }

  /**
   * Edit an open bill (AWAITING_PAYMENT only): replace its lines/discount/table with a
   * server-authoritative recompute, adjusting reserved stock by the NET change per
   * variant. The inventory ledger stays append-only — the original SALE movements are
   * untouched and a single ADJUSTMENT movement records the revision delta (a positive
   * qtyDelta releases stock, a negative one reserves more; an increase can still
   * oversell-guard). COMPLETED orders are never editable (Constitution IV).
   */
  async revise(user: AuthUser, orderId: string, dto: OrderReviseDto): Promise<CheckoutResult> {
    const order = await this.findById(user.merchantId, orderId);
    if (!order) throw new NotFoundException('Order not found');
    if (order.status !== 'AWAITING_PAYMENT') {
      throw new ConflictException('Only an open bill can be edited');
    }

    // Validate the new lines' variants + modifiers (must belong to this merchant).
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
        { id: v.id, productName: v.product.name, sku: v.sku, price: v.price, costPrice: v.costPrice, trackInventory: v.trackInventory, isOpenAmount: v.product.isOpenAmount },
      ]),
    );
    // Revise is the second door into computeOrder with client-supplied lines. Without this, a
    // catalog merchant refused an `amount` at checkout could simply send it here instead.
    await this.assertOpenAmountLines(user, dto.lines, variantMap);
    const modifierIds = [...new Set(dto.lines.flatMap((l) => l.modifierIds ?? []))];
    const modifiers = modifierIds.length
      ? await this.prisma.modifier.findMany({
          where: { id: { in: modifierIds }, group: { product: { merchantId: user.merchantId } } },
          include: { group: true },
        })
      : [];
    if (modifiers.length !== modifierIds.length) {
      throw new BadRequestException('One or more modifiers are invalid for this merchant');
    }
    const modifierMap = new Map<string, ModifierInfo>(
      modifiers.map((m) => [m.id, { id: m.id, name: m.name, priceDelta: m.priceDelta }]),
    );
    await this.validateModifierSelection(dto.lines, variants, modifiers);

    const taxRuleRow = await this.prisma.taxRule.findFirst({
      where: { merchantId: user.merchantId, outletId: order.outletId, isActive: true },
    });
    const taxRule: TaxRuleInfo = taxRuleRow
      ? { label: taxRuleRow.label, rateBps: taxRuleRow.rateBps, serviceChargeBps: taxRuleRow.serviceChargeBps, serviceLabel: taxRuleRow.serviceLabel }
      : { label: 'NONE', rateBps: 0, serviceChargeBps: null, serviceLabel: null };

    const computed = computeOrder(
      {
        lines: dto.lines.map((l) => ({ variantId: l.variantId, qty: l.qty, note: l.note, modifierIds: l.modifierIds, lineDiscount: l.lineDiscount ?? null, amount: l.amount ?? null, label: l.label ?? null })),
        orderDiscount: dto.orderDiscount ?? null,
      },
      variantMap,
      modifierMap,
      taxRule,
    );
    const newType = dto.type ?? order.type;
    // A dine-in bill keeps/updates its table; a takeaway bill has none.
    const normTable =
      newType === 'DINE_IN' ? dto.tableLabel?.trim().toUpperCase() || order.tableLabel : null;

    // A table holds at most one open bill — reject a move onto a table another
    // open bill already occupies (the bill being edited is excluded).
    if (normTable) {
      const clash = await this.prisma.order.findFirst({
        where: {
          merchantId: user.merchantId,
          outletId: order.outletId,
          status: 'AWAITING_PAYMENT',
          tableLabel: normTable,
          id: { not: order.id },
        },
        select: { id: true },
      });
      if (clash) throw new ConflictException('That table already has an open bill');
    }

    // trackInventory for the OLD line variants (to compute the release side of the delta).
    const oldVariants = await this.prisma.productVariant.findMany({
      where: { id: { in: [...new Set(order.lines.map((l) => l.variantId))] } },
      select: { id: true, trackInventory: true },
    });
    const oldTrack = new Map(oldVariants.map((v) => [v.id, v.trackInventory]));

    await this.prisma.$transaction(async (tx) => {
      const still = await tx.order.findFirst({
        where: { id: order.id, merchantId: user.merchantId, status: 'AWAITING_PAYMENT' },
      });
      if (!still) throw new ConflictException('Only an open bill can be edited');

      // Net stock delta per variant = new reserved - old reserved (tracked variants only).
      const oldByVariant = new Map<string, number>();
      for (const l of order.lines) {
        if (!oldTrack.get(l.variantId)) continue;
        oldByVariant.set(l.variantId, (oldByVariant.get(l.variantId) ?? 0) + Number(l.qty));
      }
      const newByVariant = new Map<string, number>();
      for (const cl of computed.lines) {
        if (!cl.trackInventory) continue;
        newByVariant.set(cl.variantId, (newByVariant.get(cl.variantId) ?? 0) + cl.qty);
      }
      for (const variantId of new Set([...oldByVariant.keys(), ...newByVariant.keys()])) {
        const delta = (newByVariant.get(variantId) ?? 0) - (oldByVariant.get(variantId) ?? 0);
        if (delta === 0) continue;
        if (delta > 0) {
          const dec = await tx.inventoryStock.updateMany({
            where: { outletId: order.outletId, variantId, quantityOnHand: { gte: delta } },
            data: { quantityOnHand: { decrement: delta } },
          });
          if (dec.count === 0) {
            const name = computed.lines.find((l) => l.variantId === variantId)?.productNameSnapshot ?? 'item';
            throw new BadRequestException(`Insufficient stock for ${name}`);
          }
        } else {
          await tx.inventoryStock.updateMany({
            where: { outletId: order.outletId, variantId },
            data: { quantityOnHand: { increment: -delta } },
          });
        }
        await tx.inventoryMovement.create({
          data: {
            merchantId: user.merchantId,
            outletId: order.outletId,
            variantId,
            qtyDelta: -delta, // reserve more = negative; release = positive
            reason: InventoryReason.ADJUSTMENT,
            refType: 'ORDER_REVISE',
            refId: order.id,
            createdById: user.staffId,
          },
        });
      }

      // Replace the lines + discounts (an open bill is pre-payment, not immutable history).
      await tx.orderDiscount.deleteMany({ where: { orderId: order.id } });
      await tx.orderLine.deleteMany({ where: { orderId: order.id } });
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
      await tx.order.update({
        where: { id: order.id },
        data: {
          type: newType,
          tableLabel: normTable,
          subtotal: computed.subtotal,
          discountTotal: computed.discountTotal,
          taxTotal: computed.taxTotal,
          serviceChargeTotal: computed.serviceChargeTotal,
          grandTotal: computed.grandTotal,
          taxLabelSnapshot: computed.taxLabelSnapshot,
          taxRateBpsSnapshot: computed.taxRateBpsSnapshot,
          serviceChargeLabelSnapshot: computed.serviceChargeLabelSnapshot,
          serviceChargeRateBpsSnapshot: computed.serviceChargeRateBpsSnapshot,
        },
      });
    });

    const updated = await this.findById(user.merchantId, orderId);
    return { order: updated!, replay: false };
  }

  /**
   * Cancel an unpaid open bill (AWAITING_PAYMENT → CANCELLED): release the reserved
   * stock and close the bill. No money moves (nothing was paid). Owner/manager
   * self-authorize; a cashier must present a manager PIN. Idempotent-safe via a
   * conditional status flip so a retry never double-restores stock.
   */
  async cancelOpenBill(
    user: AuthUser,
    orderId: string,
    dto: CancelOrderDto,
  ): Promise<CheckoutResult> {
    const order = await this.prisma.order.findFirst({
      where: { id: orderId, merchantId: user.merchantId },
      include: ORDER_INCLUDE,
    });
    if (!order) throw new NotFoundException('Order not found');
    if (order.status !== 'AWAITING_PAYMENT') {
      throw new ConflictException('Only an open (unpaid) bill can be cancelled');
    }

    const { approvedById, basis: approvalBasis } = await resolveCorrectionApprover(
      this.prisma,
      user,
      dto.approverPin,
    );

    await this.prisma.$transaction(async (tx) => {
      // Win the flip or bail — prevents a double stock restore on a concurrent retry.
      const flip = await tx.order.updateMany({
        where: { id: order.id, merchantId: user.merchantId, status: 'AWAITING_PAYMENT' },
        data: { status: 'CANCELLED', closedAt: new Date() },
      });
      if (flip.count === 0) throw new ConflictException('This bill is no longer open');

      // Release exactly what the bill reserved, from the ledger (the source of truth).
      const reserved = await tx.inventoryMovement.findMany({
        where: {
          merchantId: user.merchantId,
          refType: 'ORDER',
          refId: order.id,
          reason: InventoryReason.SALE,
        },
      });
      for (const m of reserved) {
        const restore = m.qtyDelta.negated();
        await tx.inventoryMovement.create({
          data: {
            merchantId: user.merchantId,
            outletId: m.outletId,
            variantId: m.variantId,
            qtyDelta: restore,
            reason: InventoryReason.ADJUSTMENT,
            refType: 'ORDER_CANCEL',
            refId: order.id,
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

      await tx.auditLog.create({
        data: {
          merchantId: user.merchantId,
          outletId: order.outletId,
          actorId: user.staffId,
          action: 'CANCEL_OPEN_BILL',
          entityType: 'Order',
          entityId: order.id,
          before: { status: 'AWAITING_PAYMENT', grandTotal: order.grandTotal },
          after: {
            status: 'CANCELLED',
            reason: dto.reason,
            approvedById,
            approvalBasis,
            releasedMovements: reserved.length,
          },
        },
      });
    });

    const updated = await this.prisma.order.findFirst({
      where: { id: orderId, merchantId: user.merchantId },
      include: ORDER_INCLUDE,
    });
    return { order: updated!, replay: false };
  }

  /** Open bills (AWAITING_PAYMENT) for one outlet, newest first. Tenant-scoped. */
  async findOpen(merchantId: string, outletId: string): Promise<OrderWithRelations[]> {
    return this.prisma.order.findMany({
      where: { merchantId, outletId, status: 'AWAITING_PAYMENT' },
      include: ORDER_INCLUDE,
      orderBy: { createdAt: 'desc' },
    });
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
