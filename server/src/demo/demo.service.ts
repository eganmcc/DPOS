import { Injectable } from '@nestjs/common';
import { StaffRole } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

/** DEMO ONLY: a public directory of demo merchants → outlets, with the demo cashier
 * PIN, so the app login screen can offer dropdowns and prefill the PIN. Only merchants
 * that have a demo cashier PIN are listed (i.e. explicitly seeded demo accounts). */
@Injectable()
export class DemoService {
  constructor(private readonly prisma: PrismaService) {}

  async directory() {
    const merchants = await this.prisma.merchant.findMany({
      include: {
        outlets: { where: { isActive: true }, orderBy: { name: 'asc' } },
        staff: { where: { isActive: true } },
      },
      orderBy: { name: 'asc' },
    });
    const roleOrder: Record<string, number> = {
      [StaffRole.OWNER]: 0,
      [StaffRole.MANAGER]: 1,
      [StaffRole.CASHIER]: 2,
      [StaffRole.SERVER]: 3,
    };
    return merchants
      .map((m) => {
        // Every demo staff that carries a plaintext demo PIN becomes a selectable
        // login on the app's login screen (Owner / Manager / Cashier).
        const logins = m.staff
          .filter((s) => s.demoPin)
          .map((s) => ({ role: s.role, name: s.name, pin: s.demoPin as string }))
          .sort((a, b) => (roleOrder[a.role] ?? 9) - (roleOrder[b.role] ?? 9));
        const cashier = logins.find((l) => l.role === StaffRole.CASHIER);
        return {
          merchantId: m.id,
          name: m.name,
          businessType: m.businessType,
          cashierPin: cashier?.pin ?? null, // kept for backward compatibility
          logins,
          outlets: m.outlets.map((o) => ({ id: o.id, name: o.name })),
        };
      })
      .filter((m) => m.logins.length > 0 && m.outlets.length > 0);
  }
}
