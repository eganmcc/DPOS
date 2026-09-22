# DIKASIR — Functional Specification for QA

**As of:** app 0.5.1 (build 2119) · `main` @ `2b0c81f` · 22 Sep 2026
**Published copy for QA:** https://claude.ai/artifact/3DjTRFHoZxkanJxbyo9s3C (Claude Doc — QA reads, comments and records results there)

> **This file is the source of truth; the Claude Doc is a published copy.**
>
> - **Any change to user-visible behaviour updates this file in the same commit** (CLAUDE.md →
>   "Spec-Driven Development"). New features bring their cases from the spec's *QA cases* section.
> - **Test IDs are permanent.** Never renumber or reuse one. A new case takes the next free number
>   in its area (APP-V17, POR-L23). A case that no longer applies is kept with its row struck
>   through and `RETIRED in <version>` in the expected result, so old QA results still resolve.
> - **Record every change** under *Changes since the last QA cycle* below: added, changed and
>   retired IDs, with the version.
> - **On release**, bump the *As of* line, publish the changed sections to the Claude Doc, and
>   clear the changes list into the doc's changelog. QA comments on the doc come back as edits to
>   this file (or issues) — never edit the doc directly, the next publish overwrites it.

## Changes since the last QA cycle

_None yet — 22 Sep 2026 is the baseline (211 cases: APP-*, POR-*, BR-*)._

This is what the DIKASIR Android app and the Customer Portal do today, written so QA can test each function against an expected result.

## 1. Test environment

Test against the live demo environment. All five demo merchants below already hold data; a test that creates sales adds real rows to that merchant's history and reports.

| Item | Value |
| --- | --- |
| App build | DIKASIR **0.5.1**, latest APK `DIKASIR-0.5.1-2119.apk` (release-signed, Android only) |
| API | `https://dikapos.ptdika.com/api/v1` |
| Customer Portal | `https://dikapos.ptdika.com/customer-portal/` |
| Device used for development | Redmi Note 14 Pro+ (Android). Any Android phone works; there is no iOS build. |
| App languages | Bahasa Indonesia and English, switched in Settings |

**Installing:** a build signed with a different key cannot update over this one. If install fails with `INSTALL_FAILED_UPDATE_INCOMPATIBLE`, uninstall the old app first (this clears its login and offline data).

### Demo merchants and logins

On the app login screen, pick the merchant, then **Login as**. The PIN fills in automatically for demo accounts.

| Merchant | Business type | App logins (role: name, PIN) | Portal login (owner only) |
| --- | --- | --- | --- |
| Warung Kopi Demo 1 | F&B | Owner: Owner Demo, 9999 · Manager: Manajer Demo, 8888 · Cashier: Kasir Demo, 1234 | `owner@warungdemo.id` / `owner123` |
| Toko Sembako Demo | Grocery | Owner: Admin Sembako, 4321 · Manager: Budi Manajer, 7777 · Cashier: Kasir Sembako, 2222 | `admin@sembako.id` / `admin123` |
| Laundry Wangi Demo | High Human Interaction (Nota) | Owner: Bu Wangi, 3333 · Cashier: Kasir Wangi, 4444 | Not issued |
| Kios Pak Darto | Grocery, UMI size, Calculator-only | Owner: Pak Darto, 2222 | Blocked by design (UMI) |
| Warung Bu Sri | F&B, UMI size | Owner: Bu Sri, 1111 | `busri@warungbusri.id` / `busri123` returns **403** by design |

### Data notes before you start

- **Warung Kopi Demo 1** has six months of history up to today and is the best merchant for Dashboard and Laporan tests. Use **Outlet Pusat** for sales: most tracked items at Outlet Cabang have 0 or 1 in stock.
- **Toko Sembako Demo**'s last sale is 10 Sep 2026. Its Dashboard shows Rp 0 for the default last-7-days window until new sales are made. That is correct behaviour, not a defect.
- Warung Kopi Demo 1 has 2 NEW online orders left on each outlet for online-order tests.
- Warung Bu Sri has no tax rule, and *Bakwan Sayur* has no cost price on purpose (it triggers the missing-cost warning in Reports).

## 2. Roles, business types and sizes

What a user sees depends on three settings: their **role**, the merchant's **business type**, and the merchant's **business size**. Most test cases must be run for more than one combination.

### Roles

| Role | App home screen | Can do | Cannot do |
| --- | --- | --- | --- |
| Owner | Reports (except UMI, Calculator and Nota merchants, which open on the till) | Everything; approve voids; log into the Portal | — |
| Manager | Reports | Sell; approve voids; see Reports | Log into the Portal |
| Cashier | The till | Sell; request a void (needs a Manager or Owner PIN) | See Reports; approve voids |

Owners and managers reach the till from Reports via **Buka kasir**.

### Business types

| Type | Home screen | What is different |
| --- | --- | --- |
| F&B | Order screen with product grid | Dine-in or takeaway, table numbers, online orders, **Baca Nota** icon, voice icon |
| Grocery | Barcode **Scanner screen** when a DPOSP printer is paired or scanner mode is On; otherwise the Order screen | Barcode scanning, weight/unit items. No Baca Nota icon. The Scanner screen has no voice icon either. |
| High Human Interaction (Nota) | **Nota chat**: photograph a handwritten nota to record the sale | No product grid. Sales are recorded as unpaid and settled later. |
| Calculator-only (a Grocery or F&B setting) | **Calculator keypad** | No catalogue: the cashier keys in amounts. Cash only. |

### Business sizes

| Size | What changes |
| --- | --- |
| General / UMKM | Normal behaviour. Card and e-wallet tenders are offered. Staff are asked to clock in at login. |
| UMI (ultra-micro) | One-person business. **Cash and QRIS only.** No clock-in prompt. Voids need no approver PIN. The owner edits items and prices **in the app** (Items icon on Reports). **Portal login is refused** with "This account manages its business in the DPOS app". |

### Branch payment mode

