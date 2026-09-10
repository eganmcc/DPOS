import { ForbiddenException, Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcryptjs';
import { StaffRole } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { JwtPayload } from './auth.types';
import { isUmiMerchant } from '../common/business-size';

export interface AuthResult {
  token: string;
  staffId: string;
  merchantId: string;
  role: StaffRole;
}

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
  ) {}

  async loginOwner(email: string, password: string): Promise<AuthResult> {
    const staff = await this.prisma.staff.findFirst({
      where: { email, role: StaffRole.OWNER, isActive: true },
    });
    if (!staff || !staff.passwordHash || !(await bcrypt.compare(password, staff.passwordHash))) {
      throw new UnauthorizedException('Invalid email or password');
    }
    // Email/password is the D-Customer Portal's door — the app logs in by PIN. A UMI
    // merchant manages its business in the app, so the portal is closed to it. Checked
    // AFTER the password comparison: before it, this would tell an unauthenticated
    // prober which emails exist and would cost a query on every failed attempt.
    if (await isUmiMerchant(this.prisma, staff.merchantId)) {
      throw new ForbiddenException({
        code: 'PORTAL_NOT_AVAILABLE',
        message: 'This account manages its business in the DPOS app.',
      });
    }
    return this.issue(staff.id, staff.merchantId, staff.role);
  }

  async loginPin(merchantId: string, pin: string): Promise<AuthResult> {
    const staffList = await this.prisma.staff.findMany({
      where: { merchantId, isActive: true },
    });
    for (const staff of staffList) {
      if (await bcrypt.compare(pin, staff.pinHash)) {
        return this.issue(staff.id, staff.merchantId, staff.role);
      }
    }
    throw new UnauthorizedException('Invalid PIN');
  }

  private async issue(staffId: string, merchantId: string, role: StaffRole): Promise<AuthResult> {
    const payload: JwtPayload = { sub: staffId, merchantId, role };
    const token = await this.jwt.signAsync(payload);
    return { token, staffId, merchantId, role };
  }
}
