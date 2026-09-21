/**
 * Six months of plausible trading history for the bank demo (specs/011-bank-reporting).
 *
 * Every report in that spec is a flat line or an empty state on two days of data. This writes a
 * history worth looking at: a weekday/weekend rhythm, a Ramadan-Lebaran lift, closed days, a
 * payment mix that drifts toward QRIS, a handful of voids, and the acquirer's settlement lines to
 * reconcile against — including a few deliberate mismatches, because a reconciliation report where
 * everything matches proves nothing.
 *
 * DEMO DATA. It writes only to the named merchant, is idempotent (re-running replaces the window
 * it owns), and never touches another tenant.
 *
 *   npx ts-node prisma/seed-bank-history.ts                    # Warung Kopi Demo 1, 6 months
 *   npx ts-node prisma/seed-bank-history.ts "Other Shop" 3     # another merchant, 3 months
 *   npx ts-node prisma/seed-bank-history.ts --clean            # remove what this wrote
 */
import { PrismaClient, Prisma } from '@prisma/client';

const prisma = new PrismaClient();

const MERCHANT = process.argv[2]?.startsWith('--') ? 'Warung Kopi Demo 1' : (process.argv[2] ?? 'Warung Kopi Demo 1');
const MONTHS = Number(process.argv[3]) || 6;
const CLEAN = process.argv.includes('--clean');

/** Marks every order this script writes, so a re-run can find and replace exactly its own rows. */
const TAG = 'SEED_BANK_HISTORY';

/** Payment mix drifts toward QRIS over the window — the story the bank wants to see. */
function mixFor(monthsAgo: number): Array<[Prisma.PaymentCreateManyInput['method'], number]> {
  // Cash share falls from ~78% six months ago to ~58% now; QRIS takes it.
  const cashShare = 0.58 + (monthsAgo / MONTHS) * 0.2;
  const qris = (1 - cashShare) * 0.72;
  const card = (1 - cashShare) * 0.2;
  const wallet = 1 - cashShare - qris - card;
  return [
    ['CASH', cashShare],
    ['QRIS_SIMULATED', qris],
    ['CARD_DEBIT', card],
    ['EWALLET_GOPAY', wallet],
  ];
}

/** A weekday/weekend rhythm, with Lebaran lifting the weeks around it. */
function dayFactor(d: Date): number {
  const dow = d.getUTCDay();
  const weekend = dow === 0 || dow === 6 ? 1.35 : dow === 5 ? 1.15 : 1.0;
  // Ramadan/Lebaran 2026 falls around Feb-Mar; the lift is keyed to the date so the demo shows a
  // seasonal bump wherever the window lands.
  const md = `${String(d.getUTCMonth() + 1).padStart(2, '0')}-${String(d.getUTCDate()).padStart(2, '0')}`;
  const lebaran = md >= '03-10' && md <= '03-22' ? 1.6 : md >= '02-20' && md <= '03-09' ? 1.25 : 1.0;
  return weekend * lebaran;
}

/** Deterministic pseudo-random so a re-run produces the same history. */
function rng(seed: number) {
  let s = seed;
  return () => {
    s = (s * 1664525 + 1013904223) % 4294967296;
    return s / 4294967296;
  };
}