Each branch is either **Immediate** (pay at the till) or **Open Bill** (the order is saved and paid later). Open Bill branches show a **Pesanan** button in the app bar listing unpaid bills. It is set per branch in Portal → Entity. Laundry Wangi Demo's branch is Open Bill.

## 3. App — login, session and home

A staff member logs in with the merchant and a 4-digit PIN, and lands on the home screen for their role and business type (section 2).

| ID | Test | Steps | Expected result |
| --- | --- | --- | --- |
| APP-L01 | PIN login | Pick a merchant, pick a **Login as** entry, confirm the PIN | Logged in; home screen matches section 2 for that role and type |
| APP-L02 | Wrong PIN | Enter a PIN that is not on the list | Error shown; not logged in |
| APP-L03 | Version display | Open the login screen | App version and build (e.g. 0.5.1 (2119)) and the server version are shown |
| APP-L04 | Clock-in prompt | Log in as a cashier on a General merchant | *Absen masuk sekarang?* appears once per session |
| APP-L05 | No clock-in for UMI | Log in to Warung Bu Sri or Kios Pak Darto | No clock-in prompt |
| APP-L06 | Clock-out on logout | While clocked in, log out from Settings | *Absen keluar?* offers **Absen keluar & keluar** |
| APP-L07 | Owner/manager to till | Log in as Owner at Warung Kopi Demo 1, tap **Buka kasir** | The till opens; Reports stays reachable from the insights icon |
| APP-L08 | Session survives restart | Log in, force-close the app, reopen | Still logged in on the same home screen |
| APP-L09 | Language | Settings → Bahasa → English, then back | Every screen switches language without restart |
| APP-L10 | Theme | Settings → Tema → Gelap / Terang | Light and dark themes apply to every screen |

## 4. App — taking an order

The cashier builds a cart from the product grid, then either pays straight away (Immediate branch) or saves it as an open bill to pay later (Open Bill branch). The totals on screen are a preview; the server recalculates every amount when the order is saved.

### Product grid and cart

| ID | Test | Steps | Expected result |
| --- | --- | --- | --- |
| APP-O01 | Category filter | Tap each category chip, then **Semua** | Grid shows only that category; Semua shows all available items |
| APP-O02 | Unavailable items hidden | Mark an item unavailable in the Portal, refresh the app | Item no longer in the grid |
| APP-O03 | Out of stock | Sell a tracked item until stock reaches 0 | Card shows **Stok habis** and cannot be added |
| APP-O04 | Stock counts the cart | Item with stock 2: add it twice | Third add is refused; stock shown accounts for what is already in the cart |
| APP-O05 | Variants | Tap an item with several variants | Variant choice shown; the cart line shows the variant and its price |
| APP-O06 | Required modifiers | Tap an item with a required modifier group | Cannot add until the minimum choices are made |
| APP-O07 | Change quantity / remove | Use + / − on a cart line, reduce to 0 | Quantity and totals update; line removed at 0 |
| APP-O08 | Tax and service | Warung Kopi Demo 1: sell 2× Kopi Susu | Total **Rp 41.400** (PBJT 10% + service 5%) |
| APP-O09 | Stock short at save | Two devices sell the last unit at the same time | The second is refused: *Stok {item} tidak cukup — pesanan tidak disimpan.* Nothing is recorded. |

### Order type (F&B)

| ID | Test | Steps | Expected result |
| --- | --- | --- | --- |
| APP-O10 | Takeaway | Choose **Bawa pulang**, complete the sale | Saved as takeaway; no table needed |
| APP-O11 | Dine-in needs a table | Choose **Makan di tempat**, leave table empty, submit | *Isi nomor meja dulu*; nothing saved |
| APP-O12 | Table chip | Enter a table number | **Meja {n}** chip shows in the app bar |

### Open bills (Open Bill branches)

| ID | Test | Steps | Expected result |
| --- | --- | --- | --- |
| APP-O13 | Save a bill | Build a cart, tap **Proses Pesanan** | Bill appears under **Pesanan**; stock is reserved; no payment taken |
| APP-O14 | One open bill per table | Save a second bill for the same table | *Meja itu sudah punya pesanan terbuka*; nothing saved |
| APP-O15 | Edit a bill | Pesanan → pencil icon → change items → **Update Pesanan** | Bill updated; totals and reserved stock follow the change |
| APP-O16 | Settle a bill | Pesanan → tap the bill → pay | Bill leaves the list and appears in Riwayat as paid |
| APP-O17 | Cancel a bill | Pesanan → **Batalkan pesanan** | *Pesanan dibatalkan, stok dikembalikan*; bill kept in history as cancelled |
| APP-O18 | Search | Pesanan → **Cari meja** | List filters by table |
| APP-O19 | No editing without a catalogue | Open a bill on Laundry Wangi or Kios Pak Darto | No pencil icon; the bill can only be settled or cancelled |

## 5. App — payment and receipts

The Payment screen shows **Total tagihan** and one button per tender. **QRIS, card and e-wallet payments are simulated**: no money moves and no real terminal or acquirer is called. Test the flow and the recorded method, not a real settlement.

| Tender | Offered to | How it completes |
| --- | --- | --- |
| Tunai (cash) | Everyone | Enter **Uang diterima** or tap **Uang pas**; change is shown |
| QRIS | Everyone | A simulated QR is shown; tap **Selesaikan** |
| Kartu debit, Kartu kredit, Kartu BCA | General and UMKM only | **Proses di EDC** opens a simulated terminal |
| ShopeePay, GoPay, OVO | General and UMKM only | A simulated wallet QR; tap **Pembayaran diterima** |

