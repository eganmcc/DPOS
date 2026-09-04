/* eslint-disable no-console */
/**
 * Top up an EXISTING merchant with the full demo menu (see menu-data.ts).
 *
 * `seed.ts` bails out when the demo merchant already exists, so this is the
 * script to run against a live database (e.g. the RDS demo merchant, which
 * already has orders): it only adds what is missing and refreshes imageUrl.
 *
 *   npx ts-node prisma/seed-menu.ts                 # auto-detects the demo merchant
 *   MERCHANT_ID=<uuid> npx ts-node prisma/seed-menu.ts
 *   MERCHANT_ID=<uuid> OUTLET_ID=<uuid> npx ts-node prisma/seed-menu.ts
 */
import { PrismaClient } from '@prisma/client';
import { applyMenu } from './menu-data';

const prisma = new PrismaClient();

async function main(): Promise<void> {
  const merchant = process.env.MERCHANT_ID
    ? await prisma.merchant.findUnique({ where: { id: process.env.MERCHANT_ID } })
    : await prisma.merchant.findFirst({
        where: { name: { startsWith: 'Warung Kopi Demo' } },
        orderBy: { createdAt: 'asc' },
      });
  if (!merchant) throw new Error('No merchant found — set MERCHANT_ID, or run prisma/seed.ts first.');

  const outlet = process.env.OUTLET_ID
    ? await prisma.outlet.findFirst({ where: { id: process.env.OUTLET_ID, merchantId: merchant.id } })
    : await prisma.outlet.findFirst({
        where: { merchantId: merchant.id, name: 'Outlet Pusat' },
      }) ?? (await prisma.outlet.findFirst({ where: { merchantId: merchant.id }, orderBy: { name: 'asc' } }));
  if (!outlet) throw new Error(`Merchant ${merchant.id} has no outlet to stock.`);

  console.log(`Applying menu to "${merchant.name}" (${merchant.id}), stock outlet "${outlet.name}"…`);
  const r = await applyMenu(prisma, { merchantId: merchant.id, stockOutletId: outlet.id });

  const total = await prisma.product.count({ where: { merchantId: merchant.id } });
  console.log(`  categories created : ${r.categoriesCreated}`);
  console.log(`  products created   : ${r.productsCreated}`);
  console.log(`  products updated   : ${r.productsUpdated} (imageUrl/category refreshed)`);
  console.log(`  stock rows opened  : ${r.stockRowsCreated} @ ${outlet.name}`);
  console.log(`  modifiers regrouped: ${r.modifiersMoved}`);
  console.log(`  products on menu   : ${total}`);
}

main()
  .then(() => prisma.$disconnect())
  .catch(async (e) => {
    console.error(e);
    await prisma.$disconnect();
    process.exit(1);
  });
