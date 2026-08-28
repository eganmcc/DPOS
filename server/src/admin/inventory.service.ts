import { BadRequestException, Injectable } from '@nestjs/common';
import { InventoryReason } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { AuthUser } from '../auth/auth.types';
import { AdjustStockDto } from './dto';

@Injectable()
export class InventoryService {
  constructor(private readonly prisma: PrismaService) {}

  /** Stock-tracked variants and their on-hand quantity for one outlet. */
  async list(merchantId: string, outletId: string) {
    if (!outletId) throw new BadRequestException('outletId is required');
    await this.assertOutlet(merchantId, outletId);
    const [variants, stock] = await Promise.all([
      this.prisma.productVariant.findMany({
        where: { product: { merchantId }, trackInventory: true },
        include: { product: { select: { name: true } } },
        orderBy: { name: 'asc' },
      }),
      this.prisma.inventoryStock.findMany({ where: { merchantId, outletId } }),
    ]);
    const onHand = new Map(stock.map((s) => [s.variantId, Number(s.quantityOnHand)]));
    return variants.map((v) => ({
      variantId: v.id,
      productName: v.product.name,
      variantName: v.name,
      sku: v.sku,
      quantityOnHand: onHand.get(v.id) ?? 0,
    }));
  }

  /**
   * Set a variant's on-hand for an outlet. Writes the difference as an ADJUSTMENT
   * movement and updates the projection in one transaction (Constitution IV:
   * the ledger is the source of truth; the balance is never edited on its own).
   */
  async adjust(user: AuthUser, dto: AdjustStockDto) {
    await this.assertOutlet(user.merchantId, dto.outletId);
    const variant = await this.prisma.productVariant.findFirst({
      where: { id: dto.variantId, product: { merchantId: user.merchantId } },
    });
    if (!variant) throw new BadRequestException('Variant not found in this merchant');

    return this.prisma.$transaction(async (tx) => {
      const current = await tx.inventoryStock.findUnique({
        where: { outletId_variantId: { outletId: dto.outletId, variantId: dto.variantId } },
      });
      const from = current ? Number(current.quantityOnHand) : 0;
      const delta = dto.quantityOnHand - from;
      if (delta !== 0) {
        await tx.inventoryMovement.create({
          data: {
            merchantId: user.merchantId,
            outletId: dto.outletId,
            variantId: dto.variantId,
            qtyDelta: delta,
            reason: InventoryReason.ADJUSTMENT,
            refType: 'ADMIN',
            refId: null,
            createdById: user.staffId,
          },
        });
      }
      await tx.inventoryStock.upsert({
        where: { outletId_variantId: { outletId: dto.outletId, variantId: dto.variantId } },
        create: {
          merchantId: user.merchantId,
          outletId: dto.outletId,
          variantId: dto.variantId,
          quantityOnHand: dto.quantityOnHand,
        },
        update: { quantityOnHand: dto.quantityOnHand },
      });
      return { variantId: dto.variantId, quantityOnHand: dto.quantityOnHand, delta };
    });
  }

  private async assertOutlet(merchantId: string, outletId: string) {
    const o = await this.prisma.outlet.findFirst({ where: { id: outletId, merchantId } });
    if (!o) throw new BadRequestException('Outlet not found in this merchant');
  }
}
