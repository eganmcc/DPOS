/* eslint-disable no-console */
// Demo UMI ("Ultra Mikro") merchant — a one-person warung, with its own catalog and
// stock. Creates NOTHING outside its own merchant row, so the existing demo merchants
// are untouched. Idempotent: re-running refreshes prices and tops the catalog up.
//
//   npx ts-node prisma/seed-umi.ts
//
// Shape is deliberate. A street-food warung:
//   - has ONE person (owner only — UMI refuses staff creation anyway),
//   - has ONE outlet,
//   - charges NO tax (no PBJT, no service charge) — so netRevenue == netSales here,
//   - takes payment immediately (no open bills / table service),
//   - cooks to order, so most items are untracked; only bottled drinks carry stock.
import { BusinessSize, BusinessType, PrismaClient, StaffRole } from '@prisma/client';
import * as bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

const MERCHANT = 'Warung Bu Sri';
const OWNER_PIN = '1111';

/** price/cost are integer rupiah. cost `null` = not costed yet (see note below). */
const MENU: {
  category: string;
  name: string;
  price: number;
  cost: number | null;
  track?: number; // opening stock; omitted = not inventory-tracked
}[] = [
  { category: 'Makanan', name: 'Nasi Goreng', price: 15000, cost: 7000 },
  { category: 'Makanan', name: 'Mie Goreng', price: 15000, cost: 6500 },
  { category: 'Makanan', name: 'Nasi Uduk', price: 10000, cost: 4500 },
  { category: 'Makanan', name: 'Ayam Goreng', price: 12000, cost: 6000 },
  { category: 'Makanan', name: 'Telur Dadar', price: 5000, cost: 2500 },
  { category: 'Makanan', name: 'Tempe Goreng', price: 3000, cost: 1200 },
  { category: 'Makanan', name: 'Tahu Goreng', price: 3000, cost: 1000 },
  // Deliberately uncosted: the price of a batch of gorengan varies by the day, so
  // Bu Sri never set one. It makes the Reports "belum ada harga modal" warning real
  // as soon as one is sold — which is exactly the case that warning exists for.
  { category: 'Makanan', name: 'Bakwan Sayur', price: 2000, cost: null },
  { category: 'Minuman', name: 'Es Teh Manis', price: 4000, cost: 1200 },
  { category: 'Minuman', name: 'Kopi Tubruk', price: 5000, cost: 1800 },
  { category: 'Minuman', name: 'Es Jeruk', price: 6000, cost: 2200 },
  { category: 'Minuman', name: 'Susu Jahe', price: 7000, cost: 3000 },
  // Bottled stock is the only thing a warung actually counts.
  { category: 'Minuman', name: 'Air Mineral', price: 4000, cost: 2500, track: 48 },
  { category: 'Minuman', name: 'Teh Botol', price: 6000, cost: 4000, track: 24 },
];

