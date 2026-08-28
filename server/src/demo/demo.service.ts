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
    return merchants
      .map((m) => {
        const cashier = m.staff.find((s) => s.role === StaffRole.CASHIER && s.demoPin);
        return {
          merchantId: m.id,
          name: m.name,
          businessType: m.businessType,
          cashierPin: cashier?.demoPin ?? null,
          outlets: m.outlets.map((o) => ({ id: o.id, name: o.name })),
        };
      })
      .filter((m) => m.cashierPin && m.outlets.length > 0);
  }
}
