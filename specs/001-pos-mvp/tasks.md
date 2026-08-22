---
description: "Task list for DPOS Mobile POS MVP"
---

# Tasks: DPOS Mobile POS MVP

**Input**: Design documents from `/specs/001-pos-mvp/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/openapi.yaml](./contracts/openapi.yaml), [quickstart.md](./quickstart.md), constitution v1.0.2

**Tests**: Targeted **integration tests are included for the critical financial-integrity guarantees only** (idempotency, server-authoritative amounts, atomicity, immutable/append-only void, tenant isolation). This is a deliberate, proportionate choice driven by the constitution's "verification is behavioral" mandate and the quickstart V1–V10 scenarios — not full TDD across every task.

**Organization**: Tasks are grouped by user story (US1–US9 from spec.md) so each story is independently implementable, testable, and demoable.

## Format: `[ID] [P?] [Story] Description with file path`

- **[P]**: Can run in parallel (different files, no dependency on an incomplete task)
- **[Story]**: US1–US9; Setup/Foundational/Polish carry no story label

## Path conventions (from plan.md)

- Backend API: `server/` (NestJS + Prisma) — the only client of PostgreSQL
- Mobile app: `app/lib/` (Flutter)
- Web admin: `web-admin/src/` (Vue 3 + Vite)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Repository and toolchain initialization.

- [X] T001 Create the multi-component repo structure (`server/`, `app/`, `web-admin/`, `docker-compose.yml`) per [plan.md](./plan.md) Project Structure
- [X] T002 Initialize the NestJS + Prisma backend in `server/` (TypeScript, Node 20) with base `package.json`, `tsconfig.json`, `nest-cli.json`
- [X] T003 [P] Initialize the Flutter app in `app/` with Riverpod, `intl`, `qr_flutter`, `drift` dependencies in `app/pubspec.yaml`
- [ ] T004 [P] Initialize the Vue 3 + Vite + TS admin in `web-admin/` with Pinia and Vue Router
- [ ] T005 [P] Configure linting/formatting for all three components (ESLint/Prettier in `server/` and `web-admin/`, `analysis_options.yaml` in `app/`)
- [ ] T006 Add local PostgreSQL to `docker-compose.yml` and `.env`/`.env.example` with `DATABASE_URL` (dev → Jakarta RDS later)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure every user story depends on.

**⚠️ CRITICAL**: No user-story work begins until this phase is complete.

- [X] T007 Author the full Prisma schema in `server/prisma/schema.prisma` for all entities in [data-model.md](./data-model.md): Merchant, Outlet, Staff, Device, Category, Product, ProductVariant (incl. `track_inventory`), ModifierGroup, Modifier, TaxRule, ProductOutlet, Order, OrderLine, OrderDiscount, OrderVoid, Payment, InventoryMovement, InventoryStock, Shift, CashMovement, AuditLog — with `merchant_id` on major transactional records, `NUMERIC(12,3)` quantities, and constraints `UNIQUE(merchant_id, client_order_id)`, `UNIQUE(order_id)` on OrderVoid, `UNIQUE(merchant_id, client_void_id)`, `UNIQUE(outlet_id, variant_id)`, `UNIQUE(outlet_id, product_id)`
- [X] T008 Generate and apply the initial migration in `server/prisma/migrations/` (`prisma migrate dev`)
- [X] T009 Implement the tenant-scoping guard/interceptor in `server/src/common/tenant.guard.ts` (derives `merchantId`/`outletId` from JWT; blocks cross-merchant access from migration one)
- [X] T010 [P] Implement the auth framework in `server/src/auth/` (JWT issue/verify, bcrypt/argon2 hashing, `RolesGuard` for OWNER/CASHIER)
- [X] T011 [P] Implement the server-authoritative money engine in `server/src/common/money.ts` (subtotal → OrderDiscount amounts → tax by `rate_bps` → service by `service_charge_bps` → grand total; integer rupiah)
- [ ] T012 [P] Implement the single-transaction helper and audit writer in `server/src/common/tx.ts` and `server/src/audit/audit.service.ts` (wrap business ops in one `prisma.$transaction`)
- [X] T013 Configure API routing, global validation pipe, and error handling in `server/src/main.ts` and `server/src/common/`
- [X] T014 Implement a **minimal, read-only** outlet-scoped catalog endpoint in `server/src/catalog/catalog.controller.ts` (`GET /catalog` only) that serves the **seeded** catalog so US1 can display products. **No catalog mutation here — all create/update remains in US2 (T030).**
- [X] T015 Write the seed script in `server/prisma/seed.ts` (1 merchant, 2 outlets, owner + cashier, categories/products/variants/modifiers, a PBJT `TaxRule`, initial stock)
- [X] T016 Build the Flutter foundation in `app/lib/`: `core/` (theme, Rupiah/Bahasa i18n via `intl`), `data/` (drift cache schema, API client, offline sync queue keyed by client-generated UUIDs), and a responsive phone/tablet scaffold in `app/lib/core/layout/`
- [ ] T017 [P] Build the Vue admin foundation in `web-admin/src/`: typed API client (`api/`), auth store (`stores/auth.ts`), and router shell (`router/`)

**Checkpoint**: Foundation ready — user stories can now proceed.

---

## Phase 3: User Story 1 - Take an order and accept payment (Priority: P1) 🎯 MVP

**Goal**: A cashier rings up an order (variants, modifiers, discounts, dine-in/takeaway), takes cash or simulated QRIS, and gets a receipt — recorded authoritatively and atomically.

**Independent Test**: With seeded catalog, complete a multi-item cash sale and a simulated-QRIS sale on phone and tablet; confirm correct server-computed totals, change, recorded transaction, and receipt preview.

### Tests for User Story 1 (critical-integrity)

- [X] T018 [P] [US1] Integration test: `POST /orders` is idempotent on `(merchantId, clientOrderId)` — duplicate submit yields one order + one stock movement — in `server/test/orders.idempotency.e2e-spec.ts` (SC-003)
- [X] T019 [P] [US1] Integration test: server recomputes totals and ignores client-sent totals in `server/test/orders.amounts.e2e-spec.ts` (SC-002)
- [X] T020 [P] [US1] Integration test: induced mid-checkout failure leaves no partial record (order/payment/movement all-or-nothing) in `server/test/orders.atomicity.e2e-spec.ts` (SC-006)

### Implementation for User Story 1

- [X] T021 [US1] Implement the checkout service in `server/src/orders/orders.service.ts`: recompute amounts (money engine), snapshot tax/service + line fields, insert Order + OrderLine + OrderDiscount inside one transaction (depends on T011, T012)
- [X] T022 [US1] Add idempotent submit in `server/src/orders/orders.service.ts` (insert-or-return-existing on `UNIQUE(merchant_id, client_order_id)`; return canonical `Order.id`)
- [X] T023a [US1] Implement the payment domain in `server/src/payments/`: the `PaymentProvider` abstraction and backend-owned payment lifecycle rules (`CREATED → PENDING → PAID`, alternates; reversal typing) — no concrete providers yet
- [X] T023b [US1] Implement the concrete providers in `server/src/payments/providers/`: `CashProvider` (tender/change) and `SimulatedQrisProvider` (QR payload + mark-paid), conforming to T023a
- [X] T024 [US1] Within the checkout transaction, write negative `InventoryMovement` + update `InventoryStock` for `track_inventory` variants in `server/src/inventory/inventory.service.ts`
- [X] T025 [US1] Expose `POST /orders` and `GET /orders/{id}` in `server/src/orders/orders.controller.ts`
- [X] T026 [P] [US1] Flutter order builder in `app/lib/features/order/` and `app/lib/features/catalog/`: browse catalog, add items with variants/modifiers/qty/notes, line + order discounts, dine-in/takeaway + table label
- [X] T027 [US1] Flutter checkout in `app/lib/features/payment/`: cash tender + change, simulated QRIS render + confirm; submit via the sync queue with a client UUID
- [X] T028 [US1] Flutter receipt preview in `app/lib/features/receipt/` (struk with header, lines, discounts, tax/service, total, method, order #) + share-as-image
- [X] T029 [US1] Wire offline cash-sale path in `app/lib/features/sync/` (queue while offline, idempotent submit + reconcile on reconnect)

**Checkpoint**: US1 is a fully functional, demoable MVP on phone and tablet.

---

## Phase 3.5: US1 UI Polish + i18n (brand redesign)

**Goal**: Brand the app to PT DIKA (navy `#133A68` + gold `#D6AD07` accent, white surfaces), add light+dark themes, full ID/EN localization, and redesign the US1 screens.

