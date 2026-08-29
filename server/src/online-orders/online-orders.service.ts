import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { randomUUID } from 'crypto';
import {
  InventoryReason,
  OnlineOrderStatus,
  OrderChannel,
  PaymentDirection,
  PaymentMethod,
  Prisma,
} from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { PaymentsService } from '../payments/payments.service';
import { computeOrder, ModifierInfo, TaxRuleInfo, VariantInfo } from '../common/money';
import { ORDER_INCLUDE, OrderWithRelations } from '../orders/order.mapper';

/**
 * Normalized input to the online-order ingestion seam. Both the demo simulator and
 * (future) per-provider webhook adapters produce this shape and call {@link OnlineOrdersService.ingest}.
 */
export interface OnlineOrderInput {
  merchantId: string;
  outletId: string;
  cashierId: string; // acting/system staff that owns the ingested sale
  channel: OrderChannel; // GOFOOD | GRABFOOD | SHOPEEFOOD
  externalOrderRef: string; // platform order code (demo: short number)
  customerName?: string | null;
  clientOrderId?: string; // idempotency key (defaults to a fresh UUID for the demo)
  lines: { variantId: string; qty: number }[];
}

const ONLINE_CHANNELS: OrderChannel[] = [
  OrderChannel.GOFOOD,
  OrderChannel.GRABFOOD,
  OrderChannel.SHOPEEFOOD,
];

const DEMO_CUSTOMERS = ['Budi', 'Siti', 'Andi', 'Rina', 'Dewi', 'Agus', 'Putri', 'Eko'];

