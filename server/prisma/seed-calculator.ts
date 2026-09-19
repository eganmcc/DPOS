/* eslint-disable no-console */
// Demo CALCULATOR-ONLY merchant (specs/008-calculator-only) — a kiosk that sells with no catalog.
// Creates NOTHING outside its own merchant row, so every other demo merchant is untouched.
// Idempotent: re-running reasserts the classification and never duplicates the provisioning.
//
//   npx ts-node prisma/seed-calculator.ts
//
// Shape is deliberate. A kiosk on the calculator:
//   - is UMI (one person, cash + QRIS only, self-authorised corrections — all from 006),
//   - is calculatorOnly, so the app lands on the keypad instead of a product grid,
//   - has ONE outlet paid immediately — never open bills, which rebuild a cart from catalog lines,
//   - has NO tax rule. That absence IS the zero-tax mechanism: computeOrder falls back to
//     rateBps 0 when no rule exists. Adding a TaxRule row later switches tax on with no code change,
//   - has exactly ONE product, hidden, flagged isOpenAmount. Every keyed amount is posted against
//     its variant and becomes that line's price (Constitution III, open-amount lines, v1.8.0).
import { BusinessSize, BusinessType, PrismaClient, StaffRole } from '@prisma/client';
import * as bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

const MERCHANT = 'Kios Pak Darto';
const OWNER_PIN = '2222';

// The open-amount product's name is written into productNameSnapshot on EVERY line, so it is what
// the merchant reads in Riwayat ("1× Nota"), on the printed receipt, and as the one row in top
// items. Chosen for that audience, not for the schema.
const OPEN_AMOUNT_NAME = 'Nota';

async function main(): Promise<void> {
  let merchant = await prisma.merchant.findFirst({ where: { name: MERCHANT } });

  if (!merchant) {
    merchant = await prisma.merchant.create({
      data: {
        name: MERCHANT,
        businessType: BusinessType.GROCERY,
        businessSize: BusinessSize.UMI,
        calculatorOnly: true,
      },
    });
    console.log(`created merchant ${merchant.id} (${MERCHANT}, GROCERY/UMI, calculator-only)`);
  } else {
    merchant = await prisma.merchant.update({
      where: { id: merchant.id },
      data: { businessType: BusinessType.GROCERY, businessSize: BusinessSize.UMI, calculatorOnly: true },
    });
    console.log(`merchant exists ${merchant.id} — reasserted GROCERY/UMI/calculator-only`);
  }

  let outlet = await prisma.outlet.findFirst({ where: { merchantId: merchant.id } });
  outlet ??= await prisma.outlet.create({
    data: {
      merchantId: merchant.id,
      code: 'HQ',
      name: 'Kios Pak Darto',
      address: 'Pasar Modern Blok C-12',
      paymentMode: 'IMMEDIATE',
    },
  });

  // Deliberately NO taxRule — see the header. This is the mechanism, not an omission.

  let owner = await prisma.staff.findFirst({
    where: { merchantId: merchant.id, role: StaffRole.OWNER },
  });
  if (!owner) {
    owner = await prisma.staff.create({
      data: {
        merchantId: merchant.id,
        employeeId: 'EMP0001',
        name: 'Pak Darto',
        role: StaffRole.OWNER,
        outletId: outlet.id,
        pinHash: await bcrypt.hash(OWNER_PIN, 10),
        demoPin: OWNER_PIN, // DEMO ONLY — puts him in the login screen's picker
      },
    });
    console.log(`created owner ${owner.name} (PIN ${OWNER_PIN}) — the only staff`);
  }

  // The partial unique index products_open_amount_uq allows at most one of these per merchant, so
  // find-or-create rather than create: a second run must not collide with the first.
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
        name: OPEN_AMOUNT_NAME,
        isOpenAmount: true,
        variants: {
          create: [
            {
              name: 'Nilai',
              sku: 'OPEN-AMOUNT',
              // Never used: the keyed amount replaces it in computeOrder. 0 is the honest
              // placeholder — a real-looking price here would be a lie waiting to be read.
              price: 0,
              // Null, not 0: 0 would assert zero COGS and make gross profit read 100% margin.
              costPrice: null,
              isDefault: true,
              // A keyed amount is not a counted good, so a nota never moves stock.
              trackInventory: false,
            },
          ],
        },
      },
      include: { variants: true },
    });
    console.log(`provisioned the open-amount product "${OPEN_AMOUNT_NAME}"`);
  }

  console.log(`
  merchant        : ${merchant.id}  ${MERCHANT}
  outlet          : ${outlet.id}  ${outlet.name}
  owner PIN       : ${OWNER_PIN}  (Pak Darto — the only staff; UMI refuses a second)
  mode            : calculator-only — the app opens on the keypad
  openAmountVariant: ${open.variants[0].id}
  tax             : none (add a TaxRule row to switch it on; no code change needed)
`);
}

main()
  .then(() => prisma.$disconnect())
  .catch(async (e) => {
    console.error(e);
    await prisma.$disconnect();
    process.exit(1);
  });
