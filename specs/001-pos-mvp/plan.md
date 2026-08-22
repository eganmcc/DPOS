# Implementation Plan: DPOS Mobile POS MVP

**Branch**: `001-pos-mvp` | **Date**: 2026-08-21 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-pos-mvp/spec.md`

## Summary

Build a mobile POS for Indonesian F&B merchants (phone + tablet) with a minimal web admin, benchmarked against Mandiri Livin' Merchant. The mobile app operates offline-first for cash sales/catalog/order creation and syncs idempotently; a backend API over PostgreSQL is the authoritative system of record and owns all money math, atomic checkout, immutable history, and an append-only inventory ledger. Payments are simulated (QRIS + cash) behind a swappable provider interface. The data model separates variants (sellable units) from modifiers so simple retail can be added later without a schema break.

## Technical Context

**Language/Version**: Mobile — Dart 3.x / Flutter 3.x. Backend — TypeScript (Node 20 LTS). Web admin — TypeScript (Vue 3).

**Primary Dependencies**: Flutter, Riverpod (state), drift (local SQLite), `qr_flutter` (QR render), `print_bluetooth_thermal` + `esc_pos_utils` (Tier-2 printing), `intl` (Rupiah/i18n). Backend — NestJS, Prisma ORM, `zod`/class-validator (input validation), `jsonwebtoken` (JWT). Web admin — Vite, Pinia, Vue Router, an HTTP client (fetch/axios).

**Storage**: PostgreSQL is the authoritative system of record (local Docker in dev → AWS RDS for PostgreSQL, Jakarta `ap-southeast-3`, for UAT/board demo). SQLite (via drift) on-device is a local operational cache only.

**Testing**: Backend — Jest + Supertest (unit + API contract/integration), plus Prisma against a test Postgres. Mobile — `flutter_test` (unit/widget) + `integration_test` (end-to-end flows incl. offline/idempotency). Web admin — Vitest + component tests.

**Target Platform**: Android phones and tablets (iOS deferred). Web admin targets modern evergreen browsers.

**Project Type**: Multi-component — mobile app + REST API + web admin (three deployables, one shared API contract).

**Performance Goals**: A typical 2–3 item sale completes in < 30s on phone and tablet (SC-001). API p95 < 300ms for catalog/order reads under demo load. App remains responsive while offline.

**Constraints**: Offline-capable POS for supported workflows; QRIS may be unavailable offline. All checkout/void/refund operations are atomic (single DB transaction). Offline submission is idempotent (`UNIQUE(merchantId, clientOrderId)`). Server owns all monetary math. Completed orders are immutable. Multi-tenant scoping + audit from the first migration. Indonesia data residency for central data.

**Scale/Scope**: MVP/demo scale — a handful of merchants, a few outlets, seeded catalog. App ~15–20 screens; web admin ~6–8 screens; API ~30–40 endpoints across auth, catalog, orders, payments, inventory, reports, admin.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| # | Principle | Design compliance | Status |
|---|-----------|-------------------|--------|
| I | Postgres is authoritative; device is a cache | Backend/Postgres owns truth; drift is cache; device reconciles from server on reconnect (see research.md §Sync) | PASS |
| II | Atomic business operations | Checkout/void/refund wrapped in a single Prisma `$transaction`; order+payment+movement+stock projection commit together (data-model.md §Transactions) | PASS |
| III | Server owns all money math | API recomputes subtotal→discount→tax→service→grand total; client totals discarded (contracts: `POST /orders` ignores client totals) | PASS |
| IV | Immutable financial history | Completed orders never updated/deleted (status terminal at COMPLETED); order lines snapshot name/SKU/price/cost/selections + tax/service snapshots; append-only `inventory_movements`; **VOID = immutable, idempotent `OrderVoid`** (`UNIQUE(order_id)` + optional `client_void_id`), **REFUND = new `REVERSAL` payment** (`reversal_type=REFUND`) referencing the original; `reversal_type` separates a VOID-driven reversal from a REFUND so effective `VOIDED`/`REFUNDED` never collide — originals never mutated (Constitution v1.0.2) | PASS |
| V | Idempotent, offline-first sync | `clientOrderId` UUID + `UNIQUE(merchantId, clientOrderId)`; submit is insert-or-return-existing; offline queue on device | PASS |
| VI | Multi-tenant scoping, least privilege, audit | Major transactional records (Order, Payment, InventoryMovement, Shift, AuditLog, OrderVoid) carry `merchantId` directly; nested children (OrderLine, OrderDiscount, Modifier) inherit via required parent FK; API guards enforce scope from migration 1; VOID/REFUND/price-edit role-gated + `audit_logs`; discounts capture `applied_by`/`approved_by` (Constitution v1.0.1) | PASS |
| VII | Indonesia-first; simulated payments behind real interface | Rupiah/Bahasa/QRIS; per-outlet configurable `tax_rules` (PBJT-aware); `PaymentProvider` with `SimulatedQrisProvider`; residency in Jakarta | PASS |

No violations. **Complexity Tracking is empty** (see below). Post-design re-check appears at the end of this plan.

## Project Structure

### Documentation (this feature)

```text
specs/001-pos-mvp/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (REST API contract)
│   └── openapi.yaml
├── checklists/
│   └── requirements.md  # from /speckit-specify
└── tasks.md             # Phase 2 (/speckit-tasks — NOT created here)
```

### Source Code (repository root)

```text
server/                     # NestJS + Prisma REST API (authoritative)
├── prisma/
│   ├── schema.prisma       # data model (see data-model.md)
│   ├── migrations/
│   └── seed.ts             # demo warung/café dataset
├── src/
│   ├── auth/               # JWT, PIN sign-in, roles/guards
│   ├── common/             # tenant scoping guard, money engine, tx helpers
│   ├── merchants/ outlets/ staff/
│   ├── catalog/            # categories, products, variants, modifiers, tax_rules
│   ├── orders/             # order lifecycle, atomic checkout, snapshots
│   ├── payments/           # PaymentProvider, SimulatedQrisProvider, lifecycle
│   ├── inventory/          # movements ledger + stock projection
│   ├── reports/            # daily totals, payment split, top items
│   └── audit/              # audit_logs writer
└── test/                   # Jest + Supertest

