import { Injectable } from '@nestjs/common';
import { PaymentMethod, PaymentStatus } from '@prisma/client';
import {
  ChargeInput,
  ChargeResult,
  PaymentProvider,
  ReversalInput,
  ReversalResult,
} from '../payment-provider';

/**
 * Online-delivery platform payment (GoFood/GrabFood/ShopeeFood). The customer has
 * already paid in the platform's app, so ingestion records a settled CHARGE for the
 * server-authoritative grand total — there is no in-store tender. A platform
 * cancellation later compensates via a REVERSAL, same as any other method.
 */
@Injectable()
export class OnlineProvider implements PaymentProvider {
  readonly method = PaymentMethod.ONLINE;

  charge(grandTotal: number, _input: ChargeInput): ChargeResult {
    return {
      method: PaymentMethod.ONLINE,
      amount: grandTotal,
      status: PaymentStatus.PAID,
    };
  }

  reverse(input: ReversalInput): ReversalResult {
    return {
      method: PaymentMethod.ONLINE,
      amount: input.amount,
      status: PaymentStatus.PAID,
      reversalType: input.reversalType,
    };
  }
}
