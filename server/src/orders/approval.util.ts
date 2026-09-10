import { ForbiddenException } from '@nestjs/common';
import * as bcrypt from 'bcryptjs';
import { StaffRole } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { isUmiMerchant } from '../common/business-size';
import { AuthUser } from '../auth/auth.types';

/**
 * How a correction came to be authorized. `approvedById` alone cannot say: null means
 * "self-authorized" AND "UMI bypass", and role is mutable, so it can never be
 * reconstructed after the fact. Callers record `basis` in the correction's AuditLog.
 */
export interface ApprovalOutcome {
  /** The MANAGER/OWNER who approved a cashier-initiated correction; null otherwise. */
  approvedById: string | null;
  basis: 'SELF' | 'UMI_BYPASS' | 'APPROVER_PIN';
}

/**
 * Authorize a void/refund/cancel. OWNER/MANAGER are self-authorized. A UMI merchant is a
 * single-person business, so every role is self-authorized there. Otherwise a CASHIER must
 * supply a manager/owner `approverPin`; if it matches an active OWNER/MANAGER of the same
 * merchant, that staff id is returned as the approver — otherwise 403.
 */
export async function resolveCorrectionApprover(
  prisma: PrismaService,
  user: AuthUser,
  approverPin?: string,
): Promise<ApprovalOutcome> {
  if (user.role === StaffRole.OWNER || user.role === StaffRole.MANAGER) {
    return { approvedById: null, basis: 'SELF' };
  }

  // UMI ("Ultra Mikro") is a single-person operation: there is no second person to
  // approve, so approval is bypassed for every role. Checked after the self-authorized
  // short-circuit so the common path pays no extra query. The mandatory reason on the
  // correction DTOs is untouched — it IS the audit record.
  if (await isUmiMerchant(prisma, user.merchantId)) {
    return { approvedById: null, basis: 'UMI_BYPASS' };
  }

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
    if (await bcrypt.compare(approverPin, a.pinHash)) {
      return { approvedById: a.id, basis: 'APPROVER_PIN' };
    }
  }
  throw new ForbiddenException({ code: 'APPROVAL_INVALID', message: 'Invalid manager PIN' });
}
