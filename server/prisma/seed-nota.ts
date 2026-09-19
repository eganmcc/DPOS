/* eslint-disable no-console */
// Demo HIGH_HUMAN_INTERACTION merchant (specs/009-nota-reading-mode) — a laundry that sells from
// its own handwritten nota. Creates NOTHING outside its own merchant row. Idempotent.
//
//   npx ts-node prisma/seed-nota.ts
//
// RUN ONLY AFTER the server that knows HIGH_HUMAN_INTERACTION is deployed. A server built before
// the enum value existed cannot decode this merchant's row, and GET /demo/directory — which lists
// every merchant — would then fail for everyone on the login screen.
//
// Shape is deliberate. A neighbourhood laundry:
//   - is HIGH_HUMAN_INTERACTION: the app opens on the nota chat, for every role;
//   - is GENERAL size, with an owner AND a cashier, so both logins can be demoed and settlement
//     offers every tender (a UMI till would be limited to cash + QRIS);
//   - has ONE outlet on OPEN_BILL: a laundry is paid when the washing is collected, not when the
//     nota is written — which is exactly what an open transaction is;
//   - has NO tax rule: laundry is not a PBJT service, so the total is the price on the paper. Adding
//     a TaxRule later switches tax on with no code change;
//   - has exactly ONE hidden product flagged isOpenAmount. Every nota line is posted against its
//     variant and priced from the paper (Constitution III, open-amount lines, v1.9.0).
//
// The name is invented on purpose. The real slips this feature was built against belong to a real
// laundry, and a demo account must not borrow a real business's name.
import { BusinessSize, BusinessType, PrismaClient, StaffRole } from '@prisma/client';
import * as bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

const MERCHANT = 'Laundry Wangi Demo';
const OWNER_PIN = '3333';
const CASHIER_PIN = '4444';

async function main(): Promise<void> {
  let merchant = await prisma.merchant.findFirst({ where: { name: MERCHANT } });
  const shape = {
    businessType: BusinessType.HIGH_HUMAN_INTERACTION,
    businessSize: BusinessSize.GENERAL,
    calculatorOnly: false,
  };
  if (!merchant) {
    merchant = await prisma.merchant.create({ data: { name: MERCHANT, ...shape } });
    console.log(`created merchant ${merchant.id} (${MERCHANT}, HIGH_HUMAN_INTERACTION)`);
  } else {
    merchant = await prisma.merchant.update({ where: { id: merchant.id }, data: shape });
    console.log(`merchant exists ${merchant.id} — reasserted HIGH_HUMAN_INTERACTION`);
  }

  let outlet = await prisma.outlet.findFirst({ where: { merchantId: merchant.id } });
  outlet ??= await prisma.outlet.create({
    data: {
      merchantId: merchant.id,
      code: 'HQ',
      name: 'Laundry Wangi — Pusat',
      address: 'Jl. Kenanga No. 12',
      paymentMode: 'OPEN_BILL',
    },
  });

  // Deliberately NO taxRule — see the header.

  const staff = [
    { role: StaffRole.OWNER, employeeId: 'EMP0001', name: 'Bu Wangi', pin: OWNER_PIN },
    { role: StaffRole.CASHIER, employeeId: 'EMP0002', name: 'Kasir Wangi', pin: CASHIER_PIN },
  ];
  for (const s of staff) {
    const existing = await prisma.staff.findFirst({
      where: { merchantId: merchant.id, employeeId: s.employeeId },
    });
    if (existing) continue;
    await prisma.staff.create({
      data: {
        merchantId: merchant.id,
        employeeId: s.employeeId,
        name: s.name,
        role: s.role,
        outletId: outlet.id,
        pinHash: await bcrypt.hash(s.pin, 10),
        demoPin: s.pin, // DEMO ONLY — puts them in the login screen's picker
      },
    });
    console.log(`created ${s.role.toLowerCase()} ${s.name} (PIN ${s.pin})`);
  }

  // At most one per merchant (partial unique index products_open_amount_uq), so find first.
  let open = await prisma.product.findFirst({
    where: { merchantId: merchant.id, isOpenAmount: true },
    include: { variants: true },
  });
  if (!open) {
    let category = await prisma.category.findFirst({
      where: { merchantId: merchant.id, name: 'Sistem' },
    });
    category ??= await prisma.category.create({ data: { merchantId: merchant.id, name: 'Sistem' } });
    open = await prisma.product.create({
      data: {
        merchantId: merchant.id,
        categoryId: category.id,
        // Every line carries its own label from the paper, so this name is only the fallback for a
        // nota whose lines had no readable wording.
        name: 'Nota',
        isOpenAmount: true,
        variants: {
          create: [
            {
              name: 'Nilai',
              sku: 'OPEN-AMOUNT',
              price: 0, // never used: the price written on the nota replaces it
              costPrice: null, // null, not 0 — 0 would claim 100% margin
              isDefault: true,
              trackInventory: false, // a service, not a counted good
            },
          ],
        },
      },
      include: { variants: true },
    });
    console.log('provisioned the open-amount product');
  }

  console.log(`
  merchant         : ${merchant.id}  ${MERCHANT}
  outlet           : ${outlet.id}  ${outlet.name}
  owner PIN        : ${OWNER_PIN}  (Bu Wangi)
  cashier PIN      : ${CASHIER_PIN}  (Kasir Wangi)
  mode             : HIGH_HUMAN_INTERACTION — the app opens on the nota chat
  openAmountVariant: ${open.variants[0].id}
  tax              : none
`);
}

main()
  .then(() => prisma.$disconnect())
  .catch(async (e) => {
    console.error(e);
    await prisma.$disconnect();
    process.exit(1);
  });
