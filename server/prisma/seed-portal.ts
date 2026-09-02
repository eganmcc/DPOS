/* eslint-disable no-console */
// Customer-portal seed. Idempotent. Run: npx ts-node prisma/seed-portal.ts
//  1) Backfill employeeId (EMP0001…) on every staff that lacks one.
//  2) Ensure the F&B demo merchant's OWNER can log into the portal
//     (owner@warungdemo.id / owner123).
//  3) Create a GROCERY demo merchant with its own admin, branch, and products,
//     so the portal can be seen adapting to businessType.
import { BusinessType, PrismaClient, ProductType, StaffRole } from '@prisma/client';
import * as bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function backfillEmployeeIds(): Promise<void> {
  const merchants = await prisma.merchant.findMany({ select: { id: true } });
  for (const m of merchants) {
    const staff = await prisma.staff.findMany({
      where: { merchantId: m.id },
      orderBy: { name: 'asc' },
    });
    let max = 0;
    for (const s of staff) {
      const n = parseInt((s.employeeId ?? '').replace(/\D/g, ''), 10);
      if (!Number.isNaN(n) && n > max) max = n;
    }
    for (const s of staff) {
      if (s.employeeId) continue;
      max += 1;
      await prisma.staff.update({
        where: { id: s.id },
        data: { employeeId: `EMP${String(max).padStart(4, '0')}` },
      });
    }
  }
  console.log('backfilled employeeIds');
}

async function ensureFnbAdmin(): Promise<void> {
  const fnb = await prisma.merchant.findFirst({
    where: { name: { startsWith: 'Warung Kopi Demo' } },
  });
  if (!fnb) {
    console.log('no F&B demo merchant found — skipping F&B admin');
    return;
  }
  await prisma.merchant.update({ where: { id: fnb.id }, data: { businessType: BusinessType.FNB } });
  const owner = await prisma.staff.findFirst({ where: { merchantId: fnb.id, role: StaffRole.OWNER } });
  if (owner) {
    await prisma.staff.update({
      where: { id: owner.id },
      data: {
        email: owner.email ?? 'owner@warungdemo.id',
        passwordHash: owner.passwordHash ?? (await bcrypt.hash('owner123', 10)),
      },
    });
    console.log(`F&B admin ready: ${owner.email ?? 'owner@warungdemo.id'} / owner123`);
  }
}

const groceries: { category: string; name: string; variant: string; price: number; cost: number; sku: string }[] = [
  { category: 'Sembako', name: 'Beras Premium 5kg', variant: 'Karung', price: 65000, cost: 58000, sku: 'BRS5' },
  { category: 'Sembako', name: 'Minyak Goreng 2L', variant: 'Pouch', price: 38000, cost: 34000, sku: 'MYK2' },
  { category: 'Sembako', name: 'Gula Pasir 1kg', variant: 'Pak', price: 15000, cost: 13000, sku: 'GLA1' },
  { category: 'Sembako', name: 'Telur Ayam 1kg', variant: 'Kg', price: 28000, cost: 25000, sku: 'TLR1' },
  { category: 'Minuman', name: 'Air Mineral 600ml', variant: 'Botol', price: 4000, cost: 2500, sku: 'AIR6' },
  { category: 'Snack', name: 'Indomie Goreng', variant: 'Pcs', price: 3500, cost: 3000, sku: 'IDM1' },
];

