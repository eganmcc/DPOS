# Handoff: DPOS Visual System (Direction A — "DIKA Bold")

## Overview
Visual system for DPOS, a mobile/tablet POS app for PT DIKA's Indonesian F&B merchants. Fixes a flat/pale Material 3 default look with navy-dominant surfaces, real elevation, and gold reserved for CTAs/selected states. Covers Login, POS/Order Builder (phone + tablet two-pane), Checkout, and Receipt, each in light and dark.

## About the Design Files
The bundled `DPOS Visual System.dc.html` is a **design reference built in HTML** — a static gallery of mockups, not production code. Target implementation is **Flutter (Material 3)**, using `ColorScheme`, `Card`, `Chip`, `ElevatedButton`, etc. Recreate the screens natively in Flutter using the tokens and component specs below — do not embed or wrap the HTML.

## Fidelity
**High-fidelity.** Exact hex colors, type sizes/weights, radii, spacing, and shadows are specified below and should be matched precisely.

## Design Tokens

### Color scheme — Light
- primary `#133A68` / onPrimary `#FFFFFF`
- primaryContainer `#DCE6F2` / onPrimaryContainer `#0B2036`
- secondary (gold) `#D6AD07` / onSecondary `#2B1D00`
- secondaryContainer `#FBEDBB` / onSecondaryContainer `#453200`
- background `#F7F5EF`
- surface `#FFFFFF` / surfaceContainer `#F2F0E9` / surfaceContainerHigh `#EAE7DD`
- onSurface `#16181D` / onSurfaceVariant `#5B6472`
- outline `#D8D4C8`
- error `#B3261E`
- custom success `#1E7B45` / successContainer `#DCF3E3` (status chips, change-due — not a stock M3 role, add as a `ColorScheme` extension or extra fields)

### Color scheme — Dark
- primary `#9DBEE8` / onPrimary `#0B2036`
- primaryContainer `#1F3A5C` / onPrimaryContainer `#D3E3F5`
- secondary (gold) `#E8C34A` / onSecondary `#3D2E00`
- secondaryContainer `#5A4300` / onSecondaryContainer `#FBEDBB`
- background `#0B111C`
- surface `#101A2C` / surfaceContainer `#17223A` / surfaceContainerHigh `#1F2C48`
- onSurface `#E7EAF1` / onSurfaceVariant `#A6AFC2`
- outline `#2C3A56`
- error `#FFB4AB`
- custom success `#6FCF97` / successContainer `#163521`

### Elevation (shadows)
- e1 (rest, inputs, unselected chips): `0 1px 2px rgba(16,24,40,.06)`
- e2 (cards, buttons): `0 2px 8px rgba(19,58,104,.12)`
- e3 (floating cart panel, FAB): `0 8px 24px rgba(19,58,104,.18)`
- e4 (bottom sheet, dialog): `0 12px 32px rgba(19,58,104,.22)`
- In Flutter, approximate with `BoxShadow` on `Container`/`Material` (elevation-based `Card` shadows read as too flat/grey by default — use custom `BoxShadow` with the navy-tinted colors above, not plain black).

### Corner radii
- chip / button: full (stadium, `StadiumBorder`)
- input / small card: 12dp
- product card / cart line block: 16dp
- panel / dialog: 20dp
- bottom sheet top corners: 28dp

### Spacing scale
4 · 8 · 12 · 16 · 20 · 24 · 32 · 40 · 48 dp

### Typography — Inter (or closest system equivalent if Inter isn't bundled)
- Total/display: 36/40, weight 700, tabular figures
- Screen title: 22/28, weight 700
- Section title: 16/22, weight 600
- Product name: 15/20, weight 600
- Price: 14/18, weight 600, tabular figures
- Body: 14/20, weight 400
- Caption: 12/16, weight 500
- Button label: 15/20, weight 600
- Eyebrow/label: 11/14, weight 700, uppercase, +0.06em letter-spacing
- Money strings always use tabular/monospaced-figure numerals, formatted as integer Rupiah with `.` thousands separator and no decimals (e.g. `Rp 41.400`).

