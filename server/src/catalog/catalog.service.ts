import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class CatalogService {
  constructor(private readonly prisma: PrismaService) {}

  /** Minimal, read-only, outlet-scoped catalog for US1 (mutation lives in US2). */
  async getCatalog(merchantId: string, outletId: string) {
    const outlet = await this.prisma.outlet.findFirst({ where: { id: outletId, merchantId } });
    if (!outlet) throw new NotFoundException('Outlet not found in this merchant');

    const [taxRule, products, productOutlets, stockRows] = await Promise.all([
      this.prisma.taxRule.findFirst({ where: { merchantId, outletId, isActive: true } }),
      this.prisma.product.findMany({
        where: { merchantId },
        include: {
          category: true,
          variants: true,
          modifierGroups: { include: { modifiers: true } },
        },
        orderBy: { name: 'asc' },
      }),
      this.prisma.productOutlet.findMany({ where: { merchantId, outletId } }),
      this.prisma.inventoryStock.findMany({ where: { merchantId, outletId } }),
    ]);

    const overrideByProduct = new Map(productOutlets.map((po) => [po.productId, po]));
    // Current on-hand per variant for this outlet (Constitution: stock is a projection).
    const stockByVariant = new Map(stockRows.map((s) => [s.variantId, Number(s.quantityOnHand)]));

    return {
      outletId,
      outletName: outlet.name,
      // Drives the app's checkout vs confirm-order behaviour (per-outlet setting).
      paymentMode: outlet.paymentMode,
      taxRule: taxRule
        ? {
            label: taxRule.label,
            rateBps: taxRule.rateBps,
            serviceChargeBps: taxRule.serviceChargeBps,
            serviceLabel: taxRule.serviceLabel,
          }
        : null,
      products: products.map((p) => {
        const override = overrideByProduct.get(p.id);
        return {
          id: p.id,
          name: p.name,
          categoryId: p.categoryId,
          categoryName: p.category.name,
          imageUrl: p.imageUrl,
          isAvailable: override ? override.isAvailable : p.isAvailable,
          variants: p.variants.map((v) => ({
            id: v.id,
            name: v.name,
            price: v.price,
            sku: v.sku,
            isDefault: v.isDefault,
            isAvailable: v.isAvailable,
            trackInventory: v.trackInventory,
            // Remaining quantity for stock-tracked variants; null = not tracked (unlimited).
            stock: v.trackInventory ? (stockByVariant.get(v.id) ?? 0) : null,
          })),
          modifierGroups: p.modifierGroups.map((g) => ({
            id: g.id,
            name: g.name,
            minSelect: g.minSelect,
            maxSelect: g.maxSelect,
            required: g.required,
            modifiers: g.modifiers.map((m) => ({ id: m.id, name: m.name, priceDelta: m.priceDelta })),
          })),
        };
      }),
    };
  }
}