| ID | Test | Steps | Expected result |
| --- | --- | --- | --- |
| APP-P01 | Cash with change | Total Rp 41.400, enter 50.000 | **Kembalian** Rp 8.600; sale saved as Tunai |
| APP-P02 | Exact cash | Tap **Uang pas** | Change Rp 0; sale saved |
| APP-P03 | Cash short | Enter less than the total | *Uang tunai kurang dari total*; cannot complete |
| APP-P04 | QRIS | Choose QRIS, tap Selesaikan | Sale saved with method QRIS |
| APP-P05 | Card approved | Choose Kartu debit → Proses di EDC → **Proses kartu** | Terminal runs MEMBACA KARTU → MEMPROSES → **DISETUJUI**; approval code, RRN and terminal shown; sale saved as that card type |
| APP-P06 | Card declined | On the EDC screen tap **Simulasikan kartu ditolak** | **DITOLAK** and *Kartu ditolak. Coba lagi atau gunakan metode pembayaran lain.* No sale saved; cashier can choose another tender |
| APP-P07 | E-wallet | Choose GoPay, tap Pembayaran diterima | Sale saved with method GoPay |
| APP-P08 | UMI tenders | Pay at Warung Bu Sri | Only Tunai and QRIS are offered |
| APP-P09 | Receipt | Complete any sale | **Struk** shows items, Subtotal, Pajak, Service, Total, method, amount tendered, change (cash) or approval code (card) |
| APP-P10 | Print | On the receipt tap **Cetak** with a paired printer | Receipt prints. With no printer: *Printer tidak terhubung* |
| APP-P11 | Share | Tap **Bagikan** | *Bagikan struk (segera hadir)*: not built yet, expected |
| APP-P12 | Next sale | Tap **Pesanan baru** | Empty cart, back on the till |

## 6. App — corrections: void, refund, cancel

A completed sale is never edited or deleted. A void or refund adds a new record on top of it, returns the stock, and keeps the original visible in Riwayat and every report. Corrections start from **Riwayat** → tap the transaction.

| Correction | When | Scope | Stock |
| --- | --- | --- | --- |
| Void (**Batalkan transaksi**) | Same business day only (Jakarta time) | The whole sale | All returned |
| Refund | Any day | **Penuh** (full) or **Per item** | Refunded items returned |
| Cancel bill (**Batalkan pesanan**) | Open bills only, before payment | The whole bill | Reservation released |

**Who approves.** An owner or manager approves their own correction. A cashier must enter a manager or owner PIN in the **Persetujuan manajer** dialog. At a UMI merchant nobody is asked for a PIN. A reason is always required, including at UMI.

| ID | Test | Steps | Expected result |
| --- | --- | --- | --- |
| APP-C01 | Void as manager | Manager: Riwayat → today's sale → void → pick a reason | *Transaksi dibatalkan, stok dikembalikan*; sale shows as voided, not removed |
| APP-C02 | Void reasons | Open the reason dialog | Salah item, Salah harga, Pelanggan batal, Transaksi tes; a reason is mandatory |
| APP-C03 | Void as cashier | Cashier voids; enter manager PIN 8888 | Void succeeds; the manager is recorded as approver |
| APP-C04 | Wrong approver PIN | Cashier voids; enter 0000 | Refused (invalid manager PIN); nothing changes |
| APP-C05 | Cashier PIN as approver | Cashier voids; enter a cashier PIN (1234) | Refused: only owner or manager PINs approve |
| APP-C06 | Yesterday's sale | Try to void a sale from a previous day | *Pembatalan hanya boleh di hari yang sama — lakukan refund.* |
| APP-C07 | UMI quick void | Warung Bu Sri: void from the Riwayat list | Reason asked, no PIN asked; void succeeds |
| APP-C08 | Stock restored | Note an item's stock, sell 2, void | Stock back to the starting figure |
| APP-C09 | Full refund | Refund → **Penuh** → reason | *Refund diproses*; status Refund penuh |
| APP-C10 | Partial refund | Sale of 3 items: refund 1 by item | **Perkiraan refund** shows that item's value; **Sudah direfund** updates; status Refund sebagian |
| APP-C11 | Over-refund | Refund the same item again beyond what was sold | Refused: cannot refund more than remains |
| APP-C12 | Nothing left | Fully refunded sale → Refund | *Tidak ada yang bisa direfund lagi.* |
| APP-C13 | Void after refund / refund after void | Try each on the same sale | A voided sale cannot be refunded; a refunded sale can no longer be voided |
| APP-C14 | Online orders | Try to refund an online order | Refund is not offered |
| APP-C15 | Audit trail | Portal → Laporan → Jurnal Koreksi | Every void and refund above is listed with reason, who did it and who approved it |

## 7. App — grocery scanner mode and printers

A grocery till can sell by barcode. The **Pindai** screen has a camera scanner, an editable SKU field and **Lihat produk** to fall back to the grid; the cart and payment below it are the same as the order screen. Use Toko Sembako Demo, whose items carry barcodes (e.g. Bawang Merah 2kg `8992750540917`, Air Mineral 600ml `AIR6`).

**Scanner mode** (Settings → Mode pindai, Grocery only): **Otomatis** opens the scanner when a Bluetooth receipt printer is paired, **Aktif** always opens it, **Nonaktif** always opens the product grid.

| ID | Test | Steps | Expected result |
| --- | --- | --- | --- |
| APP-S01 | Mode On | Settings → Mode pindai → Aktif, return to till | The Pindai screen opens |
| APP-S02 | Mode Off | Set Nonaktif | The product-grid order screen opens |
| APP-S03 | Mode Auto | Set Otomatis, with and without a paired printer | Scanner with a printer; grid without |
| APP-S04 | Camera scan | Point the camera at an item's barcode | *Ditambahkan: {item}*; line added to cart |
| APP-S05 | Typed SKU | Type `AIR6` and tap **Tambah** | Air Mineral 600ml added |
| APP-S06 | Unknown SKU | Type `XXXX` and tap Tambah | *SKU tidak ditemukan: XXXX*; cart unchanged |
| APP-S07 | Out of stock by scan | Scan an item with 0 stock | **Stok habis**; not added |
| APP-S08 | Scan again | Scan the same item twice | Quantity 2 on one line, capped at stock on hand |
| APP-S09 | Browse fallback | Tap **Lihat produk** | Product grid opens; items can be added by tap |
| APP-S10 | Mode hidden elsewhere | Open Settings on an F&B merchant | No Mode pindai section |

