import { ForbiddenException, Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

/**
 * Reporting for the acquiring bank (specs/011-bank-reporting).
 *
 * Read-only over recorded orders, with one exception: settlement lines are INGESTED and stored as
 * the acquirer sent them. They are the bank's record, not ours, and nothing here edits them to fit
 * our orders — a mismatch is a finding (Constitution IV).
 *
 * The thesis of the whole file: the bank already sees QRIS and EDC in its own systems and cannot
 * see cash, which for a warung is most of the turnover. DPOS holds both. Matching the non-cash half
 * against the bank's settlement is what makes the cash figure beside it believable, so
 * {@link reconciliation} is the report the rest lean on.
 */

/** Non-cash rails, mapped to the acquirer's own word for them. */
const RAIL_OF_METHOD: Record<string, string> = {
  QRIS_SIMULATED: 'QRIS',
  EWALLET_SHOPEEPAY: 'QRIS',
  EWALLET_GOPAY: 'QRIS',
  EWALLET_OVO: 'QRIS',
  CARD_CREDIT: 'CARD',
  CARD_DEBIT: 'CARD',
  CARD_BCA: 'CARD',
};

export interface PeriodQuery {
  from?: string;
  to?: string;
  outletId?: string;
}

/** One merchant's line in the activation funnel. */
export interface ActivationRow {
  merchantId: string;
  name: string;
  bankBranch: string | null;
  bankCif: string | null;
  hasQris: boolean;
  hasEdc: boolean;
  consented: boolean;
  onboardedAt: string;
  firstSaleAt: string | null;
  daysToFirstSale: number | null;
  lastSaleAt: string | null;
  daysSinceLastSale: number | null;
  active7d: boolean;
  active30d: boolean;
}

@Injectable()
export class BankService {
  constructor(private readonly prisma: PrismaService) {}

  // ---------------------------------------------------------------- consent

  /**
   * Sharing this merchant's data with the bank is the merchant's decision, and it is checked HERE
   * rather than in the portal — a UI that hides a button is not a control (UU PDP 27/2022).
   */
  private async assertConsent(merchantId: string) {
    const m = await this.prisma.merchant.findUnique({
      where: { id: merchantId },
      select: { dataConsentAt: true, dataConsentRevokedAt: true },
    });
    const given = m?.dataConsentAt != null && m.dataConsentRevokedAt == null;
    if (!given) {
      throw new ForbiddenException({
        code: 'DATA_CONSENT_REQUIRED',
        message: 'This merchant has not consented to sharing transaction data.',
      });
    }
  }

  // ------------------------------------------------------------ settlement

  /**
   * Take the acquirer's settlement lines as given. Re-sending the same file updates rather than
   * duplicates, keyed on the acquirer's own reference.
   */
  async ingestSettlement(
    merchantId: string,
    rows: Array<{
      settledOn: string;
      method: string;
      terminalRef?: string | null;
      grossAmount: number;
      feeAmount?: number;
      netAmount: number;
      txnCount?: number;
      externalRef?: string | null;
    }>,
  ) {
    let written = 0;
    for (const r of rows) {
      const data = {
        merchantId,
        settledOn: new Date(`${r.settledOn}T00:00:00.000Z`),
        method: r.method,
        terminalRef: r.terminalRef ?? null,
        grossAmount: Math.round(r.grossAmount),
        feeAmount: Math.round(r.feeAmount ?? 0),
        netAmount: Math.round(r.netAmount),
        txnCount: Math.round(r.txnCount ?? 0),
        externalRef: r.externalRef ?? null,
      };
      if (data.externalRef) {
        await this.prisma.settlementRecord.upsert({
          where: { merchantId_externalRef: { merchantId, externalRef: data.externalRef } },
          create: data,
          update: data,
        });
      } else {
        await this.prisma.settlementRecord.create({ data });
      }
      written += 1;
    }
    return { written };
  }

  /**
   * DPOS's own non-cash sales against what the acquirer settled, per day and rail.
   *
   * The match rate is the headline: it is the number that lets a credit officer believe the cash
   * figure sitting beside it in the same ledger. Both sides are always shown — a difference is
   * reported, never reconciled away.
   */
  async reconciliation(merchantId: string, q: PeriodQuery) {
    const { from, to } = range(q, 30);

    const [orders, settled] = await Promise.all([
      this.prisma.order.findMany({
        where: {
          merchantId,
          status: 'COMPLETED',
          ...(q.outletId ? { outletId: q.outletId } : {}),
          createdAt: { gte: from, lte: to },
        },
        include: { voids: { select: { id: true } }, payments: true },
      }),
      this.prisma.settlementRecord.findMany({
        where: { merchantId, settledOn: { gte: from, lte: to } },
      }),
    ]);

    // day|rail -> what we recorded
    const ours = new Map<string, { amount: number; count: number }>();
    for (const o of orders) {
      if (o.voids.length) continue; // a voided sale was never settled
      const day = o.createdAt.toISOString().slice(0, 10);
      for (const p of o.payments) {
        if (p.direction !== 'CHARGE' || p.status !== 'PAID') continue;
        const rail = RAIL_OF_METHOD[p.method];
        if (!rail) continue; // cash and platform-paid online orders never reach an acquirer
        const key = `${day}|${rail}`;
        const cur = ours.get(key) ?? { amount: 0, count: 0 };
        cur.amount += p.amount;
        cur.count += 1;
        ours.set(key, cur);
      }
    }

    const theirs = new Map<string, { amount: number; count: number; fee: number; net: number }>();
    for (const s of settled) {
      const key = `${s.settledOn.toISOString().slice(0, 10)}|${s.method}`;
      const cur = theirs.get(key) ?? { amount: 0, count: 0, fee: 0, net: 0 };
      cur.amount += s.grossAmount;
      cur.count += s.txnCount;
      cur.fee += s.feeAmount;
      cur.net += s.netAmount;
      theirs.set(key, cur);
    }

    const days = [...new Set([...ours.keys(), ...theirs.keys()])].sort();
    const lines = days.map((key) => {
      const [day, rail] = key.split('|');
      const o = ours.get(key) ?? { amount: 0, count: 0 };
      const s = theirs.get(key) ?? { amount: 0, count: 0, fee: 0, net: 0 };
      return {
        day,
        rail,
        dposAmount: o.amount,
        dposCount: o.count,
        settledAmount: s.amount,
        settledCount: s.count,
        feeAmount: s.fee,
        netAmount: s.net,
        difference: o.amount - s.amount,
        status:
          o.amount === s.amount && o.amount > 0
            ? 'MATCHED'
            : s.amount === 0
              ? 'NOT_SETTLED' // we recorded it; the acquirer has not (yet) paid it
              : o.amount === 0
                ? 'NOT_IN_DPOS' // the acquirer settled something we never recorded
                : 'AMOUNT_DIFFERS',
      };
    });

    const dposTotal = lines.reduce((s, l) => s + l.dposAmount, 0);
    const settledTotal = lines.reduce((s, l) => s + l.settledAmount, 0);
    const matchedTotal = lines
      .filter((l) => l.status === 'MATCHED')
      .reduce((s, l) => s + l.dposAmount, 0);

    return {
      range: isoRange(from, to),
      lines,
      summary: {
        dposTotal,
        settledTotal,
        matchedTotal,
        difference: dposTotal - settledTotal,
        // Of everything we say went over the bank's rails, how much the bank agrees with. The
        // number a risk team looks at first.
        matchRateBps: dposTotal > 0 ? Math.round((matchedTotal / dposTotal) * 10000) : 0,
        matched: lines.filter((l) => l.status === 'MATCHED').length,
        notSettled: lines.filter((l) => l.status === 'NOT_SETTLED').length,
        notInDpos: lines.filter((l) => l.status === 'NOT_IN_DPOS').length,
        amountDiffers: lines.filter((l) => l.status === 'AMOUNT_DIFFERS').length,
      },
    };
  }

  // ------------------------------------------------------------ activation

  /**
   * The distribution story: of the merchants the bank handed this to, how many ever rang a sale.
   *
   * Counted from what already exists — a first sale is the first COMPLETED order, never a flag
   * somebody remembered to set.
   */
  /**
   * [portfolio] widens this beyond the caller's own merchant, and is granted ONLY by the bank key
   * (see the controller). Without it the funnel is a funnel of one: an OWNER token belongs to a
   * merchant, and letting one merchant's owner read another's name, CIF and takings because the
   * report happens to be bank-shaped would be a tenancy breach whatever the screen is called.
   */
  async activation(merchantId: string, opts: { portfolio: boolean; bankBranch?: string }) {
    const scope = opts.portfolio
      ? opts.bankBranch
        ? { bankBranch: opts.bankBranch }
        : { onboardedAt: { not: null } }
      : { id: merchantId };
    const merchants = await this.prisma.merchant.findMany({
      where: scope,
      select: {
        id: true,
        name: true,
        bankBranch: true,
        bankCif: true,
        qrisNmid: true,
        edcTid: true,
        onboardedAt: true,
        createdAt: true,
        dataConsentAt: true,
        dataConsentRevokedAt: true,
      },
    });

    const now = Date.now();
    const rows: ActivationRow[] = [];
    for (const m of merchants) {
      const [first, last, in7, in30] = await Promise.all([
        this.prisma.order.findFirst({
          where: { merchantId: m.id, status: 'COMPLETED' },
          orderBy: { createdAt: 'asc' },
          select: { createdAt: true },
        }),
        this.prisma.order.findFirst({
          where: { merchantId: m.id, status: 'COMPLETED' },
          orderBy: { createdAt: 'desc' },
          select: { createdAt: true },
        }),
        this.prisma.order.count({
          where: { merchantId: m.id, status: 'COMPLETED', createdAt: { gte: daysAgo(7) } },
        }),
        this.prisma.order.count({
          where: { merchantId: m.id, status: 'COMPLETED', createdAt: { gte: daysAgo(30) } },
        }),
      ]);
      const onboarded = m.onboardedAt ?? m.createdAt;
      rows.push({
        merchantId: m.id,
        name: m.name,
        bankBranch: m.bankBranch,
        bankCif: m.bankCif,
        hasQris: !!m.qrisNmid,
        hasEdc: !!m.edcTid,
        consented: m.dataConsentAt != null && m.dataConsentRevokedAt == null,
        onboardedAt: onboarded.toISOString().slice(0, 10),
        firstSaleAt: first?.createdAt.toISOString().slice(0, 10) ?? null,
        daysToFirstSale: first
          ? Math.max(0, Math.round((first.createdAt.getTime() - onboarded.getTime()) / 86400000))
          : null,
        lastSaleAt: last?.createdAt.toISOString().slice(0, 10) ?? null,
        daysSinceLastSale: last
          ? Math.floor((now - last.createdAt.getTime()) / 86400000)
          : null,
        active7d: in7 > 0,
        active30d: in30 > 0,
      });
    }

    const activated = rows.filter((r) => r.firstSaleAt != null);
    const withFirst = activated.filter((r) => r.daysToFirstSale != null);
    return {
      funnel: {
        onboarded: rows.length,
        activated: activated.length,
        active7d: rows.filter((r) => r.active7d).length,
        active30d: rows.filter((r) => r.active30d).length,
        consented: rows.filter((r) => r.consented).length,
        withQris: rows.filter((r) => r.hasQris).length,
        withEdc: rows.filter((r) => r.hasEdc).length,
        medianDaysToFirstSale: median(withFirst.map((r) => r.daysToFirstSale as number)),
      },
      // Silent longest first: the ones a relationship manager should call today.
      dormant: rows
        .filter((r) => r.daysSinceLastSale != null && (r.daysSinceLastSale as number) >= 7)
        .sort((a, b) => (b.daysSinceLastSale as number) - (a.daysSinceLastSale as number)),
      merchants: rows.sort((a, b) => a.name.localeCompare(b.name)),
    };
  }

  // ----------------------------------------------------------- credit data

  /**
   * The monthly figures a scorecard eats, for one merchant.
   *
   * Consistency is first-class on purpose: a merchant trading 26 days a month is a different risk
   * from one trading 9, and nothing else the bank holds says which it is.
   */
  async creditProfile(merchantId: string, months = 12) {
    await this.assertConsent(merchantId);

    const from = startOfMonth(monthsAgo(months - 1));
    const orders = await this.prisma.order.findMany({
      where: { merchantId, status: 'COMPLETED', createdAt: { gte: from } },
      include: {
        voids: { select: { id: true } },
        payments: true,
        lines: {
          include: { variant: { select: { product: { select: { isOpenAmount: true } } } } },
        },
      },
    });

    const merchant = await this.prisma.merchant.findUnique({
      where: { id: merchantId },
      select: {
        name: true,
        businessType: true,
        businessSize: true,
        calculatorOnly: true,
        createdAt: true,
        onboardedAt: true,
        npwp: true,
        nib: true,
        qrisNmid: true,
        edcTid: true,
      },
    });

    type Month = {
      month: string;
      turnover: number;
      orders: number;
      days: Set<string>;
      cash: number;
      nonCash: number;
      bankRails: number;
      netRevenue: number;
      cogs: number;
      costKnown: boolean;
      voided: number;
    };
    const byMonth = new Map<string, Month>();
    const monthOf = (d: Date) => d.toISOString().slice(0, 7);
    const ensure = (m: string): Month => {
      const cur = byMonth.get(m) ?? {
        month: m,
        turnover: 0,
        orders: 0,
        days: new Set<string>(),
        cash: 0,
        nonCash: 0,
        bankRails: 0,
        netRevenue: 0,
        cogs: 0,
        costKnown: true,
        voided: 0,
      };
      byMonth.set(m, cur);
      return cur;
    };

    for (const o of orders) {
      const m = ensure(monthOf(o.createdAt));
      if (o.voids.length) {
        m.voided += 1;
        continue;
      }
      m.turnover += o.grandTotal;
      m.orders += 1;
      m.days.add(o.createdAt.toISOString().slice(0, 10));
      m.netRevenue += o.subtotal - o.discountTotal;
      for (const p of o.payments) {
        if (p.direction !== 'CHARGE' || p.status !== 'PAID') continue;
        if (p.method === 'CASH') m.cash += p.amount;
        else m.nonCash += p.amount;
        if (RAIL_OF_METHOD[p.method]) m.bankRails += p.amount;
      }
      for (const l of o.lines) {
        if (l.costPriceSnapshot == null) {
          // No catalogue, no cost — by definition, not by omission. Said so rather than sent as a
          // zero for a scorecard to read as a 100% margin.
          if (!l.variant?.product?.isOpenAmount) m.costKnown = false;
        } else {
          m.cogs += Math.round(l.costPriceSnapshot * Number(l.qty));
        }
      }
    }

    const months_ = [...byMonth.values()].sort((a, b) => a.month.localeCompare(b.month));
    const sellsFromCatalogue = !merchant?.calculatorOnly && merchant?.businessType !== 'HIGH_HUMAN_INTERACTION';

    const series = months_.map((m) => {
      const tradingDays = m.days.size;
      const grossProfit = m.netRevenue - m.cogs;
      return {
        month: m.month,
        turnover: m.turnover,
        orders: m.orders,
        avgTicket: m.orders ? Math.round(m.turnover / m.orders) : 0,
        tradingDays,
        avgPerTradingDay: tradingDays ? Math.round(m.turnover / tradingDays) : 0,
        cash: m.cash,
        nonCash: m.nonCash,
        cashShareBps: m.turnover > 0 ? Math.round((m.cash / m.turnover) * 10000) : 0,
        bankRailShareBps: m.turnover > 0 ? Math.round((m.bankRails / m.turnover) * 10000) : 0,
        voidedOrders: m.voided,
        // Margin only where a cost price can exist at all.
        grossProfit: sellsFromCatalogue && m.costKnown ? grossProfit : null,
        grossMarginBps:
          sellsFromCatalogue && m.costKnown && m.netRevenue > 0
            ? Math.round((grossProfit / m.netRevenue) * 10000)
            : null,
      };
    });

    const turnovers = series.map((s) => s.turnover);
    const first = orders.length
      ? orders.reduce((a, b) => (a.createdAt < b.createdAt ? a : b)).createdAt
      : null;

    return {
      merchant: {
        name: merchant?.name,
        businessType: merchant?.businessType,
        businessSize: merchant?.businessSize,
        hasQris: !!merchant?.qrisNmid,
        hasEdc: !!merchant?.edcTid,
        hasNpwp: !!merchant?.npwp,
        hasNib: !!merchant?.nib,
        sellsFromCatalogue,
      },
      series,
      summary: {
        // A score needs a floor, so the floor is in the payload rather than assumed.
        monthsOfHistory: first ? monthsBetween(first, new Date()) + 1 : 0,
        turnover12m: turnovers.reduce((a, b) => a + b, 0),
        avgMonthlyTurnover: turnovers.length
          ? Math.round(turnovers.reduce((a, b) => a + b, 0) / turnovers.length)
          : 0,
        medianMonthlyTurnover: median(turnovers),
        // How steady it is. The bank sizes an instalment off the bad months, not the average.
        turnoverCvBps: cvBps(turnovers),
        worstMonthTurnover: turnovers.length ? Math.min(...turnovers) : 0,
        bestMonthTurnover: turnovers.length ? Math.max(...turnovers) : 0,
        avgTradingDays: series.length
          ? Math.round(series.reduce((a, b) => a + b.tradingDays, 0) / series.length)
          : 0,
        longestGapDays: longestGap(orders.filter((o) => !o.voids.length).map((o) => o.createdAt)),
        cashShareBps: shareBps(series, 'cash'),
        nonCashShareBps: shareBps(series, 'nonCash'),
        growthBps: growthBps(turnovers),
      },
    };
  }

  // -------------------------------------------------------------- simple P&L

  /** Laporan Laba Rugi Sederhana — the three figures DPOS can prove, plus what the merchant adds. */
  async profitAndLoss(merchantId: string, q: PeriodQuery & { expenses?: number }) {
    const { from, to } = range(q, 30);
    const orders = await this.prisma.order.findMany({
      where: {
        merchantId,
        status: 'COMPLETED',
        ...(q.outletId ? { outletId: q.outletId } : {}),
        createdAt: { gte: from, lte: to },
      },
      include: {
        voids: { select: { id: true } },
        lines: {
          include: { variant: { select: { product: { select: { isOpenAmount: true } } } } },
        },
      },
    });

    let revenue = 0;
    let cogs = 0;
    let costKnown = true;
    let orderCount = 0;
    for (const o of orders) {
      if (o.voids.length) continue;
      orderCount += 1;
      revenue += o.subtotal - o.discountTotal;
      for (const l of o.lines) {
        if (l.costPriceSnapshot == null) {
          if (!l.variant?.product?.isOpenAmount) costKnown = false;
        } else {
          cogs += Math.round(l.costPriceSnapshot * Number(l.qty));
        }
      }
    }
    const expenses = Math.max(0, Math.round(q.expenses ?? 0));
    const grossProfit = revenue - cogs;
    return {
      range: isoRange(from, to),
      orderCount,
      pendapatan: revenue,
      hpp: cogs,
      labaKotor: grossProfit,
      bebanUsaha: expenses,
      labaBersih: grossProfit - expenses,
      // Said plainly rather than left for a reader to assume: a missing cost price would overstate
      // profit, so the statement declares whether every line had one.
      costComplete: costKnown,
    };
  }

  // --------------------------------------------------------- data integrity

  /**
   * What could distort the numbers above, stated rather than hidden.
   *
   * This does NOT claim the data cannot be wrong — a merchant can under-record cash. It offers the
   * three things that make tampering hard or visible: the reconciliation anchor, an append-only
   * correction trail, and patterns that betray editing after the fact.
   */
  async integrity(merchantId: string, q: PeriodQuery) {
    const { from, to } = range(q, 90);
    const orders = await this.prisma.order.findMany({
      where: { merchantId, createdAt: { gte: from, lte: to } },
      include: {
        voids: { select: { id: true, approvedById: true } },
        refunds: { select: { id: true, amount: true } },
        discounts: { select: { discountAmount: true } },
      },
    });

    const completed = orders.filter((o) => o.status === 'COMPLETED');
    const voided = completed.filter((o) => o.voids.length > 0);
    const refunded = completed.filter((o) => o.refunds.length > 0);
    const discounted = completed.filter((o) => o.discounts.length > 0);
    const grossSales = completed.reduce((s, o) => s + o.grandTotal, 0);

    // Who authorised the voids. A cluster on one approver is the pattern a risk officer looks for,
    // so the name is resolved rather than left as an id nobody can act on.
    const approverIds = [
      ...new Set(voided.flatMap((o) => o.voids.map((v) => v.approvedById).filter(Boolean))),
    ] as string[];
    const approvers = approverIds.length
      ? await this.prisma.staff.findMany({
          where: { id: { in: approverIds } },
          select: { id: true, name: true },
        })
      : [];
    const nameOf = new Map(approvers.map((s) => [s.id, s.name]));

    const byApprover = new Map<string, { name: string; count: number }>();
    for (const o of voided) {
      for (const v of o.voids) {
        const key = v.approvedById ?? 'self';
        const cur = byApprover.get(key) ?? {
          name: v.approvedById ? (nameOf.get(v.approvedById) ?? key) : '(self-authorised)',
          count: 0,
        };
        cur.count += 1;
        byApprover.set(key, cur);
      }
    }

    const devices = await this.prisma.order.groupBy({
      by: ['deviceId'],
      where: { merchantId, createdAt: { gte: from, lte: to }, deviceId: { not: null } },
      _count: { _all: true },
    });

    return {
      range: isoRange(from, to),
      orders: completed.length,
      grossSales,
      voids: {
        count: voided.length,
        amount: voided.reduce((s, o) => s + o.grandTotal, 0),
        rateBps: completed.length ? Math.round((voided.length / completed.length) * 10000) : 0,
        byApprover: [...byApprover.values()].sort((a, b) => b.count - a.count),
      },
      refunds: {
        count: refunded.length,
        amount: refunded.reduce((s, o) => s + o.refunds.reduce((x, r) => x + r.amount, 0), 0),
        rateBps: completed.length ? Math.round((refunded.length / completed.length) * 10000) : 0,
      },
      discounts: {
        count: discounted.length,
        amount: completed.reduce(
          (s, o) => s + o.discounts.reduce((x, d) => x + d.discountAmount, 0),
          0,
        ),
      },
      devices: devices.map((d) => ({ deviceId: d.deviceId, orders: d._count._all })),
      /**
       * Claims this report is prepared to stand behind, in the order a risk officer asks them.
       * They are properties of the system, not of any one merchant's honesty.
       */
      assurances: {
        serverRecomputesAmounts: true,
        correctionsAppendOnly: true,
        voidsRequireApproval: true,
        dataResidency: 'ap-southeast-3 (Jakarta)',
      },
    };
  }
}

// ---------------------------------------------------------------- helpers

function range(q: PeriodQuery, defaultDays: number) {
  const to = q.to ? new Date(`${q.to}T23:59:59.999Z`) : new Date();
  const from = q.from
    ? new Date(`${q.from}T00:00:00.000Z`)
    : new Date(to.getTime() - defaultDays * 86400000);
  return { from, to };
}

function isoRange(from: Date, to: Date) {
  return { from: from.toISOString().slice(0, 10), to: to.toISOString().slice(0, 10) };
}

function daysAgo(n: number) {
  return new Date(Date.now() - n * 86400000);
}

function monthsAgo(n: number) {
  const d = new Date();
  d.setUTCMonth(d.getUTCMonth() - n);
  return d;
}

function startOfMonth(d: Date) {
  return new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), 1));
}