- [X] T029a Brand theme (light + dark) in `app/lib/core/theme.dart` — Material 3 `ColorScheme` seeded on navy, gold accent; navy AppBar, rounded cards; bundle the DIKA logo in `app/assets/images/` + `pubspec.yaml`
- [X] T029b `themeMode` provider (light/dark/system, persisted) + AppBar toggle in `app/lib/core/settings.dart`
- [X] T029c i18n scaffold: `l10n.yaml` + `app/lib/l10n/app_id.arb` + `app_en.arb`; enable `generate: true`; `localeProvider` (persisted, default ID) + ID/EN toggle; wire `MaterialApp` delegates/locale
- [X] T029d Extract all hardcoded strings to `AppLocalizations` keys across login/order/checkout/receipt
- [X] T029e Redesign Login — navy/logo header, PIN entry, Merchant/Outlet IDs behind an "advanced" expander, language toggle
- [X] T029f Redesign POS — category filter chips + responsive product-card grid (placeholder tiles), cart summary card, sticky navy Bayar bar, empty/loading states
- [X] T029g Redesign Checkout — payment-method cards, quick-tender chips + live change, brand-framed QR
- [X] T029h Redesign Receipt — branded struk card with status chip + share/print actions

**Checkpoint**: US1 looks like a real, branded, bilingual POS on phone and tablet.