### Printers

Settings → **Printer** (Grocery, F&B and Nota merchants) lists paired Bluetooth printers and has **Tes cetak**. Supported: thermal 58 mm ESC/POS printers (tested on RPP02N and Rongta RP58). Pair the printer in Android Bluetooth settings first.

| ID | Test | Steps | Expected result |
| --- | --- | --- | --- |
| APP-S11 | List printers | Pair a printer in Android, open Settings → Printer | It appears under **Terpasang**; with none: **Tidak ditemukan** |
| APP-S12 | Test print | Tap **Tes cetak** | A test slip prints; **Tercetak** shown |
| APP-S13 | Receipt print | Complete a sale, tap Cetak | The receipt prints, matching the on-screen Struk |
| APP-S14 | Cash drawer | With a drawer wired to the printer's RJ11 port, print a receipt | Drawer opens right after printing |
| APP-S15 | Printer off | Switch the printer off, tap Cetak | *Printer tidak terhubung*; the sale is still saved |

## 8. App — Calculator mode

A merchant with no product catalogue sells on a keypad: the cashier keys each amount, and the finished **nota** is saved as a normal sale. Every role lands here. Test on **Kios Pak Darto** (owner PIN 2222). Calculator mode is **cash only**.

Keypad: digits, **00**, **000**, **⌫** (backspace), **C** (clear the current value), **↵** (commit the value as a line).

| ID | Test | Steps | Expected result |
| --- | --- | --- | --- |
| APP-K01 | Home screen | Log in to Kios Pak Darto | **Input nota** keypad with **Nota #{n}**; empty list reads *Ketik nilai, lalu tekan ↵* |
| APP-K02 | Add lines | Key 15000 ↵, 000 shortcut: 25 000 ↵ | Lines **Item 1** Rp 15.000 and **Item 2** Rp 25.000; **Jumlah item** 2; TOTAL Rp 40.000 |
| APP-K03 | Backspace / clear | Key 1234, ⌫, then C | 123, then 0; no line added |
| APP-K04 | Empty commit | Press ↵ with value 0 | No line added |
| APP-K05 | Pay with change | **Selesai** → **Uang diterima** 50.000 | *Lunas · kembalian Rp 10.000*; sale in Riwayat |
| APP-K06 | Cash short | Enter less than TOTAL | **Kurang** shown with the shortfall; cannot complete |
| APP-K07 | Cancel nota | **Kembali** / cancel → *Batalkan nota ini?* → **Ya, batalkan** | Every line deleted; nota number unchanged; nothing recorded |
| APP-K08 | Nota number | Complete two notas | Nota # increases by 1 each time; it restarts daily and after logout (display only) |
| APP-K09 | Save fails offline | Airplane mode, then Selesai | Sale is queued and syncs later, or *Penjualan ini belum tersimpan … tekan Selesai lagi.* No double sale after retrying |
| APP-K10 | Double tap Selesai | Tap Selesai twice quickly | One sale recorded; a retry shows *Nota sebelumnya sudah tersimpan — cek Riwayat.* |
| APP-K11 | Tax line | On a calculator merchant with a tax rule | A **{label} {pct}%** line shows under the items and is included in TOTAL |
| APP-K12 | Voice entry | Tap the mic icon | Voice order opens in calculator mode (section 10) |

**Known limitation:** a committed line cannot be deleted on its own. Only cancelling the whole nota clears it.

## 9. App — Baca Nota (reading a handwritten bill)

The app photographs a handwritten nota, an AI reader returns its lines, and the cashier checks them before anything is recorded. It needs a network connection; a read takes up to about 30 seconds. There are two surfaces:

| Surface | Where | Result |
| --- | --- | --- |
| **Baca nota** screen | Document-scanner icon on the F&B order screen | **Jadikan pesanan** turns the reading into a normal order from the catalogue |
| **Nota chat** | Home screen of Laundry Wangi Demo (Nota business type) | **Tidak, buat transaksi** records an unpaid sale, settled later |

If the screen shows *Mode contoh: pembaca AI belum diaktifkan di server…*, the server's AI reader is switched off and every photo returns the same sample. Report it as an environment issue, not an app defect.

### Baca nota screen (F&B)

| ID | Test | Steps | Expected result |
| --- | --- | --- | --- |
| APP-N01 | Read a nota | Icon → **Ambil foto** → photograph a nota | *Membaca nota…*, then **Hasil bacaan DPOS**: No. nota, Tanggal, Nama/Meja, and lines with Keterangan, Qty, Harga, Jumlah |
| APP-N02 | Totals agree | Nota whose lines add up to its written total | **Total di nota** equals **Jumlah per baris**; no warning |
| APP-N03 | Totals disagree | Nota whose lines do not add up | Warning plus **Selisih**, e.g. *Baris-barisnya Rp 25.000 lebih banyak dari total yang tertulis.* |
| APP-N04 | Correct a line | Tap a line (**Perbaiki baris**), change qty or price | Line marked **diubah**; totals and Selisih recalculate |
| APP-N05 | Unclear lines | Blurred or partly unreadable nota | **Kurang jelas terbaca** section with a confidence %; unreadable fields say *Tidak terbaca* |
| APP-N06 | Table number → dine-in | Name field reads a number, e.g. "12" or "Meja 07" | Field labelled **Meja**; the order is dine-in, table 12 (or 7; leading zeros dropped) |
| APP-N07 | Name → takeaway | Name field reads a name, e.g. "Budi" | Field labelled **Nama**; the order is takeaway |
| APP-N08 | Shop price wins | A line whose paper price differs from the catalogue | *Di nota {price} — yang dikenakan harga toko*; the order charges the catalogue price |
| APP-N09 | Make the order | **Jadikan pesanan** | **Pesanan dari nota** with *Dibaca dari nota #{number}*; continues into the normal payment or open-bill flow |
| APP-N10 | Stock short | A read line exceeds stock | The order is refused with the stock message; nothing recorded |
| APP-N11 | Bad file / no camera | Deny camera permission | *Akses kamera diperlukan untuk memotret nota.* |
| APP-N12 | Unreadable photo | Photograph a blank page | *Nota tidak dapat dibaca. Coba foto yang lebih jelas dan dekat.* |
| APP-N13 | Hidden controls | Open the screen | No "Dibaca oleh" line, no Data mentah toggle, no Pilih dari galeri button |
| APP-N14 | Not on Grocery | Open the order screen on Toko Sembako Demo | No Baca nota icon (see section 16) |