## Component specs
- **AppBar**: 64dp, navy gradient 135° `#0B2036 → #133A68` (dark theme: `#060a12 → #122239`), white/onSurface title and icons, flat at rest, e2 shadow only once content scrolls under it.
- **Product card**: `surface` background, radius 16, e2 shadow. Top band 60–64dp tall, navy gradient (same as AppBar), centered single-letter placeholder in `secondary` gold, 24–28px bold — swap for a product photo later without changing the card shell. Name below, 15/600; price "dari Rp X" 14/600 in muted/eyebrow color. Qty badge: 22dp gold circle, onSecondary text, positioned top-right, overlapping the band by ~16px.
- **Category chip**: height 36, radius full. Selected: `primary` fill, `onPrimary` text, e1. Unselected: `surface` fill, 1px `outline` border, `onSurfaceVariant` text.
- **Cart line**: ~56dp row. Name + variant note stacked left (14/600 + 12/400 muted). Qty stepper center: two 24–26dp outlined circle buttons (−/+) flanking the number. Line total right-aligned, tabular.
- **Totals bar**: `surfaceContainer` block, radius 16. Label/value rows 14/400 in `onSurfaceVariant`. Divider, then TOTAL row 19–20/800 in `primary` (light) or `primary` (dark, lighter tone).
- **Primary button**: height 50–52, radius full (stadium), `secondary` (gold) fill, `onSecondary` text 15/600, e2 shadow tinted gold, optional trailing icon.
- **Secondary button**: height 46–52, radius full, transparent fill, 1.5px `primary` outline, `primary` text.
- **Payment-method card**: ~96dp, radius 16. Selected: 2px `secondary` (gold) border + `secondaryContainer` tint + e2. Unselected: 1px `outline` border, e1, `surface` fill.
- **Input field**: filled style, `surfaceContainer` background, radius 12, 1px `outline` border (2px `primary` on focus), label 12/500 above field, value 15/500.
- **Status chip** (e.g. "Lunas"/Paid): height 28, radius full, success container background + success text. Never gold — gold is reserved for actionable/CTA elements only.

## Screens / Views

### 1. Login
- Top bar: two small segmented pill toggles, top-right — language (`ID` / `EN`) and theme (`Terang` / `Gelap`), each a stadium pill with the active side filled `primary`/onPrimary.
- Center: 64×64dp navy-gradient rounded-square (radius 16) logo mark with a gold letterform, two small gold "wing" bars angled outward from its sides; "DPOS" wordmark 24/800 `primary`/onSurface, "PT DIKA" eyebrow caption below.
- PIN entry: 6 boxed cells, 44×52dp, radius 12, 1.5px `outline` border; filled cells show a solid `primary`-color dot centered; active/next cell gets a `primary`-color border instead of `outline`.
- "Pengaturan lanjutan" (Advanced settings): collapsible row with a small downward triangle, label 13/600 `primary`. Expanded, reveals two filled fields: Merchant ID, Outlet ID (`surfaceContainer` bg, radius 12, 11/600 eyebrow label + 14/500 value).
- Primary button: full-width, "Masuk" (Sign in), gold fill per primary-button spec.
- Footer caption: "Lupa PIN? Hubungi admin outlet." 12/500 muted, centered.

### 2. POS / Order Builder
**Tablet (primary layout, landscape, two-pane):**
- AppBar: outlet name + "Meja 12" pill + "Riwayat" gold pill, per AppBar spec.
- Left pane (~65% width): horizontal category chip row (`Semua, Kopi, Non-Kopi, Makanan, Snack`), then a responsive product grid, 4 columns on tablet, cards per Product card spec. Grid scrolls vertically inside its own pane (`overflow-y: auto` / `ListView`/`GridView` in Flutter) — do not clip.
- Right pane (~300dp fixed width): floating cart panel (e3 shadow, radius 16, margin off the edges). Header "Pesanan". Order-type segmented toggle: Dine-in ("Makan di sini") / Takeaway ("Bawa pulang"), `primary` fill on selected side. Table-number field shown only when Dine-in. Scrollable list of cart lines per Cart line spec. Totals bar per spec (Subtotal, Diskon, PBJT (10%), Biaya layanan (5%), TOTAL). Full-width primary button "Bayar · Rp {total}".