async function main(): Promise<void> {
  let merchant = await prisma.merchant.findFirst({ where: { name: MERCHANT } });

  if (!merchant) {
    merchant = await prisma.merchant.create({
      data: {
        name: MERCHANT,
        businessType: BusinessType.FNB,
        businessSize: BusinessSize.UMI,
      },
    });
    console.log(`created merchant ${merchant.id} (${MERCHANT}, FNB/UMI)`);
  } else {
    // Idempotent: make sure an existing row is still classified UMI.
    merchant = await prisma.merchant.update({
      where: { id: merchant.id },
      data: { businessSize: BusinessSize.UMI, businessType: BusinessType.FNB },
    });
    console.log(`merchant exists ${merchant.id} — reasserted FNB/UMI`);
  }

  let outlet = await prisma.outlet.findFirst({ where: { merchantId: merchant.id } });
  outlet ??= await prisma.outlet.create({
    data: {
      merchantId: merchant.id,
      code: 'HQ',
      name: 'Warung Bu Sri',
      address: 'Jl. Melati No. 7',
      // A street vendor is paid when the food is handed over — never an open bill.
      paymentMode: 'IMMEDIATE',
    },
  });

  // Deliberately NO taxRule: a warung this size charges no PBJT and no service charge.

  let owner = await prisma.staff.findFirst({
    where: { merchantId: merchant.id, role: StaffRole.OWNER },
  });
  if (!owner) {
    owner = await prisma.staff.create({
      data: {
        merchantId: merchant.id,
        employeeId: 'EMP0001',
        name: 'Bu Sri',
        role: StaffRole.OWNER,
        outletId: outlet.id,
        pinHash: await bcrypt.hash(OWNER_PIN, 10),
        demoPin: OWNER_PIN, // DEMO ONLY — puts her in the login screen's picker
        // Portal credentials exist only so the UMI lockout is demonstrable: signing in
        // at /customer-portal/ with these returns 403 PORTAL_NOT_AVAILABLE.
        email: 'busri@warungbusri.id',
        passwordHash: await bcrypt.hash('busri123', 10),
      },
    });
    console.log(`created owner ${owner.name} (PIN ${OWNER_PIN}) — the only staff`);
  }

  const catCache = new Map<string, string>();
  async function categoryId(name: string): Promise<string> {
    if (catCache.has(name)) return catCache.get(name)!;
    let c = await prisma.category.findFirst({ where: { merchantId: merchant!.id, name } });
    c ??= await prisma.category.create({ data: { merchantId: merchant!.id, name } });
    catCache.set(name, c.id);
    return c.id;
  }

  let created = 0;
  let updated = 0;
  for (const item of MENU) {
    const existing = await prisma.product.findFirst({
      where: { merchantId: merchant.id, name: item.name },
      include: { variants: true },
    });
    if (existing) {
      const v = existing.variants[0];
      if (v) {
        await prisma.productVariant.update({
          where: { id: v.id },
          data: { price: item.price, costPrice: item.cost },
        });
      }
      updated += 1;
      continue;
    }

    const product = await prisma.product.create({
      data: {
        merchantId: merchant.id,
        categoryId: await categoryId(item.category),
        name: item.name,
        variants: {
          create: [
            {
              name: 'Porsi',
              price: item.price,
              costPrice: item.cost,
              isDefault: true,
              trackInventory: item.track !== undefined,
            },
          ],
        },
      },
      include: { variants: true },
    });
    created += 1;

    if (item.track !== undefined) {
      const variant = product.variants[0];
      // Opening stock goes in through the ledger, never as a bare balance write
      // (Constitution IV): a RECEIVE movement plus its projection, in one transaction.
      await prisma.$transaction(async (tx) => {
        await tx.inventoryMovement.create({
          data: {
            merchantId: merchant!.id,
            outletId: outlet!.id,
            variantId: variant.id,
            qtyDelta: item.track!,
            reason: 'RECEIVE',
            refType: 'SEED',
            createdById: owner!.id,
          },
        });
        await tx.inventoryStock.upsert({
          where: { outletId_variantId: { outletId: outlet!.id, variantId: variant.id } },
          create: {
            merchantId: merchant!.id,
            outletId: outlet!.id,
            variantId: variant.id,
            quantityOnHand: item.track!,
          },
          update: { quantityOnHand: item.track! },
        });
      });
    }
  }

  const total = await prisma.product.count({ where: { merchantId: merchant.id } });
  console.log(`
  merchant   : ${merchant.id}  ${MERCHANT}
  outlet     : ${outlet.id}  ${outlet.name}
  owner PIN  : ${OWNER_PIN}  (Bu Sri — the only staff; UMI refuses a second)
  portal     : busri@warungbusri.id / busri123 -> 403 PORTAL_NOT_AVAILABLE
  catalog    : ${created} created, ${updated} refreshed, ${total}/30 items used
  tax        : none (a warung this size charges no PBJT/service)
`);
}

main()
  .then(() => prisma.$disconnect())
  .catch(async (e) => {
    console.error(e);
    await prisma.$disconnect();
    process.exit(1);
  });