### Nota chat (Laundry Wangi Demo)

| ID | Test | Steps | Expected result |
| --- | --- | --- | --- |
| APP-N15 | Send a photo | **Kamera** or **Galeri** → a nota | Reply shows **Nota #{number}**, each line, **Total di nota** and **Akan ditagih** |
| APP-N16 | Nothing recorded yet | After the reply, check Riwayat | No transaction exists until confirmed |
| APP-N17 | Confirm | *Apakah ada yang perlu diperbaiki?* → **Tidak, buat transaksi** | *Transaksi dibuat — menunggu pembayaran.*; sale listed as unpaid |
| APP-N18 | Ask to fix | Tap **Ya, perbaiki** | *Perbaikan belum tersedia. Nota ini BELUM dicatat…*; nothing recorded |
| APP-N19 | Pay now | Tap **Bayar sekarang** | Normal payment flow; sale becomes paid |
| APP-N20 | Same nota twice | Send the same nota again and confirm | *Nota #{number} sudah tercatat, jadi tidak dibuat dua kali.* with **Lihat transaksi** |
| APP-N21 | Re-record after cancel | Cancel the unpaid sale, send the nota again | Recorded again (cancelled notas can be re-recorded) |
| APP-N22 | Unpriced lines | Lines like "A/J FREE" or "31 pc" | Shown as **tidak dihitung**; not charged |
| APP-N23 | Totals disagree | Written total differs from the lines | *Total yang ditulis di nota berbeda dengan barisnya. Transaksi memakai jumlah baris: {amount}.* |
| APP-N24 | Total only | Nota with a total but no line prices | *Tidak ada baris yang berharga sendiri, jadi transaksi memakai total di nota.* |

## 10. App — Voice order (speech to text)

The cashier reads the order aloud and the app lists it as rows of **Item, Jml, Harga, Jumlah**. It runs on **Android only**, uses the phone's Google speech recognizer in Indonesian, and needs microphone permission. Open it with the **mic icon** on the order screen or the calculator. Listening stops on the **Berhenti** button or when the cashier says **"pesanan selesai"** (also "pesanan sudah selesai" or "order selesai").

| Mode | Say | Result |
| --- | --- | --- |
| **Dari katalog** | "ayam geprek keju lima, es teh dua" | Each item is matched to the catalogue and checked against stock; price is the shop's |
| **Harga diucapkan** (calculator) | "pecel lele seratus, es teh lima" | Each line takes the spoken name and price. A bare number under 1.000 means thousands: "100" = Rp 100.000, "5" = Rp 5.000 |

The mode can only be switched while the list is empty.

| ID | Test | Steps | Expected result |
| --- | --- | --- | --- |
| APP-V01 | Permission | First use; deny, then allow the microphone | Deny: listening does not start and the reason is shown. Allow: listening starts |
| APP-V02 | Start / stop | Tap the mic, speak, tap **Berhenti** | Button reads Berhenti only while listening; returns to the mic when stopped |
| APP-V03 | Stop phrase | Say an order, then "pesanan selesai" | Listening stops; "pesanan selesai" is **not** added as a line |
| APP-V04 | Several items in one breath | "air mineral satu ayam bakar dua" | Two rows: Air Mineral ×1, Ayam Bakar ×2 |
| APP-V05 | Quantity after a pause | Say "ayam geprek keju", pause 5 s, say "lima" | One row, quantity 5 (not a new row with qty 1) |
| APP-V06 | Stock check | Ask for more than is in stock | Row flagged *{item} — sisa {left}, diminta {asked}*; out of stock: *stok habis (sisa 0)* |
| APP-V07 | Not in catalogue | Say an item that does not exist | Row flagged **Tidak ada di katalog** |
| APP-V08 | Flagged rows block | Leave any flagged row | *Perbaiki {n} baris bertanda dulu.*; Selesai and Tambah ke keranjang are disabled |
| APP-V09 | Remove a row | Tap × on a row | Row removed; total updates |
| APP-V10 | Repeat ignored | Say the same item twice within a few seconds | Second one not added: *Terdengar lagi dalam hitungan detik — dianggap ulangan* |
| APP-V11 | Add to cart | Dari katalog → **Tambah ke keranjang** | Back on the till with those items in the cart |
| APP-V12 | Selesai (catalogue) | Dari katalog → **Selesai** | Goes straight into payment (or saves the open bill on an Open Bill branch) |
| APP-V13 | Spoken price | Harga diucapkan: "pecel lele seratus" | Row: Pecel lele, 1, Rp 100.000, Rp 100.000 |
| APP-V14 | Missing price | Harga diucapkan: "pecel lele" only | Row marked **Harga belum disebut**; blocks Selesai until fixed |
| APP-V15 | Selesai (calculator) | Kios Pak Darto, Harga diucapkan → Selesai → cash | Payment dialog; sale saved with the spoken names and prices |
| APP-V16 | Continuous listening | Keep talking across several pauses | Listening continues; no utterance silently dropped |

**Test tips:** speak at normal pace in a quiet room first, then with background noise. Record the phrase you said and what appeared. If a row is wrong or missing, note the time so the developer can match it to the device log.

## 11. App — online orders, offline use and sync

### Online orders (F&B)

Delivery-platform orders arrive in **Pesanan → Pesanan Online**, listed after the open bills, each with its platform logo. **These are simulated**: there is no live GoFood, GrabFood or ShopeeFood connection. Settings → **Pesanan online (demo)** makes the server inject a random order every 1–3 minutes. The app checks for new orders every 15 seconds.

