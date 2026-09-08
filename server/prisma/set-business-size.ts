/* eslint-disable no-console */
// Set a merchant's business SIZE. There is no super-admin UI yet, so provisioning
// happens here (or in raw SQL). Idempotent.
//
//   npx ts-node prisma/set-business-size.ts "<merchant id or exact name>" UMI
//   npx ts-node prisma/set-business-size.ts                                   # list all
//
// Resolves by UUID or exact name and refuses on 0 or >1 match — never an
// unfiltered updateMany, which would retier every merchant in the database.
import { BusinessSize, PrismaClient, StaffRole } from '@prisma/client';

const prisma = new PrismaClient();

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const SIZES = Object.values(BusinessSize);

async function list(): Promise<void> {
  const merchants = await prisma.merchant.findMany({
    select: { id: true, name: true, businessType: true, businessSize: true },
    orderBy: { name: 'asc' },
  });
  console.log('\nmerchants:');
  for (const m of merchants) {
    console.log(`  ${m.id}  ${m.businessSize.padEnd(7)} ${m.businessType.padEnd(7)} ${m.name}`);
  }
  console.log(`\nusage: npx ts-node prisma/set-business-size.ts "<id or exact name>" <${SIZES.join('|')}>`);
}

/**
 * A UMI merchant manages everything in the app, and the in-app screens it depends
 * on (/admin/products, /admin/dashboard) are OWNER-gated. A UMI merchant whose only
 * login is a CASHIER PIN would find the whole feature set silently unreachable, and
 * a UMI merchant with several staff is not a one-person business at all. Warn on
 * both — this is a provisioning smell, not an error, so it never blocks.
 */
async function warnIfMisprovisioned(merchantId: string): Promise<void> {
  const staff = await prisma.staff.findMany({
    where: { merchantId, isActive: true },
    select: { name: true, role: true },
  });
  if (staff.length > 1) {
    console.log(`\n  WARNING: ${staff.length} active staff — UMI is a single-person business.`);
    for (const s of staff) console.log(`    - ${s.name} (${s.role})`);
  }
  if (!staff.some((s) => s.role === StaffRole.OWNER)) {
    console.log('\n  WARNING: no active OWNER. In-app reports and item management are OWNER-gated,');
    console.log('  so this merchant would not be able to reach either from the app.');
  }
}

async function main(): Promise<void> {
  const [target, sizeArg] = process.argv.slice(2);
  if (!target || !sizeArg) return list();

  const size = sizeArg.toUpperCase() as BusinessSize;
  if (!SIZES.includes(size)) {
    console.error(`unknown size "${sizeArg}" — expected one of ${SIZES.join(', ')}`);
    process.exitCode = 1;
    return;
  }

  const matches = await prisma.merchant.findMany({
    where: UUID_RE.test(target) ? { id: target } : { name: target },
    select: { id: true, name: true, businessSize: true },
  });
  if (matches.length === 0) {
    console.error(`no merchant matched "${target}"`);
    process.exitCode = 1;
    return list();
  }
  if (matches.length > 1) {
    console.error(`"${target}" matched ${matches.length} merchants — pass an id instead`);
    process.exitCode = 1;
    return list();
  }

  const m = matches[0];
  if (m.businessSize === size) {
    console.log(`${m.name} is already ${size} — nothing to do`);
    if (size === BusinessSize.UMI) await warnIfMisprovisioned(m.id);
    return;
  }

  await prisma.merchant.update({ where: { id: m.id }, data: { businessSize: size } });
  console.log(`${m.name}\n  ${m.id}\n  ${m.businessSize} -> ${size}`);
  if (size === BusinessSize.UMI) await warnIfMisprovisioned(m.id);
}

main()
  .then(() => prisma.$disconnect())
  .catch(async (e) => {
    console.error(e);
    await prisma.$disconnect();
    process.exit(1);
  });
