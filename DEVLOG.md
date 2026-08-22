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
- **Spec Kit artifacts** complete: constitution **v1.0.2**, `spec.md`, `plan.md`, `research.md`, `data-model.md`, `contracts/openapi.yaml`, `quickstart.md`, `tasks.md`, plus design handoff in `specs/001-pos-mvp/design/`.
- Tasks done: T001–T029 (incl. T029a–h UI polish). See [`specs/001-pos-mvp/tasks.md`](specs/001-pos-mvp/tasks.md).

## Next steps (board scope = US1 + US3 + US6 + US7)
1. **US3 — Void** (next): transaction history + append-only `OrderVoid` (owner-gated, audited, stock-restoring, idempotent via `client_void_id`) + `REVERSAL` payment typing. Integrity test **T035**. Tasks T035–T039.
2. **US6** — multi-outlet switcher + reports (daily total, payment split, top items). T046–T048.
3. **US7** — Vue 3 web admin (products/variants, outlets, staff, dashboard). T049–T050.
4. Backend leftovers: T012 (audit writer/tx helper module), then US2/US4/US5/US8/US9 per tasks.md.

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
