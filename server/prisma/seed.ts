/* eslint-disable no-console */
import { PrismaClient, StaffRole } from '@prisma/client';
import * as bcrypt from 'bcryptjs';
import { applyMenu } from './menu-data';

const prisma = new PrismaClient();

async function main(): Promise<void> {
  // Idempotent-ish seed: wipe demo merchant if present, then recreate.
  const existing = await prisma.merchant.findFirst({ where: { name: 'Warung Kopi Demo' } });
  if (existing) {
    console.log('Demo merchant already exists — skipping seed. Merchant id:', existing.id);
    return;
  }

  const merchant = await prisma.merchant.create({ data: { name: 'Warung Kopi Demo' } });

  const outletA = await prisma.outlet.create({
    data: { merchantId: merchant.id, name: 'Outlet Pusat' },
  });
  const outletB = await prisma.outlet.create({
    data: { merchantId: merchant.id, name: 'Outlet Cabang' },
  });

  await prisma.staff.create({
    data: {
      merchantId: merchant.id,
      name: 'Owner Demo',
      role: StaffRole.OWNER,
      email: 'owner@warungdemo.id',
      passwordHash: await bcrypt.hash('owner123', 10),
      pinHash: await bcrypt.hash('9999', 10),
    },
  });
  await prisma.staff.create({
    data: {
      merchantId: merchant.id,
      name: 'Kasir Demo',
      role: StaffRole.CASHIER,
      pinHash: await bcrypt.hash('1234', 10),
    },
  });

  // Per-outlet tax rule: PBJT 10% + 5% service charge.
  for (const outlet of [outletA, outletB]) {
    await prisma.taxRule.create({
      data: {
        merchantId: merchant.id,
        outletId: outlet.id,
        label: 'PBJT',
        rateBps: 1000,
        serviceChargeBps: 500,
        serviceLabel: 'Service Charge',
      },
    });
  }

  // Full demo menu (20 items across Minuman / Makanan / Snack) + opening stock
  // at Outlet Pusat for every tracked variant. Shared with prisma/seed-menu.ts.
  const menu = await applyMenu(prisma, { merchantId: merchant.id, stockOutletId: outletA.id });

  console.log('Seed complete.');
  console.log('  merchantId :', merchant.id);
  console.log('  outletA    :', outletA.id, '(Outlet Pusat, has stock)');
  console.log('  outletB    :', outletB.id, '(Outlet Cabang)');
  console.log('  owner login: owner@warungdemo.id / owner123');
  console.log('  cashier PIN: 1234   (owner PIN: 9999)');
  console.log('  menu       :', menu.productsCreated, 'products,', menu.stockRowsCreated, 'stock rows');
}

main()
  .then(() => prisma.$disconnect())
  .catch(async (e) => {
    console.error(e);
    await prisma.$disconnect();
    process.exit(1);
  });
