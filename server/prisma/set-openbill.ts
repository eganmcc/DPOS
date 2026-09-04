/* eslint-disable no-console */
// One-off: switch every outlet of the demo merchant(s) to OPEN_BILL so the app
// runs the confirm-order / pay-later flow. Idempotent. Run: npx ts-node prisma/set-openbill.ts
import { PrismaClient, OutletPaymentMode } from '@prisma/client';

const prisma = new PrismaClient();

async function main(): Promise<void> {
  const res = await prisma.outlet.updateMany({
    data: { paymentMode: OutletPaymentMode.OPEN_BILL },
  });
  console.log(`set paymentMode=OPEN_BILL on ${res.count} outlets`);
}

main()
  .then(() => prisma.$disconnect())
  .catch(async (e) => {
    console.error(e);
    await prisma.$disconnect();
    process.exit(1);
  });
