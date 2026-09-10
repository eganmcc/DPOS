import { Injectable } from '@nestjs/common';
import { PaymentMethod, PaymentStatus } from '@prisma/client';
import { v4 as uuidv4 } from 'uuid';
import {
  ChargeInput,
  ChargeResult,
  PaymentProvider,
  ReversalInput,
  ReversalResult,
} from '../payment-provider';

/** Display name + QR prefix per wallet. All three are QRIS issuers in practice. */
const WALLETS: Record<string, { label: string; code: string }> = {
  [PaymentMethod.EWALLET_SHOPEEPAY]: { label: 'ShopeePay', code: 'SPAY' },
  [PaymentMethod.EWALLET_GOPAY]: { label: 'GoPay', code: 'GOPAY' },
  [PaymentMethod.EWALLET_OVO]: { label: 'OVO', code: 'OVO' },
};

/**
 * Simulated e-wallet provider (ShopeePay / GoPay / OVO).
 *
 * Mirrors the QRIS simulator: renders a QR for the exact amount and settles on confirmation.
 * A real PSP implements the same interface with asynchronous CREATED → PENDING → PAID.
 */
@Injectable()
export class SimulatedEwalletProvider implements PaymentProvider {
  readonly method = PaymentMethod.EWALLET_GOPAY;
  readonly methods = [
    PaymentMethod.EWALLET_SHOPEEPAY,
    PaymentMethod.EWALLET_GOPAY,
    PaymentMethod.EWALLET_OVO,
  ] as const;

  charge(grandTotal: number, input: ChargeInput, method?: PaymentMethod): ChargeResult {
    const resolved = method ?? this.method;
    const wallet = WALLETS[resolved] ?? { label: 'E-Wallet', code: 'EWALLET' };
    const ref = input.wallet?.reference ?? uuidv4();

    return {
      method: resolved,
      amount: grandTotal,
      status: PaymentStatus.PAID,
      providerRef: ref,
      qrPayload: `DPOS-${wallet.code}-SIM|amount=${grandTotal}|ref=${ref}`,
      providerMeta: { wallet: wallet.label, reference: ref, simulated: true },
    };
  }

  reverse(input: ReversalInput, method?: PaymentMethod): ReversalResult {
    const resolved = method ?? this.method;
    return {
      method: resolved,
      amount: input.amount,
      status: PaymentStatus.PAID,
      reversalType: input.reversalType,
      providerRef: `rev-${input.originalProviderRef ?? 'unknown'}-${uuidv4()}`,
      providerMeta: {
        wallet: (WALLETS[resolved] ?? { label: 'E-Wallet' }).label,
        reversesReference: input.originalProviderRef ?? null,
        simulated: true,
      },
    };
  }
}