| ID | Test | Steps | Expected result |
| --- | --- | --- | --- |
| APP-D01 | New order arrives | Turn on Pesanan online (demo), wait up to 3 min | Order appears with a **Baru** tag; the Pesanan badge count goes up; the phone announces it aloud |
| APP-D02 | Accept | Tap **Terima** | **Baru** tag disappears; badge count drops |
| APP-D03 | Complete | Tap the order → **Cetak** | Receipt prints (or *Printer tidak terhubung*); the order leaves the queue and appears in Riwayat as completed |
| APP-D04 | Platform logos | View orders from each platform | Correct logo on each (on a white chip) |
| APP-D05 | Demo off | Turn the toggle off | No new orders are injected |
| APP-D06 | Not a correction target | Open a completed online order | Refund is not offered |
| APP-D07 | Pull to refresh | Pull down on Pesanan | List reloads |
| APP-D08 | Not on other types | Open the app as Grocery or Nota | No online-order section |

### Offline use and sync

The app keeps the catalogue on the phone and queues sales made without a connection, sending them when the connection returns. Each sale carries its own ID, so a resend never creates a second sale.

| ID | Test | Steps | Expected result |
| --- | --- | --- | --- |
| APP-D09 | Sell offline | Airplane mode, complete a cash sale | *Tersimpan offline — akan tersinkron saat online*; receipt still shown |
| APP-D10 | Sync on reconnect | Turn the connection back on, wait | The sale appears in Riwayat and in the Portal, **exactly once** |
| APP-D11 | Catalogue offline | Kill the app, go offline, reopen | Logged in; product grid loads from the phone |
| APP-D12 | Unstable network | Toggle data on and off while paying | No duplicate sale in Riwayat or Portal |
| APP-D13 | Stock conflict on sync | Sell the last unit offline on phone A and online on phone B, then reconnect A | A's sale is refused by the server with the stock message; stock never goes below 0 |
| APP-D14 | Features that need a connection | Offline: open Baca nota and online orders | Each reports it cannot connect; nothing is recorded half-way |

## 12. App — reports, history, items and settings

### Laporan (owners and managers)

Period switch: **Harian** (today), **Mingguan** (last 7 days), **Bulanan** (this month). Cards: net sales, **Transaksi**, **Rata-rata**, **LABA KOTOR**, **METODE PEMBAYARAN**, **PRODUK TERLARIS**, **PER OUTLET**, **PENJUALAN HARIAN** and **ABSENSI** (not for UMI).

| ID | Test | Steps | Expected result |
| --- | --- | --- | --- |
| APP-R01 | Figures match | Make 3 known sales, open Harian | Net sales, count and average match the three sales |
| APP-R02 | Voids excluded | Void one of them | Net sales drops by that sale; count drops |
| APP-R03 | Portal agrees | Same period in Portal → Dashboard | Same net sales and order count |
| APP-R04 | Gross profit | Sell items that have a cost price | LABA KOTOR = sales − cost |
| APP-R05 | Missing cost warning | Warung Bu Sri: sell *Bakwan Sayur* | Warning names the item with no cost price; profit marked incomplete |
| APP-R06 | Attendance | Clock in and out as a cashier | ABSENSI lists the staff member and hours |
| APP-R07 | Cashier blocked | Log in as a cashier | No Laporan icon |

### Riwayat (history)

| ID | Test | Steps | Expected result |
| --- | --- | --- | --- |
| APP-R08 | List | Open Riwayat | Newest first; header shows **PENJUALAN BERSIH**, {n} transaksi, {n} dibatalkan |
| APP-R09 | Detail | Tap a transaction | Items, totals, method, status, and any void or refund under it |
| APP-R10 | Reprint | Detail → Cetak | Receipt reprints |

### Barang & harga (UMI owners only)

A UMI owner manages items in the app because the Portal is closed to them. Reach it from the Items icon on Laporan. The limit is **30 items**.

| ID | Test | Steps | Expected result |
| --- | --- | --- | --- |
| APP-R11 | Add item | **Tambah barang**: name, category, **Harga jual**, **Harga modal**, SKU, **Lacak stok**, **Stok saat ini** | *Tersimpan*; item appears on the till; counter shows used / 30 |
| APP-R12 | Required fields | Save without name or category | *Nama dan kategori wajib diisi* |
| APP-R13 | Margin | Enter price and cost | **Margin {amount}** shown; without cost: *Belum ada harga modal* |
| APP-R14 | Limit | Add a 31st item | *Batas barang tercapai. Hubungi DPOS untuk mengubah paket.* |
| APP-R15 | Not for others | Log in as a General owner | No Items icon (items are managed in the Portal) |

### Pengaturan (settings)

| Setting | Shown to | Test |
| --- | --- | --- |
| Bahasa, Tema | Everyone | APP-L09, APP-L10 |
| Mode pindai | Grocery | APP-S01 to APP-S03 |
| Printer | Grocery, F&B, Nota | APP-S11 to APP-S15 |
| Pesanan online (demo) | F&B | APP-D01, APP-D05 |
| **Uji coba suara** | Everyone (Android) | A tuning bench for the speech recognizer, used by developers. It records nothing; QA only needs to confirm it opens and listens |
| Keluar (log out) | Everyone | APP-L06 |

## 13. Customer Portal — dashboard, staff, items, entity

The **D-Customer Portal** is a web app for the business owner. Sign in with the owner's email and password (section 1). Only owners of General or UMKM merchants can sign in. The sidebar has **Dashboard**, **Resources**, **Prices**, **Entity Settings** and a collapsible **Laporan** group (section 14). Test in Chrome and on a phone-width window.

**Caution:** the demo merchants are shared. Do not change a demo merchant's **Business type** or deactivate its demo staff; create new staff and items for tests instead.

### Sign in

