/* eslint-disable no-console */
// One-off: make every variant stock-tracked and seed a random 1..15 on-hand
// quantity per (outlet, variant). Idempotent — re-running just re-randomises.
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();
const rnd = () => Math.floor(Math.random() * 15) + 1; // 1..15

async function main(): Promise<void> {
  // 1) Every sellable variant is stock-tracked.
  const tracked = await prisma.productVariant.updateMany({ data: { trackInventory: true } });
  console.log(`trackInventory=true on ${tracked.count} variants`);

  const merchants = await prisma.merchant.findMany({
    include: {
      outlets: true,
      products: { include: { variants: true } },
    },
  });

  let rows = 0;
  for (const m of merchants) {
    const variantIds = m.products.flatMap((p) => p.variants.map((v) => v.id));
    for (const outlet of m.outlets) {
      for (const variantId of variantIds) {
        const qty = rnd();
        await prisma.inventoryStock.upsert({
          where: { outletId_variantId: { outletId: outlet.id, variantId } },
          create: { merchantId: m.id, outletId: outlet.id, variantId, quantityOnHand: qty },
          update: { quantityOnHand: qty },
        });
        rows++;
      }
    }
  }
  console.log(`set random 1..15 stock on ${rows} (outlet,variant) rows`);
}

main()
  .then(() => prisma.$disconnect())
  .catch(async (e) => {
    console.error(e);
    await prisma.$disconnect();
    process.exit(1);
  });
