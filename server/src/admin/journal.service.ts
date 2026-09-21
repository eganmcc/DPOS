import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { PeriodQuery, range, isoRange } from './bank.service';

/**
 * Transaction-level and journal reporting (specs/011-bank-reporting).
 *
 * The bank reports next door answer "can this merchant repay". These answer the question that
 * always follows it — **show me the transactions** — and the one an accountant asks instead:
 * give me something I can post.
 *
 * All of it is derived from recorded orders; nothing here computes money that was not already
 * computed at the till (Constitution III), and nothing is editable (IV).
 */
@Injectable()
export class JournalService {
  constructor(private readonly prisma: PrismaService) {}

  // ------------------------------------------------------- jurnal transaksi

  /**
   * Every transaction in the period, newest first — the workhorse listing.
   *
   * Voided and refunded sales are INCLUDED and labelled rather than filtered out. A journal that
   * quietly omits the corrections is the one nobody can audit; the status column is the point.
   */
  async transactions(merchantId: string, q: PeriodQuery & { limit?: number; offset?: number }) {
    const { from, to } = range(q, 30);
    const take = Math.min(2000, Math.max(1, q.limit ?? 200));
    const skip = Math.max(0, q.offset ?? 0);

    const where = {
      merchantId,
      ...(q.outletId ? { outletId: q.outletId } : {}),
      createdAt: { gte: from, lte: to },
      status: { in: ['COMPLETED', 'AWAITING_PAYMENT', 'CANCELLED'] as never },
    };

    const [total, orders] = await Promise.all([
      this.prisma.order.count({ where }),
      this.prisma.order.findMany({
        where,
        include: {
          outlet: { select: { name: true } },
          payments: { select: { method: true, amount: true, direction: true, status: true } },
          voids: { select: { id: true, reason: true, createdAt: true } },
          refunds: { select: { id: true, amount: true } },
          lines: { select: { productNameSnapshot: true, qty: true, lineTotal: true } },
        },
        orderBy: { createdAt: 'desc' },
        take,
        skip,
      }),
    ]);

    const staff = await this.staffNames(merchantId);

    return {
      range: isoRange(from, to),
      total,
      limit: take,
      offset: skip,
      rows: orders.map((o) => {
        const refunded = o.refunds.reduce((s, r) => s + r.amount, 0);
        return {
          id: o.id,
          at: o.createdAt.toISOString(),
          outlet: o.outlet.name,
          cashier: staff.get(o.cashierId) ?? o.cashierId,
          type: o.type,
          channel: o.channel,
          ref: o.externalOrderRef,
          customer: o.customerName,
          items: o.lines.length,
          // A one-line description of what was sold, so the journal reads without opening each row.
          description: o.lines
            .slice(0, 3)
            .map((l) => `${trimNum(l.qty)}× ${l.productNameSnapshot}`)
            .join(', ') + (o.lines.length > 3 ? ` +${o.lines.length - 3}` : ''),
          subtotal: o.subtotal,
          discount: o.discountTotal,
          tax: o.taxTotal,
          service: o.serviceChargeTotal,
          total: o.grandTotal,
          methods: [
            ...new Set(
              o.payments.filter((p) => p.direction === 'CHARGE' && p.status === 'PAID').map((p) => p.method),
            ),
          ],
          refunded,
          status: o.voids.length
            ? 'VOIDED'
            : refunded > 0
              ? refunded >= o.grandTotal
                ? 'REFUNDED'
                : 'PARTIAL_REFUND'
              : o.status,
          voidReason: o.voids[0]?.reason ?? null,
        };
      }),
    };
  }

  // ---------------------------------------------------------- rekap harian

