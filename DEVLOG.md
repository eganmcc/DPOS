# DPOS — Dev Log & Session Handoff

> **Purpose:** a living handoff so work with Claude Code can continue across machines/sessions.
> Update the **Current status** and **Next steps** at the end of each working session, then commit.
> Full design/decisions live in [`specs/001-pos-mvp/`](specs/001-pos-mvp/) (Spec Kit artifacts).

_Last updated: 2026-08-24._

## What this project is
Indonesian mobile POS (F&B-first) built with **Spec-Driven Development (GitHub Spec Kit)**.
- **`server/`** — NestJS + Prisma REST API (the *only* client of PostgreSQL). Authoritative for all money math, atomic checkout, idempotent submit, inventory ledger, audit, tenant scoping.
- **`app/`** — Flutter phone+tablet app (offline-first, drift cache + sync queue). Brand UI = "DIKA Bold" (navy `#133A68` + gold `#D6AD07`, light/dark, ID/EN).
- **`customer-portal/`** — **D-Customer Portal**, Vue 3 + Vite + TS admin SPA (dashboard, staff/PIN, inventory, prices, entity/branch settings; business-type aware). Runs locally against the live API (`npm run dev`, :5173).
- **DB** — AWS RDS for PostgreSQL, Jakarta (`ap-southeast-3`).

## Current status
- **US1 (Take an order & accept payment) — DONE and verified.**
  - Backend: checkout (atomic, idempotent on `UNIQUE(merchant_id, client_order_id)`, server-authoritative amounts), payments (`PaymentProvider` + Cash + SimulatedQRIS), inventory movement + stock. Integrity tests **T018–T020 pass** against RDS (`cd server && npm test`).
  - App: PIN login, category chips + product grid **with photos**, cart, checkout (cash tender/change + simulated QRIS QR), receipt preview; bilingual ID/EN; light/dark DIKA-Bold theme.
- **US3 (Review transactions & void a sale) — backend DONE + verified; app UI built, on-device walk still outstanding.**
  - Backend: `POST /orders/{id}/void` (OWNER-gated) appends an immutable `OrderVoid`, positive `VOID_RESTORE` movements, a `Payment(direction=REVERSAL)` per captured charge, and an `AuditLog` — one transaction, nothing rewritten. `GET /orders?outletId=…` gives outlet-scoped history. Integrity test **T035 passes**.
  - App: `app/lib/features/transactions/` — history list + detail + owner-gated void with reason dialog. **Still unverified on a device:** the POS screen and login were exercised on the emulator and on the release build, but nobody has walked history → detail → void end to end.
- **Demo catalog — 20 items** (7 Minuman / 8 Makanan / 5 Snack) with photos served from S3. See `server/prisma/menu-data.ts`.
- **Deployed** — API live at **https://dikapos.ptdika.com** (see below). The app's release build points at it.
- **Spec Kit artifacts** complete: constitution **v1.0.2**, `spec.md`, `plan.md`, `research.md`, `data-model.md`, `contracts/openapi.yaml`, `quickstart.md`, `tasks.md`, plus design handoff in `specs/001-pos-mvp/design/`.

## Next steps (board scope = US1 + US3 + US6 + US7)
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
| Code | `/opt/dpos` (git clone of this repo) — currently tracks branch **`beta-1`** |
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
Release APKs are **debug-signed** (fine for sideloading, not for Play Store).

**VS Code:** `.vscode/` is deliberately **git-ignored** — launch configs hold machine-specific emulator ids and SDK paths. Create your own `launch.json` per machine; don't commit it.

## Seeded demo data
- Merchant `cad63409-136c-4d01-92d2-26e493dc64ce` ("Warung Kopi Demo 1")
- Outlet (has stock) `91298a41-b8ed-4b1a-a5c9-2e4aaad036b3` = "Outlet Pusat"; second outlet "Outlet Cabang".
- Cashier **PIN `1234`** · Owner PIN `9999` / `owner@warungdemo.id` / `owner123`.
- 20 products across Minuman / Makanan / Snack, PBJT tax 10% + 5% service. A 2× Kopi Susu sale = **Rp 41.400**.
- `prisma/seed.ts` only seeds a *fresh* merchant; use `prisma/seed-menu.ts` against an existing one (e.g. RDS, which has orders).

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
