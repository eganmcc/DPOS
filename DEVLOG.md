# DPOS — Dev Log & Session Handoff

> **Purpose:** a living handoff so work with Claude Code can continue across machines/sessions.
> Update the **Current status** and **Next steps** at the end of each working session, then commit.
> Full design/decisions live in [`specs/001-pos-mvp/`](specs/001-pos-mvp/) (Spec Kit artifacts).

_Last updated: 2026-09-25._

## What this project is
Indonesian mobile POS (F&B-first) built with **Spec-Driven Development (GitHub Spec Kit)**.
- **`server/`** — NestJS + Prisma REST API (the *only* client of PostgreSQL). Authoritative for all money math, atomic checkout, idempotent submit, inventory ledger, audit, tenant scoping.
- **`app/`** — Flutter phone+tablet app (offline-first, drift cache + sync queue). Brand UI = "DIKA Bold" (navy `#133A68` + gold `#D6AD07`, light/dark, ID/EN).
- **`customer-portal/`** — **D-Customer Portal**, Vue 3 + Vite + TS admin SPA (dashboard, staff/PIN, inventory, prices, entity/branch settings; business-type aware). Runs locally against the live API (`npm run dev`, :5173).
- **DB** — AWS RDS for PostgreSQL, Jakarta (`ap-southeast-3`).

## Current status

> ### Note to the next Claude session (written 2026-09-21 evening, Mac → PC)
>
> - **State, already verified — don't re-derive it.** `main` @ `c3d6adb` (+ this DEVLOG commit):
>   app **0.5.1**, `flutter analyze` clean, **246 Dart tests**; server unchanged today, still 14
>   suites / 107. Tree clean, nothing unpushed. Re-run the suites when you change code, not to
>   confirm this line.
> - **The phone is back on the RELEASE key (resolved 2026-09-21, PC).** The Xiaomi (Redmi Note 14
>   Pro+, wireless adb) carries **0.5.1 / build 2114**, release-signed from the PC. Getting there
>   meant uninstalling the Mac's debug-signed 2113 — the signatures do not match, and there is no
>   way round it — which wiped login, cached catalogue, bench tuning and anything left in the sync
>   queue. The user accepted that. **Next build: 2115 or higher.**
> - **Only the PC has the release keystore.** A Mac build is debug-signed, so every PC ⇄ Mac
>   handover of the *phone* costs an uninstall. Hand out release builds from the PC, or put the
>   keystore on the Mac.
> - **A debug-signed 0.4.0 / 2111 APK may have been sent out on WhatsApp** (`dist/`, Mac only,
>   gitignored). Anyone who installed it hits `INSTALL_FAILED_UPDATE_INCOMPATIBLE` on the next real
>   release and has to uninstall first — worth warning them before they lose anything.
> - **Two things changed behaviour on the till today** (entries below): a read nota can become an
>   order on an F&B till, and **short or sold-out stock now blocks Selesai in voice too** — spec 010
>   § 12 was reversed on purpose, because the server refuses to oversell. A refused sale now says why
>   instead of "Gagal masuk (cek koneksi)".
> - **Not yet confirmed on the device:** the stock fix was installed but the user had not re-run
>   the nota from the first failure when the Mac session ended. Warung Kopi Demo's **Outlet Cabang
>   has every tracked item at 0 or 1** — test on Outlet Pusat, or restock.
> - **The online-order queue was cleared for demos (2026-09-21, PC).** Warung Kopi Demo had 74
>   active on Outlet Pusat and 21 on Cabang; **2 NEW are left on each**, the rest marked COMPLETED
>   through the app's own `POST /online-orders/:id/complete`. Nothing was deleted — they are real
>   orders with payments and stock behind them, and they stay in history and reports. If they pile
>   up again, that is the way to clear them; a direct DB write is both wrong and blocked.
> - **Read "What the device taught us" below before touching `app/lib/features/stt/`.**
> - **Diagnose from the device log, never from a plausible story.** If the log cannot answer it, say
>   so and ask. Today's stock bug was traced through the phone log, the live catalogue and the server
>   code — SSH to EC2 **timed out from the Mac**, so check whether it works from the PC.
> - **State branch + commit + date in any finding about the code.**
> - **Stage the whole tree**, but **leave `app/windows/` out** — a Flutter build regenerates its
>   plugin registrant and this app is Android-only by decision.
> - **The phone is the user's.** Install, `adb`, and log pulls only when asked for that round.
> - **Never weaken a failing test to make it pass.** If the product changed, say so and update the
>   assertion to the new contract, explicitly (as done today in `voice_order_screen_test.dart`).
>
> Still the biggest gap: voice has never had a clean end-to-end run on a device. Item 2 of Next steps.

> ### 2026-09-25 (PC) — spec↔code audit: six defects fixed on `fix/spec-gaps`, specs reconciled
>
> All 11 specs were audited against `main` @ `6fa84e7`. ~20 drifts and ~15 unbuilt requirements.
> Work is on **`fix/spec-gaps`** (short-lived, not merged) at the user's request so it can be tested
> before it reaches the trunk.
>
> **Fixed (six).**
> 1. **Consent was enforced on one bank report out of five.** `assertConsent()` now guards
>    reconciliation, laba rugi and integritas as well as the credit profile. The **journal** reports
>    are deliberately NOT gated — they are the merchant's own books read by its own staff; gating
>    them would lock out every merchant that never onboarded through a bank (spec 011 §G22).
>    Activation is per-row: a merchant without consent is counted in the funnel but not named.
> 2. **The offline queue never sent.** `SyncQueue.flush()` had no callers and `connectivity_plus`
>    was never imported, so "Tersimpan offline — akan tersinkron saat online" was false. New
>    `data/sync_flusher.dart` drains on connectivity regained, on app resume and on a 60s timer,
>    started from `_RootGate`, with a pending badge on both till app bars.
>    **Also:** a sale the server REFUSED used to stay `pending`. A naive flush would have retried it
>    for ever and could have created a sale minutes after the cashier was told it failed — refused
>    orders are now marked `rejected` and never replayed. Only "never reached the server" retries.
> 3. **A partly refunded sale could still be voided** (`VOID_AFTER_REFUND`): money and stock were
>    reversed twice, and the app offered the button next to "Sudah direfund".
> 4. **An online order could be refunded through the API** (`REFUND_NOT_IN_APP`); only Flutter checked.
> 5. **`GET /demo/directory` published demo PINs with no auth.** Now 404 unless `DEMO_LOGINS=1`
>    (**set this on the demo EC2 box or the login picker goes empty**), and rotating a PIN in the
>    portal clears `demoPin` so a stale PIN is never published.
> 6. **A refused spoken-price voice sale hung the screen** — no try/catch, so Selesai span for ever.
>
> **Specs reconciled:** 001 carries a supersession table (cashier voids, refunds, hold/park, tenders,
> the bank-key exception) and its data-model and OpenAPI are marked where the code outgrew them;
> 011 gained §G for the whole Laporan journal suite (shipped 21 Sep, previously in no spec) plus a
> Known-gaps list; 004, 009, 010 gained amendment notes. `docs/qa/fsd.md` has 6 new cases.
>
> **NOT VERIFIED: the server suite did not run.** RDS refused TCP 5432 from this PC all afternoon
> (it worked that morning), there is no local Postgres and no Docker here. `npx tsc --noEmit` is
> clean and the new tests are written (`demo.directory.e2e-spec.ts` + cases in bank.reporting,
> orders.void, orders.refund) but **unrun** — run `cd server && npm test` before merging.
> Flutter is green: `flutter analyze` clean, **278 tests**, including 7 new flusher tests.
>
> **Backlog the audit found and nobody has built** (recorded in the specs, not fixed): shifts and the
> cash drawer, discounts in the app, tax-rule editing, product photos, outlet switching in the app,
> recording consent, outlet-level bank identifiers, the portal in Bahasa Indonesia, UTC-vs-Jakarta
> report days, raw tender enum codes on 4 surfaces, the partial-refund proportion using net-over-gross,
> the tenant-isolation and offline-sync test suites, and the `NOTA_RESULT` PII log.
>

