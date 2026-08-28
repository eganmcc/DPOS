import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import * as bcrypt from 'bcryptjs';
import { PrismaService } from '../prisma/prisma.service';
import { CreateStaffDto, SetPinDto, UpdateStaffDto } from './dto';

@Injectable()
export class StaffService {
  constructor(private readonly prisma: PrismaService) {}

  async list(merchantId: string) {
    const [staff, outlets] = await Promise.all([
      this.prisma.staff.findMany({ where: { merchantId }, orderBy: { name: 'asc' } }),
      this.prisma.outlet.findMany({ where: { merchantId }, select: { id: true, name: true } }),
    ]);
    const outletName = new Map(outlets.map((o) => [o.id, o.name]));
    return staff.map((s) => this.view(s, outletName));
  }

  async create(merchantId: string, dto: CreateStaffDto) {
    await this.assertOutlet(merchantId, dto.outletId);
    const employeeId = await this.nextEmployeeId(merchantId);
    const s = await this.prisma.staff.create({
      data: {
        merchantId,
        employeeId,
        name: dto.name,
        phone: dto.phone ?? null,
        role: dto.role,
        outletId: dto.outletId ?? null,
        pinHash: await bcrypt.hash(dto.pin, 10),
        email: dto.email ?? null,
        passwordHash: dto.password ? await bcrypt.hash(dto.password, 10) : null,
      },
    });
    return this.one(merchantId, s.id);
  }

  async update(merchantId: string, id: string, dto: UpdateStaffDto) {
    await this.assertStaff(merchantId, id);
    await this.assertOutlet(merchantId, dto.outletId);
    await this.prisma.staff.update({
      where: { id },
      data: {
        ...(dto.name !== undefined ? { name: dto.name } : {}),
        ...(dto.phone !== undefined ? { phone: dto.phone } : {}),
        ...(dto.role !== undefined ? { role: dto.role } : {}),
        ...(dto.outletId !== undefined ? { outletId: dto.outletId } : {}),
        ...(dto.email !== undefined ? { email: dto.email } : {}),
        ...(dto.isActive !== undefined ? { isActive: dto.isActive } : {}),
      },
    });
    return this.one(merchantId, id);
  }

  async setPin(merchantId: string, id: string, dto: SetPinDto) {
    await this.assertStaff(merchantId, id);
    await this.prisma.staff.update({
      where: { id },
      data: { pinHash: await bcrypt.hash(dto.pin, 10) },
    });
    return { ok: true };
  }

  private async one(merchantId: string, id: string) {
    return (await this.list(merchantId)).find((s) => s.id === id)!;
  }

  // Never leak hashes.
  private view(s: { id: string; employeeId: string | null; name: string; phone: string | null; role: string; outletId: string | null; email: string | null; isActive: boolean }, outletName: Map<string, string>) {
    return {
      id: s.id,
      employeeId: s.employeeId,
      name: s.name,
      phone: s.phone,
      role: s.role,
      outletId: s.outletId,
      outletName: s.outletId ? (outletName.get(s.outletId) ?? null) : null, // null = HQ
      email: s.email,
      isActive: s.isActive,
    };
  }

  private async assertStaff(merchantId: string, id: string) {
    const s = await this.prisma.staff.findFirst({ where: { id, merchantId } });
    if (!s) throw new NotFoundException('Staff not found');
  }

  private async assertOutlet(merchantId: string, outletId?: string) {
    if (!outletId) return;
    const o = await this.prisma.outlet.findFirst({ where: { id: outletId, merchantId } });
    if (!o) throw new BadRequestException('Outlet not found in this merchant');
  }

  /** "EMP0001", "EMP0002", … — max existing numeric suffix + 1, per merchant. */
  private async nextEmployeeId(merchantId: string): Promise<string> {
    const rows = await this.prisma.staff.findMany({
      where: { merchantId, employeeId: { not: null } },
      select: { employeeId: true },
    });
    let max = 0;
    for (const r of rows) {
      const n = parseInt((r.employeeId ?? '').replace(/\D/g, ''), 10);
      if (!Number.isNaN(n) && n > max) max = n;
    }
    return `EMP${String(max + 1).padStart(4, '0')}`;
  }
}