async function seedGrocery(): Promise<void> {
  const existing = await prisma.merchant.findFirst({ where: { name: 'Toko Sembako Demo' } });
  if (existing) {
    console.log('grocery demo already exists — skipping');
    return;
  }
  const merchant = await prisma.merchant.create({
    data: { name: 'Toko Sembako Demo', businessType: BusinessType.GROCERY },
  });
  const outlet = await prisma.outlet.create({
    data: { merchantId: merchant.id, code: 'HQ', name: 'Toko Pusat', address: 'Jl. Pasar No. 1' },
  });
  await prisma.taxRule.create({
    data: { merchantId: merchant.id, outletId: outlet.id, label: 'PPN', rateBps: 1100 },
  });

  const admin = await prisma.staff.create({
    data: {
      merchantId: merchant.id,
      employeeId: 'EMP0001',
      name: 'Admin Sembako',
      role: StaffRole.OWNER,
      email: 'admin@sembako.id',
      passwordHash: await bcrypt.hash('admin123', 10),
      pinHash: await bcrypt.hash('4321', 10),
    },
  });
  await prisma.staff.create({
    data: {
      merchantId: merchant.id,
      employeeId: 'EMP0002',
      name: 'Kasir Sembako',
      role: StaffRole.CASHIER,
      outletId: outlet.id,
      pinHash: await bcrypt.hash('2222', 10),
    },
  });
  await prisma.outlet.update({ where: { id: outlet.id }, data: { managerId: admin.id } });

  const catByName = new Map<string, string>();
  for (const name of [...new Set(groceries.map((g) => g.category))]) {
    const c = await prisma.category.create({ data: { merchantId: merchant.id, name } });
    catByName.set(name, c.id);
  }

  for (const g of groceries) {
    const product = await prisma.product.create({
      data: {
        merchantId: merchant.id,
        categoryId: catByName.get(g.category)!,
        name: g.name,
        type: ProductType.RETAIL,
      },
    });
    const variant = await prisma.productVariant.create({
      data: {
        productId: product.id,
        name: g.variant,
        price: g.price,
        costPrice: g.cost,
        sku: g.sku,
        isDefault: true,
        trackInventory: true,
      },
    });
    await prisma.inventoryStock.create({
      data: { merchantId: merchant.id, outletId: outlet.id, variantId: variant.id, quantityOnHand: 100 },
    });
    await prisma.inventoryMovement.create({
      data: {
        merchantId: merchant.id,
        outletId: outlet.id,
        variantId: variant.id,
        qtyDelta: 100,
        reason: 'RECEIVE',
        refType: 'SEED',
        createdById: admin.id,
      },
    });
  }
  console.log('grocery demo created: admin@sembako.id / admin123 (PIN 4321)');
}

// DEMO ONLY: set the plaintext demo PIN on each demo merchant's cashier so the app
// login screen can prefill it. These match the seeded cashier PINs.
async function setDemoPins(): Promise<void> {
  const fnb = await prisma.merchant.findFirst({ where: { name: { startsWith: 'Warung Kopi Demo' } } });
  if (fnb) {
    await prisma.staff.updateMany({
      where: { merchantId: fnb.id, role: StaffRole.CASHIER },
      data: { demoPin: '1234' },
    });
    await prisma.staff.updateMany({
      where: { merchantId: fnb.id, role: StaffRole.OWNER },
      data: { demoPin: '9999' },
    });
    await ensureDemoManager(fnb.id, 'Manajer Demo', '8888');
  }
  const gro = await prisma.merchant.findFirst({ where: { name: 'Toko Sembako Demo' } });
  if (gro) {
    await prisma.staff.updateMany({
      where: { merchantId: gro.id, role: StaffRole.CASHIER },
      data: { demoPin: '2222' },
    });
    await prisma.staff.updateMany({
      where: { merchantId: gro.id, role: StaffRole.OWNER },
      data: { demoPin: '4321' },
    });
    await ensureDemoManager(gro.id, 'Manajer Sembako', '7777');
  }
  console.log('set demo PINs on owner / manager / cashier');
}

/** DEMO ONLY: ensure a MANAGER exists for a demo merchant with the given demo PIN.
 * Idempotent — updates the PIN if a manager already exists. */
async function ensureDemoManager(merchantId: string, name: string, pin: string): Promise<void> {
  const existing = await prisma.staff.findFirst({
    where: { merchantId, role: StaffRole.MANAGER },
  });
  if (existing) {
    await prisma.staff.update({
      where: { id: existing.id },
      data: { demoPin: pin, isActive: true },
    });
    return;
  }
  await prisma.staff.create({
    data: {
      merchantId,
      name,
      role: StaffRole.MANAGER,
      pinHash: await bcrypt.hash(pin, 10),
      demoPin: pin,
    },
  });
}

async function main(): Promise<void> {
  await backfillEmployeeIds();
  await ensureFnbAdmin();
  await seedGrocery();
  await setDemoPins();
}

main()
  .then(() => prisma.$disconnect())
  .catch(async (e) => {
    console.error(e);
    await prisma.$disconnect();
    process.exit(1);
  });
