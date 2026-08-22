import { BadRequestException, Injectable } from '@nestjs/common';
import { PaymentMethod, PaymentStatus } from '@prisma/client';
import {
  ChargeInput,
  ChargeResult,
  PaymentProvider,
  ReversalInput,
  ReversalResult,
} from '../payment-provider';

@Injectable()
export class CashProvider implements PaymentProvider {
  readonly method = PaymentMethod.CASH;

  charge(grandTotal: number, input: ChargeInput): ChargeResult {
    const tendered = input.tendered ?? grandTotal;
    if (tendered < grandTotal) {
      throw new BadRequestException('Tendered cash is less than the total due');
    }
    return {
      method: PaymentMethod.CASH,
      amount: grandTotal,
      status: PaymentStatus.PAID,
      tendered,
      change: tendered - grandTotal,
    };
  }

  /** Cash back out of the drawer settles immediately. */
  reverse(input: ReversalInput): ReversalResult {
    return {
      method: PaymentMethod.CASH,
      amount: input.amount,
      status: PaymentStatus.PAID,
      reversalType: input.reversalType,
    };
  }
}