---

## Phase 4: User Story 2 - Manage catalog & tax/fee settings (Priority: P2)

**Goal**: Owners define categories, products, variants, and modifiers, and configure per-outlet tax label/rate + service charge.

**Independent Test**: Create a product with two variants and a modifier group, set outlet PBJT tax + service charge, and confirm they apply when building an order.

### Implementation for User Story 2

- [ ] T030 [P] [US2] Catalog write endpoints in `server/src/catalog/` (create/update categories, products, variants, modifier groups; `POST /admin/products`)
- [ ] T031 [US2] Per-outlet `TaxRule` + service-charge config endpoints in `server/src/outlets/tax-rule.controller.ts`
- [ ] T032 [P] [US2] Vue admin catalog screens in `web-admin/src/views/products/` (products, variants, modifiers) with `applied_by`/threshold-aware discount policy hooks
- [ ] T033 [US2] Vue admin outlet tax/fee settings screen in `web-admin/src/views/outlets/TaxSettings.vue`
- [ ] T034 [US2] Flutter: honor availability toggle and per-outlet catalog in `app/lib/features/catalog/`

**Checkpoint**: US1 + US2 both work independently.

---

## Phase 5: User Story 3 - Transactions & full VOID (Priority: P2)

**Goal**: View transactions and full-void a sale — append-only, permission-gated, audited, stock-restoring, idempotent — without mutating the completed order.

**Independent Test**: Void a completed sale as owner (denied as cashier); confirm the order is preserved (`effectiveStatus=VOIDED`), a positive `VOID_RESTORE` movement exists, and an `AuditLog` entry records the actor.

### Tests for User Story 3 (critical-integrity)

- [ ] T035 [P] [US3] Integration test: void appends immutable `OrderVoid` (`UNIQUE(order_id)`), order unchanged, stock restored, `AuditLog` written, cashier denied — **and idempotency is strict: retrying the same `client_void_id` produces exactly one `OrderVoid`, exactly one applicable `REVERSAL` Payment (`reversal_type=VOID`), and exactly one set of `VOID_RESTORE` movements** — in `server/test/orders.void.e2e-spec.ts` (SC-004, SC-005)

### Implementation for User Story 3