@Injectable()
export class OnlineOrdersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly payments: PaymentsService,
  ) {}

  /**
   * Ingest an online-delivery order as a first-class, server-authoritative sale.
   * The platform has already charged the customer, so the order lands COMPLETED
   * (money) + onlineStatus NEW (fulfillment), with a synthetic ONLINE payment and
   * the same inventory decrement + idempotency guard as an in-store checkout.
   * This is the single seam the demo simulator and real webhooks both call.
   */
  async ingest(input: OnlineOrderInput): Promise<OrderWithRelations> {
    const clientOrderId = input.clientOrderId ?? randomUUID();

    const existing = await this.prisma.order.findUnique({
      where: { merchantId_clientOrderId: { merchantId: input.merchantId, clientOrderId } },
      include: ORDER_INCLUDE,
    });
    if (existing) return existing;

    const outlet = await this.prisma.outlet.findFirst({
      where: { id: input.outletId, merchantId: input.merchantId },
    });
    if (!outlet) throw new NotFoundException('Outlet not found in this merchant');
    if (!input.lines.length) throw new BadRequestException('Online order has no lines');

    const variantIds = [...new Set(input.lines.map((l) => l.variantId))];
    const variants = await this.prisma.productVariant.findMany({
      where: { id: { in: variantIds }, product: { merchantId: input.merchantId } },
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

    const taxRuleRow = await this.prisma.taxRule.findFirst({
      where: { merchantId: input.merchantId, outletId: input.outletId, isActive: true },
    });
    const taxRule: TaxRuleInfo = taxRuleRow
      ? {
          label: taxRuleRow.label,
          rateBps: taxRuleRow.rateBps,
          serviceChargeBps: taxRuleRow.serviceChargeBps,
          serviceLabel: taxRuleRow.serviceLabel,
        }
      : { label: 'NONE', rateBps: 0, serviceChargeBps: null, serviceLabel: null };

    // SERVER-AUTHORITATIVE totals (no modifiers/discounts on ingested orders yet).
    const computed = computeOrder(
      { lines: input.lines.map((l) => ({ variantId: l.variantId, qty: l.qty })), orderDiscount: null },
      variantMap,
      new Map<string, ModifierInfo>(),
      taxRule,
    );

    const charge = this.payments.charge(PaymentMethod.ONLINE, computed.grandTotal, { tendered: null });

    const orderId = await this.prisma.$transaction(async (tx) => {
      const order = await tx.order.create({
        data: {
          clientOrderId,
          merchantId: input.merchantId,
          outletId: input.outletId,
          cashierId: input.cashierId,
          type: 'TAKEAWAY',
          status: 'COMPLETED',
          channel: input.channel,
          onlineStatus: OnlineOrderStatus.NEW,
          externalOrderRef: input.externalOrderRef,
          customerName: input.customerName ?? null,
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

      for (const cl of computed.lines) {
        await tx.orderLine.create({
          data: {
            orderId: order.id,
            variantId: cl.variantId,
            qty: cl.qty,
            productNameSnapshot: cl.productNameSnapshot,
            skuSnapshot: cl.skuSnapshot,
            unitPriceSnapshot: cl.unitPriceSnapshot,
            costPriceSnapshot: cl.costPriceSnapshot,
            selectedModifiersSnapshot:
              cl.selectedModifiersSnapshot as unknown as Prisma.InputJsonValue,
            lineDiscount: cl.lineDiscount,
            lineTotal: cl.lineTotal,
          },
        });
      }

      await tx.payment.create({
        data: {
          merchantId: input.merchantId,
          orderId: order.id,
          direction: PaymentDirection.CHARGE,
          method: charge.method,
          amount: charge.amount,
          status: charge.status,
          paidAt: new Date(),
        },
      });

      // Same conditional decrement as checkout — an ingested order never oversells.
      const neededByVariant = new Map<string, number>();
      for (const cl of computed.lines) {
        if (!cl.trackInventory) continue;
        neededByVariant.set(cl.variantId, (neededByVariant.get(cl.variantId) ?? 0) + cl.qty);
      }
      for (const [variantId, qty] of neededByVariant) {
        const dec = await tx.inventoryStock.updateMany({
          where: { outletId: input.outletId, variantId, quantityOnHand: { gte: qty } },
          data: { quantityOnHand: { decrement: qty } },
        });
        if (dec.count === 0) {
          const name =
            computed.lines.find((l) => l.variantId === variantId)?.productNameSnapshot ?? 'item';
          throw new BadRequestException(`Insufficient stock for ${name}`);
        }
        await tx.inventoryMovement.create({
          data: {
            merchantId: input.merchantId,
            outletId: input.outletId,
            variantId,
            qtyDelta: -qty,
            reason: InventoryReason.SALE,
            refType: 'ORDER',
            refId: order.id,
            createdById: input.cashierId,
          },
        });
      }

      return order.id;
    });

    const order = await this.findById(input.merchantId, orderId);
    return order!;
  }

  /** Online orders for an outlet — NEW pinned first (enum order), then newest. */
  async findOnline(
    merchantId: string,
    outletId: string,
    status?: OnlineOrderStatus,
  ): Promise<OrderWithRelations[]> {
    return this.prisma.order.findMany({
      where: {
        merchantId,
        outletId,
        channel: { not: OrderChannel.POS },
        ...(status ? { onlineStatus: status } : {}),
      },
      include: ORDER_INCLUDE,
      orderBy: [{ onlineStatus: 'asc' }, { createdAt: 'desc' }],
      take: 100,
    });
  }

  /** Cashier acknowledges a new online order: NEW → ACCEPTED. Idempotent. */
  async accept(merchantId: string, orderId: string): Promise<OrderWithRelations> {
    const order = await this.prisma.order.findFirst({ where: { id: orderId, merchantId } });
    if (!order) throw new NotFoundException('Order not found');
    if (order.channel === OrderChannel.POS) {
      throw new BadRequestException('Not an online order');
    }
    await this.prisma.order.updateMany({
      where: { id: orderId, merchantId, onlineStatus: OnlineOrderStatus.NEW },
      data: { onlineStatus: OnlineOrderStatus.ACCEPTED },
    });
    const updated = await this.findById(merchantId, orderId);
    return updated!;
  }

  /**
   * DEMO ONLY: fabricate a random online order for the outlet — random vendor, 1–4
   * random in-stock items — and run it through {@link ingest}. Real provider webhooks
   * replace this entry point; the ingestion seam stays the same.
   */
  async simulate(
    merchantId: string,
    outletId: string,
    cashierId: string,
  ): Promise<OrderWithRelations> {
    const outlet = await this.prisma.outlet.findFirst({ where: { id: outletId, merchantId } });
    if (!outlet) throw new NotFoundException('Outlet not found in this merchant');

    // Available variants for the merchant, with this outlet's stock.
    const variants = await this.prisma.productVariant.findMany({
      where: {
        isAvailable: true,
        product: { merchantId, isAvailable: true },
      },
      include: { stock: { where: { outletId } } },
    });
    // Keep only those we can actually sell 1–2 of: untracked, or ≥2 on hand.
    const sellable = variants.filter((v) => {
      if (!v.trackInventory) return true;
      const onHand = Number(v.stock[0]?.quantityOnHand ?? 0);
      return onHand >= 2;
    });
    if (!sellable.length) {
      throw new BadRequestException('No in-stock items available to simulate an online order');
    }

    const channel = ONLINE_CHANNELS[Math.floor(Math.random() * ONLINE_CHANNELS.length)];
    const count = Math.min(sellable.length, 1 + Math.floor(Math.random() * 4)); // 1..4 distinct items
    const shuffled = [...sellable].sort(() => Math.random() - 0.5).slice(0, count);
    const lines = shuffled.map((v) => ({ variantId: v.id, qty: 1 + Math.floor(Math.random() * 2) })); // qty 1..2
    const externalOrderRef = String(1000 + Math.floor(Math.random() * 9000)); // 4-digit
    const customerName = DEMO_CUSTOMERS[Math.floor(Math.random() * DEMO_CUSTOMERS.length)];

    return this.ingest({
      merchantId,
      outletId,
      cashierId,
      channel,
      externalOrderRef,
      customerName,
      lines,
    });
  }

  private async findById(merchantId: string, id: string) {
    return this.prisma.order.findFirst({ where: { id, merchantId }, include: ORDER_INCLUDE });
  }
}
