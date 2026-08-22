# DPOS — Dev Log & Session Handoff

> **Purpose:** a living handoff so work with Claude Code can continue across machines/sessions.
> Update the **Current status** and **Next steps** at the end of each working session, then commit.
> Full design/decisions live in [`specs/001-pos-mvp/`](specs/001-pos-mvp/) (Spec Kit artifacts).

_Last updated: 2026-08-22._

## What this project is
Indonesian mobile POS (F&B-first) built with **Spec-Driven Development (GitHub Spec Kit)**.
- **`server/`** — NestJS + Prisma REST API (the *only* client of PostgreSQL). Authoritative for all money math, atomic checkout, idempotent submit, inventory ledger, audit, tenant scoping.
- **`app/`** — Flutter phone+tablet app (offline-first, drift cache + sync queue). Brand UI = "DIKA Bold" (navy `#133A68` + gold `#D6AD07`, light/dark, ID/EN).
- **`web-admin/`** — Vue 3 + Vite (not started yet; US7).
- **DB** — AWS RDS for PostgreSQL, Jakarta (`ap-southeast-3`).

## Current status
- **US1 (Take an order & accept payment) — DONE and verified.**
  - Backend: checkout (atomic, idempotent on `UNIQUE(merchant_id, client_order_id)`, server-authoritative amounts), payments (`PaymentProvider` + Cash + SimulatedQRIS), inventory movement + stock. Integrity tests **T018–T020 pass** against RDS (`cd server && npm test`).
  - App: PIN login (4-cell), category chips + product-card grid, cart, checkout (cash tender/change + simulated QRIS QR), receipt preview; bilingual ID/EN; light/dark DIKA-Bold theme.
