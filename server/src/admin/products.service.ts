import { BadRequestException, Injectable } from '@nestjs/common';
import { BusinessType, InventoryReason, ProductType } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { AuthUser } from '../auth/auth.types';
import { CreateProductDto, UpdateVariantDto } from './dto';

@Injectable()
export class ProductsService {
  constructor(private readonly prisma: PrismaService) {}

  /** Products with their variants (prices live on the variant). */
  async list(merchantId: string) {
    const products = await this.prisma.product.findMany({
      where: { merchantId },
      include: { category: true, variants: { orderBy: { name: 'asc' } } },
      orderBy: { name: 'asc' },
    });
    return products.map((p) => ({
      id: p.id,
      name: p.name,
      categoryName: p.category.name,
      type: p.type,
      isAvailable: p.isAvailable,
      imageUrl: p.imageUrl,
      variants: p.variants.map((v) => ({
        id: v.id,
        name: v.name,
        price: v.price,
        costPrice: v.costPrice,
        sku: v.sku,
        isAvailable: v.isAvailable,
        trackInventory: v.trackInventory,
      })),
    }));
  }

  /**
   * Create a product with one default variant (portal Prices → Add item). Finds or
   * creates the named category; product type follows the merchant's business type.
   * Optionally receives opening stock at an outlet (RECEIVE movement + projection).
   */
  async createProduct(user: AuthUser, dto: CreateProductDto) {
    const merchant = await this.prisma.merchant.findUnique({ where: { id: user.merchantId } });
    if (!merchant) throw new BadRequestException('Merchant not found');

    const sku = dto.sku?.trim() || null;
    if (sku) {
      const clash = await this.prisma.productVariant.findFirst({
        where: { product: { merchantId: user.merchantId }, sku: { equals: sku, mode: 'insensitive' } },
        select: { id: true },
      });
      if (clash) throw new BadRequestException('That SKU is already used by another item');
    }

    const track = dto.trackInventory ?? true;
    const opening = dto.initialStock ?? 0;
    if (opening > 0) {
      if (!track) throw new BadRequestException('Opening stock needs inventory tracking on');
      if (!dto.outletId) throw new BadRequestException('outletId is required for opening stock');
      await this.assertOutlet(user.merchantId, dto.outletId);
    }

    const type =
      merchant.businessType === BusinessType.GROCERY ? ProductType.RETAIL : ProductType.FNB;

    const productId = await this.prisma.$transaction(async (tx) => {
      // Find or create the category by name for this merchant.
      const catName = dto.categoryName.trim();
      const category =
        (await tx.category.findFirst({ where: { merchantId: user.merchantId, name: catName } })) ??
        (await tx.category.create({ data: { merchantId: user.merchantId, name: catName } }));

      const product = await tx.product.create({
        data: {
          merchantId: user.merchantId,
          categoryId: category.id,
          name: dto.name.trim(),
          type,
        },
      });
      const variant = await tx.productVariant.create({
        data: {
          productId: product.id,
          name: dto.variantName?.trim() || 'Regular',
          price: dto.price,
          costPrice: dto.costPrice ?? null,
          sku,
          isDefault: true,
          trackInventory: track,
        },
      });

      if (opening > 0 && dto.outletId) {
        await tx.inventoryStock.create({
          data: {
            merchantId: user.merchantId,
            outletId: dto.outletId,
            variantId: variant.id,
            quantityOnHand: opening,
          },
        });
        await tx.inventoryMovement.create({
          data: {
            merchantId: user.merchantId,
            outletId: dto.outletId,
            variantId: variant.id,
            qtyDelta: opening,
            reason: InventoryReason.RECEIVE,
            refType: 'ADMIN',
            refId: null,
            createdById: user.staffId,
          },
        });
      }
      return product.id;
    });

    return { id: productId };
  }

  private async assertOutlet(merchantId: string, outletId: string) {
    const o = await this.prisma.outlet.findFirst({ where: { id: outletId, merchantId } });
    if (!o) throw new BadRequestException('Outlet not found in this merchant');
  }

  async updateVariant(merchantId: string, variantId: string, dto: UpdateVariantDto) {
    const v = await this.prisma.productVariant.findFirst({
      where: { id: variantId, product: { merchantId } },
    });
    if (!v) throw new BadRequestException('Variant not found in this merchant');

    // Normalize SKU: empty/blank clears it (null). Guard against duplicates within
    // the merchant — barcode scanning in the POS resolves items by SKU.
    let sku: string | null | undefined;
    if (dto.sku !== undefined) {
      sku = dto.sku.trim() || null;
      if (sku) {
        const clash = await this.prisma.productVariant.findFirst({
          where: {
            id: { not: variantId },
            product: { merchantId },
            sku: { equals: sku, mode: 'insensitive' },
          },
          select: { id: true },
        });
        if (clash) throw new BadRequestException('That SKU is already used by another item');
      }
    }

    await this.prisma.productVariant.update({
      where: { id: variantId },
      data: {
        ...(dto.price !== undefined ? { price: dto.price } : {}),
        ...(dto.costPrice !== undefined ? { costPrice: dto.costPrice } : {}),
        ...(dto.isAvailable !== undefined ? { isAvailable: dto.isAvailable } : {}),
        ...(sku !== undefined ? { sku } : {}),
      },
    });
    return { ok: true };
  }
}
