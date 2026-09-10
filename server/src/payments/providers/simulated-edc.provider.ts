import { BadRequestException, Injectable } from '@nestjs/common';
import { PaymentMethod, PaymentStatus } from '@prisma/client';
import {
  ChargeInput,
  ChargeResult,
  EdcInput,
  PaymentProvider,
  ReversalInput,
  ReversalResult,
} from '../payment-provider';

/** Card schemes the till can present. BCA is the acquirer for CARD_BCA, not a scheme. */
const SCHEMES = ['VISA', 'MASTERCARD', 'BCA', 'JCB', 'OTHER'];
const ENTRY_MODES = ['CHIP', 'CONTACTLESS', 'SWIPE'];

/** Six digits, zero-padded — the shape every EDC prints on the slip. */
function digits(n: number): string {
  return Math.floor(Math.random() * 10 ** n)
    .toString()
    .padStart(n, '0');
}

/**
 * Simulated EDC (card-present) provider covering credit, debit and BCA-acquired debit.
 *
 * The till's EDC screen collects what a terminal would hand back — scheme, masked PAN, entry
 * mode, approval code, RRN — and posts it with the sale. This provider VALIDATES that evidence
 * and owns the resulting payment status (Constitution VII: the backend owns state transitions).
 * Anything the terminal didn't supply is simulated here, so an API-only caller (and the test
 * suite) can charge a card without a device attached.
 *
 * A real EDC integration replaces this class and nothing in checkout changes.
 */
@Injectable()
export class SimulatedEdcProvider implements PaymentProvider {
  readonly method = PaymentMethod.CARD_CREDIT;
  readonly methods = [
    PaymentMethod.CARD_CREDIT,
    PaymentMethod.CARD_DEBIT,
    PaymentMethod.CARD_BCA,
  ] as const;

  charge(grandTotal: number, input: ChargeInput, method?: PaymentMethod): ChargeResult {
    const edc: EdcInput = input.edc ?? {};
    const resolved = method ?? this.method;

    if (edc.maskedPan && !/^[0-9*\s]{8,25}$/.test(edc.maskedPan)) {
      throw new BadRequestException('maskedPan must be digits and asterisks only');
    }
    if (edc.maskedPan && /\d{13,}/.test(edc.maskedPan.replace(/\s/g, ''))) {
      // Refuse to store what looks like a full PAN — the POS must never hold one.
      throw new BadRequestException('maskedPan looks unmasked; refusing to store a full PAN');
    }
    if (edc.scheme && !SCHEMES.includes(edc.scheme)) {
      throw new BadRequestException(`Unknown card scheme: ${edc.scheme}`);
    }
    if (edc.entryMode && !ENTRY_MODES.includes(edc.entryMode)) {
      throw new BadRequestException(`Unknown entry mode: ${edc.entryMode}`);
    }

    const approvalCode = edc.approvalCode ?? digits(6);
    const rrn = edc.rrn ?? `${Date.now()}`.slice(-12);
    const scheme = edc.scheme ?? (resolved === PaymentMethod.CARD_BCA ? 'BCA' : 'VISA');

    return {
      method: resolved,
      amount: grandTotal,
      status: PaymentStatus.PAID, // the terminal already authorized it
      providerRef: approvalCode,
      providerMeta: {
        scheme,
        maskedPan: edc.maskedPan ?? '**** **** **** 0000',
        entryMode: edc.entryMode ?? 'CHIP',
        approvalCode,
        rrn,
        traceNo: edc.traceNo ?? digits(6),
        batchNo: edc.batchNo ?? digits(6),
        terminalId: edc.terminalId ?? 'DPOS0001',
        acquirer: resolved === PaymentMethod.CARD_BCA ? 'BCA' : 'SIMULATED',
        cardholderName: edc.cardholderName ?? null,
        simulated: true,
      },
    };
  }

  /**
   * A card void/refund goes back through the acquirer and gets its own reference — the original
   * authorization is never rewritten (Constitution IV).
   */
  reverse(input: ReversalInput, method?: PaymentMethod): ReversalResult {
    const rrn = `${Date.now()}`.slice(-12);
    return {
      method: method ?? this.method,
      amount: input.amount,
      status: PaymentStatus.PAID,
      reversalType: input.reversalType,
      providerRef: `rev-${input.originalProviderRef ?? 'unknown'}-${rrn}`,
      providerMeta: { rrn, reversesApprovalCode: input.originalProviderRef ?? null, simulated: true },
    };
  }
}
