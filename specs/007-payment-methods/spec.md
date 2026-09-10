# Feature Specification: Card and e-wallet payment methods

**Feature branch**: `feat/payment-methods` (cut from `features/UMI`)
**Date**: 2026-09-10
**Status**: implemented, pending device verification and migration

## Summary

The till accepts cash and QRIS. Indonesian F&B merchants also take **cards through an EDC terminal**
(credit, debit, and BCA-acquired debit) and **e-wallets** (ShopeePay, GoPay, OVO). This adds those six
tenders to the payment screen, behind the existing `PaymentProvider` abstraction, with a simulated EDC
round-trip standing in for a real terminal until an integration exists.

Card and e-wallet acceptance requires an acquirer relationship, which a one-person Ultra Mikro business
does not have — so these tenders are **available to non-UMI merchants only**, enforced server-side.

## Constitution check

| Principle | How this complies |
|---|---|
| III — server owns money math | The terminal supplies evidence, never an amount. A card charge is a normal `CHARGE` for the server-computed `grandTotal`; `providerMeta` is display and reconciliation data only. |
| IV — immutable history | A card void appends a `REVERSAL` with its own acquirer reference; the original authorization is never rewritten. |
| VI — least privilege, audit | The UMI tender restriction is enforced in the API (`UMI_TENDER_NOT_AVAILABLE`), not by hiding a button. |
| VII — simulated payments behind a real interface | `SimulatedEdcProvider` and `SimulatedEwalletProvider` implement the same `PaymentProvider` as cash and QRIS. A real EDC or PSP replaces the class with no change to checkout. |

**No constitution amendment required.** v1.7.0 already establishes UMI as a commercial tier; this adds a
tender boundary to it rather than a new principle.

## User Story 1 — Take a card payment (Priority: P1)

A cashier rings up a sale, selects Debit, Credit or BCA card, and processes it on the EDC. The terminal
authorizes and returns the slip data; the sale completes and the receipt shows the approval code.

**Independent Test**: Ring up a sale, pay by card, and confirm the order records a PAID `CHARGE` whose
`providerRef` is the approval code and whose `providerMeta` carries scheme, masked PAN, entry mode and RRN.

**Acceptance scenarios**
1. **Given** a sale in progress, **When** the cashier picks a card tender, **Then** the primary action
   becomes "Process on EDC" and the sale cannot be completed until the terminal approves.
2. **Given** the terminal approves, **Then** the sale completes automatically and the receipt shows the
   card scheme, masked PAN and approval code.
3. **Given** the terminal declines, **Then** no sale is recorded and the cashier can retry or switch tender.
4. **Given** a completed card sale, **When** an owner voids it, **Then** a `REVERSAL` is appended with its
   own reference and the original authorization is unchanged.

## User Story 2 — Take an e-wallet payment (Priority: P1)

A cashier selects ShopeePay, GoPay or OVO; the till shows a branded QR for the exact amount; the customer
scans; the cashier confirms receipt.

**Acceptance scenarios**
1. **Given** a wallet tender is selected, **Then** a QR for the exact amount renders with that wallet's mark.
2. **Given** the cashier confirms receipt, **Then** the sale completes with the wallet's reference stored.

## User Story 3 — Ultra Mikro stays on cash and QRIS (Priority: P1)

**Acceptance scenarios**
1. **Given** a UMI merchant, **Then** the till shows cash and QRIS only.
2. **Given** a UMI merchant and a direct API call with a card or wallet tender, **Then** the API responds
   `403 UMI_TENDER_NOT_AVAILABLE` and no order is created — for checkout and for settling an open bill.

## Functional requirements

- **FR-101**: The system MUST offer `CARD_CREDIT`, `CARD_DEBIT`, `CARD_BCA`, `EWALLET_SHOPEEPAY`,
  `EWALLET_GOPAY` and `EWALLET_OVO` alongside cash and QRIS for non-UMI merchants.
- **FR-102**: A card tender MUST route through an EDC step before the sale completes.
- **FR-103**: The system MUST store the terminal's evidence (scheme, masked PAN, entry mode, approval
  code, RRN, trace, batch, terminal id) with the payment, and MUST refuse a PAN that is not masked.
- **FR-104**: Payment amounts MUST remain server-computed; terminal data MUST NOT influence an amount.
- **FR-105**: Card and e-wallet tenders MUST be refused for UMI merchants by the API.
- **FR-106**: Receipts and the payment-split report MUST name every tender; no surface may show a raw
  enum code for a tender the app knows.
- **FR-107**: A void or refund of a card or wallet sale MUST append a reversal carrying its own reference.

## Success criteria

- **SC-101**: A card sale completes in under 20 seconds including the simulated terminal round-trip.
- **SC-102**: 100% of card sales store a non-null approval code and RRN.
- **SC-103**: 0 unmasked PANs are ever persisted (asserted by test).
- **SC-104**: UMI card/wallet attempts are refused 100% of the time, at checkout and at settle.

## What is simulated, and what changes when it is not

| Today | With a real terminal / PSP |
|---|---|
| `EdcScreen` mimics insert/tap → authorize → approve, and mints the approval code, RRN and trace | The terminal returns them over its SDK; the screen becomes a thin status view |
| `SimulatedEdcProvider` validates evidence and marks the payment PAID | The provider calls the acquirer and may report PENDING before settling |
| Wallet QR is a `DPOS-<WALLET>-SIM` payload | A PSP-issued QRIS payload with an asynchronous callback |

Nothing in checkout, the receipt, reports or the schema changes when that swap happens — which is the
point of the abstraction.

## Brand marks

The Visa, Mastercard, BCA, ShopeePay, GoPay and OVO marks in `app/assets/images/payments/` are
**placeholders** pending the official acceptance marks from the acquirer and wallet brand kits. Replacing
a file is the whole migration; `BrandMark` falls back to a text label if an asset is missing, so a bad
file never blanks the till. GoFood, GrabFood and ShopeeFood marks ship in the same folder for the
existing `ONLINE` tender.

## Out of scope

- Real EDC/PSP integration, settlement files, and batch close on the terminal.
- Split tender (part cash, part card) — one tender per sale, as today.
- Surcharges or MDR handling; the merchant absorbs fees outside the POS.