- [ ] T036 [US3] Void service in `server/src/orders/void.service.ts`: append `OrderVoid` (never mutate order), positive `VOID_RESTORE` movements, `Payment(direction=REVERSAL, reversal_type=VOID)` where charged, `AuditLog` — one transaction; OWNER-gated; idempotent via `UNIQUE(order_id)`/`client_void_id`
- [ ] T037 [US3] Expose `POST /orders/{id}/void` and `GET /orders` (history, outlet-scoped) in `server/src/orders/orders.controller.ts`
- [ ] T038 [P] [US3] Flutter transaction history + detail in `app/lib/features/transactions/`
- [ ] T039 [US3] Flutter void action (owner-gated) + derived effective-status display in `app/lib/features/transactions/`

**Checkpoint**: US1–US3 independently functional.

---

## Phase 6: User Story 4 - Sell offline & sync safely (Priority: P2)

**Goal**: Keep selling offline (cash/catalog/order creation); QRIS clearly unavailable offline; queued sales sync exactly once.

**Independent Test**: Airplane-mode a cash sale, restore network, confirm one synced order; force a duplicate submit and confirm no double-post.

### Tests for User Story 4 (critical-integrity)

- [ ] T040 [P] [US4] Integration/app test: offline sale syncs exactly once and a forced duplicate submit creates no second order/stock movement — in `server/test/sync.idempotency.e2e-spec.ts` and `app/integration_test/offline_sync_test.dart` (SC-003)

### Implementation for User Story 4

- [ ] T041 [US4] Flutter offline hardening in `app/lib/features/sync/`: connectivity detection, QRIS-unavailable-offline UX, queue flush + reconciliation from server state
- [ ] T042 [US4] Server: confirm idempotent replay returns existing order and void idempotency via `client_void_id` in `server/src/orders/orders.service.ts`

**Checkpoint**: Offline-first path proven end to end.

---

## Phase 7: User Story 5 - Staff PIN & roles (Priority: P2)

**Goal**: Staff sign in by PIN; owner vs cashier roles gate sensitive actions; sales attributed to staff/device/shift.

**Independent Test**: Sign in as owner and cashier; confirm cashier is blocked from void and sales record who rang them up.

### Implementation for User Story 5

- [ ] T043 [P] [US5] PIN login endpoint + role gating in `server/src/auth/auth.controller.ts` (owner email/password; staff PIN)
- [ ] T044 [US5] Attribution of `cashier_id`/`device_id`/`shift_id` on orders in `server/src/orders/orders.service.ts`
- [ ] T045 [P] [US5] Flutter PIN login + role-aware UI (hide void/price edits for cashier) in `app/lib/features/auth/`

**Checkpoint**: US1–US5 independently functional.

---

## Phase 8: User Story 6 - Multi-outlet & reports (Priority: P3)

**Goal**: Switch outlets (scoped catalog/reports); view daily total, payment-method breakdown, top items.

**Independent Test**: With two outlets, switch and confirm scoping; after sales, confirm daily total/split/top items match.

### Implementation for User Story 6

- [ ] T046 [P] [US6] Reports service + `GET /reports/daily` in `server/src/reports/` (total, payment-method breakdown, top items)
- [ ] T047 [US6] Outlet switch scoping across app requests in `app/lib/features/outlets/`
- [ ] T048 [P] [US6] Flutter outlet switcher + reports screen in `app/lib/features/outlets/` and `app/lib/features/reports/`

**Checkpoint**: US1–US6 independently functional.

---

## Phase 9: User Story 7 - Web admin (Priority: P3)

**Goal**: Manage products/variants, outlets, and staff and view a sales dashboard from the web.

**Independent Test**: Edit a product price in admin → reflected in app; dashboard matches recent sales.

### Implementation for User Story 7

- [ ] T049 [P] [US7] Vue admin outlets + staff management screens in `web-admin/src/views/outlets/` and `web-admin/src/views/staff/`
- [ ] T050 [US7] Vue admin sales dashboard in `web-admin/src/views/dashboard/` (consumes `GET /reports/daily`)

**Checkpoint**: US1–US7 independently functional.

---

## Phase 10: User Story 8 - Hold open orders (F&B tables) (Priority: P3)

**Goal**: Park a dine-in order (table label) and settle later; multiple open orders at once.

**Independent Test**: Hold an order, start another, recall and settle the first.

### Implementation for User Story 8

