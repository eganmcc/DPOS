/* eslint-disable no-console */
import { PrismaClient, StaffRole } from '@prisma/client';
import * as bcrypt from 'bcryptjs';

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

  const minuman = await prisma.category.create({
    data: { merchantId: merchant.id, name: 'Minuman', sortOrder: 1 },
  });
  const makanan = await prisma.category.create({
    data: { merchantId: merchant.id, name: 'Makanan', sortOrder: 2 },
  });

  // Kopi Susu — two variants + a "Sugar level" modifier group. Regular variant tracks stock.
  const kopiSusu = await prisma.product.create({
    data: {
      merchantId: merchant.id,
      categoryId: minuman.id,
      name: 'Kopi Susu',
      variants: {
        create: [
          { name: 'Regular', price: 18000, costPrice: 7000, isDefault: true, trackInventory: true },
          { name: 'Large', price: 23000, costPrice: 9000, trackInventory: true },
        ],
      },
      modifierGroups: {
        create: [
          {
            name: 'Sugar level',
            minSelect: 0,
            maxSelect: 1,
            modifiers: {
              create: [
                { name: 'Less sugar', priceDelta: 0 },
                { name: 'Normal', priceDelta: 0 },
                { name: 'Extra shot', priceDelta: 5000 },
              ],
            },
          },
        ],
      },
    },
    include: { variants: true },
  });

  // Nasi Goreng — single variant, tracks stock.
  const nasiGoreng = await prisma.product.create({
    data: {
      merchantId: merchant.id,
      categoryId: makanan.id,
      name: 'Nasi Goreng',
      variants: { create: [{ name: 'Regular', price: 27000, costPrice: 12000, isDefault: true, trackInventory: true }] },
    },
    include: { variants: true },
  });

  // Seed opening stock (100 each) at Outlet Pusat for tracked variants.
  const trackedVariants = [...kopiSusu.variants, ...nasiGoreng.variants];
  for (const v of trackedVariants) {
    await prisma.inventoryStock.create({
      data: {
        merchantId: merchant.id,
        outletId: outletA.id,
        variantId: v.id,
        quantityOnHand: 100,
      },
    });
    await prisma.inventoryMovement.create({
      data: {
        merchantId: merchant.id,
        outletId: outletA.id,
        variantId: v.id,
        qtyDelta: 100,
        reason: 'RECEIVE',
        refType: 'SEED',
        createdById: 'seed',
      },
    });
  }

  console.log('Seed complete.');
  console.log('  merchantId :', merchant.id);
  console.log('  outletA    :', outletA.id, '(Outlet Pusat, has stock)');
  console.log('  outletB    :', outletB.id, '(Outlet Cabang)');
  console.log('  owner login: owner@warungdemo.id / owner123');
  console.log('  cashier PIN: 1234   (owner PIN: 9999)');
}

main()
  .then(() => prisma.$disconnect())
  .catch(async (e) => {
    console.error(e);
    await prisma.$disconnect();
    process.exit(1);
  });
