# Feature Spec — Nota Reading Mode (High Human Interactions)

**Feature ID:** 009-nota-reading-mode
**Status:** In progress
**Applies to:** the new business type `HIGH_HUMAN_INTERACTION`. Orthogonal to business size.
Constitution v1.9.0.

## Why

Some trades are made of conversations, not catalogs: a laundry weighs a bag and writes the price,
a tailor quotes a hem, a repair shop prices the part after looking at it. The sale already exists —
handwritten on a paper nota, in the merchant's own shorthand. Asking these merchants to rebuild each
sale in a product grid is asking them to write it twice.

`/nota/read` (read-only, spec'd in the earlier nota-reader slice) already reads a photographed nota
reliably: on three real laundry slips Opus 5 returned every priced line and every total correctly.
This feature turns that reading into the sale: **photograph the nota, confirm the reading, and it
becomes an open transaction**, paid later through the existing settlement flow.

## User Stories & Acceptance

### A. The business type

1. `BusinessType` gains `HIGH_HUMAN_INTERACTION`, displayed as **"High Human Interactions"**.
2. Every existing merchant keeps its type; nothing about FNB or GROCERY changes.
3. A merchant of this type gets **one provisioned open-amount product** (as calculator-only merchants
   do, `008`) — plumbing, never shown in any catalog, item manager or item count.

### B. The nota chat

1. For this type, the app's home surface is the **nota chat** — for every role. Riwayat, open bills,
   Laporan (owner/manager) and Pengaturan stay on its app bar.
2. The chat opens with a prompt to send a nota photo; the input bar offers **camera** and **gallery**.
3. The photo appears as the cashier's message; the reply is the reading — nota number, date,
   customer, each line as written with its price, the written total, and anything flagged unclear.
4. The reading ends with a question: **"Apakah ada yang perlu diperbaiki?"**
   - **Ya** — no action in this release; the reply says corrections are coming and suggests retaking
     the photo.
   - **Tidak** — the transaction is created (C) and the reply confirms it with a **Bayar sekarang**
     action into the existing payment screen, in settle mode.

### C. How a confirmed nota is recorded

1. As an **open transaction**: `POST /orders` with **no payment**, so it is `AWAITING_PAYMENT` and
   appears in the open bills list, where tapping it settles it through the existing settle path
   (`POST /orders/:id/settle`, every tender the merchant's size allows).
2. Each **priced** nota line becomes one open-amount line: `qty 1`, `amount` = the line total as
   written, `label` = the line exactly as written ("1 M BESAR"), snapshotted as the line's name.
3. **Priceless lines** ("A/J FREE", "31 pc", "S/B guling = 4") are not charged. They are recorded in
   the transaction **note** (`Order.note`, text only, never money), together with anything the reader
   flagged as unclear and — when the sale is the written total — the lines that total covers. The
   chat shows that note before the cashier confirms, and the transaction detail shows it afterwards,
   so nothing written on the slip is lost.
4. If no line carries a price but the total is written, the sale is **one line** labelled with the
   nota number at the written total. If neither exists there is nothing to charge and the chat asks
   for a clearer photo.
5. **Paper total ≠ sum of lines**: the confirmation shows both and says the transaction uses the sum
   of the lines — the server always computes from lines (Constitution III); the discrepancy is shown,
   never resolved silently.
6. The nota **number** is stored as `Order.externalOrderRef`; the **customer** as
   `Order.customerName`. Both are text, never money.
7. **One nota, one transaction.** A nota number already on an open or completed, un-voided order at
   the outlet is refused (`409 NOTA_ALREADY_RECORDED`), so re-photographing a slip can never bill it
   twice. A nota with no readable number is not deduplicated.
8. Idempotent on `clientOrderId`, minted once per reading, so a double tap on **Tidak** creates one
   transaction.

### D. The gate (Constitution III, v1.9.0)

1. Open-amount lines are admitted for a merchant that is `calculatorOnly` **or** of type
   `HIGH_HUMAN_INTERACTION`, decided from the database. Every other rule of `008` is unchanged —
   provisioned variant, positive bounded integer, `qty 1`, no modifiers, no discount, and any other
   `amount` is **refused, never ignored**.
2. A `label` is accepted only on an open-amount line and is refused on a catalog line — it must never
   rename a catalog item's history. Max 120 characters.

### E. Open bills list

1. A nota transaction reads **"Nota #2237 · Edward"** instead of a table or "Takeaway".
2. The **edit** action is hidden for this type: editing rebuilds a cart from catalog variants, and a
   nota has none. Cancel and settle work as for any open bill.

## Out of scope

- Correcting a reading ("Ya" is a placeholder).
- Persisting the chat history across app launches — the transactions themselves are on the server.
- A catalog for this type; matching nota shorthand to products.

## Open item — must be decided before any real merchant uses this

Reading a nota sends the photo to an AI provider **outside Indonesia** for the seconds the read
takes. Nothing is stored there, and Principle VII's residency rule governs stored production data —
but a real merchant's slips carry customers' names, and the reader's server log currently records
the full reading (`NOTA_RESULT`). Both need an explicit decision — a scoped constitution exception
with merchant consent, and removal of the PII log — before a non-demo merchant is given this type.

## Constitution

v1.9.0: Principle III's open-amount exception admits `HIGH_HUMAN_INTERACTION` and allows a line
`label`; the business-type clause names the new type and its home surface.
