import { BadRequestException, Injectable } from '@nestjs/common';
import { PaymentMethod } from '@prisma/client';
import { ChargeInput, ChargeResult, PaymentProvider } from './payment-provider';
import { CashProvider } from './providers/cash.provider';
import { SimulatedQrisProvider } from './providers/simulated-qris.provider';

/** Resolves the PaymentProvider for a method and applies backend-owned lifecycle rules. */
@Injectable()
export class PaymentsService {
  private readonly registry: Map<PaymentMethod, PaymentProvider>;

  constructor(cash: CashProvider, qris: SimulatedQrisProvider) {
    this.registry = new Map<PaymentMethod, PaymentProvider>([
      [cash.method, cash],
      [qris.method, qris],
    ]);
  }

  charge(method: PaymentMethod, grandTotal: number, input: ChargeInput): ChargeResult {
    const provider = this.registry.get(method);
    if (!provider) {
      throw new BadRequestException(`Unsupported payment method: ${method}`);
    }
    return provider.charge(grandTotal, input);
  }
}
