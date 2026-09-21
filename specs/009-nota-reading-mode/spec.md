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

### F. On an F&B till: a read nota becomes a catalogue order (added 2026-09-21)

The till's **Baca nota** screen (scan icon, F&B) used to be read-only. It now ends the way voice's
catalogue mode ends (`specs/010`), and deliberately by the same code:

1. After a reading, **Jadikan pesanan** opens the lines in voice's four columns. Shown only on an F&B
   till with a catalogue — a nota-reading merchant has the chat above; grocery and calculator tills
   have no catalogue lines a nota could match.
2. Every line is checked with the **voice matcher** (`checkItem`): product, the variant the paper
   names, availability and stock. Counts and prices written into a line's text ("2 nasgor 30.000")
   are stripped before matching; the reader's own qty field is the quantity.
3. **The shop's price is charged, never the paper's.** A catalogue merchant cannot be charged a
   written amount (the open-amount gate, D, refuses it). Where the paper's unit price differs, the
   line says so — *"Di nota Rp 20.000 — yang dikenakan harga toko"* — and **does not block**,
   for the same reason short stock doesn't: the cashier can see both.
4. **Blocks Selesai:** a line not in the catalogue (as in voice), and a quantity that is not a whole
   number of at least one. A line with no count written is one of it. Unavailable and short-stock
   lines are flagged, not blocked — as in voice. Every line can be removed; nothing on the paper
   silently disappears — an unmatched line stays, in the paper's own words, until removed.
5. **Tambah ke keranjang** puts the lines in the till's cart; **Selesai** goes through the existing
   open-bill path, or the payment screen where the outlet pays immediately. Both are the shared
   `features/order/staged_order.dart`, which voice now uses too. **No new money path.**
6. **Lines only.** The nota number is not carried into the order (decided 2026-09-21), so the
   `NOTA_ALREADY_RECORDED` guard does not apply here: reading the same slip twice makes two sales,
   and the second is voided by hand. The server already accepts `notaNumber` from any merchant, so
   adding it later is app-side plumbing through the cart, not a server change.

## Out of scope

- Correcting a reading ("Ya" is a placeholder).
- Persisting the chat history across app launches — the transactions themselves are on the server.
- A catalog for this type. (Matching nota shorthand to products now exists for **F&B** tills — F above —
  as far as the voice matcher goes: "nasgor" will not find "Nasi Goreng"; it is reported as not in the
  catalogue and a human decides.)

## Open item — must be decided before any real merchant uses this

Reading a nota sends the photo to an AI provider **outside Indonesia** for the seconds the read
takes. Nothing is stored there, and Principle VII's residency rule governs stored production data —
but a real merchant's slips carry customers' names, and the reader's server log currently records
the full reading (`NOTA_RESULT`). Both need an explicit decision — a scoped constitution exception
with merchant consent, and removal of the PII log — before a non-demo merchant is given this type.

## Constitution

v1.9.0: Principle III's open-amount exception admits `HIGH_HUMAN_INTERACTION` and allows a line
`label`; the business-type clause names the new type and its home surface.
