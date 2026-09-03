import { ForbiddenException } from '@nestjs/common';
import * as bcrypt from 'bcryptjs';
import { StaffRole } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { AuthUser } from '../auth/auth.types';

/**
 * Authorize a void/refund. OWNER/MANAGER are self-authorized (returns null). A CASHIER
 * must supply a manager/owner `approverPin`; if it matches an active OWNER/MANAGER of the
 * same merchant, that staff id is returned (the approver) — otherwise 403.
 */
export async function resolveCorrectionApprover(
  prisma: PrismaService,
  user: AuthUser,
  approverPin?: string,
): Promise<string | null> {
  if (user.role === StaffRole.OWNER || user.role === StaffRole.MANAGER) return null;

  if (!approverPin) {
    throw new ForbiddenException({
      code: 'APPROVAL_REQUIRED',
      message: 'Manager or owner approval is required',
    });
  }
  const approvers = await prisma.staff.findMany({
    where: {
      merchantId: user.merchantId,
      isActive: true,
      role: { in: [StaffRole.OWNER, StaffRole.MANAGER] },
    },
    select: { id: true, pinHash: true },
  });
  for (const a of approvers) {
    if (await bcrypt.compare(approverPin, a.pinHash)) return a.id;
  }
  throw new ForbiddenException({ code: 'APPROVAL_INVALID', message: 'Invalid manager PIN' });
}