  /** One row per day: the end-of-day figures a merchant reconciles their drawer against. */
  async daily(merchantId: string, q: PeriodQuery) {
    const { from, to } = range(q, 30);
    const orders = await this.prisma.order.findMany({
      where: {
        merchantId,
        status: 'COMPLETED',
        ...(q.outletId ? { outletId: q.outletId } : {}),
        createdAt: { gte: from, lte: to },
      },
      include: {
        payments: { select: { method: true, amount: true, direction: true, status: true } },
        voids: { select: { id: true } },
        refunds: { select: { amount: true } },
      },
    });

    type Day = {
      day: string;
      orders: number;
      voided: number;
      subtotal: number;
      discount: number;
      tax: number;
      service: number;
      gross: number;
      refunded: number;
      cash: number;
      nonCash: number;
      byMethod: Map<string, number>;
    };
    const days = new Map<string, Day>();
    for (const o of orders) {
      const key = o.createdAt.toISOString().slice(0, 10);
      const d =
        days.get(key) ??
        ({
          day: key, orders: 0, voided: 0, subtotal: 0, discount: 0, tax: 0,
          service: 0, gross: 0, refunded: 0, cash: 0, nonCash: 0, byMethod: new Map(),
        } as Day);
      days.set(key, d);
      if (o.voids.length) {
        d.voided += 1;
        continue; // a voided sale is counted, never banked
      }
      d.orders += 1;
      d.subtotal += o.subtotal;
      d.discount += o.discountTotal;
      d.tax += o.taxTotal;
      d.service += o.serviceChargeTotal;
      d.gross += o.grandTotal;
      d.refunded += o.refunds.reduce((s, r) => s + r.amount, 0);
      for (const p of o.payments) {
        if (p.direction !== 'CHARGE' || p.status !== 'PAID') continue;
        if (p.method === 'CASH') d.cash += p.amount;
        else d.nonCash += p.amount;
        d.byMethod.set(p.method, (d.byMethod.get(p.method) ?? 0) + p.amount);
      }
    }

    const rows = [...days.values()]
      .sort((a, b) => b.day.localeCompare(a.day))
      .map((d) => ({
        ...d,
        byMethod: [...d.byMethod.entries()].map(([method, amount]) => ({ method, amount })),
        // What should be in the drawer at close, before payouts.
        netCash: d.cash,
      }));

    return {
      range: isoRange(from, to),
      rows,
      totals: rows.reduce(
        (a, r) => ({
          orders: a.orders + r.orders,
          voided: a.voided + r.voided,
          subtotal: a.subtotal + r.subtotal,
          discount: a.discount + r.discount,
          tax: a.tax + r.tax,
          service: a.service + r.service,
          gross: a.gross + r.gross,
          refunded: a.refunded + r.refunded,
          cash: a.cash + r.cash,
          nonCash: a.nonCash + r.nonCash,
        }),
        { orders: 0, voided: 0, subtotal: 0, discount: 0, tax: 0, service: 0, gross: 0, refunded: 0, cash: 0, nonCash: 0 },
      ),
    };
  }

  // -------------------------------------------------------- jurnal koreksi

