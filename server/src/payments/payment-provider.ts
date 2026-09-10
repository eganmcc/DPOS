import { PaymentMethod, PaymentStatus, ReversalType } from '@prisma/client';

/** What an EDC terminal hands back after it authorizes a card-present sale. */
export interface EdcInput {
  scheme?: string; // VISA | MASTERCARD | BCA | JCB | OTHER
  maskedPan?: string; // e.g. "4811 **** **** 1234" — never a full PAN
  entryMode?: string; // CHIP | CONTACTLESS | SWIPE
  approvalCode?: string;
  rrn?: string; // retrieval reference number
  traceNo?: string;
  batchNo?: string;
  terminalId?: string;
  cardholderName?: string;
}

/** What an e-wallet returns once the customer's payment lands. */
export interface WalletInput {
  reference?: string;
}

/** Input the cashier (or the terminal) supplies for a tender. */
export interface ChargeInput {
  tendered?: number | null; // cash
  edc?: EdcInput | null; // card present
  wallet?: WalletInput | null; // e-wallet
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
  /** Tender-specific evidence for the receipt and reconciliation. Never money math. */
  providerMeta?: Record<string, unknown> | null;
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
  providerMeta?: Record<string, unknown> | null;
}

/**
 * PaymentProvider abstraction (Constitution VII): the MVP ships simulated QRIS, card (EDC) and
 * e-wallet providers; a real PSP or EDC integration later implements the same interface with no
 * change to checkout.
 *
 * A provider serving several tenders (one EDC covers credit/debit/BCA) declares them all in
 * `methods`; `method` stays its primary one.
 */
export interface PaymentProvider {
  readonly method: PaymentMethod;
  readonly methods?: readonly PaymentMethod[];
  charge(grandTotal: number, input: ChargeInput, method?: PaymentMethod): ChargeResult;
  /** Compensate a captured charge (void or refund). */
  reverse(input: ReversalInput, method?: PaymentMethod): ReversalResult;
}
