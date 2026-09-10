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
import { OnlineProvider } from './providers/online.provider';
import { SimulatedEdcProvider } from './providers/simulated-edc.provider';
import { SimulatedEwalletProvider } from './providers/simulated-ewallet.provider';

/** Resolves the PaymentProvider for a method and applies backend-owned lifecycle rules. */
@Injectable()
export class PaymentsService {
  private readonly registry = new Map<PaymentMethod, PaymentProvider>();

  constructor(
    cash: CashProvider,
    qris: SimulatedQrisProvider,
    online: OnlineProvider,
    edc: SimulatedEdcProvider,
    ewallet: SimulatedEwalletProvider,
  ) {
    // A provider may serve several tenders (one EDC covers credit/debit/BCA).
    for (const p of [cash, qris, online, edc, ewallet] as PaymentProvider[]) {
      for (const m of p.methods ?? [p.method]) this.registry.set(m, p);
    }
  }

  charge(method: PaymentMethod, grandTotal: number, input: ChargeInput): ChargeResult {
    return this.provider(method).charge(grandTotal, input, method);
  }

  /**
   * Build the compensating movement of money for a captured charge. The caller persists it as a
   * NEW Payment row (direction = REVERSAL) pointing at the original CHARGE.
   */
  reverse(method: PaymentMethod, input: ReversalInput): ReversalResult {
    return this.provider(method).reverse(input, method);
  }

  private provider(method: PaymentMethod): PaymentProvider {
    const provider = this.registry.get(method);
    if (!provider) {
      throw new BadRequestException(`Unsupported payment method: ${method}`);
    }
    return provider;
  }
}
