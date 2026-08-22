import { Injectable } from '@nestjs/common';
import { PaymentMethod, PaymentStatus } from '@prisma/client';
import { v4 as uuidv4 } from 'uuid';
import { ChargeInput, ChargeResult, PaymentProvider } from '../payment-provider';

/**
 * Simulated QRIS: produces a QR payload for the exact amount and marks it PAID (demo "mark as
 * paid"). A real PSP (Midtrans/Xendit/DOKU) implements PaymentProvider with the same shape and
 * asynchronous PENDING → PAID transitions.
 */
@Injectable()
export class SimulatedQrisProvider implements PaymentProvider {
  readonly method = PaymentMethod.QRIS_SIMULATED;

  charge(grandTotal: number, _input: ChargeInput): ChargeResult {
    const ref = uuidv4();
    // A recognizable, non-real QR payload encoding the amount (rupiah).
    const qrPayload = `DPOS-QRIS-SIM|amount=${grandTotal}|ref=${ref}`;
    return {
      method: PaymentMethod.QRIS_SIMULATED,
      amount: grandTotal,
      status: PaymentStatus.PAID,
      providerRef: ref,
      qrPayload,
    };
  }
}
