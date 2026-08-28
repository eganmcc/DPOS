/* eslint-disable no-console */
// Grocery catalog seed for "Toko Sembako Demo". Idempotent:
//  - existing products (matched by name) get their imageUrl refreshed;
//  - missing products are created (variant + opening stock at the HQ outlet).
// Run AFTER scripts/provision-grocery-images.ts has uploaded the photos to S3.
//   npx ts-node prisma/seed-grocery-menu.ts
import { PrismaClient, ProductType } from '@prisma/client';
import { GROCERY, menuImageUrl } from './grocery-data';

const prisma = new PrismaClient();

async function main(): Promise<void> {
  const merchant = await prisma.merchant.findFirst({ where: { name: 'Toko Sembako Demo' } });
  if (!merchant) {
    console.log('grocery merchant not found — run seed-portal.ts first');
    return;
  }
  const outlets = await prisma.outlet.findMany({ where: { merchantId: merchant.id } });
  const hq = outlets.find((o) => o.code === 'HQ') ?? outlets.find((o) => /pusat/i.test(o.name)) ?? outlets[0];
  const owner = await prisma.staff.findFirst({ where: { merchantId: merchant.id, role: 'OWNER' } });
  const createdById = owner?.id ?? 'seed';

  const catCache = new Map<string, string>();
  async function categoryId(name: string): Promise<string> {
    if (catCache.has(name)) return catCache.get(name)!;
    let cat = await prisma.category.findFirst({ where: { merchantId: merchant!.id, name } });
    cat ??= await prisma.category.create({ data: { merchantId: merchant!.id, name } });
    catCache.set(name, cat.id);
    return cat.id;
  }

  let created = 0;
  let updated = 0;
  for (const item of GROCERY) {
    const imageUrl = menuImageUrl(item.name);
    const existing = await prisma.product.findFirst({
      where: { merchantId: merchant.id, name: item.name },
    });
    if (existing) {
      await prisma.product.update({ where: { id: existing.id }, data: { imageUrl } });
      updated += 1;
      continue;
    }
    const product = await prisma.product.create({
      data: {
        merchantId: merchant.id,
        categoryId: await categoryId(item.category),
        name: item.name,
        type: ProductType.RETAIL,
        imageUrl,
      },
    });
    const variant = await prisma.productVariant.create({
      data: {
        productId: product.id,
        name: item.variant,
        price: item.price,
        costPrice: item.cost,
        sku: item.sku,
        isDefault: true,
        trackInventory: true,
      },
    });
    if (hq) {
      await prisma.inventoryStock.create({
        data: { merchantId: merchant.id, outletId: hq.id, variantId: variant.id, quantityOnHand: 100 },
      });
      await prisma.inventoryMovement.create({
        data: {
          merchantId: merchant.id,
          outletId: hq.id,
          variantId: variant.id,
          qtyDelta: 100,
          reason: 'RECEIVE',
          refType: 'SEED',
          createdById,
        },
      });
    }
    created += 1;
  }
  console.log(`grocery menu: created ${created}, image-refreshed ${updated} (of ${GROCERY.length})`);
}

main()
  .then(() => prisma.$disconnect())
  .catch(async (e) => {
    console.error(e);
    await prisma.$disconnect();
    process.exit(1);
  });