app/                        # Flutter (phone + tablet)
└── lib/
    ├── core/               # theme, money/i18n (Rupiah/Bahasa), result types
    ├── data/               # drift cache, models, api client, sync queue
    └── features/
        ├── catalog/ order/ payment/ receipt/
        ├── transactions/   # history + void
        ├── auth/ outlets/ shift/ reports/
        └── sync/           # offline queue, idempotent submit, reconciliation

web-admin/                  # Vue 3 + Vite + TS SPA
└── src/
    ├── api/                # typed API client
    ├── stores/             # Pinia (auth, catalog, outlets)
    ├── router/
    └── views/              # products/variants, outlets, staff, dashboard

docker-compose.yml          # local Postgres for dev
```

**Structure Decision**: Multi-component layout (Option 3: Mobile + API, extended with a web admin). Three deployables share one REST API contract (`contracts/openapi.yaml`). The backend is the only client of PostgreSQL; the app and admin never touch the DB directly. This matches Principles I and VI and keeps the Flutter app and Vue admin thin over a single authoritative service.

## UI Design System — "DIKA Bold"

The Flutter app uses the PT DIKA brand system: navy `#133A68` primary, gold `#D6AD07` accent, white/cream surfaces; Material 3 **light and dark** `ColorScheme` plus a `ThemeExtension` (success color + navy header gradient); gold CTAs, navy-tinted layered shadows, product-card grid, and full **ID/EN localization** (`gen_l10n`, persisted locale toggle, default Indonesian). The complete token/component/screen specification — with mockups — is committed at [design/ui-design-handoff.md](./design/ui-design-handoff.md). Implemented in `app/lib/core/theme.dart` and the feature screens (Login, POS, Checkout, Receipt).

## Complexity Tracking

> No constitution violations — no entries required.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| — | — | — |

## Post-Design Constitution Re-Check

After the Phase 1 revision (data-model.md, contracts/openapi.yaml, quickstart.md; constitution v1.0.2): all seven gates still **PASS**, and the revision strengthens Principle IV. The schema now encodes immutability with **no mutation path at all** for completed orders — a void is an immutable, idempotent append-only `OrderVoid` (`UNIQUE(order_id)`, optional `client_void_id`; no "unvoid") and a refund is a new `REVERSAL` `Payment` (`reversal_type=REFUND`). `Payment.reversal_type` (`VOID`|`REFUND`) keeps a void-driven reversal from ever deriving as `REFUNDED`; effective `VOIDED`/`REFUNDED` state is derived, never stored over the original. It retains the ledger + projection, `UNIQUE(merchant_id, client_order_id)`, per-outlet `tax_rules` with full tax/service snapshots on the order, an audit-friendly `OrderDiscount` (applied_by/approved_by), `track_inventory` per variant, `NUMERIC` quantities, and per-outlet `ProductOutlet` availability. Tenancy wording is reconciled with the schema (Constitution v1.0.1): major transactional records carry `merchant_id` directly; nested children inherit via a required parent FK. No new complexity beyond these records; no violations.