> ### 2026-09-21 (latest, Mac) — first device run of nota → order failed; fixed (app 0.5.1)
>
> On the Xiaomi, nota #2 read **Mie Goreng ×1, Es Campur ×2**; Warung Kopi Demo has **0 and 1** on
> hand (both stock-tracked, both outlets). Stock only *warned* — voice's rule, "short stock does not
> block" — so Selesai went through, the server refused it (`400 Insufficient stock for Mie Goreng`,
> `orders.service.ts:305`) and rolled back, and the till said **"Gagal masuk (cek koneksi)"**. Nothing
> was recorded. Diagnosed from the phone log (the reading), the live catalogue (the stock), and the
> server code (the refusal); **not** from the server log — SSH to EC2 timed out from this Mac's
> network, so the 400 itself was inferred, not seen.
>
> - **Stock now blocks Selesai in voice AND nota** — `SttStockCheck.blocksSale`: not in the catalogue,
>   sold out, or short. A switched-off item still only warns (the server accepts it). **Voice's spec
>   010 § 12 is reversed, deliberately**, and its one test that pinned the old rule
>   (`sold out ... does NOT block`) was rewritten to the new contract, with the reason in the test.
> - **The till says why a sale failed** — `core/submit_error.dart`: stock in Indonesian ("Stok X
>   tidak cukup — pesanan tidak disimpan"), otherwise the server's own words, and "cek koneksi" only
>   when the server was never reached. Used by the open-bill confirm and the payment screen. This
>   also closes the old note under 2026-09-19 that `payment_screen.dart` showed a *sign-in* message
>   for a failed sale. (`checkout_screen.dart` still has it — superseded, nothing routes to it.)
> - Dart **246 tests** (+11), `flutter analyze` clean. App-only; no server change.
> - **To demo nota → order on Warung Kopi Demo, it needs stock.** Checked live: **Outlet Cabang has
>   all 28 tracked variants at 0 or 1**, and it is the login picker's default; Outlet Pusat has 15 of
>   28. Log in to Pusat, or restock in the portal.

> ### 2026-09-21 (later, Mac) — a read nota becomes an order on the F&B till (app 0.5.0)
>
> The till's **Baca nota** (scan icon, F&B) is no longer read-only. After a reading, **Jadikan
> pesanan** opens the lines in voice's four-column list, each checked with the **voice matcher**
> (`checkItem`: product, named variant, availability, stock), then **Tambah ke keranjang** or
> **Selesai** through the existing open-bill / payment flow. Spec: `specs/009` § F.
>
> - **The shop's price is charged, never the paper's** — a catalogue merchant can't be charged a
>   written amount. A different written price is shown on the line and does **not** block.
> - **Blocks Selesai:** whatever the server would refuse — not in the catalogue, **sold out or
>   short** — or a non-whole quantity. A switched-off item only warns. *(Stock blocking was added
>   after the first device run — see the entry above.)*
> - **Lines only, on your call:** the nota number is NOT carried, so re-reading one slip makes two
>   sales. The server already accepts `notaNumber` from any merchant if that changes.
> - **One money path:** voice's two finish helpers moved to `features/order/staged_order.dart`, and
>   voice and nota both call them. Voice behaviour unchanged; its tests untouched and green.
> - App-only: **no server change, no migration, EC2 needs nothing.** Dart **235 tests** (+21:
>   `nota_order_test.dart`, `nota_order_screen_test.dart`), `flutter analyze` clean.
> - **Not yet on a device.** Matching is the voice matcher's: shorthand like "nasgor" will not find
>   "Nasi Goreng" — it shows as not in the catalogue and must be removed. That is the thing to watch
>   on real slips.
> - The **0.4.0 / 2111** APK built earlier today (debug-signed, `dist/`) predates this.

> ### 2026-09-21 — speech to text is ON `main` (app 0.4.0). PICK UP HERE.
>
> **`feat/stt` was merged into `main` (18 commits) and deleted.** Everything below is on the trunk;
> there is no branch to check out.
>
> ```bash
> git checkout main && git pull --ff-only
> cd app && flutter pub get && flutter test      # 214 pass
> cd ../server && npm ci && npm test             # 14 suites / 107 pass
> ```
>
> Verified green on `main` after the merge: `flutter analyze` clean, **214 Dart tests**,
> **107 server tests**. Phone carries build **2110** (`dist/DIKASIR-0.3.1-2110.apk`), built from
> the branch tip — identical code, older version string.
>
> **EC2 needs nothing.** The only server change in the merge is a new test file; no runtime code,
> no migration. App 0.3.1 → **0.4.0** (voice is user-visible, so the version moves on merge).
>
> **Merged before a merchant trial, on your call** — the bench is harmless, but voice creates real
> orders and now ships to every cashier on the next build. It has been driven only by me, from the
> device log. Item 2 of Next steps is the end-to-end pass that has not happened yet.
>
> **What the branch adds — speech to text, two surfaces (`specs/010-voice-order-entry/spec.md`):**
>
> - **A tuning bench** — Settings → *Uji coba suara*. Android only. Every dial the plugin actually
>   honours, a live log, counters, and a *Salin diagnostik* button. It exists because the device
>   answers questions the docs get wrong; leave it in until voice ships.
> - **Voice order entry** — a mic on the till's app bar (and on the calculator screen, whose
>   merchants never see the till). Two modes: **from the catalogue** (matched to product, named
>   variant and stock) and **at a spoken price** ("Pecel lele 100" = one at 100.000). Four columns,
>   no keypad, lines removable, Selesai finishes through the EXISTING open-bill or payment flow —
>   voice adds no money path. The till app bar was also rearranged: words (Pesanan, Riwayat) then
>   icons (mic, nota, laporan, pengaturan); the nota icon now only shows for F&B/HHI.
>
> **What the device taught us (all of it cost real debugging — don't re-derive):**
>
> - Android reports Indonesian as legacy **`in_ID`**, never `id_ID`. Ask the device, never assume.
> - **`pauseFor` counts from `listen()`, not from the first word.** A silent session dies at exactly
>   that many seconds (measured: 3.010s). The till therefore floors it at 6s and forces continuous;
>   the bench keeps whatever you set.
> - `speech_to_text` **swallows a refused start**: it asks the platform, gets false, and returns
>   with no timers, no status, no error. The only honest answer to "is the mic open" is polling
>   `engine.isListening` — that is what the watchdog does.
> - `SpeechToText.initialize()` **returns early once it has worked**, so a second screen's callbacks
>   were never registered and statuses kept going to a dead screen (stop button stuck on). The
>   engine now forwards through a stable pair of listeners; the newest caller always wins.
> - An utterance is committed **five different ways** (final result, status, error, user stop, next
>   session finding leftovers). Listening to only one of them is how a heard line never got listed.
> - The recognizer **splits an utterance**: "ayam geprek keju" … 5.9s … "5", and "pesanan"/"selesai"
>   across two results. Hence: a lone number joins the line before it, and a line of only command
>   words is the stop instruction.
> - **Open-amount lines must have `qty: 1`** (server invariant), so a spoken quantity is expanded
>   into repeated lines. That is also what the receipt should read.
> - **The restart seam still loses syllables** spoken between sessions. Structural, not a bug we can
>   fix — Android has no continuous API. If it bites in a demo, **push-to-talk** is the answer and
>   `voice_order_screen.dart` is where it goes.
>
> **Shape of the code:** `app/lib/features/stt/` — `stt_runner.dart` is the ONE listening machine
> (both screens use it; it was duplicated once and the copy was immediately buggy). `stt_engine`,
> `stt_transcript`, `stt_commands`, `stt_stock_check`, `voice_order_parse` are pure and unit-tested;
> the two screens are Screen + injectable Body as usual.
>
> **Not done / open:** push-to-talk; tuning for a noisy warung; any merchant trial of voice;
> correcting a misread nota. Still blocking a real merchant on nota reading: the photo leaves
> Indonesia, and `NOTA_RESULT` holds customer names. The STT notes now reach logcat too (gated on
> the bench's `debugLogging`) — same rule, they are a customer's order and must not be in a real
> merchant's logs.
>
> **Two pitch decks exist outside the repo** (investor/partner, EN + ID), with placeholders for
> pilot numbers, pricing, the ask and contact details. Links are in the 2026-09-21 chat; they are
> private until shared.
>
> **Mac gotcha, recurring:** a Flutter build regenerates `app/windows/flutter/generated_plugin*`
> because the speech plugin declares a Windows target. This branch is Android-only by decision —
> `git checkout -- app/windows` before committing, every time.

> **2026-09-19 (later) — nota reading mode, live on `main` + EC2 (server 0.4.0, app 0.3.0, portal
> 0.3.0).** New business TYPE `HIGH_HUMAN_INTERACTION` ("High Human Interactions") for trades whose
> sale is handwritten on a nota. The app opens on the **nota chat** for every role: send a photo →
> the reply is the reading line by line → "Apakah ada yang perlu diperbaiki?" **Ya** records nothing
> (corrections not built yet). **Tidak** posts it with **no payment**, so it is an **open
> transaction** (`AWAITING_PAYMENT`) settled through the existing settle flow ("Bayar sekarang", or
> tap it in the open bills list). Spec `specs/009-nota-reading-mode/spec.md`; Constitution v1.9.0.
>
> - **Recording:** each priced line → an open-amount line at the price written on the paper,
>   **named as written** (new line `label`, refused on catalog lines). Priceless lines ("A/J FREE",
>   "31 pc") are shown as not charged. A nota priced only as a whole → one line at the written total.
>   Paper total ≠ sum of lines → flagged in the chat; the lines are what gets charged. The
>   open-amount gate is now `acceptsOpenAmountLines` = `calculatorOnly` OR this business type.
> - **One nota, one sale:** nota number → `externalOrderRef`, customer → `customerName`. A number
>   already on an open or paid, un-voided order at the outlet → `409 NOTA_ALREADY_RECORDED`; the chat
>   links to the existing transaction. Cancelled ones can be re-recorded.
> - **Migration 13 (`20260919180000_business_type_high_human_interaction`) is applied to RDS.**
>   Deploy order matters: migrate → deploy a server that knows the enum → only then create a merchant
>   of this type. A server without it can't decode that row and `/demo/directory` fails for everyone.
> - **Demo seeded on RDS: Laundry Wangi Demo** (`7175c186-…`), GENERAL size, OPEN_BILL outlet, no tax.
>   Owner **Bu Wangi PIN 3333**, cashier **Kasir Wangi PIN 4444**. `npx ts-node prisma/seed-nota.ts` is
>   idempotent. Name is invented on purpose — the real slips belong to a real laundry.
> - Phone has build **2093** (`dist/DIKASIR-0.3.0-2093.apk`). Server suite **14 suites / 104 tests**
>   (+ `orders.nota-sale.e2e-spec.ts`, 13); disabling the duplicate check fails exactly the two
>   "already recorded" tests. Dart **64 tests** incl. the chat end to end. Verified live: Kasir Wangi
>   logs in, catalog is HHI with the variant, slip 2532 reads `1 M BESAR → 130.000` via Opus 5 in 3.9 s.
> - **Update (same day): uncharged lines are kept as a note.** Priceless lines ("A/J FREE", "31 pc",
>   "S/B guling = 4"), anything the reader flagged unclear, and — for a total-only nota — the lines the
>   total covers go into a new **`Order.note`** (text, never money), previewed in the chat and shown in
>   the transaction detail. **Migration 14 (`20260919200000_order_note`) is applied to RDS.** Server
>   0.4.1, app 0.3.1, phone build **2094**. 106 server tests, 69 Dart tests.
> - **BLOCKER before any real merchant:** the photo goes to an AI provider outside Indonesia, and the
>   server log `NOTA_RESULT` holds customer names. Needs a scoped Constitution VII decision + merchant
>   consent, and the PII log removed. Also not built: correcting a reading; chat history across
>   launches (the transactions themselves are on the server).


> **2026-09-19 — calculator-only mode, live on `main` + EC2 (server 0.3.0, app 0.2.0).** A UMI
> merchant with no catalog now opens on **Input nota**: key an amount, `↵`, repeat, **Selesai** →
> cash received → Kembalian. Each finished nota is a **real Order** (one qty-1 line per amount) that
> shows in Riwayat, can be voided, and feeds Reports. Spec `specs/008-calculator-only/spec.md`;
> **Constitution v1.8.0** adds the bounded open-amount exception to Principle III.
>
> - **How a keyed amount is stored:** `OrderLine.variantId` stays `NOT NULL`. Each calculator merchant
>   has ONE hidden provisioned product `isOpenAmount` (named "Nota"); a line posts
>   `{variantId: <its variant>, qty: 1, amount}` and `computeOrder` uses `amount` as the unit price
>   for that variant only. The gate (`assertOpenAmountLines`, on **checkout AND revise**) is decided
>   from the DB and **refuses, never ignores**: 403 `OPEN_AMOUNT_NOT_AVAILABLE` for any
>   non-calculator merchant, 400s for amount-on-catalog-line / missing amount / qty≠1 / modifiers /
>   discount / out of range. `MAX_OPEN_AMOUNT` (server) must equal `kMaxNotaAmount` (app) = Rp 100 jt.
> - **Tax is data, not code:** calculator merchants have no `TaxRule`, so tax is 0 through the
>   engine's normal fallback. **Insert a `TaxRule` for the outlet and tax applies on the server AND
>   on the keypad total/change — no code change** (both suites assert 40000 → 46000).
> - **Migration 12 (`20260919120000_calculator_only_mode`) is applied to RDS.** It includes a partial
>   unique index `products_open_amount_uq` that Prisma can't represent — it lives in SQL only; run
>   `prisma migrate diff` after schema changes so a drift fix never drops it.
> - **Demo merchant seeded on RDS: Kios Pak Darto** (`a3e10dfd-…`), UMI + calculator-only, owner
>   **PIN 2222** in the login picker. `npx ts-node prisma/seed-calculator.ts` is idempotent.
> - Phone has build **2089** (`dist/DIKASIR-0.2.0-2089.apk`). Suite: **13 suites / 91 tests**
>   (+ `orders.open-amount.e2e-spec.ts`, 22 tests; disabling the merchant gate fails exactly the 3
>   that should catch it). Dart: 39 tests incl. `nota_calculator_test.dart` + a keypad→payment widget
>   test. Plus Jakarta Sans is bundled in `app/google_fonts/` (OFL) and scoped to this screen.
> - **Not done / follow-ups:** cash only (no QRIS on the keypad); "Nota #N" is a device-local daily
>   counter, display-only, and a logout (which clears prefs) resets it; a committed line can't be
>   deleted individually — only Batal clears the nota. `payment_screen.dart` shows
>   "Gagal masuk (cek koneksi)" (a *sign-in* message) when a sale fails — pre-existing, not touched.


> **2026-09-18 (models) — Opus 5 is the only reader that gets the money right. Haiku is not an
> option.** Compared on all three real laundry slips at 600px and 1200px, through the live
> endpoint via the new owner-only `?model=` override:
>
> | Slip | Opus 5 | Sonnet 5 | Haiku 4.5 |
> |---|---|---|---|
> | 1900 | correct, c88 | correct, c80 | lost the price |
> | 2237 | correct, c90 | correct, c75 | **total 120000, paper says 130000** |
> | 2532 | correct incl. `spre=1`, `S/B GULING=4`, `pkn=46`, c88 | dropped all three extra lines, c62 | **total 260000**, read the loose "2" as the amount |
>
> **Haiku got the total wrong on two of three slips, and 1200px did not fix it** (still 120000 and
> 260000) — it is misreading, not under-resolving. Sonnet keeps the totals but silently drops
> lines on 2532, which is arguably worse: a missing line looks like a clean read. Opus is the only
> one that reads 2532 completely.
>
> **So the ~4s wait is the price of a correct total, and it stays.** Opus at 600px (3.3-5.8s) is
> as good as Opus at 1200px (4.4-5.0s) and slightly faster — at 1200px it mangled the shorthand
> into `S/B 6uLIN6` — so **600px stays the setting**. Latency per model on these slips: Opus
> 3.3-5.8s, Sonnet 2.6-3.2s, Haiku 2.0-2.3s.
>
> Testing this needed neither a production restart nor sending slips to the API from a laptop:
> `POST /nota/read?model=` picks the reader for one request, OWNER-only and allowlisted to the
> three candidates (`EVALUATION_MODELS`), because choosing the model chooses the bill. The app
> never sends it. **12 suites / 69 tests.**
>
> What is left for the wait is perception, not seconds: cache a reading by image hash so a
> re-read is instant, or stream the reading so the nota number lands at ~1.7s. Nothing makes Opus
> faster.


> **2026-09-18 (latest) — the nota reader's wait is the model, and nothing else.** Measured on the
> phone (build 2088, `adb logcat | grep NOTA_TIMING`):
>
> ```
> afterSelect=3890ms = resize=30ms + roundTrip=3860ms (model=3729ms + network=131ms)
> ```
>
> **The app and the network are 161ms of 3890ms.** An earlier reading showed `capture=14606ms`,
> which looked alarming until the resize was separated from the picker: `pickImage(maxWidth:)`
> performs the downscale inside the same call the user spends browsing the gallery, so the two
> could not be told apart. Picking at full size and resizing with `flutter_image_compress` puts
> the resize at **30ms** — the 14.6s was a human choosing a photo. Every phone-side theory about
> why the reader feels slow is now retired.
>
> Six server-side levers were measured and **none of them moved the total**: prompt caching (cost
> win only, TTFT unchanged), fewer output tokens (181 -> 69, invisible on a 2-line slip),
> `effort: low` (not faster), a keep-alive for cold connections (the effect was noise), free-form
> JSON instead of structured output (faster per token, more tokens, net wash), and streaming vs
> `messages.parse()` (3030ms vs 2986ms — identical). **Opus 5's floor here is ~1.7s before the
> first token plus ~1.2-2s generating.** Nothing in the request shape changes it.
>
> What did land: input cost down ~70%, output tokens down 62%, and accuracy slightly *better* —
> the terse `unc` schema reads `"31 pc"` as qty 31 where the old prompt returned null, and returns
> `["tanggal"]` instead of a sentence. **The only remaining option is streaming the reading to the
> app** so the nota number lands at ~1.7s instead of everything at ~3.9s. That is perceived
> latency, not real, and it is the honest answer to "why is Claude web faster" — it is not, it
> just shows the words as they arrive.


> **2026-09-18 (later) — the nota reader's ~4s, measured properly.** `scripts/bench-nota-ttft.ts`
> splits the one opaque `latencyMs` into time-to-first-token and generation. On EC2, Opus 5,
> effort medium, 600x800 page: **TTFT ~1.6-1.8s, then ~13ms per output token.** Four levers were
> tried and only one of them is real:
>
> | Lever | Result |
> |---|---|
> | Prompt caching (`cache_control` on the system block) | **No speed change at all.** Input fell 2144 -> 651 tokens and TTFT did not budge, so the 1.6s is *not* prefill. **Kept for cost**, not speed. |
> | Fewer output tokens (terse wire schema + no prose in `unclear[]`) | Output **181 -> 69 tokens**, generation 2144 -> 1527ms on a dense page. **Invisible on a real 2-line slip**, whose output was already tiny. |
> | `effort: low` | **3538ms vs 3280ms at medium — no faster.** Not a speed lever; dropped without risking accuracy. |
> | Keep-alive for a cold connection | **Not a real effect.** The cold-run penalty measured +1222ms, +705ms, +14ms, -252ms across runs. It was noise. Dropped. |
>
> Net: input cost down ~70%, output tokens down 62%, **wall clock unchanged for short slips**.
> Live reads of a real slip after the change: 3634 / 4637 / 5669 ms — a +-1s spread that swamps
> any of the above. **The floor is ~1.7s of fixed overhead before the first token plus ~1.2-1.5s
> of generation, and nothing short of a different model moves it.** The only untried option is
> streaming the reading to the app so the nota number appears at ~1.7s instead of the whole thing
> at ~4s; that is perceived latency, not real, and it is half a day on `/nota/read`.
>
> The model now fills a terse wire schema (`no`/`dt`/`cust`/`it`/`raw`/`q`/`up`/`lt`) renamed back
> to `NotaExtraction` in `claude.provider.ts` — the API and the app are unchanged. That rename is
> where a nota's money could go silently wrong, so `test/nota.wire.e2e-spec.ts` pins it.
> **12 suites / 66 tests.** App also logs `NOTA_TIMING capture/roundTrip/model/network`
> (`adb logcat | grep NOTA_TIMING`) — the phone's share of the wait has never actually been
> measured, only the server's.


> **2026-09-18 — nota reader: 600 px photos, and the full reading in the log.** Two changes on
> `main` @ `b27b179`. (1) The app now downscales to **600 px** before upload (`kNotaMaxPixels` in
> `nota_reader_screen.dart`, was 1600). Image tokens scale with **pixel area**, not file size —
> measured 641 tokens at 600 px vs 4469 at 1600 px, so this is a ~7x cut in input cost, and it does
> **not** change latency (~4 s either way; the model is the wait, not the upload). (2) Both ends now
> log the whole reading: `NOTA_RESULT <json>` from `NotaService`
> (`sudo journalctl -u dpos | grep NOTA_RESULT`) and `NOTA_READ sent=<bytes> maxPx=600 result=<json>`
> from the app (`adb logcat | grep NOTA_READ`). **Both lines contain everything written on the slip,
> customer name included** — fine while this is trialled on the owner's own nota, but they must go
> before a real merchant's slips run through it, alongside the Constitution VII residency exception.
>
> Reader on EC2 is **`claude-opus-5 · effort medium · thinking off`** (module defaults; no
> `NOTA_VISION_*` in `/opt/dpos/server/.env`). Verified against one of the real laundry slips on
> 18 Sep: a 600 px, 42.8 kB copy posted to production came back in **4.2 s** with every field
> matching the paper at confidence 95 — and critically returned **nulls for the line that has no
> price** rather than inventing 0, which is what thinking-on runs used to do. So 600 px is legible
> for this handwriting. **Not yet settled:** whether 900/1200/1600 read *better* on the harder
> slips. `scripts/bench-nota-size.ts` answers that but is blocked in the cloud sandbox as data
> exfiltration — run it from a local shell. Phone has build **2086**.

> **2026-09-16 — nota reader (read-only), live on `main` and EC2.** `POST /api/v1/nota/read` + the
> **Baca nota** screen (scan icon in the POS app bar): photograph a handwritten nota and see what it
> says — number, date, name, verbatim lines, written total vs line sum, unclear fields. **Nothing is
> stored and no sale is created.** Reader is `claude-sonnet-5` via structured output, but **only when
> `ANTHROPIC_API_KEY` is set**; without it (the case on EC2 today) a stub returns a fixed laundry
> nota (Edward · 1. M. KECIL · Rp 65.000) for every photo. Adding the key to `/opt/dpos/server/.env`
> sends photos outside ap-southeast-3 — needs a Constitution VII exception + merchant consent first.
> **Server change outside git:** `client_max_body_size 8m;` added to the 443 block of
> `/etc/nginx/conf.d/dpos.conf` (backup `dpos.conf.bak-nota`) — nginx's 1 MB default returned 413
> on detailed photos before Node saw them. Phone has build **2082** (`dist/DIKASIR-0.1.0-2082.apk`).
> Suite: **11 suites / 63 tests**. Plan for turning nota into sales: `~/.claude/plans/i-want-the-pos-zesty-crab.md` (earlier revision).

> **2026-09-10 (later) — payment screen redesigned to the visual system, on `feat/payment-methods`.**
> Rebuilt as `app/lib/features/payment/payment_screen.dart` from the handoff canvas *DPOS Checkout
> Redesign* (`DPOS Visual System payment design.zip`): payment TYPE is now a **segmented tab**
> (Tunai · QRIS · Kartu · E-Wallet) instead of eight equal-weight tiles, so each tab gets the full
> width for one focused flow. Fixed chrome across tabs — app bar, TOTAL TAGIHAN block, tab track,
> content pane, pinned gold pill button. Tunai = quick-tender pills + Jumlah diterima + green
> Kembalian card; QRIS = centred gold-framed QR; Kartu = radio rows with brand marks then the EDC
> step; E-Wallet = radio rows + that wallet's QR. A **Metode lain** strip (56px tiles) jumps
> straight to any card or wallet. Selected state is one pattern everywhere: gold 2px border over a
> light-gold tint. A UMI till shows two tabs and no strip. **The old grid screen
> (`checkout_screen.dart`) is kept, not deleted** — marked SUPERSEDED, nothing routes to it, so it
> is a one-line delete once the new one has done a few real shifts. This also fixes the overlap bug
> where the wallet QR hint sat under the bottom button: the pane scrolls, the button is pinned
> outside it. All four tabs walked on the emulator.


> **2026-09-10 — card & e-wallet tenders, on `feat/payment-methods` (cut from `features/UMI`).**
> Six new tenders for non-UMI merchants: `CARD_CREDIT`, `CARD_DEBIT`, `CARD_BCA`,
> `EWALLET_SHOPEEPAY`, `EWALLET_GOPAY`, `EWALLET_OVO`, each behind the existing `PaymentProvider`
> (`SimulatedEdcProvider`, `SimulatedEwalletProvider`) so a real EDC or PSP drops in unchanged. A
> card tender routes through an **EDC simulation screen** (insert/tap/swipe → authorize → approve)
> that returns approval code, RRN, masked PAN, entry mode, trace and batch; the server validates
> that evidence, **refuses an unmasked PAN**, and stores it in a new nullable `Payment.providerMeta`
> JSONB. Amounts stay server-computed — the terminal never supplies one. Wallets render a per-wallet
> QR (all three are QRIS issuers). **UMI is refused card and wallet tenders server-side**
> (`403 UMI_TENDER_NOT_AVAILABLE`, at checkout *and* at settle) because acceptance needs an acquirer
> relationship; the till hides them too. Receipt, thermal slip and the reports payment-split now
> share one label map, so no surface can print a raw enum. **Migration 11 is applied to RDS**
> (additive: six enum values + one nullable column; the EC2 API on `main` is unaffected). Suite:
> **10 suites / 56 tests green**; `flutter analyze` clean + 6 unit tests. Spec
> `specs/007-payment-methods/spec.md`; no constitution change needed (Principle VII already covers
> simulated payments behind a real interface). **Verified on the emulator end to end**: card sale →
> EDC approval → receipt shows `VISA · 4*** **** **** 8944 · CHIP` and the approval code, and the
> stored payment row matches the slip. **Not merged; the brand marks are still placeholders.**

> **2026-09-08 — UMI (Ultra Mikro) business size, on `features/UMI`.** A new `Merchant.businessSize`
> axis (`GENERAL | UMKM | UMI`), **orthogonal** to `businessType` — a UMI merchant is still F&B or
> grocery. **UMI = a one-person business**: corrections need **no approver PIN for any role** (there is
> nobody to approve; the **mandatory reason stays** — a test asserts a reason-less void is still 400),
> the **portal is closed** to it (`loginOwner` → 403 `PORTAL_NOT_AVAILABLE`, which works because the app
> only ever logs in by PIN), **staff creation is refused** (403 `UMI_SINGLE_USER`), and the catalog is
> **capped at 30 products** (400 `ITEM_LIMIT_REACHED` — a hard stop; nothing writes `Product.isAvailable`,
> so the message says *contact DPOS*, never "switch one off"). In the app a UMI operator **lands on the
> POS** (not Reports), voids from the history tile in **2 taps** instead of 5, sees **no attendance**, and
> gets an **Items & prices** screen. New **gross-profit reporting for every merchant** (Laba Kotor =
> revenue − COGS from the already-written `costPriceSnapshot`; no schema change) with a visible
> **missing-cost-price warning**. Every correction now records an **approval basis**
> (`SELF | UMI_BYPASS | APPROVER_PIN`) in its `AuditLog`, so a null approver is never ambiguous.
> **Migration 10 is applied to RDS** (both demo merchants backfilled to `GENERAL`). Constitution
> **v1.7.0**, spec `specs/006-umi-business-size/spec.md`. Suite: **9 suites / 46 tests green**;
> `flutter analyze` clean + 6 unit tests. **Not yet merged to `main`, and not yet walked on a device.**

### UMI — handoff for the next session (written 2026-09-10, on `features/UMI`)

**Where it stands:** all 7 planned steps are committed on `features/UMI` (10 commits off `main` @
`1fc071f`). Server, app and portal all build; **9 suites / 46 tests green**, `flutter analyze` clean,
6 Flutter unit tests. The branch has **never been merged to `main`** and the app has **not been
walked on a device as a UMI merchant** — that is the main thing left.

**Read first:** `specs/006-umi-business-size/spec.md` (what was built and why) and constitution
**v1.7.0** (the clause that makes the approval bypass legal). Both are on this branch.

**Decisions already made with the user — do not relitigate:**
- Void/cancel bypasses the approver PIN for **every role** at a UMI merchant, but the **reason stays
  mandatory**. `umi.e2e-spec.ts` asserts a reason-less UMI void is still `400`. Don't "simplify" that.
- P/L is **gross margin only** (revenue − COGS). No expense table. Revenue is `netRevenue`
  (subtotal − discount), **not** the tax-inclusive `netSales`, which is left byte-identical.
- The 30-item cap is a **hard stop**. Nothing writes `Product.isAvailable`, so there is no
  self-service escape; the message must say *contact DPOS*, never "switch one off" (a test asserts it).
- `businessSize` is **read-only over the API** — set by script/SQL until a DPOS super-admin exists.
- The P/L card shows for **all** merchants, not just UMI.

**Environment traps that cost time here — don't rediscover them:**
1. **RDS blocks a new machine.** Add the desktop's public IP to the RDS security group (inbound
   5432) or nothing works — `nc -z dpos.cjcm0wuu2mj5.ap-southeast-3.rds.amazonaws.com 5432` is the
   quick check. This bit mid-session when the Mac's IP changed.
2. **RDS is already one migration ahead of `main`.** `20260908120000_merchant_business_size` was
   applied to production RDS on 2026-09-08 (both existing merchants backfilled to `GENERAL`). Harmless
   for the deployed API — it doesn't read the column — but `main` no longer describes the live schema.
   **Do not re-run the migration**; `prisma migrate status` will already show it applied.
3. **Stale APKs in `app/build/`.** `flutter build apk --release` writes `app-release.apk`, but
   `app-x86_64-release.apk` and the arm64/armeabi ones may be weeks old with identical `versionCode`
   (4001), so installing one looks successful and silently runs old code. `flutter clean` first, or
   check the file's timestamp.
4. **Emulator choice matters.** A Pixel 9a / API 36 image runs this app in 16 KB page-compat mode and
   ANRs repeatedly on both debug and release. **Pixel 3a / API 34 runs it fine.** Also: the debug APK
   is ~165 MB and takes ~3 min per install — use a release build for manual testing (already in
   Gotchas).

**To pick it up on another machine:**
```
git fetch origin && git checkout features/UMI       # then git pull --ff-only
cd server && npm install && npx prisma generate     # regenerate: the client has BusinessSize now
npm test                                            # expect 9 suites / 46 tests
cd ../app && flutter pub get && flutter gen-l10n && flutter analyze && flutter test
```

**Demo UMI merchant — already seeded on RDS, so don't re-seed unless it's missing:**
`Warung Bu Sri` · merchant `c06dbad8-69ae-4cb1-8f39-52345b0984dd` · outlet
`a54ab023-d020-465d-b815-552b098b4695` · **owner PIN `1111`** (Bu Sri, the only staff) ·
portal `busri@warungbusri.id` / `busri123` → **403 `PORTAL_NOT_AVAILABLE`** (that's the point) ·
14 of 30 items, **no tax rule**, stock only on Air Mineral (48) and Teh Botol (24) ·
**Bakwan Sayur has no cost price on purpose** — sell one and the Reports missing-cost warning goes
live. Re-create with `npx ts-node prisma/seed-umi.ts` (idempotent). The two original demo merchants
were deliberately left alone and are still `GENERAL` with all their order history.

**Verified against the live API (not just tests):** portal login → 403; the same person's PIN login →
200 as OWNER; catalog carries `businessSize: UMI`; `POST /admin/staff` → 403 `UMI_SINGLE_USER`; and
the P/L on Warung Kopi Demo 1 reads Rp 6.298.000 − Rp 2.644.000 = Rp 3.654.000 (58.0%), rendered on
the emulator as the **Laba Kotor** card.

**Still to do, in order:**
1. **Walk the UMI flow on a device** as Bu Sri: lands on the POS (not Reports), sell something, void
   from the history tile in 2 taps with no PIN, check Reports shows Laba Kotor + the missing-cost
   warning after selling a Bakwan Sayur, open Items & prices, confirm the `14 / 30` chip.
2. Confirm a **GENERAL** merchant is unchanged: cashier void still demands a manager PIN, owner still
   lands on Reports, attendance still prompts.
3. Merge to `main` and delete the branch (trunk-based; record the tip SHA in the deletion ledger).
4. Redeploy EC2 from `main` — no migration needed, it is already applied.

> **2026-09-05 — consolidated to a single trunk.** `main` is now the **only** branch; `beta-1` and the
> `beta-with-SDP-printer` / `customer-portal` / `claude/*` branches were merged/superseded and retired
> (restore SHAs in the deletion ledger under the branch map). **EC2 `/opt/dpos` deploys from `main`**
> and is in sync. The integrity suite (**8 suites / 35 tests**) is green on the merged tree. **Portal
> hardened to v0.2.1:** an expired-session `401` now clears the token and redirects to login instead of
> white-screening (plus a Vue `errorHandler` safety net). App on emulator + phone at build **2070**.

> **2026-09-04 — `main` is the trunk again.** `beta-1` merged into `main` via `--no-ff` (merge **`f48ce2b`**); the cloud session's `claude/correction-path-tests` was merged into `beta-1` first. Live on the trunk now: open bills (confirm-now, settle-later), **corrections — void (same-day + mandatory reason), refund (full & line-level partial), cancel an unpaid open bill (releases reserved stock)**, all with a **manager-PIN override** for cashier-initiated corrections (approver recorded); order **revise**; stock tracking; employee **attendance** (clock-in/out prompted at login/logout); owner/manager **reporting** home (daily/weekly/monthly + payment mix + top items + attendance); the **D-Customer Portal** (now incl. add-item + SKU edit + responsive layout); **online-delivery order** ingestion; TTS; settings; and **DIKASIR** branding (Quicksand wordmark). **Integrity suite: 8 files / 35 tests pass against RDS** (settle · cancel · refund · revise · void · atomicity · idempotency · amounts). All **9 migrations applied to RDS** (`prisma migrate deploy` → none pending). End-to-end verified on the live API: open bill → cancel (reserved stock restored) → new sale → settle → refund (net stock conserved). Constitution is at **v1.6.0**; the feature spec for this work is **`specs/005-corrections-attendance/spec.md`**. Android release builds are now **release-signed** (see `app/android/RELEASE_SIGNING.md`). App version `0.1.0`, build **2070**; server `0.2.0`; portal `0.2.0`.

- **US1 (Take an order & accept payment) — DONE and verified.**
  - Backend: checkout (atomic, idempotent on `UNIQUE(merchant_id, client_order_id)`, server-authoritative amounts), payments (`PaymentProvider` + Cash + SimulatedQRIS), inventory movement + stock. Integrity tests **T018–T020 pass** against RDS (`cd server && npm test`).
  - App: PIN login, category chips + product grid **with photos**, cart, checkout (cash tender/change + simulated QRIS QR), receipt preview; bilingual ID/EN; light/dark DIKA-Bold theme.
- **US3 (Review transactions & void a sale) — backend DONE + verified; app UI built, on-device walk still outstanding.**
  - Backend: `POST /orders/{id}/void` (OWNER-gated) appends an immutable `OrderVoid`, positive `VOID_RESTORE` movements, a `Payment(direction=REVERSAL)` per captured charge, and an `AuditLog` — one transaction, nothing rewritten. `GET /orders?outletId=…` gives outlet-scoped history. Integrity test **T035 passes**.
  - App: `app/lib/features/transactions/` — history list + detail + owner-gated void with reason dialog. **Still unverified on a device:** the POS screen and login were exercised on the emulator and on the release build, but nobody has walked history → detail → void end to end.
- **Demo catalog — 20 items** (7 Minuman / 8 Makanan / 5 Snack) with photos served from S3. See `server/prisma/menu-data.ts`.
- **Deployed** — API live at **https://dikapos.ptdika.com** (see below). The app's release build points at it.
- **Spec Kit artifacts** complete: constitution **v1.0.2**, `spec.md`, `plan.md`, `research.md`, `data-model.md`, `contracts/openapi.yaml`, `quickstart.md`, `tasks.md`, plus design handoff in `specs/001-pos-mvp/design/`.

## Next steps

**Next, on the PC (from 2026-09-21 evening):**
1. ~~Build from `main` and put it on the phone.~~ **Done on the Mac: 0.5.1 / 2113, debug-signed.**
   To go back to release signing, uninstall on the phone first, then install a PC build ≥ 2114.
   Re-run the nota that failed (Mie Goreng ×1, Es Campur ×2) to confirm Selesai is now blocked
   with *"Perbaiki 2 baris bertanda dulu."*
2. Run voice on the device end to end: catalogue mode with real stock, then spoken-price mode on
   the calculator account. Everything since build 2107 was fixed from logs, not from a clean run.
3. If the restart seam loses words in front of a real merchant, build **push-to-talk** — hold to
   speak, release to commit. It removes the seam, the `pauseFor` guillotine and the give-up loop
   in one move, and the sheet is already the right place for it.
4. Fill the five placeholders in the pitch decks before showing either: pilot status, commercial
   model, next commercial milestone, the investment ask, contact details.
5. **Nota → order on an F&B till, on a device:** read a real slip as Warung Kopi Demo, check how many
   lines the voice matcher misses on real shorthand, then Selesai through the open bill. If shorthand
   misses dominate, the fix is aliases on the matcher, which helps voice too.

**Older board scope (US1 + US3 + US6 + US7):**
1. **US3 on-device pass**: as owner, walk history → detail → void; confirm the sale shows as *Dibatalkan*, the reversal row appears, and stock comes back.
2. **US6** — multi-outlet switcher + reports (daily total, payment split, top items). T046–T048.
3. **US7** — Vue 3 web admin (products/variants, outlets, staff, dashboard). T049–T050.
4. Backend leftovers: T012 (audit writer/tx helper module), then US2/US4/US5/US8/US9 per tasks.md.
5. Housekeeping: add `@nestjs/cli` to `server/devDependencies` (see gotchas); replace the CC BY-SA placeholder menu photos with owned/licensed images before any customer-facing use.

## Production deployment (live)
| Piece | Value |
|---|---|
| Host | EC2 `i-099712ab949933cb5`, t3.small, AL2023, `ap-southeast-3c` |
| Public address | **Elastic IP `16.78.176.250`** (stable across stop/start) |
| Domain | `dikapos.ptdika.com` → A record to the EIP |
| TLS | Let's Encrypt via certbot + nginx; renew timer enabled, nginx reload hook installed |
| API | `dpos.service` (systemd, `enabled`), node on `127.0.0.1:3000`, nginx proxies 443 → 3000 |
| Code | `/opt/dpos` (git clone of this repo) — tracks branch **`main`** (trunk-based since 2026-09-05; was `beta-1`) |
| Security group | `sg-02adab4f9e3431899` — 22, 80, 443 open; **3000 deliberately closed** |
| RDS access | RDS security group allows **the EC2 security group** (not an IP) on 5432; resolves privately to `172.31.29.105` |
| S3 | `amzn-s3-dkpos-bucket`, `menu/` prefix public-read, `ap-southeast-3` |
| IAM | instance role `EC2-Role-DKPOS-S3` — **no access keys anywhere**, do not add any |

**SSH:** `ssh -i <key> ec2-user@16.78.176.250` (key must be `chmod 600`). The key lives at
**`C:\aws\DPOS.pem`** on the PC (`/c/aws/DPOS.pem` from Git Bash) and `~/Documents/aws/DPOS.pem` on
the Mac.

**Redeploy after pushing:**
```
ssh -i ~/Documents/aws/DPOS.pem ec2-user@16.78.176.250
cd /opt/dpos && git fetch origin && git reset --hard origin/<branch>
cd server && npm ci && npx prisma generate && npx tsc -p tsconfig.json
sudo systemctl restart dpos && systemctl status dpos --no-pager
```
`npx tsc` rather than `npm run build` — see gotchas. Entry point is `dist/src/main.js`.

**Logs:** `sudo journalctl -u dpos -n 100 --no-pager` (add `-f` to follow).

**D-Customer Portal** — live at **https://dikapos.ptdika.com/customer-portal/**. Served by a **PM2** process `customer-portal` (`customer-portal/server.mjs`, an express static server on `127.0.0.1:5001`, SPA fallback, mounted at `/customer-portal`); **nginx** reverse-proxies it via a `location /customer-portal/` block in `/etc/nginx/conf.d/dpos.conf` (backup `dpos.conf.bak-portal`). The SPA is built with Vite `base:/customer-portal/`. Redeploy after a portal change:
```
# local: build, then ship the static dist (dist is gitignored)
cd customer-portal && npm run build
scp -i <key> -r dist ec2-user@16.78.176.250:/opt/dpos/customer-portal/
# server (first time only): npm install --omit=dev; sudo npm i -g pm2; pm2 start ecosystem.config.cjs; pm2 save
ssh … 'pm2 restart customer-portal'
```
Logs: `pm2 logs customer-portal`. **Pattern for future web apps:** new PM2 process on a new `127.0.0.1` port + a matching `location /<app>/` proxy block; nginx stays the only public-facing tier.

**Menu images:** `cd /opt/dpos/server && npx ts-node scripts/provision-menu-images.ts` uploads every photo to S3 using the instance role, then `npx ts-node prisma/seed-menu.ts` repoints `imageUrl` in the DB. Both are idempotent. `MENU_IMAGE_BASE_URL` moves the images elsewhere (e.g. CloudFront) without a code change or app release.

## How to run locally (either machine)
**Prereqs:** Node 20+, **Flutter 3.47+ / Dart 3.13+** (the app requires Dart ≥3.5), Android SDK **36** + build-tools 36 + NDK `28.2.13676358`, an emulator or device.

**Env (not in git — recreate per machine):**
- Copy `server/.env.example` → `server/.env`, fill `DATABASE_URL` (RDS) + `JWT_SECRET`.
- **Add the machine's public IP** to the RDS security group (inbound 5432) or it can't connect.

**Backend:**
```
cd server && npm install && npx prisma generate
npx prisma migrate deploy       # fresh DB only
npx ts-node prisma/seed.ts      # fresh DB: merchant + full 20-item menu
npx ts-node src/main.ts         # http://0.0.0.0:3000/api/v1
```
**Integrity tests without RDS** (any local Postgres 16; the suite makes its own merchant):
```
psql -c "CREATE ROLE dpos LOGIN PASSWORD 'dpos'" ; createdb -O dpos dpos
# server/.env → DATABASE_URL="postgresql://dpos:dpos@127.0.0.1:5432/dpos?schema=public"
cd server && npx prisma migrate deploy && npm test
```
**App:**
```
cd app && flutter pub get && flutter gen-l10n
dart run build_runner build          # drift codegen
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1   # emulator → host API
```
`API_BASE_URL` is **compile-time** (`String.fromEnvironment`) — it cannot be changed after a build.
- Emulator → local API: `http://10.0.2.2:3000/api/v1`
- Chrome/desktop → local API: `http://localhost:3000/api/v1`
- Real device / demo: `https://dikapos.ptdika.com/api/v1`

**Demo build for a real phone:**
```
cd app && flutter build apk --release --split-per-abi \
  --dart-define=API_BASE_URL=https://dikapos.ptdika.com/api/v1
# app-arm64-v8a-release.apk (~22 MB) covers modern phones; the universal APK is ~59 MB
```
Release APKs are now **release-signed** from `android/key.properties` (falls back to debug when that file is absent). Keystore location + fingerprints: `app/android/RELEASE_SIGNING.md`. The keystore/password live outside git — back them up.

**VS Code:** `.vscode/` is deliberately **git-ignored** — launch configs hold machine-specific emulator ids and SDK paths. Create your own `launch.json` per machine; don't commit it.

## Seeded demo data
- Merchant `cad63409-136c-4d01-92d2-26e493dc64ce` ("Warung Kopi Demo 1")
- Outlet (has stock) `91298a41-b8ed-4b1a-a5c9-2e4aaad036b3` = "Outlet Pusat"; second outlet "Outlet Cabang".
- F&B **Warung Kopi Demo**: Cashier PIN `1234` · Manager `8888` · Owner `9999` / `owner@warungdemo.id` / `owner123`.
- Grocery **Toko Sembako Demo** (`admin@sembako.id` / `admin123`): Owner PIN `4321` · Manager `7777` · Cashier `2222`. These plaintext demo PINs are prefilled on the app login "Login as" picker (`Staff.demoPin`, DEMO ONLY).
- **Both demo merchants are `businessSize = GENERAL`.** To demo UMI, provision one:
  `cd server && npx ts-node prisma/set-business-size.ts "Warung Kopi Demo 1" UMI` (no args lists every
  merchant and its size; revert with `… GENERAL`). There is no admin UI for this yet — a DPOS
  super-admin surface is the planned home for it.
- 20 products across Minuman / Makanan / Snack, PBJT tax 10% + 5% service. A 2× Kopi Susu sale = **Rp 41.400**.
- `prisma/seed.ts` only seeds a *fresh* merchant; use `prisma/seed-menu.ts` against an existing one (e.g. RDS, which has orders).

### Payments / build traps (2026-09-10)

1. **`versionCode` is 1 in the repo but installed APKs were 2070/4001.** `pubspec.yaml` says
   `0.1.0+1`, so a plain `flutter build apk` produces versionCode 1 and `adb install` fails with
   `INSTALL_FAILED_VERSION_DOWNGRADE` against anything installed earlier — `-d` does not override it
   on Android 16. Build with `--build-number <n>` above whatever is on the device (2073 was used
   here), or uninstall first and lose the app's local cache.
2. **flutter_svg ignores CSS inside an SVG.** `mastercard.svg` styled its shapes with a
   `<style>` block and `class="stN"`, with no inline `fill` — flutter_svg does not apply CSS class
   rules, so the mark rendered as a **black blob**. `app/tool/inline-svg-css.js` rewrites those rules
   as presentation attributes; run it on any new brand mark that renders black. The other eight
   assets use inline fills and were fine.
3. **The API 36 emulator runs this app fine on the desktop.** The Mac's "Pixel 9a / API 36 ANRs"
   note did not reproduce here — a Medium Phone API 36.1 image ran the release build without an ANR
   through a full card sale. Keep the API 34 advice for the Mac, not as a global rule.

## Gotchas already solved (don't re-debug these)
- **Bluetooth thermal printers (RPP02N) reject the plugin's secure socket.** `print_bluetooth_thermal`'s `connect()` uses a *secure* RFCOMM socket and swallows the failure, so it "just fails" silently on cheap printers. The fix (in `MainActivity.kt`, MethodChannel `dpos/printer`) connects over an **insecure** RFCOMM socket first (then secure, then reflection channel-1) and writes the ESC/POS bytes. Also: the plugin reports the device's **factory name** (`RPP02N`), not the alias you rename it to (`DPOSP`), so match leniently / let the user pick the printer from the paired list. The scan **beep** uses the native `ToneGenerator` — the audio-asset (`audioplayers`) path queued/lagged (silent scans, then a stray beep seconds later).
- **Release builds had no network.** Flutter declares `android.permission.INTERNET` only in the `debug/` and `profile/` manifests. Without it in `main/`, every release build fails every request instantly and shows "Gagal masuk (cek koneksi)" — which looks exactly like a server or TLS fault and isn't. Fixed in `main/AndroidManifest.xml`; don't remove it.
- **`@nestjs/cli` is not a dependency.** `npm run build` / `npm run start` call `nest` and fail on any clean machine (EC2, CI, a fresh laptop). Build with `npx tsc -p tsconfig.json`; output lands in `dist/src/` because tsconfig sets no `rootDir`. Adding the CLI to devDependencies is the real fix.
- **certbot's renewal timer was installed but disabled** on AL2023, despite certbot printing that it had scheduled renewal. Enabled now (`certbot-renew.timer`), plus a deploy hook to reload nginx — without it a renewal succeeds and nginx keeps serving the expired cert.
- **There are two splash screens, and the first one is the OS's.** Android 12+ owns the launch splash: one background *colour* (`windowSplashScreenBackground` takes no drawable or gradient), plus an icon that is always circular-masked at a fixed size. Pre-12 `windowBackground` accepted any drawable; that freedom is gone at targetSdk 31+. So the brand diagonal is drawn by the app (`app/lib/features/splash/splash_screen.dart`, a `CustomPainter` at a true 45°) and cannot appear before Flutter's first frame. The system splash is set to the same navy so the handover reads as one screen.
- **The splash icon's padding must be baked into the PNG.** Drawable-level sizing and insets (layer-list `android:width`, `android:left`, `<inset>`) are ignored — the system scales whatever drawable it gets up to the icon area, so the corners clip again. `splash_icon.png` is the mark at 46% of a 1024px canvas padded with the splash colour, under the 47% (192/√2/288) where corners would touch the mask.
- **Wikimedia rate-limits hotlinking** (~20 parallel requests → HTTP 429), which is why menu photos live on S3. Also only certain thumbnail widths are valid (250, 500); others return 400.
- **Android cleartext:** `android:usesCleartextTraffic="true"` is in the manifest for local HTTP dev. Unnecessary for the HTTPS demo path; remove once local dev moves off plain HTTP.
- **Impeller** disabled in the manifest (`EnableImpeller=false`). Predates the Flutter 3.47 upgrade; worth re-testing whether it's still needed.
- **POS "broken/blank" bug (fixed):** the bottom cart bar's inner `Column` used default `mainAxisSize.max` inside `bottomNavigationBar`'s loose constraint and filled the screen. Fix = `mainAxisSize: MainAxisSize.min` in `order_screen.dart`.
- **Debug APKs are very slow to start** on the emulator (~29 s to first frame), which trips ANR dialogs if you tap too early. Use release builds for manual testing.
- **Emulator "not enough space":** `adb shell pm uninstall-system-updates` reclaimed ~4 GB.
- **Screenshots:** PowerShell `>` corrupts binary; use `adb shell screencap -p /sdcard/x.png` then `adb pull`.

## Branch map (keep this current)

`main` is the trunk. Everything else is a work stream — check the date before believing any claim
about "the code"; the SessionStart hook prints this table live at the start of every session.

| Branch | What it is | Status |
|---|---|---|
| `main` | **trunk — the only branch** (trunk-based dev; commit here, deploy here) | current, 2026-09-21 |
| `feat/nota-reader` | Nota photo reading — its work shipped via `main` on 2026-09-19 | behind `main`, safe to delete, 2026-09-16 |
| `features/UMI` | UMI (Ultra Mikro) business size — 7 commits off `main` @ `1fc071f` | behind `main` (shipped), 2026-09-08 |
| `feat/payment-methods` | Card (EDC) + e-wallet tenders — cut from `features/UMI` | behind `main` (shipped), 2026-09-10 |

> Nothing is ahead of the trunk. `feat/stt` ran two days and 18 commits — longer than this
> project's rule likes — and was merged and deleted on 2026-09-21 rather than left to drift.

**Workflow:** trunk-based on `main` — `main` is always deployable and is what EC2 ships. Cut a
**short-lived** feature branch only for risky/parallel work, then merge back and delete it. Keep
`main` green (the integrity suite, `cd server && npm test`, is the gate). Tag releases (`vX.Y.Z`)
rather than keeping long-lived release branches.

_Deleted (fully merged into `main`; commits live on in `main` history + reflog — recreate with `git branch <name> <sha>`):_
- _2026-09-21: `feat/stt` (was `b1d95e8`) — speech to text, `specs/010`_
- _2026-09-05: `beta-1` (was `0d0f2e9`), `claude/correction-path-tests` (was `71f2a5d`), `claude/us3-void-implementation-3zl5oh` (was `8551d36`)_
- _2026-09-04: `beta-with-SDP-printer` (was `7517303`), `customer-portal` (was `8514286`)_

**Why this table matters:** a cloud session reported "open bills can't be cancelled" after reading
the US3 branch (28 Aug) while the feature had shipped on `beta-1` (3 Sep). Any finding about the
code must name the branch and date it came from — that rule now lives in `CLAUDE.md`, which every
session loads automatically.

## Session sync protocol (all surfaces)

Git is the only channel between sessions — no session can see another's conversation, cloud or
local. These five rules are what keep desktop, Mac, VS Code and cloud from contradicting each other.

1. **One trunk.** `main` is the truth. Commit there for ordinary work; short-lived branches only for
   risky or parallel work, merged back and deleted the same day or two (see Branch map above).
2. **Start of session:** read the branch map the SessionStart hook prints. If it shows a branch
   ahead of `main`, that branch is the current truth — not `main`.
3. **End of session, every time:** update *Current status* + *Next steps* above, commit, push. An
   unpushed commit does not exist to any other machine.
4. **Switching machines:** push before you leave, `git pull` when you arrive. Never leave work
   uncommitted overnight.
5. **Two sessions at once:** give each its own branch, tell each what the other is doing, and merge
   both to `main` the same day. Never push onto a branch another session is using.

**When an agent tells you something about the code, it must name the branch and commit date it
read** (the rule lives in `CLAUDE.md`, which every session loads automatically). If that contradicts
what you see in the running app, the app is right and the agent's ref is stale — tell it to
`git fetch --all` and re-check.

## Working across surfaces (cloud ⇄ local, PC ⇄ Mac)

**Key idea:** running the app needs the **code**, not the **conversation**. Keep them separate.

- **Cloud session (claude.ai/code) = the portable "brain."** Steer it from a **browser on any machine**. It writes code and pushes a branch to `github.com/eganmcc/DPOS`. Close the tab / switch machines freely — it persists server-side (left sidebar → Sessions).
- **Local runs (emulator, RDS, hands-on testing):** just `git pull` the branch on whichever machine and run it. No need to move the session.
- **Teleport** — only when you want to keep *talking to Claude while working locally*:
  ```bash
  claude --teleport <session-id>     # checks out the branch AND loads the cloud conversation into the local CLI/VS Code
  claude -p "message" --cloud <session-id>   # send a one-off follow-up to a cloud session from the CLI
  ```
  Get `<session-id>` from the cloud session URL (`claude.ai/code/session_…`). ⚠️ After teleport the conversation becomes **local/machine-bound**; to go portable again, push commits and continue via the browser/a new cloud session (git carries the code, not the local chat).
- **VS Code:** can resume a cloud session via **Claude Code panel → Session history → Web tab** (downloads the conversation as a new *local* session; branch not auto-checked-out — `git pull` first, or use teleport).

| I want to… | Do this |
|---|---|
| Keep the portable thread across machines | Cloud session in the **browser** |
| Just **run** it (emulator + RDS) | `git pull` the branch locally; leave the session in the cloud |
| **Code hands-on with Claude locally** | `claude --teleport <id>` (convo goes local) |
| Sync local edits back | `git commit && git push`; cloud session `git pull`s them |

**Cloud sandbox limits:** no Android/iOS emulator (visual app testing is local-only); it can't reach our AWS RDS (security-group/IP) — use the sandbox's local Postgres for backend tests there.

**Always true:** git is the only bridge between surfaces. Local sessions do **not** sync across machines. Secrets (`server/.env`) are never committed — recreate per machine. Update this DEVLOG at the end of each session so any surface catches up fast.