  /**
   * Every void, refund and cancellation, with its reason and who approved it.
   *
   * This is the append-only trail the constitution promises, read back as a report: corrections
   * are records, so they can be listed. A system that could not produce this list would not be
   * able to claim history is immutable.
   */
  async corrections(merchantId: string, q: PeriodQuery) {
    const { from, to } = range(q, 90);
    const [voids, refunds, cancelled] = await Promise.all([
      this.prisma.orderVoid.findMany({
        where: { merchantId, createdAt: { gte: from, lte: to } },
        include: { order: { select: { grandTotal: true, createdAt: true, externalOrderRef: true } } },
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.refund.findMany({
        where: { merchantId, createdAt: { gte: from, lte: to } },
        include: { order: { select: { grandTotal: true, createdAt: true, externalOrderRef: true } } },
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.order.findMany({
        where: { merchantId, status: 'CANCELLED', createdAt: { gte: from, lte: to } },
        select: { id: true, createdAt: true, grandTotal: true, tableLabel: true },
        orderBy: { createdAt: 'desc' },
      }),
    ]);

    const staff = await this.staffNames(merchantId);
    const who = (id: string | null) => (id ? (staff.get(id) ?? id) : null);

    const rows = [
      ...voids.map((v) => ({
        kind: 'VOID',
        at: v.createdAt.toISOString(),
        orderId: v.orderId,
        orderAt: v.order.createdAt.toISOString(),
        amount: v.order.grandTotal,
        reason: v.reason,
        by: who(v.voidedById),
        approvedBy: who(v.approvedById),
        selfApproved: v.approvedById == null,
      })),
      ...refunds.map((r) => ({
        kind: r.isFull ? 'REFUND' : 'PARTIAL_REFUND',
        at: r.createdAt.toISOString(),
        orderId: r.orderId,
        orderAt: r.order.createdAt.toISOString(),
        amount: r.amount,
        reason: r.reason,
        by: who(r.refundedById),
        approvedBy: who(r.approvedById),
        selfApproved: r.approvedById == null,
      })),
      ...cancelled.map((o) => ({
        kind: 'CANCELLED_BILL',
        at: o.createdAt.toISOString(),
        orderId: o.id,
        orderAt: o.createdAt.toISOString(),
        amount: o.grandTotal,
        reason: o.tableLabel ? `meja ${o.tableLabel}` : null,
        by: null,
        approvedBy: null,
        selfApproved: false,
      })),
    ].sort((a, b) => b.at.localeCompare(a.at));

    return {
      range: isoRange(from, to),
      rows,
      totals: {
        voids: voids.length,
        voidAmount: voids.reduce((s, v) => s + v.order.grandTotal, 0),
        refunds: refunds.length,
        refundAmount: refunds.reduce((s, r) => s + r.amount, 0),
        cancelled: cancelled.length,
        // Corrections a cashier authorised alone. Not wrong on its own — an owner IS the approver
        // in a one-person shop — but the number a reviewer wants in front of them.
        selfApproved: rows.filter((r) => r.selfApproved).length,
      },
    };
  }

  // ------------------------------------------------------------ rekap pajak

  /** What was collected as tax and service charge, per day, with the rate it was charged at. */
  async tax(merchantId: string, q: PeriodQuery) {
    const { from, to } = range(q, 31);
    const orders = await this.prisma.order.findMany({
      where: {
        merchantId,
        status: 'COMPLETED',
        ...(q.outletId ? { outletId: q.outletId } : {}),
        createdAt: { gte: from, lte: to },
      },
      include: { voids: { select: { id: true } } },
    });

    const days = new Map<string, { day: string; base: number; tax: number; service: number; orders: number }>();
    const labels = new Set<string>();
    let rateBps: number | null = null;
    for (const o of orders) {
      if (o.voids.length) continue;
      if (o.taxLabelSnapshot) labels.add(o.taxLabelSnapshot);
      if (o.taxRateBpsSnapshot != null) rateBps = o.taxRateBpsSnapshot;
      const key = o.createdAt.toISOString().slice(0, 10);
      const d = days.get(key) ?? { day: key, base: 0, tax: 0, service: 0, orders: 0 };
      d.base += o.subtotal - o.discountTotal;
      d.tax += o.taxTotal;
      d.service += o.serviceChargeTotal;
      d.orders += 1;
      days.set(key, d);
    }
    const rows = [...days.values()].sort((a, b) => b.day.localeCompare(a.day));
    return {
      range: isoRange(from, to),
      label: [...labels][0] ?? null,
      rateBps,
      rows,
      totals: rows.reduce(
        (a, r) => ({ base: a.base + r.base, tax: a.tax + r.tax, service: a.service + r.service, orders: a.orders + r.orders }),
        { base: 0, tax: 0, service: 0, orders: 0 },
      ),
    };
  }

  // ------------------------------------------------------------ jurnal umum

  /**
   * Double-entry postings, one set per day — the report an accountant can actually use.
   *
   * Debits: cash and bank receipts, and cost of goods sold.
   * Credits: sales revenue, tax payable, service charge, and inventory.
   *
   * Every day balances by construction, and the check is returned rather than asserted: if
   * `balanced` is ever false the figures upstream disagree with each other and the report says so
   * instead of hiding it behind a tidy total.
   */
  async generalJournal(merchantId: string, q: PeriodQuery) {
    const { from, to } = range(q, 31);
    const orders = await this.prisma.order.findMany({
      where: {
        merchantId,
        status: 'COMPLETED',
        ...(q.outletId ? { outletId: q.outletId } : {}),
        createdAt: { gte: from, lte: to },
      },
      include: {
        payments: { select: { method: true, amount: true, direction: true, status: true } },
        voids: { select: { id: true } },
        lines: {
          select: {
            qty: true,
            costPriceSnapshot: true,
            variant: { select: { product: { select: { isOpenAmount: true } } } },
          },
        },
      },
    });

    type Day = { day: string; cash: number; bank: number; revenue: number; tax: number; service: number; cogs: number; costKnown: boolean };
    const days = new Map<string, Day>();
    for (const o of orders) {
      if (o.voids.length) continue;
      const key = o.createdAt.toISOString().slice(0, 10);
      const d = days.get(key) ?? { day: key, cash: 0, bank: 0, revenue: 0, tax: 0, service: 0, cogs: 0, costKnown: true };
      days.set(key, d);
      d.revenue += o.subtotal - o.discountTotal;
      d.tax += o.taxTotal;
      d.service += o.serviceChargeTotal;
      for (const p of o.payments) {
        if (p.direction !== 'CHARGE' || p.status !== 'PAID') continue;
        if (p.method === 'CASH') d.cash += p.amount;
        else d.bank += p.amount; // QRIS, card and wallets all land in the merchant's account
      }
      for (const l of o.lines) {
        if (l.costPriceSnapshot == null) {
          if (!l.variant?.product?.isOpenAmount) d.costKnown = false;
        } else {
          d.cogs += Math.round(l.costPriceSnapshot * Number(l.qty));
        }
      }
    }

    const entries = [...days.values()]
      .sort((a, b) => b.day.localeCompare(a.day))
      .map((d) => {
        const postings = [
          { account: 'Kas', debit: d.cash, credit: 0 },
          { account: 'Bank / Piutang Penyelenggara', debit: d.bank, credit: 0 },
          { account: 'Pendapatan Penjualan', debit: 0, credit: d.revenue },
          { account: 'Pajak Terutang (PB1/PPN)', debit: 0, credit: d.tax },
          { account: 'Service Charge', debit: 0, credit: d.service },
          ...(d.cogs > 0
            ? [
                { account: 'Harga Pokok Penjualan', debit: d.cogs, credit: 0 },
                { account: 'Persediaan', debit: 0, credit: d.cogs },
              ]
            : []),
        ].filter((p) => p.debit !== 0 || p.credit !== 0);
        const debit = postings.reduce((s, p) => s + p.debit, 0);
        const credit = postings.reduce((s, p) => s + p.credit, 0);
        return {
          day: d.day,
          postings,
          debit,
          credit,
          balanced: debit === credit,
          // Without a cost price the HPP/Persediaan pair is missing, and the entry still balances
          // — but the reader must know the cost side is incomplete rather than zero.
          costComplete: d.costKnown,
        };
      });

    return {
      range: isoRange(from, to),
      entries,
      totals: {
        debit: entries.reduce((s, e) => s + e.debit, 0),
        credit: entries.reduce((s, e) => s + e.credit, 0),
        unbalancedDays: entries.filter((e) => !e.balanced).length,
      },
    };
  }

  // ----------------------------------------------------------------- shared

  private async staffNames(merchantId: string) {
    const staff = await this.prisma.staff.findMany({
      where: { merchantId },
      select: { id: true, name: true },
    });
    return new Map(staff.map((s) => [s.id, s.name]));
  }
}


/** Decimal(12,3) reads as "2" rather than "2.000" in a journal a human is scanning. */
function trimNum(q: unknown): string {
  const n = Number(q);
  return Number.isInteger(n) ? String(n) : String(n);
}