function monthsBetween(a: Date, b: Date) {
  return (b.getUTCFullYear() - a.getUTCFullYear()) * 12 + (b.getUTCMonth() - a.getUTCMonth());
}

function median(xs: number[]): number {
  if (!xs.length) return 0;
  const s = [...xs].sort((a, b) => a - b);
  const mid = Math.floor(s.length / 2);
  return s.length % 2 ? s[mid] : Math.round((s[mid - 1] + s[mid]) / 2);
}

/** Coefficient of variation in basis points — how bumpy the monthly turnover is. */
function cvBps(xs: number[]): number {
  if (xs.length < 2) return 0;
  const mean = xs.reduce((a, b) => a + b, 0) / xs.length;
  if (mean === 0) return 0;
  const variance = xs.reduce((a, b) => a + (b - mean) ** 2, 0) / xs.length;
  return Math.round((Math.sqrt(variance) / mean) * 10000);
}

function shareBps(
  series: Array<{ turnover: number; cash: number; nonCash: number }>,
  key: 'cash' | 'nonCash',
): number {
  const total = series.reduce((a, b) => a + b.turnover, 0);
  if (!total) return 0;
  const part = series.reduce((a, b) => a + b[key], 0);
  return Math.round((part / total) * 10000);
}

/** Last month against the first, in basis points. Flat when there is too little history. */
function growthBps(xs: number[]): number {
  if (xs.length < 2 || xs[0] === 0) return 0;
  return Math.round(((xs[xs.length - 1] - xs[0]) / xs[0]) * 10000);
}

/** The longest run of days with no sale at all — the silence a lender cares about. */
function longestGap(dates: Date[]): number {
  if (dates.length < 2) return 0;
  const days = [...new Set(dates.map((d) => d.toISOString().slice(0, 10)))].sort();
  let worst = 0;
  for (let i = 1; i < days.length; i++) {
    const gap = Math.round(
      (new Date(days[i]).getTime() - new Date(days[i - 1]).getTime()) / 86400000,
    );
    if (gap - 1 > worst) worst = gap - 1;
  }
  return worst;
}