async function main() {
  const merchant = await prisma.merchant.findFirst({
    where: { name: MERCHANT },
    include: { outlets: true, staff: true },
  });
  if (!merchant) throw new Error(`No merchant named "${MERCHANT}"`);

  const outlet = merchant.outlets[0];
  const cashier = merchant.staff.find((s) => s.role === 'CASHIER') ?? merchant.staff[0];
  if (!outlet || !cashier) throw new Error('Merchant has no outlet or staff to attribute sales to');

  // ---- clean: this script owns every order whose clientOrderId carries the tag ----------------
  const owned = { merchantId: merchant.id, clientOrderId: { startsWith: TAG } };
  const existing = await prisma.order.findMany({ where: owned, select: { id: true } });
  if (existing.length) {
    const ids = existing.map((o) => o.id);
    await prisma.$transaction([
      prisma.payment.deleteMany({ where: { orderId: { in: ids } } }),
      prisma.orderVoid.deleteMany({ where: { orderId: { in: ids } } }),
      prisma.orderLine.deleteMany({ where: { orderId: { in: ids } } }),
      prisma.order.deleteMany({ where: { id: { in: ids } } }),
    ]);
    console.log(`removed ${ids.length} previously seeded orders`);
  }
  await prisma.settlementRecord.deleteMany({
    where: { merchantId: merchant.id, externalRef: { startsWith: TAG } },
  });
  if (CLEAN) {
    console.log('clean only — nothing written');
    return;
  }

  // ---- the catalogue it sells from -----------------------------------------------------------
  const variants = await prisma.productVariant.findMany({
    where: { product: { merchantId: merchant.id, isAvailable: true, isOpenAmount: false } },
    include: { product: { select: { name: true } } },
    take: 12,
  });
  if (!variants.length) throw new Error('Merchant has no catalogue variants to sell');

  const taxRule = await prisma.taxRule.findFirst({
    where: { merchantId: merchant.id, outletId: outlet.id },
  });

  const rand = rng(20260921);
  const today = new Date();
  const start = new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth() - MONTHS + 1, 1));

  type SettleKey = string; // `${day}|${rail}`
  const settle = new Map<SettleKey, { gross: number; count: number }>();

  let orders = 0;
  let voids = 0;
  const batch: Prisma.OrderCreateManyInput[] = [];
  const lines: Prisma.OrderLineCreateManyInput[] = [];
  const payments: Prisma.PaymentCreateManyInput[] = [];
  const voidRows: Prisma.OrderVoidCreateManyInput[] = [];

  for (let d = new Date(start); d <= today; d.setUTCDate(d.getUTCDate() + 1)) {
    const day = new Date(d);
    // Closed roughly one day a fortnight, and never on a weekend — consistency is a credit
    // variable, so the gaps have to be real but plausible.
    const dow = day.getUTCDay();
    if (dow !== 0 && dow !== 6 && rand() < 0.07) continue;

    const monthsAgo = (today.getUTCFullYear() - day.getUTCFullYear()) * 12 + today.getUTCMonth() - day.getUTCMonth();
    const base = 14 + Math.round(rand() * 10); // 14–24 sales a day
    const count = Math.max(4, Math.round(base * dayFactor(day)));
    const mix = mixFor(monthsAgo);

    for (let i = 0; i < count; i++) {
      const hour = 8 + Math.floor(rand() * 13);
      const at = new Date(day);
      at.setUTCHours(hour, Math.floor(rand() * 60), Math.floor(rand() * 60), 0);

      // 1–3 lines per sale.
      const lineCount = 1 + Math.floor(rand() * 3);
      const picked: typeof variants = [];
      for (let k = 0; k < lineCount; k++) picked.push(variants[Math.floor(rand() * variants.length)]);

      let subtotal = 0;
      const orderId = crypto.randomUUID();
      for (const v of picked) {
        const qty = 1 + Math.floor(rand() * 2);
        const lineTotal = v.price * qty;
        subtotal += lineTotal;
        lines.push({
          id: crypto.randomUUID(),
          orderId,
          variantId: v.id,
          qty: new Prisma.Decimal(qty),
          productNameSnapshot: v.product.name,
          unitPriceSnapshot: v.price,
          costPriceSnapshot: v.costPrice ?? null,
          lineTotal,


        });
      }

      const taxTotal = taxRule ? Math.round((subtotal * taxRule.rateBps) / 10000) : 0;
      const serviceTotal = taxRule?.serviceChargeBps
        ? Math.round((subtotal * taxRule.serviceChargeBps) / 10000)
        : 0;
      const grandTotal = subtotal + taxTotal + serviceTotal;

      // Pick a tender from the month's mix.
      const roll = rand();
      let acc = 0;
      let method = mix[0][0];
      for (const [m, share] of mix) {
        acc += share;
        if (roll <= acc) {
          method = m;
          break;
        }
      }

      batch.push({
        id: orderId,
        clientOrderId: `${TAG}:${orderId}`,
        merchantId: merchant.id,
        outletId: outlet.id,
        cashierId: cashier.id,
        type: 'DINE_IN',
        status: 'COMPLETED',
        channel: 'POS',
        subtotal,
        discountTotal: 0,
        taxTotal,
        serviceChargeTotal: serviceTotal,
        grandTotal,
        taxLabelSnapshot: taxRule?.label ?? null,
        taxRateBpsSnapshot: taxRule?.rateBps ?? null,
        serviceChargeLabelSnapshot: taxRule?.serviceLabel ?? null,
        serviceChargeRateBpsSnapshot: taxRule?.serviceChargeBps ?? null,
        createdAt: at,
        closedAt: at,
      });

      payments.push({
        id: crypto.randomUUID(),
        merchantId: merchant.id,
        orderId,
        method,
        direction: 'CHARGE',
        status: 'PAID',
        amount: grandTotal,
        tendered: method === 'CASH' ? Math.ceil(grandTotal / 5000) * 5000 : null,
        change: method === 'CASH' ? Math.ceil(grandTotal / 5000) * 5000 - grandTotal : 0,
        createdAt: at,
      });

      // A void every ~120 sales, so the integrity report has something real to show. Decided
      // BEFORE the settlement below: a voided sale was never settled, and seeding it as though it
      // were would manufacture dozens of reconciliation mismatches that drown the few deliberate
      // ones. (It did, on the first run: 15 amount-differs instead of 2.)
      const isVoided = rand() < 0.008;

      // What the acquirer would have settled for this sale.
      const rail = method === 'QRIS_SIMULATED' || method.startsWith('EWALLET') ? 'QRIS'
        : method.startsWith('CARD') ? 'CARD' : null;
      if (rail && !isVoided) {
        const key = `${at.toISOString().slice(0, 10)}|${rail}`;
        const cur = settle.get(key) ?? { gross: 0, count: 0 };
        cur.gross += grandTotal;
        cur.count += 1;
        settle.set(key, cur);
      }

      if (isVoided) {
        voidRows.push({
          id: crypto.randomUUID(),
          merchantId: merchant.id,
          outletId: outlet.id,
          orderId,
          clientVoidId: `${TAG}:${orderId}`,
          reason: 'salah input',
          voidedById: cashier.id,
          approvedById: merchant.staff.find((s) => s.role === 'MANAGER')?.id ?? null,
          createdAt: new Date(at.getTime() + 600000),
        });
        voids += 1;
      }
      orders += 1;
    }
  }

  // Chunked: a six-month history is thousands of rows and one createMany of that size is slow.
  const chunk = <T>(xs: T[], n: number) =>
    Array.from({ length: Math.ceil(xs.length / n) }, (_, i) => xs.slice(i * n, i * n + n));
  for (const c of chunk(batch, 500)) await prisma.order.createMany({ data: c });
  for (const c of chunk(lines, 500)) await prisma.orderLine.createMany({ data: c });
  for (const c of chunk(payments, 500)) await prisma.payment.createMany({ data: c });
  if (voidRows.length) await prisma.orderVoid.createMany({ data: voidRows });

  // ---- the acquirer's side --------------------------------------------------------------------
  // Built by reading the database back, NOT from the map above: an acquirer settles every card and
  // QRIS sale the merchant took, including the ones made by hand on the till during testing. Built
  // from the seed alone, those real sales showed up as a dozen unexplained shortfalls and buried
  // the three mismatches that are there on purpose.
  settle.clear();
  const settleable = await prisma.order.findMany({
    where: {
      merchantId: merchant.id,
      status: 'COMPLETED',
      createdAt: { gte: start },
      voids: { none: {} },
    },
    select: { createdAt: true, payments: { select: { method: true, amount: true, direction: true, status: true } } },
  });
  for (const o of settleable) {
    for (const p of o.payments) {
      if (p.direction !== 'CHARGE' || p.status !== 'PAID') continue;
      const rail = p.method === 'QRIS_SIMULATED' || p.method.startsWith('EWALLET')
        ? 'QRIS'
        : p.method.startsWith('CARD')
          ? 'CARD'
          : null;
      if (!rail) continue;
      const key = `${o.createdAt.toISOString().slice(0, 10)}|${rail}`;
      const cur = settle.get(key) ?? { gross: 0, count: 0 };
      cur.gross += p.amount;
      cur.count += 1;
      settle.set(key, cur);
    }
  }

  // Mostly matching, with a deliberate handful that do not: one day never settled, one settled
  // short, one settled for a day we have no record of. A reconciliation report where everything
  // matches demonstrates nothing.
  const settleRows: Prisma.SettlementRecordCreateManyInput[] = [];
  const keys = [...settle.keys()].sort();
  keys.forEach((key, i) => {
    const [day, rail] = key.split('|');
    const { gross, count } = settle.get(key)!;
    if (i === Math.floor(keys.length * 0.3)) return; // never settled
    const short = i === Math.floor(keys.length * 0.6);
    const amount = short ? gross - 25000 : gross;
    const fee = Math.round(amount * 0.003); // the acquirer's cut
    settleRows.push({
      merchantId: merchant.id,
      settledOn: new Date(`${day}T00:00:00.000Z`),
      method: rail,
      terminalRef: rail === 'CARD' ? merchant.edcTid ?? 'TID-DEMO' : merchant.qrisNmid ?? 'NMID-DEMO',
      grossAmount: amount,
      feeAmount: fee,
      netAmount: amount - fee,
      txnCount: count,
      externalRef: `${TAG}:${key}`,
    });
  });
  // One the acquirer says it settled and we have no record of at all.
  if (keys.length) {
    const ghost = keys[Math.floor(keys.length * 0.8)].split('|')[0];
    settleRows.push({
      merchantId: merchant.id,
      settledOn: new Date(`${ghost}T00:00:00.000Z`),
      method: 'EWALLET',
      terminalRef: 'NMID-DEMO',
      grossAmount: 180000,
      feeAmount: 540,
      netAmount: 179460,
      txnCount: 3,
      externalRef: `${TAG}:ghost`,
    });
  }
  for (const c of chunk(settleRows, 500)) await prisma.settlementRecord.createMany({ data: c });

  // ---- the bank's own keys, so reconciliation has something to join on ------------------------
  await prisma.merchant.update({
    where: { id: merchant.id },
    data: {
      bankCif: merchant.bankCif ?? '0081234567',
      bankBranch: merchant.bankBranch ?? 'KCP Kemang',
      onboardedAt: merchant.onboardedAt ?? start,
      qrisNmid: merchant.qrisNmid ?? 'ID1023456789012',
      qrisMpan: merchant.qrisMpan ?? '9360081234567890123',
      edcTid: merchant.edcTid ?? 'TID00912345',
      edcMid: merchant.edcMid ?? 'MID000123456789',
      npwp: merchant.npwp ?? '09.254.294.1-407.000',
      nib: merchant.nib ?? '8120012345678',
      mcc: merchant.mcc ?? '5812',
      // Demo consent, recorded the way a real one would be.
      dataConsentAt: merchant.dataConsentAt ?? start,
      dataConsentVersion: merchant.dataConsentVersion ?? 'demo-v1',
    },
  });

  console.log(
    `seeded ${orders} orders (${voids} voided) and ${settleRows.length} settlement rows ` +
      `for ${merchant.name}, ${start.toISOString().slice(0, 10)} → today`,
  );
}

main()
  .catch((e) => {
    console.error(e);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
