# Feature Spec — Grocery Barcode-Scanner POS + Bluetooth Receipt Printing

**Feature ID:** 003-scanner-printing
**Status:** Implemented (MVP)
**Applies to:** GROCERY business type (scanner mode); any outlet with a paired thermal printer (printing)

## Why
Grocery tills ring items by scanning barcodes and hand the customer a printed receipt. On a real
device with a Bluetooth thermal printer, the grocery cashier should scan-to-add and auto-print,
while F&B keeps its tap-and-settle flow. The catalog/cart/checkout logic is unchanged — scanning and
printing are input/output surfaces over the existing sale.

## User Stories & Acceptance
1. **Scanner home (grocery).** For a GROCERY outlet with a paired thermal printer (or forced via the
   Settings toggle), the home is a scanner screen: a **camera preview**, an **editable SKU field**,
   a **Browse products** button, and the **order list + Pay**. Non-grocery / no-printer / toggle-off
   → the normal product grid.
2. **Scan to add.** Scanning a bar/QR code whose value equals a variant **SKU** adds 1 to the cart —
   through the same add + stock-cap path as tapping (out-of-stock and unknown-SKU are reported, not
   added). A short **beep** and haptic confirm each add; the just-added line moves to the **top** of
   the order list.
3. **Type / search SKU.** The SKU field is editable — the cashier can type a SKU and submit to add,
   and **Browse products** opens the normal grid to tap-add anything.
4. **Activation.** Auto-on when a suitable printer is paired; a Settings **Auto / On / Off** toggle
   (grocery only) overrides it. The cashier **selects the printer** from the paired list (the OS
   reports the factory name, e.g. `RPP02N`, not the alias).
5. **Auto-print receipt.** After **Bayar** commits the sale, the 58mm ESC/POS receipt prints to the
   selected printer automatically; a **Cetak** button on the receipt reprints. A **Test print** in
   Settings verifies the connection.

## Functional Requirements / Invariants (Constitution IV/I)
- Scanning introduces **no** client-side money or stock rule: a SKU resolves to a variant and goes
  through `CartController.addItem` after the same remaining-stock check the picker uses.
- Receipt printing is a **non-blocking side effect of an already-committed order** — it never gates
  or alters the sale, a print/connect failure is **silent**, and the **database record** (not the
  paper) is authoritative.
- The scanner POS mode is **grocery-only**; F&B is unaffected.
- Money stays integer rupiah; the server still owns all totals (the receipt renders the committed
  order's stored figures).

## Implementation notes
- Packages: `mobile_scanner` (camera), `print_bluetooth_thermal` (enumerate paired devices),
  `esc_pos_utils_plus` (build the 58mm ticket), `permission_handler` (BLUETOOTH_CONNECT). Android:
  CAMERA + BLUETOOTH permissions, `minSdk 24`.
- **Native connect + beep** (`MainActivity.kt`, MethodChannel `dpos/printer`): the plugin's *secure*
  RFCOMM socket fails on cheap thermal printers and swallows the error, so printing connects over an
  **insecure RFCOMM socket** (then secure, then reflection channel-1) and writes the bytes; the scan
  **beep** uses the system `ToneGenerator` (instant, no asset — the audio-asset path queued/lagged).
- Selected printer MAC is persisted; if unset, the first paired device whose factory name looks like
  a thermal printer (`DPOS`/`RPP`/`POS`/…) is auto-picked.
- Screen reuse: `CartPanel`/`CatalogPanel` were made public so the scanner reuses the cart + grid.

## Demo note
The seeded grocery SKUs are short codes (`IDM1`, `BRS5`, `MYK2`, … — on the portal Prices page);
generate QR/barcodes from those strings to scan. Real EAN barcodes would need to be stored as the
SKU (or a future dedicated `barcode` field surfaced in the catalog).

## Out of scope
Real EAN/barcode field distinct from SKU; kitchen/label printing; iOS Bluetooth printing;
offline-queued printing.

## Verification
- `flutter analyze` clean; `flutter build apk` succeeds with the native plugins + Kotlin channel.
- Emulator (no camera/BT): Settings → Scanner mode **On** renders the scanner; typed-SKU add, Browse,
  and Pay work. Real device: scan a QR of a seeded SKU → beep + added on top; select the printer →
  **Test print** and post-Bayar receipt print on the RPP02N.
