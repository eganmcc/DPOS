# Feature Spec — Calculator-Only Mode

**Feature ID:** 008-calculator-only
**Status:** In progress
**Applies to:** UMI merchants (business SIZE), orthogonal to business type.
Constitution v1.8.0.

## Why

`006-umi-business-size` established that a UMI merchant is a one-person operation and capped its
catalog at 30 items as a concession to how little structure these businesses have. For a large part
of the segment even 30 is 30 too many: a warung, a street-food cart, a market trader has **no
catalog at all**. They know their prices, they quote them out loud, they take cash. Asking them to
build a product list before they can ring anything up is asking them to do bookkeeping they have
never done, in order to use a till they only wanted for the till.

**Calculator-only mode removes the catalog from the equation.** The cashier keys a bare rupiah
amount per item on a keypad, sees a running list and a total, takes cash, and the screen shows the
change.

What makes this a POS mode rather than a calculator app: **every finished nota is recorded as a real
sale.** It appears in the transaction history, it can be voided, and it feeds the same
server-authoritative reporting as any other sale. A merchant who uses this for a month has a month
of books — which is the entire point of them using DPOS instead of the calculator they already own.

## User Stories & Acceptance

### A. The mode

1. `Merchant.calculatorOnly` is a boolean defaulting to **false**, set by **DPOS provisioning** and
   **read-only over the API** — returned by `GET /catalog`, accepted by no endpoint. A merchant MUST
   NOT be able to switch itself into or out of the mode.
2. It is only meaningful alongside `businessSize = UMI`; the tender restrictions and correction
   rules of `006` apply unchanged.
3. Every existing merchant is `false` and behaves exactly as before. No existing order, product or
   report changes.

### B. Selling

1. The app lands a calculator-only merchant **directly on the keypad** — no product grid, no cart.
   Riwayat, Laporan and Setelan remain reachable from its app bar.
2. The cashier keys an amount, commits it with `↵`, and repeats. The screen shows the current entry,
   the item count, the committed list, and the running total.
3. **Batal** abandons the whole nota behind a confirm dialog. Nothing was sent, so there is nothing
   to void and no audit record is owed. The nota number does **not** advance.
4. **Selesai** opens cash payment: amount received, live change (`Kembalian`) or shortfall
   (`Kurang`). The sale cannot be completed while the tender is short — refused by the app and,
   independently, by the server.
5. A completed nota resets the keypad for the next customer. The "Nota #N" counter is a
   **device-local display affordance** that resets daily; it is never sent to the server and is
   never an order's identity.
6. Selling works **offline**, through the same queue as every other sale: the order is enqueued
   locally with its client UUID and replayed when the connection returns.

### C. How the sale is recorded

1. Each keyed amount becomes one `OrderLine` with `qty = 1` and the keyed amount as its
   `unitPriceSnapshot` and `lineTotal`.
2. Lines point at a **provisioned open-amount variant** — one hidden `Product` per calculator
   merchant, flagged `isOpenAmount`, created by provisioning and settable through no API. It is
   excluded from `GET /catalog`, from the in-app item manager, and from the UMI 30-item cap.
3. `OrderLine.variantId` remains `NOT NULL`. The referential guarantee that every line points at a
   real catalog row is preserved for **every** merchant.
4. The server MUST still compute `subtotal`, discounts, tax, service charge, `grandTotal` and
   `change`. Client-sent totals are discarded exactly as before.
5. The order carries no stock movement: the open-amount variant is `trackInventory: false`, so no
   `InventoryMovement` is written and no oversell check applies.
6. Idempotency is unchanged — `(merchantId, clientOrderId)`, replay returns the same order.

### D. The gate

An `amount` on a line is accepted **only** when the server determines, from the database:

1. the merchant has `calculatorOnly = true`; **and**
2. the line targets a variant of a product marked `isOpenAmount`; **and**
3. the amount is a positive integer rupiah within the published ceiling, with `qty = 1`, no
   modifiers and no line discount.

Anything else is **refused with an error, never silently ignored** — including an `amount` sent by a
normal merchant, an `amount` on a catalog variant, an open-amount line with no amount, and a
cross-merchant reference to another merchant's open-amount variant.

The gate applies to **both** order entry points: `POST /orders` and `POST /orders/:id/revise`.

### E. Tax

1. A calculator merchant is provisioned with **no `TaxRule`**, so tax and service charge are zero —
   through the money engine's existing "no rule" fallback, **not** through a calculator-specific
   branch.
2. Adding tax later MUST be a **data change, not a code change**: inserting a `TaxRule` for the
   outlet makes both the server total and the on-screen preview include it, with no edit to either
   engine. This is pinned by a test that switches tax on and asserts the new totals.

### F. Reporting

1. Calculator sales appear in the transaction history with their lines, total and payment, and can
   be voided under the existing UMI correction rules.
2. Open-amount lines have no cost price, so they are **excluded from the missing-cost warning**
   rather than permanently triggering it. They still count toward revenue and item totals.
3. The in-app **Items** manager is hidden for calculator merchants — their catalog holds exactly one
   hidden sentinel and nothing a merchant should see.

## Out of scope

- QRIS on the calculator screen (cash only for v1; the tender restriction from `006` already blocks
  cards and wallets).
- A server-side per-outlet nota sequence. The counter is device-local and display-only; a true
  sequence is a separate change.
- Open bills. A calculator merchant stays on `paymentMode: IMMEDIATE`.
- Turning the mode on or off from the app or the portal. Provisioning only.

## Constitution

Requires **v1.8.0**, which adds the bounded open-amount exception to Principle III. Principle IV is
met rather than excepted — the line snapshots its true selling price and `qty` stays 1, so
quantity-sold reporting keeps counting sales rather than rupiah. Principles I, II, V and VI are
untouched.
