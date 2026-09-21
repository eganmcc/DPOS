# Feature Spec — Voice Order Entry

**Feature ID:** 010-voice-order-entry
**Status:** In progress
**Applies to:** any merchant on Android. Orthogonal to business size and business type.
Constitution v1.9.0.

## Why

A cashier's hands are full. They are handing over change, wrapping an order, holding a phone to
their ear — and the till needs both hands and a clear line of sight. Every other input this app
has (keypad, product grid, barcode) assumes a free hand.

The tuning bench (`Settings → Uji coba suara`, shipped on `feat/stt`) established what the handset
can actually do: Indonesian is recognised under the legacy locale `in_ID`, quantities and item
names come back reliably enough to check against a catalogue, and the failure modes are known and
handled. This feature turns that from a bench into a way to take an order.

**Recognition stays on the handset.** Nothing is recorded, and no audio leaves the device — it goes
to the phone's own speech service exactly as the bench does. Unlike the nota photos (009), this
raises no data-residency question under Constitution VII, and that property is worth defending in
any future accuracy work.

## User Stories & Acceptance

### A. Reaching it

1. The till's app bar reads **Pesanan · Riwayat**, then icons: **mic, nota, laporan, pengaturan**.
   Words first, icons right; nothing in the middle.
2. The nota icon shows only where a paper nota is taken (F&B, HHI). A grocery till has no use for
   it and the room is needed.
3. A calculator-only merchant never sees the till, so its own screen carries the mic too, in
   spoken-price mode.
4. Voice appears only on Android. Other platforms show nothing, rather than a control that cannot
   work.

### B. Two ways to hear an order

5. **From the catalogue** — "nasi goreng dua" means two of them, and the price is the shop's.
   Each line is checked against the catalogue and its stock, with the variant the cashier named
   (`ayam geprek keju` is the Keju variant, at Keju's price, out of Keju's stock).
6. **At a spoken price** — "Pecel lele 100" means one pecel lele at 100.000, because there is no
   catalogue to price it from. The last number is the money, not the quantity; a number said
   *before* the name is the quantity ("dua pecel lele 100").
7. A bare number under 1000 is heard as thousands, the way it is said in a warung. A number said in
   full ("seratus ribu", "25000") is taken as spoken and never multiplied again.
8. The mode follows the merchant — no catalogue means spoken price — and can be switched by hand
   until the first line is staged, after which it locks rather than silently discarding a bill.

### C. The list

9. Four columns: **item, jumlah, harga, jumlah**. No keypad.
10. Every line can be removed before it becomes money.
11. Problems are stated on the line: not in the catalogue, unavailable, sold out (with the real
    remaining count), fewer left than asked for.
12. **A line the server would refuse blocks Selesai** — not in the catalogue, no price said, or
    **more than is on hand** (sold out or short). A switched-off item only warns: the server
    accepts it.
    *Changed 2026-09-21.* This used to read "Short stock does not block: the cashier is looking at
    the shelf and the database often is not." The server does not share that view — it refuses to
    take a tracked variant below zero and rolls the whole sale back (Constitution IV) — so the old
    rule only moved the failure to the till, where it surfaced as "Gagal masuk (cek koneksi)". It
    was found on the device through the nota order screen (009 § F), which shares this rule. If the
    shelf really has more than the database, the fix is a stock adjustment, not an oversold order.
13. The total is shown with tax and service charge when the outlet has a rule, through the same
    `previewTotals` as every other surface.

### D. Finishing

14. **Tambah ke keranjang** puts the spoken lines in the same cart as tapped ones, so one bill can
    be half spoken and half tapped.
15. **Selesai** depends on the mode, because the two trades settle differently:
    - catalogue → the existing open-bill path (or the payment screen where the outlet pays
      immediately);
    - spoken price → the existing `showNotaPaymentDialog`, settled now as a counter sale.
16. Both go through code that already existed. No new money path.
17. A failed submit leaves the bill on screen. Nothing was recorded, so nothing may be cleared.
    The cashier is told **why** — the server's reason, stock in Indonesian ("Stok X tidak cukup —
    pesanan tidak disimpan"), and "cek koneksi" only when the server was never reached
    (`core/submit_error.dart`). Previously every refusal read "Gagal masuk (cek koneksi)".

### E. What the receipt says

18. A spoken open-price line carries its words as the line's **label**, which the server snapshots
    as `productNameSnapshot` — so Riwayat and the printed receipt read "pecel lele", not "Nota".
19. A spoken quantity becomes **repeated qty-1 lines**, because the server requires `qty: 1` on an
    open-amount line: an amount is the price of one thing. Two at 100.000 is two lines of 100.000,
    which is also what the receipt should read.

## Constitution

- **III (the server owns money math).** Unchanged. Catalogue lines carry no price at all. A spoken
  price is the same client-originated amount that `008` already established, gated by
  `acceptsOpenAmountLines()` and recomputed server-side; the cashier confirms it in the payment
  dialog before anything is sent.
- **IV (immutable financial history).** No correction paths change. Voice creates orders; it never
  edits one.
- **V (idempotent offline sync).** Spoken-price sales go through the same queue as the keypad, with
  a `clientOrderId` minted per sale.
- **VII (Indonesia-first).** Recognition is on the handset. No audio is stored or transmitted.

## Out of scope

- Wiring voice into the nota chat (009) or the scanner.
- Recording audio for later transcription, and any cloud speech service — both were considered and
  rejected for now; see the note on residency above.
- **The restart seam.** Continuous listening loses the syllables spoken between sessions; this is a
  property of Android's recognizer, not of this code (`stt_lab_screen.dart` documents it). If it
  bites in real use, push-to-talk is the answer, and this screen is where it would live.

## Verification

```bash
cd app && flutter analyze && flutter test     # includes voice_order_parse_test, voice_order_screen_test
cd server && npm test                          # 14 suites; open-amount adds "a spoken sale"
```
