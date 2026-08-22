import { Prisma } from '@prisma/client';

/** Everything the API returns with an order (and everything effective-status derivation needs). */
export const ORDER_INCLUDE = {
  lines: true,
  discounts: true,
  payments: true,
  voids: true,
} satisfies Prisma.OrderInclude;

export type OrderWithRelations = Prisma.OrderGetPayload<{ include: typeof ORDER_INCLUDE }>;

/**
 * Derive the effective transaction state (Constitution IV):
 *  - VOIDED  when an OrderVoid exists
 *  - REFUNDED when a successful REVERSAL payment with reversalType=REFUND exists
 *  - otherwise the stored status (terminal at COMPLETED)
 * A VOID-type reversal never yields REFUNDED.
 */
export function deriveEffectiveStatus(order: OrderWithRelations): string {
  if (order.voids && order.voids.length > 0) return 'VOIDED';
  const refunded = order.payments?.some(
    (p) => p.direction === 'REVERSAL' && p.reversalType === 'REFUND' && p.status === 'PAID',
  );
  if (refunded) return 'REFUNDED';
  return order.status;
}

export function mapOrder(order: OrderWithRelations) {
  return { ...order, effectiveStatus: deriveEffectiveStatus(order) };
}
