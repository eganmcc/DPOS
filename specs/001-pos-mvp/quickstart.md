# Quickstart & Validation Guide: DPOS Mobile POS MVP

This guide proves the feature works end-to-end. It references [data-model.md](./data-model.md) and [contracts/openapi.yaml](./contracts/openapi.yaml) rather than restating them. Implementation code, migrations, and full test suites belong to `/speckit-tasks` and the implementation phase — not here.

## Prerequisites

- Docker (local PostgreSQL), Node 20 LTS + a package manager, Flutter SDK, an Android phone and an Android tablet (or emulators).
- Repo checked out at `d:\Repos\DPOS`.

## One-time setup

```powershell
# 1. Start local Postgres (authoritative store, dev)
docker compose up -d db

# 2. Backend: install, migrate, seed a demo warung/café dataset
cd server
npm install
npx prisma migrate dev
npm run seed          # seeds a merchant, 2 outlets, staff (owner+cashier), catalog, tax rule (PBJT), stock
npm run start:dev     # API on http://localhost:3000

# 3. Web admin
cd ../web-admin
npm install
npm run dev           # admin on http://localhost:5173

# 4. Mobile app (point at your machine's LAN IP for device testing)
cd ../app
flutter pub get
flutter run           # select the phone, repeat for the tablet
```

## Validation scenarios

Each maps to Success Criteria (SC-xxx) and Functional Requirements (FR-xxx) in [spec.md](./spec.md).

### V1 — Cash sale, end to end (SC-001, SC-002; FR-005/006/009/011/013)
1. Sign in as the cashier (PIN) on the phone.
2. Add two items; on one, pick a variant and a modifier; apply a 10% order discount; choose Takeaway.
3. Confirm subtotal/discount/tax(PBJT)/service/total match the outlet's configured rules.
4. Tender cash above the total → correct change shown; sale completes; receipt preview renders.
5. **Expected**: total equals the server-computed `grandTotal` (compare against `GET /orders/{id}`); a typical sale finishes in under 30s. Repeat on the tablet and confirm the two-pane layout.

### V2 — Simulated QRIS (FR-010; payment lifecycle)
1. Build an order → choose QRIS → a QR for the exact amount renders.
2. Confirm "mark as paid" → payment moves `CREATED/PENDING → PAID`; receipt shows QRIS.
3. **Expected**: order `COMPLETED`, one `Payment` with `method=QRIS_SIMULATED`, `status=PAID`.

### V3 — Server owns the math (SC-002; FR-011)
1. Using the API directly, `POST /orders` with deliberately wrong client-side totals in the body.
2. **Expected**: the stored order's `grandTotal` reflects the server recomputation, not the client's numbers.

### V4 — Offline + idempotent sync (SC-003; FR-020/021/022)
1. Put the phone in airplane mode; confirm catalog still loads and a **cash** sale completes (QRIS shows "unavailable offline").
2. Restore connectivity → the queued sale appears exactly once in `GET /orders` and in the web admin.
3. Force a duplicate submit of the same `clientOrderId` (replay the request).
4. **Expected**: exactly one order and one set of stock movements exist; the replay returns the existing order (HTTP 200).

### V5 — Immutability + audit on void (SC-004, SC-005; FR-016/017/018/026)
1. As the **cashier**, attempt to void a completed sale → **denied** (403).
2. As the **owner**, void it → order becomes `VOIDED` with lines/totals intact.
3. **Expected**: a positive `VOID_RESTORE` movement appears (`GET /inventory/movements`), stock is restored (`GET /inventory/stock`), and an `AuditLog` entry records the owner as actor.

### V6 — Inventory ledger (FR-019)
1. Sell qty 2 of a tracked variant → `GET /inventory/movements` shows `-2`; balance drops by 2.
2. Void that sale → a `+2` movement; balance restored.
3. **Expected**: the balance is always the sum of the ledger; no in-place counter overwrite.

### V7 — Atomicity under failure (SC-006; FR-012)
1. Simulate a mid-checkout failure (e.g. kill the API between payment insert and stock update, or use a test hook that throws inside the transaction).
2. **Expected**: no partial record — either the whole sale (order + payment + movement) exists or none of it does.

### V8 — Tenant isolation (SC-008; FR-025)
1. Authenticate as merchant A; request merchant B's outlet/order IDs.
2. **Expected**: 403/404 within scope — no cross-merchant read or write is possible.

### V9 — Multi-outlet + reports + admin (SC-007; FR-027/028/029)
1. Switch outlets on the app; confirm catalog/transactions reflect only the selected outlet.
2. In the web admin, edit a product price → confirm the app shows the new price on the next order.
3. Open `GET /reports/daily` (and the admin dashboard) → daily total, payment split, and top items match the sales rung up.

### V10 — Board demo path (SC-009)
Run V1 → V2 → view transaction → V5 (owner void) on both phone and tablet, using only the on-screen receipt preview (no physical printer required). This is the script for the board.

## Notes

- Bluetooth thermal printing (Tier 2) is validated separately once added; it is never on the critical demo path.
- Promotion to AWS RDS (Jakarta) is a configuration change (`DATABASE_URL`); the same Prisma migrations apply.