- [ ] T051 [US8] Held-order persistence (`DRAFT`/`HELD`) + recall in `server/src/orders/orders.service.ts`
- [ ] T052 [P] [US8] Flutter hold/recall open-orders UI (table label) in `app/lib/features/order/hold/`

**Checkpoint**: US1–US8 independently functional.

---

## Phase 11: User Story 9 - Shift / cash drawer (Priority: P3)

**Goal**: Open/close shifts, record cash in/out, compare expected vs counted; attribute sales to a shift.

**Independent Test**: Open a shift, make cash sales + a cash-out, close and confirm expected vs counted.

### Implementation for User Story 9

- [ ] T053 [P] [US9] Shifts module in `server/src/shifts/` (open/close, `CashMovement`, expected-vs-counted)
- [ ] T054 [US9] Flutter shift open/close + cash in/out UI in `app/lib/features/shift/`

**Checkpoint**: All user stories independently functional.

---

## Phase 12: Polish & Cross-Cutting Concerns

**Purpose**: Cross-story hardening and demo readiness.

- [ ] T055 [P] Bluetooth 58mm ESC/POS thermal printing (Tier 2) in `app/lib/features/receipt/printing/` — must not block a sale
- [ ] T056 [P] Tenant-isolation test across two merchants in `server/test/tenant.isolation.e2e-spec.ts` (SC-008)
- [ ] T057 [P] Seed a realistic warung/café demo dataset in `server/prisma/seed.demo.ts`
- [ ] T058 Run the [quickstart.md](./quickstart.md) V1–V10 validation on phone + tablet (board-demo path)
- [ ] T059 [P] Add the AWS RDS (Jakarta `ap-southeast-3`) `DATABASE_URL` config for the UAT/demo environment in `server/.env.uat`
- [ ] T060 [P] Project docs/README covering run steps in `README.md` (mirror quickstart setup)

---

## Dependencies & Execution Order

### Phase dependencies

- **Setup (Phase 1)**: no dependencies.
- **Foundational (Phase 2)**: depends on Setup; **blocks all user stories**.
- **User Stories (Phases 3–11)**: all depend on Foundational; then proceed in priority order (P1 → P2 → P3) or in parallel if staffed.
- **Polish (Phase 12)**: after the desired stories are complete.

### Story dependencies & independence

- **US1 (P1)** is the MVP; it relies only on Foundational (catalog read + seed).
- **US2–US9** each depend only on Foundational and are independently testable. Practical soft-links (not blockers): US3 void naturally demos on a US1 sale; US6 reports read US1 sales; US7 admin manages US2 catalog. None break another story's independent test.

### Within a story

- Critical-integrity tests (where present) are written first and must fail before implementation.
- Server model/service → endpoint → app UI. Commit after each task or logical group.

### Parallel opportunities

- Setup: T003, T004, T005 in parallel.
- Foundational: T010, T011, T012, T017 in parallel after T007–T009.
- US1 tests T018–T020 in parallel; app T026 parallel with server tasks.
- Different stories can be built by different developers once Foundational is done.

---

## Implementation Strategy

### MVP first (US1 only)

1. Phase 1 Setup → 2. Phase 2 Foundational → 3. Phase 3 US1 → **STOP & validate** (quickstart V1–V3, V5-prep) → demo.

### Incremental delivery

Foundational → US1 (MVP) → US2 → US3 → US4 → US5 → (P3) US6 → US7 → US8 → US9 → Polish. Each story is tested independently and adds value without breaking earlier stories.

### Board-demo scope

- **Preferred demo scope**: **US1 + US3 + US6 + US7** (sell + void + multi-outlet reports + web admin dashboard) on phone and tablet — the fullest convincing story for the board.
- **Minimum technical MVP**: **US1 + US3** (sell + void with receipt preview), quickstart V10.
- Printing (T055) and RDS promotion (T059) remain non-blocking either way.

---

## Notes

- `[P]` = different files, no incomplete-task dependency; `[Story]` maps a task to a user story for traceability.
- Tests here are scoped to the financial-integrity guarantees per the constitution's behavioral-verification mandate — not exhaustive TDD.
- Every business operation touching orders/payments/inventory runs in a single transaction (Constitution II); voids/refunds are append-only (Constitution IV).
- Total: **60 tasks** (T001–T060).