- **US3 (Review transactions & void a sale) — backend DONE + verified; app UI built, needs an on-device pass.**
  - Backend: `POST /orders/{id}/void` (OWNER-gated, 200 per contract) appends an immutable `OrderVoid`, positive `VOID_RESTORE` movements (inverted straight from the sale's ledger rows), a `Payment(direction=REVERSAL, reversal_type=VOID)` per captured charge, and an `AuditLog` — all in one transaction. The order, its lines and the original `PAID` charge are never rewritten; `effectiveStatus` derives to `VOIDED`. Idempotent via `UNIQUE(order_id)` + `UNIQUE(merchant_id, client_void_id)`. `GET /orders?outletId=…` gives outlet-scoped history (newest first, optional `from`/`to`/`limit`).
  - `PaymentProvider` now also types reversals (`reverse()` on cash + simulated QRIS) so a real PSP drops in unchanged.
  - Integrity test **T035 passes** (`server/test/orders.void.e2e-spec.ts`): immutability, stock restore, audit, cashier 403, strict idempotency (one `OrderVoid`, one `REVERSAL`, one set of `VOID_RESTORE`), concurrent voids, cross-merchant 404.
  - App: `app/lib/features/transactions/` — history list (net sales header, per-sale status pill) + detail (lines, totals, charge *and* reversal rows, void record) + owner-gated void with a reason dialog and a per-attempt `clientVoidId`. Cashiers see why the action is unavailable. New ID/EN strings; the POS "History" button now opens it.
- **Spec Kit artifacts** complete: constitution **v1.0.2**, `spec.md`, `plan.md`, `research.md`, `data-model.md`, `contracts/openapi.yaml`, `quickstart.md`, `tasks.md`, plus design handoff in `specs/001-pos-mvp/design/`.
- Tasks done: T001–T029 (incl. T029a–h UI polish), **T035–T039**. See [`specs/001-pos-mvp/tasks.md`](specs/001-pos-mvp/tasks.md).

## Next steps (board scope = US1 + US3 + US6 + US7)
1. **US3 on-device pass**: run the app against the API and walk history → detail → void as owner (button hidden for cashier); confirm the sale shows as *Dibatalkan*, the reversal row appears, and stock comes back. The UI was written in a cloud sandbox with no emulator, so this is the one unverified piece.
2. **US6** — multi-outlet switcher + reports (daily total, payment split, top items). T046–T048.
3. **US7** — Vue 3 web admin (products/variants, outlets, staff, dashboard). T049–T050.
4. Backend leftovers: T012 (audit writer/tx helper module — the void service currently writes its `AuditLog` inline), then US2/US4/US5/US8/US9 per tasks.md.

## How to run (either machine)
**Prereqs:** Node 20+, Flutter 3.4+, an Android emulator (or device). `uv` optional.

**Env (not in git — recreate per machine):**
- Copy `server/.env.example` → `server/.env`, fill `DATABASE_URL` (RDS, you hold the password) + `JWT_SECRET`.
- **Add the current machine's public IP** to the RDS security group (inbound TCP 5432) or it can't connect.

**Backend:**
```
cd server
npm install
npx prisma generate
npx prisma migrate deploy   # first time on a fresh DB; use `migrate dev` when changing schema
npx ts-node prisma/seed.ts  # seeds demo data (idempotent-ish; skips if 'Warung Kopi Demo' exists)
npx ts-node src/main.ts     # API on http://0.0.0.0:3000/api/v1  (CORS enabled)
```
**Running the integrity tests without RDS** (cloud sandbox, or a machine whose IP isn't allow-listed):
any Postgres 16 will do — the suite creates and deletes its own isolated merchant per run.
```
pg_ctlcluster 16 main start                      # or: docker compose up -d db
psql -c "CREATE ROLE dpos LOGIN PASSWORD 'dpos'" ; createdb -O dpos dpos
# server/.env → DATABASE_URL="postgresql://dpos:dpos@127.0.0.1:5432/dpos?schema=public"
cd server && npx prisma migrate deploy && npm test   # T018–T020 + T035
```

**App:**
```
cd app
flutter pub get
flutter gen-l10n
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1   # Android emulator → host
# desktop/web: use http://localhost:3000/api/v1
```
**VS Code:** `.vscode/launch.json` has a compound **"DPOS: Server + App (emulator)"** that runs both.

## Seeded demo data
- Merchant `cad63409-136c-4d01-92d2-26e493dc64ce`
- Outlet (has stock) `91298a41-b8ed-4b1a-a5c9-2e4aaad036b3` = "Outlet Pusat"; second outlet "Outlet Cabang".
- Cashier **PIN `1234`** · Owner PIN `9999` / `owner@warungdemo.id` / `owner123`.
- Catalog: Kopi Susu (Regular/Large + sugar modifiers), Nasi Goreng. PBJT tax 10% + 5% service. A 2× Kopi Susu sale = **Rp 41.400**.

## Gotchas already solved (don't re-debug these)
- **Android cleartext:** `android:usesCleartextTraffic="true"` added to `app/android/app/src/main/AndroidManifest.xml` (dev only; prod = HTTPS). Without it, HTTP calls silently fail → "cek koneksi".
- **Impeller:** disabled in the manifest (`EnableImpeller=false`, forces Skia) — Impeller had emulator glitches during triage; the real POS bug was layout, not the renderer. (Deprecation warning is harmless.)
- **POS "broken/blank" bug (fixed):** the bottom cart bar's inner `Column` used default `mainAxisSize.max` and, inside `bottomNavigationBar`'s loose height constraint, expanded to fill the whole screen. Fix = `mainAxisSize: MainAxisSize.min` on that Column/Row in `order_screen.dart`.
- **Emulator "not enough space":** `adb shell pm uninstall-system-updates` reclaimed ~4 GB.
- **Screenshots:** PowerShell `>` corrupts binary; use `adb shell screencap -p /sdcard/x.png` then `adb pull`.

## Cross-machine workflow (PC ⇄ Mac)
- **Code:** git. Commit + push often; `git pull` on the other machine. Remote = `github.com/eganmcc/DPOS` (`main`).
- **Session with Claude:** local Claude Code sessions do **not** sync across machines. For a portable, back-and-forth session use **claude.ai/code (web)** (cloud-hosted, account-portable). Keep this DEVLOG updated so any session/machine catches up fast.
- **Secrets** (`server/.env`) never get committed — recreate them per machine.