| ID | Test | Steps | Expected result |
| --- | --- | --- | --- |
| POR-A01 | Owner sign in | `owner@warungdemo.id` / `owner123` | Dashboard opens; merchant name and business type badge in the header |
| POR-A02 | Wrong password | Any wrong password | *Invalid email or password* |
| POR-A03 | UMI refused | `busri@warungbusri.id` / `busri123` | Refused: *This account manages its business in the DPOS app.* |
| POR-A04 | Log out | **Log out** (top right) | Back to Sign in; protected pages redirect to Sign in |

### Dashboard

Filters: branch (**All branches** or one), from and to dates (default: the last 7 days). Shows **Net sales**, **Orders**, **Avg ticket**, **Sales by day**, **Payment methods**, **Top items** and **By branch**.

| ID | Test | Steps | Expected result |
| --- | --- | --- | --- |
| POR-D01 | Matches the app | Compare with the app's Laporan for the same days | Same net sales and order count |
| POR-D02 | Branch filter | Pick Outlet Pusat, then Outlet Cabang | Figures change to that branch only; By branch agrees |
| POR-D03 | Date filter | Pick a range with known sales | Only sales in the range counted |
| POR-D04 | Empty range | Toko Sembako Demo, default range | Rp 0 and *No sales in range.* (its last sale is 10 Sep) |
| POR-D05 | Voids excluded | Void a sale in the app, refresh | Net sales drops by that sale |

### Resources (staff)

| ID | Test | Steps | Expected result |
| --- | --- | --- | --- |
| POR-S01 | Add cashier | **+ Add staff**: Name, Phone, Role Cashier, Assignment (a branch), PIN 4–6 digits | Listed; can log into the app with that PIN |
| POR-S02 | PIN rules | PIN of 3 or 7 digits, or letters | Refused: pin must be 4–6 digits |
| POR-S03 | Update PIN | **Update PIN** → New PIN | Old PIN stops working in the app; new one works |
| POR-S04 | Deactivate | Edit → Status inactive | That staff member can no longer log in |
| POR-S05 | Role change | Change a cashier to Manager | After re-login, they land on Reports and can approve voids |
| POR-S06 | HQ assignment | Leave Assignment empty | Staff belongs to HQ / all branches |

### Prices (items and stock)

| ID | Test | Steps | Expected result |
| --- | --- | --- | --- |
| POR-P01 | Add item | **+ Add item**: Product name, Category, Variant / unit, SKU / Barcode, Selling price, Cost price, Track inventory, Opening stock | Item appears in the list and on the app till after refresh |
| POR-P02 | New category | Type a category that does not exist | Created and used |
| POR-P03 | Edit price | **Edit** → change Selling price → Save | New price on the next sale; past sales keep the old price |
| POR-P04 | Unavailable | Edit → untick **Available for sale** | Item hidden from the app till |
| POR-P05 | Stock adjust | Choose a branch, Edit → **On hand** 0 → Save | App shows Stok habis for that item at that branch only |
| POR-P06 | Barcode | Set SKU / Barcode, then scan it in the app | Item added (section 7) |
| POR-P07 | Negative values | Price or stock below 0 | Refused |

### Entity Settings

| ID | Test | Steps | Expected result |
| --- | --- | --- | --- |
| POR-E01 | Company | Edit Company name and Logo URL | Header and app show the new name |
| POR-E02 | Add branch | **+ Branch**: Branch code, Name, Address, Branch manager, Bill settlement | New branch listed; selectable in Dashboard and staff Assignment |
| POR-E03 | Bill settlement | Switch a test branch between pay-at-till and open bill | App on that branch shows or hides the **Pesanan** button |

## 14. Customer Portal — Laporan (reports)

Six read-only reports sit under **Laporan** in the sidebar. The group opens by itself on any `/laporan/...` page, and the old `/bank` link redirects to `/laporan/bank`. Use **Warung Kopi Demo 1**: it has six months of history, bank settlement lines and data-sharing consent.

| Report | Path | What it shows | Default range |
| --- | --- | --- | --- |
| Jurnal Transaksi | `/laporan/jurnal` | Every sale, newest first: time, items, cashier, subtotal, tax, total, method, status. **Ekspor CSV**. 100 per page | Last 30 days |
| Rekap Harian | `/laporan/harian` | One row per day: transactions, subtotal, discount, tax + service, cash, non-cash, gross, voided count; totals row. **Cetak** | Last 30 days |
| Jurnal Koreksi | `/laporan/koreksi` | Every void, refund and cancelled bill: reason, by whom, approved by. "Disetujui sendiri" counted | Last 90 days |
| Rekap Pajak | `/laporan/pajak` | Taxable base, tax and service per day at the rate charged. **Cetak** | Last 31 days |
| Jurnal Umum | `/laporan/umum` | Double-entry postings per day; debit must equal credit. **Cetak** | Last 31 days |
| Laporan Bank | `/laporan/bank` | Reconciliation with bank settlement, credit profile, simple profit and loss, data integrity, merchant activation | Last 30 days |

### Checks common to every report

| ID | Test | Steps | Expected result |
| --- | --- | --- | --- |
| POR-L01 | Date range | Set from and to | Range shown under the title matches; only sales in range |
| POR-L02 | Single day | Same date in from and to | Only that day's sales |
| POR-L03 | Reversed range | From later than To | Range is swapped and shown corrected; results are not empty |
| POR-L04 | Wide tables | Narrow the window | Rows stay on one line; a horizontal scrollbar appears under the table |
| POR-L05 | Print | **Cetak** where offered | Print preview shows the whole table, wrapped, without the filters |
| POR-L06 | Manager access | A manager's token (reports API) | Journal reports allowed; Laporan Bank is owner only |

### Report-specific checks

