import { StaffRole } from '@prisma/client';

export interface AuthUser {
  staffId: string;
  merchantId: string;
  role: StaffRole;
}

export interface JwtPayload {
  sub: string; // staffId
  merchantId: string;
  role: StaffRole;
}
