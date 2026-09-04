import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AuthUser } from '../auth/auth.types';

@Injectable()
export class AttendanceService {
  constructor(private readonly prisma: PrismaService) {}

  /** The caller's latest open (not-yet-clocked-out) record, or null. */
  async current(user: AuthUser) {
    return this.prisma.attendance.findFirst({
      where: { staffId: user.staffId, clockOutAt: null },
      orderBy: { clockInAt: 'desc' },
    });
  }

  /** Clock in. Idempotent — if already on the clock, returns the open record. */
  async clockIn(user: AuthUser, outletId?: string) {
    const open = await this.current(user);
    if (open) return open;
    return this.prisma.attendance.create({
      data: {
        merchantId: user.merchantId,
        staffId: user.staffId,
        outletId: outletId ?? null,
      },
    });
  }

  /** Clock out the latest open record; returns null if not clocked in. */
  async clockOut(user: AuthUser) {
    const open = await this.current(user);
    if (!open) return null;
    return this.prisma.attendance.update({
      where: { id: open.id },
      data: { clockOutAt: new Date() },
    });
  }

  /**
   * Owner/manager attendance report: rows in a date range (by clock-in), each with
   * the staff name/role and worked minutes (null while still on the clock).
   */
  async adminList(merchantId: string, from?: string, to?: string) {
    const clockInAt: { gte?: Date; lt?: Date } = {};
    if (from) clockInAt.gte = startOfDay(from);
    if (to) clockInAt.lt = dayAfter(to);
    const rows = await this.prisma.attendance.findMany({
      where: { merchantId, ...(from || to ? { clockInAt } : {}) },
      include: { staff: { select: { name: true, role: true } } },
      orderBy: { clockInAt: 'desc' },
    });
    return rows.map((r) => ({
      id: r.id,
      staffName: r.staff.name,
      role: r.staff.role,
      clockInAt: r.clockInAt,
      clockOutAt: r.clockOutAt,
      minutes: r.clockOutAt
        ? Math.max(0, Math.round((r.clockOutAt.getTime() - r.clockInAt.getTime()) / 60000))
        : null,
      open: r.clockOutAt === null,
    }));
  }
}

function startOfDay(day: string): Date {
  return new Date(`${day}T00:00:00.000Z`);
}

function dayAfter(day: string): Date {
  const d = new Date(`${day}T00:00:00.000Z`);
  d.setUTCDate(d.getUTCDate() + 1);
  return d;
}
