import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CreateBranchDto, UpdateBranchDto, UpdateMerchantDto } from './dto';

@Injectable()
export class EntityService {
  constructor(private readonly prisma: PrismaService) {}

  /** Company / entity settings. */
  async getMerchant(merchantId: string) {
    const m = await this.prisma.merchant.findUnique({ where: { id: merchantId } });
    if (!m) throw new NotFoundException('Merchant not found');
    return { id: m.id, name: m.name, businessType: m.businessType, logoUrl: m.logoUrl };
  }

  async updateMerchant(merchantId: string, dto: UpdateMerchantDto) {
    await this.prisma.merchant.update({
      where: { id: merchantId },
      data: {
        ...(dto.name !== undefined ? { name: dto.name } : {}),
        ...(dto.businessType !== undefined ? { businessType: dto.businessType } : {}),
        ...(dto.logoUrl !== undefined ? { logoUrl: dto.logoUrl } : {}),
      },
    });
    return this.getMerchant(merchantId);
  }

  /** Branches (outlets) with resolved manager name. */
  async listBranches(merchantId: string) {
    const [outlets, staff] = await Promise.all([
      this.prisma.outlet.findMany({ where: { merchantId }, orderBy: { name: 'asc' } }),
      this.prisma.staff.findMany({ where: { merchantId }, select: { id: true, name: true } }),
    ]);
    const nameById = new Map(staff.map((s) => [s.id, s.name]));
    return outlets.map((o) => ({
      id: o.id,
      code: o.code,
      name: o.name,
      address: o.address,
      managerId: o.managerId,
      managerName: o.managerId ? (nameById.get(o.managerId) ?? null) : null,
      paymentMode: o.paymentMode,
      isActive: o.isActive,
    }));
  }

  async createBranch(merchantId: string, dto: CreateBranchDto) {
    await this.assertManagerBelongs(merchantId, dto.managerId);
    try {
      const o = await this.prisma.outlet.create({
        data: {
          merchantId,
          code: dto.code ?? null,
          name: dto.name,
          address: dto.address ?? null,
          managerId: dto.managerId ?? null,
          paymentMode: dto.paymentMode ?? undefined,
        },
      });
      return this.oneBranch(merchantId, o.id);
    } catch (e) {
      throw this.branchError(e);
    }
  }

  async updateBranch(merchantId: string, id: string, dto: UpdateBranchDto) {
    const existing = await this.prisma.outlet.findFirst({ where: { id, merchantId } });
    if (!existing) throw new NotFoundException('Branch not found');
    await this.assertManagerBelongs(merchantId, dto.managerId);
    try {
      await this.prisma.outlet.update({
        where: { id },
        data: {
          ...(dto.code !== undefined ? { code: dto.code } : {}),
          ...(dto.name !== undefined ? { name: dto.name } : {}),
          ...(dto.address !== undefined ? { address: dto.address } : {}),
          ...(dto.managerId !== undefined ? { managerId: dto.managerId } : {}),
          ...(dto.paymentMode !== undefined ? { paymentMode: dto.paymentMode } : {}),
          ...(dto.isActive !== undefined ? { isActive: dto.isActive } : {}),
        },
      });
      return this.oneBranch(merchantId, id);
    } catch (e) {
      throw this.branchError(e);
    }
  }

  private async oneBranch(merchantId: string, id: string) {
    return (await this.listBranches(merchantId)).find((b) => b.id === id)!;
  }

  private async assertManagerBelongs(merchantId: string, managerId?: string) {
    if (!managerId) return;
    const s = await this.prisma.staff.findFirst({ where: { id: managerId, merchantId } });
    if (!s) throw new BadRequestException('Manager is not a staff member of this merchant');
  }

  private branchError(e: unknown): Error {
    if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
      return new BadRequestException('Branch code already in use');
    }
    return e as Error;
  }
}
