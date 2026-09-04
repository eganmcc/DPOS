import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { DashboardQuery } from './dto';

@Injectable()
export class DashboardService {
  constructor(private readonly prisma: PrismaService) {}

  /** Sales summary for the merchant (optionally one outlet), over a date range. */
  async summary(merchantId: string, q: DashboardQuery) {
    const to = q.to ? endOfDay(q.to) : new Date();
    const from = q.from ? startOfDay(q.from) : startOfDay(daysAgoIso(6));

    const orders = await this.prisma.order.findMany({
      where: {
        merchantId,
        status: 'COMPLETED',
        ...(q.outletId ? { outletId: q.outletId } : {}),
        createdAt: { gte: from, lte: to },
      },
      include: {
        voids: { select: { id: true } },
        lines: true,
        payments: true,
        outlet: { select: { id: true, name: true } },
      },
      orderBy: { createdAt: 'desc' },
    });

    // Voided sales are excluded from revenue (derived VOIDED state).
    const live = orders.filter((o) => o.voids.length === 0);

    const netSales = live.reduce((s, o) => s + o.grandTotal, 0);
    const orderCount = live.length;
    const avgTicket = orderCount ? Math.round(netSales / orderCount) : 0;

    const byMethod = new Map<string, number>();
    const byOutlet = new Map<string, { name: string; sales: number; count: number }>();
    const byItem = new Map<string, { name: string; qty: number; sales: number }>();
    const byDay = new Map<string, number>();

    for (const o of live) {
      for (const p of o.payments) {
        if (p.direction === 'CHARGE' && p.status === 'PAID') {
          byMethod.set(p.method, (byMethod.get(p.method) ?? 0) + p.amount);
        }
      }
      const ob = byOutlet.get(o.outletId) ?? { name: o.outlet.name, sales: 0, count: 0 };
      ob.sales += o.grandTotal;
      ob.count += 1;
      byOutlet.set(o.outletId, ob);

      for (const l of o.lines) {
        const it = byItem.get(l.productNameSnapshot) ?? { name: l.productNameSnapshot, qty: 0, sales: 0 };
        it.qty += Number(l.qty);
        it.sales += l.lineTotal;
        byItem.set(l.productNameSnapshot, it);
      }

      const day = o.createdAt.toISOString().slice(0, 10);
      byDay.set(day, (byDay.get(day) ?? 0) + o.grandTotal);
    }

    return {
      range: { from: from.toISOString().slice(0, 10), to: to.toISOString().slice(0, 10) },
      netSales,
      orderCount,
      avgTicket,
      paymentBreakdown: [...byMethod.entries()].map(([method, amount]) => ({ method, amount })),
      byOutlet: [...byOutlet.values()].sort((a, b) => b.sales - a.sales),
      topItems: [...byItem.values()].sort((a, b) => b.qty - a.qty).slice(0, 8),
      salesByDay: [...byDay.entries()].sort().map(([day, sales]) => ({ day, sales })),
    };
  }
}

function startOfDay(dayIso: string): Date {
  return new Date(`${dayIso}T00:00:00.000Z`);
}
function endOfDay(dayIso: string): Date {
  return new Date(`${dayIso}T23:59:59.999Z`);
}
function daysAgoIso(n: number): string {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() - n);
  return d.toISOString().slice(0, 10);
}
