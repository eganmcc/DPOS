import { PaymentMethod, PaymentStatus } from '@prisma/client';

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

/**
 * PaymentProvider abstraction (Constitution VII): the MVP ships a simulated QRIS provider and a
 * cash provider; a real PSP later implements the same interface with no change to checkout.
 */
export interface PaymentProvider {
  readonly method: PaymentMethod;
  charge(grandTotal: number, input: ChargeInput): ChargeResult;
}
