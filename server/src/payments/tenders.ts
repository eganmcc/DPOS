import { PaymentMethod } from '@prisma/client';

/** Card-present tenders, captured by an EDC terminal. */
export const CARD_METHODS: readonly PaymentMethod[] = [
  PaymentMethod.CARD_CREDIT,
  PaymentMethod.CARD_DEBIT,
  PaymentMethod.CARD_BCA,
];

/** E-wallet tenders (QRIS issuers in practice). */
export const EWALLET_METHODS: readonly PaymentMethod[] = [
  PaymentMethod.EWALLET_SHOPEEPAY,
  PaymentMethod.EWALLET_GOPAY,
  PaymentMethod.EWALLET_OVO,
];

/**
 * Tenders a UMI ("Ultra Mikro") merchant cannot accept.
 *
 * Card and e-wallet acceptance needs an acquirer relationship — an EDC terminal or a wallet
 * merchant account — which a one-person Ultra Mikro business is not set up with. UMI stays on
 * cash and QRIS. Enforced server-side because the UI hiding a button is not a rule
 * (Constitution VI); the app hides them too, for a clean till.
 */
export const UMI_RESTRICTED_METHODS: readonly PaymentMethod[] = [
  ...CARD_METHODS,
  ...EWALLET_METHODS,
];

export function isCardTender(method: PaymentMethod): boolean {
  return CARD_METHODS.includes(method);
}

export function isEwalletTender(method: PaymentMethod): boolean {
  return EWALLET_METHODS.includes(method);
}

export function isUmiRestrictedTender(method: PaymentMethod): boolean {
  return UMI_RESTRICTED_METHODS.includes(method);
}
