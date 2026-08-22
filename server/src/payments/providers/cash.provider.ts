import { BadRequestException, Injectable } from '@nestjs/common';
import { PaymentMethod, PaymentStatus } from '@prisma/client';
import { ChargeInput, ChargeResult, PaymentProvider } from '../payment-provider';

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
}
