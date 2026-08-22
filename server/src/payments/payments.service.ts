import { BadRequestException, Injectable } from '@nestjs/common';
import { PaymentMethod } from '@prisma/client';
import {
  ChargeInput,
  ChargeResult,
  PaymentProvider,
  ReversalInput,
  ReversalResult,
} from './payment-provider';
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
    return this.provider(method).charge(grandTotal, input);
  }

  /**
   * Build the compensating movement of money for a captured charge. The caller persists it as a
   * NEW Payment row (direction = REVERSAL) pointing at the original CHARGE.
   */
  reverse(method: PaymentMethod, input: ReversalInput): ReversalResult {
    return this.provider(method).reverse(input);
  }

  private provider(method: PaymentMethod): PaymentProvider {
    const provider = this.registry.get(method);
    if (!provider) {
      throw new BadRequestException(`Unsupported payment method: ${method}`);
    }
    return provider;
  }
}
