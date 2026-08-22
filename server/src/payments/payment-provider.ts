import { PaymentMethod, PaymentStatus, ReversalType } from '@prisma/client';

/** Input the cashier supplies for a tender. */
export interface ChargeInput {
  tendered?: number | null; // cash
}

/** Backend-owned result of a charge. Providers never persist — the orders service does. */
export interface ChargeResult {
  method: PaymentMethod;
  amount: number;
  status: PaymentStatus;
  tendered?: number | null;
  change?: number | null;
  providerRef?: string | null;
  qrPayload?: string | null;
}

/** The original CHARGE a reversal compensates. */
export interface ReversalInput {
  amount: number; // rupiah captured by the original charge
  reversalType: ReversalType; // VOID (void-driven) | REFUND (customer refund)
  originalProviderRef?: string | null;
}

/**
 * Backend-owned result of a reversal. A reversal is always a NEW payment row
 * (direction = REVERSAL) referencing the original CHARGE — the original is never mutated
 * (Constitution IV).
 */
export interface ReversalResult {
  method: PaymentMethod;
  amount: number;
  status: PaymentStatus;
  reversalType: ReversalType;
  providerRef?: string | null;
}

/**
 * PaymentProvider abstraction (Constitution VII): the MVP ships a simulated QRIS provider and a
 * cash provider; a real PSP later implements the same interface with no change to checkout.
 */
export interface PaymentProvider {
  readonly method: PaymentMethod;
  charge(grandTotal: number, input: ChargeInput): ChargeResult;
  /** Compensate a captured charge (void or refund). */
  reverse(input: ReversalInput): ReversalResult;
}