**Phone:**
- Same AppBar, single category chip row, 2-column product grid, scrolls independently within the remaining vertical space.
- Sticky bottom cart bar (`primary`/navy fill, 64dp): left shows "{n} item" caption + total in white; right shows a gold "Lihat pesanan" pill button. Tapping opens the cart as a modal bottom sheet.
- Cart bottom sheet: scrim overlay, sheet radius 28 top corners, e4 shadow, drag handle bar, same order-type toggle / cart lines / totals bar / primary "Bayar" button as the tablet right pane.

### 3. Checkout
- Header "Checkout" (17/700), back affordance implied.
- Total display: navy-gradient panel (radius 20, e3 shadow in light / bordered flat panel in dark), eyebrow "Total tagihan" in gold, big total 34/800 white/onSurface.
- Two payment-method cards side by side: Tunai (Cash) / QRIS, per Payment-method card spec — selected card shows the gold border + tint.
- **Cash selected**: row of quick-tender chips ("Pas" = exact, "Rp 50.000", "Rp 100.000" — selected one filled `primary`), an amount-received field (Input field spec), and a live "Kembalian" (Change) card using the success color pairing (container bg + success text), value bold 19/800.
- **QRIS selected**: centered framed QR placeholder (176×176dp bordered frame in gold, striped placeholder square inside labeled "QR code" in monospace — swap for a real QR at build time), caption "Pindai dengan aplikasi pembayaran apa pun".
- Primary button, full width: "Selesaikan" (cash) / "Tandai sudah dibayar" (QRIS).

### 4. Receipt (struk)
- Canvas background slightly recessed from the card (`surfaceContainerHigh`-ish), receipt card centered: radius 20, e2 shadow.
- Header: 44dp logo mark, merchant name 15/700, address caption 11.5/500 muted.
- Row: "Order #{id}" (13/600 muted) + status chip ("Lunas", success colors, never gold).
- Timestamp caption below.
- Dashed divider (`1px dashed outline`) — intentional receipt-paper motif, keep it.
- Itemized lines: "{qty}× {name}" left, tabular total right, 13/400–500.
- Dashed divider, then totals block (same rows as cart), TOTAL row 18/800 in `primary`.
- Payment method + change lines, small caption text.
- Footer button row: secondary outline "Bagikan" (Share) + primary gold "Pesanan baru" (New order), each ~46–52dp, stadium, flex 1:1.

## Interactions & Behavior
- Login: PIN cells fill left-to-right as digits are entered; advanced settings section expands/collapses on tap of its header row; language and theme toggles are simple two-state segmented switches.
- POS: tapping a product card increments its cart qty and shows/updates the gold qty badge; category chips are single-select; on phone, the sticky cart bar updates its item count/total live and opens the cart sheet on tap; qty steppers in cart lines increment/decrement, removing the line when quantity reaches 0.
- Checkout: selecting Tunai vs QRIS swaps the lower half of the screen between the cash flow and the QR flow; tapping a quick-tender chip sets the amount-received field and recomputes "Kembalian" live; "Pas" sets amount received equal to total (change = 0, hide or zero out the change card).
- Receipt: "Bagikan" triggers the platform share sheet with a text/image summary; "Pesanan baru" clears the cart and returns to the POS screen.

## State Management
- POS: category filter (selected id), product list with per-item qty, order type (dine-in/takeaway), table number (nullable), computed subtotal/discount/tax/service/total.
- Checkout: selected payment method, amount received (cash), computed change, payment status (pending/paid).
- Login: PIN buffer (masked), advanced-settings expanded flag, merchant ID / outlet ID fields, language, theme.
- Receipt: read-only order snapshot (items, totals, payment method, change, order id, timestamp, status).

## Assets
- Logo mark is a placeholder (navy-gradient rounded square + gold letterform + two angled gold bars) standing in for PT DIKA's winged emblem — swap in the real logo asset at build time; keep the 64×64dp (login) / 44×44dp (receipt) sizing and rounded-square treatment.
- Product tiles use single-letter color placeholders (no photos yet) — swap for real product photography behind the same navy-gradient-band card shell when available.
- QR code is a striped placeholder — replace with a generated QRIS QR image.

## Files
- `DPOS Visual System.dc.html` — full HTML design reference (token panel + all 4 screens × light/dark, tablet + phone POS variants). Open in a browser to view; do not ship as-is.
- `screenshots/01-full-page.png` … `06-full-page.png` — scrolling captures of the full page, top to bottom, for quick reference without opening the HTML.
