import { BadRequestException, Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { UpdateVariantDto } from './dto';

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