| ID | Test | Steps | Expected result |
| --- | --- | --- | --- |
| POR-L07 | Voids stay in the journal | Void a sale, open Jurnal Transaksi | The sale is still listed, status **Dibatalkan** with the reason, in red |
| POR-L08 | CSV export | Jurnal Transaksi → Ekspor CSV, open in Excel | File `jurnal-transaksi-{from}-{to}.csv`; Indonesian characters intact; same rows as the page |
| POR-L09 | Paging | Range with more than 100 sales | **Berikutnya** and **Sebelumnya** move 100 at a time; page count correct |
| POR-L10 | Daily totals | Rekap Harian | Totals row = sum of the rows; cash + non-cash = gross; voided sales counted but not in gross |
| POR-L11 | Corrections match | Do APP-C01, C03, C09 and C10, open Jurnal Koreksi | Each listed with the right kind (Pembatalan, Refund penuh, Refund sebagian), amount, reason and approver |
| POR-L12 | Self-approved | Void as a manager | Counted under **Disetujui sendiri** |
| POR-L13 | Tax rate | Rekap Pajak on Warung Kopi Demo 1 | Rate label shown; tax = 10% of base, service = 5% |
| POR-L14 | No tax rule | Rekap Pajak on a merchant without a tax rule | Explains the outlet has no tax rule, rather than showing zeros as if missing |
| POR-L15 | Ledger balances | Jurnal Umum, any range | Every day says **seimbang**; total debit = total credit; **Hari tidak seimbang** 0 |
| POR-L16 | Cash vs bank | Jurnal Umum on a day with cash and QRIS sales | Cash posts to **Kas**; QRIS and card to **Bank / Piutang Penyelenggara** |
| POR-L17 | Voided sale not posted | Void a sale, recheck Jurnal Umum totals | Debit total unchanged by the voided sale |
| POR-L18 | Missing cost | A day with an item without cost price | Note that the HPP / Persediaan pair is incomplete that day |
| POR-L19 | Reconciliation | Laporan Bank → Rekonsiliasi | Match rate shown; mismatched days listed first with status (settled, not settled, not in DPOS, amount differs); cash never appears |
| POR-L20 | Credit profile | Laporan Bank → Profil kredit | Months of history, average monthly turnover, lowest month, trading days per month |
| POR-L21 | No consent | Laporan Bank on a merchant without data-sharing consent | Credit profile says consent is missing instead of an empty card |
| POR-L22 | Activation | Laporan Bank → Aktivasi pedagang | Hidden or empty unless the bank portfolio key is configured (not configured today) |

## 15. Business rules every tester should verify

These rules hold across every screen. A failure of any of them is a **critical defect**, whatever feature it was found in.

| ID | Rule | How to check it |
| --- | --- | --- |
| BR-01 | **The server sets every amount.** The app's totals are a preview | Totals on the receipt, Riwayat, Portal and every report agree to the rupiah |
| BR-02 | **History is never rewritten.** Voids, refunds and cancellations add records; the original sale stays | After any correction, the original sale is still in Riwayat, Jurnal Transaksi and Jurnal Koreksi |
| BR-03 | **One sale is recorded once**, however many times it is sent | Offline and flaky-network tests (APP-D09 to D13), double taps (APP-K10): never a duplicate |
| BR-04 | **Stock never goes below zero** | Selling the last unit from two phones: one is refused (APP-O09, APP-D13) |
| BR-05 | **Every stock change is traceable**: sale, void, refund, cancelled bill, manual adjustment | Stock after a sell-then-void cycle returns exactly to the start (APP-C08) |
| BR-06 | **Prices and tax are fixed at the moment of sale** | Change a price or tax rule, then view an old sale: it keeps the old figures |
| BR-07 | **A merchant sees only its own data** | Logged in as one merchant, no screen, report or export shows another merchant's sales, staff or items |
| BR-08 | **Corrections need authority**: owner or manager, or a manager's PIN for a cashier; UMI excepted | APP-C03 to C05 |
| BR-09 | **A reason is always recorded** for voids and refunds | No correction can be submitted without one |
| BR-10 | **UMI merchants take cash and QRIS only**, enforced by the server too | APP-P08; no other method ever appears on a UMI sale |
| BR-11 | **A nota number is recorded once per branch** unless the earlier sale was cancelled | APP-N20, APP-N21 |
| BR-12 | **The ledger balances**: total debit = total credit on every day | POR-L15 |

When reporting a defect against these rules, include the merchant, branch, staff login, device, the time to the minute, and the receipt or transaction number.

## 16. Known limitations and out of scope

The items below are known and expected today. Do not log them as new defects; do report anything that behaves differently from what is described here.

| Area | Known behaviour |
| --- | --- |
| Payments | QRIS, card (EDC) and e-wallet payments are simulated. No real acquirer or terminal is connected |
| Online orders | Simulated by the demo toggle. No live delivery-platform integration |
| Dates and times | Reports and the Portal use **UTC** calendar days, and Jurnal Transaksi shows times in UTC (7 hours behind Jakarta). A sale made after 00:00 and before 07:00 WIB appears under the previous day. A fix is planned |
| Grocery till | The barcode Scanner screen has no voice or Baca nota icon, and Baca nota is hidden on Grocery. Under review |
| Voice order | Android only. A full end-to-end device pass has not been completed yet, so QA findings here are especially useful. The **Harga diucapkan** mode is offered on catalogue merchants too, but saving it needs an open-amount item that only Calculator and Nota merchants have: record what Selesai does there |
| Calculator mode | Cash only. A committed line cannot be deleted on its own. Nota # is kept on the phone and resets daily and on logout |
| Nota chat | **Ya, perbaiki** (correcting a reading) is not built: re-take the photo instead |
| Receipts | **Bagikan** (share) is not built |
| Discounts | No discount control on the till |
| Portal items | No product image field. Images shown on the till come from seeded data only |
| Portal language | Core Portal pages are in English; the Laporan reports are in Indonesian |
| Laporan Bank | Merchant activation (portfolio) view is switched off until a bank key is configured |
| Platforms | No iOS app. The Portal is tested on desktop Chrome and phone-width browsers |

### Out of scope for this test cycle

- Performance and load testing of the server.
- Security and penetration testing.
- Real bank settlement files (Laporan Bank uses seeded settlement data).
