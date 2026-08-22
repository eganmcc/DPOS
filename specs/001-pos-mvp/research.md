# Phase 0 Research: DPOS Mobile POS MVP

All major technology and pattern decisions were resolved during planning; there are **no open `NEEDS CLARIFICATION` items**. This document records each decision, its rationale, and the alternatives considered, so downstream tasks inherit settled ground.

## Decision: Mobile framework — Flutter

- **Decision**: Flutter (Dart) for the phone + tablet app.
- **Rationale**: Single codebase with strong responsive support (two-pane catalog+cart on tablet, stacked on phone); mature ESC/POS Bluetooth printing packages; Android-first, which dominates the Indonesian market.
- **Alternatives considered**: React Native (viable, but printing is more fiddly and the team gains less from a shared UI system); native Android (fastest device integration but no path to iOS and slower to build the demo); PWA (weak/unreliable Bluetooth thermal printing, especially iOS — rejected for a "real POS" story).

## Decision: Backend — NestJS + Prisma over PostgreSQL, API-fronted

- **Decision**: A TypeScript NestJS API with Prisma ORM in front of PostgreSQL; the app/admin never connect to Postgres directly.
- **Rationale**: A mobile app must not hold DB credentials or bypass business rules; the API is the enforcement point for money math, atomic transactions, tenant scoping, and audit (Constitution I, II, III, VI). Prisma gives typed models, migrations, and first-class `$transaction` for atomic checkout.
- **Alternatives considered**: Direct-to-DB from device (violates Principles I/VI — rejected); a BaaS like Supabase/Firebase (faster to start, but row-level rules and vendor lock-in complicate the strict atomic/immutable/ledger requirements and Indonesia residency — rejected in favor of an explicit API we control).

## Decision: PostgreSQL as authoritative store; local Docker → AWS RDS Jakarta

- **Decision**: PostgreSQL everywhere. Local Postgres via Docker Compose during development; promote to AWS RDS for PostgreSQL in Jakarta (`ap-southeast-3`) for UAT/board-demo once schema/migrations stabilize.
- **Rationale**: Same engine + Prisma migrations in both places makes the move config-only; Jakarta region satisfies Indonesian data-residency (Constitution VII). Deferring RDS avoids cloud cost/latency while the schema churns.
- **Alternatives considered**: Start directly on RDS (slower inner loop, cost during churn — rejected); SQLite on the server (cannot meet concurrency/transaction/residency needs — rejected).

## Decision: Web admin — Vue 3 + Vite + TypeScript

- **Decision**: A separate Vue 3 + Vite + TS SPA (Pinia, Vue Router) consuming the same REST API.
- **Rationale**: Lighter and lower-boilerplate for a dashboard; excellent Vite DX; pairs cleanly with the TS backend; a good learning surface. Chosen by stakeholder over React.
- **Alternatives considered**: React + Vite (larger ecosystem, more boilerplate — not chosen); Flutter Web admin (would reuse Dart models but is heavier for data-dense dashboards — rejected).

## Decision: Offline-first with idempotent, event-based sync (no LWW on money/stock)

- **Decision**: drift/SQLite as a local cache and an offline **sync queue**. Each order is minted on-device with a `clientOrderId` (UUID); the submit endpoint is idempotent on `UNIQUE(merchantId, clientOrderId)` (insert-or-return-existing). Financial/operational records are append-based; last-write-wins is used only for benign catalog metadata (e.g. a product photo).
- **Rationale**: Indonesian connectivity is intermittent; the POS must keep selling offline and must never double-post on retry (Constitution V; SC-003). Idempotency at the unique constraint is simpler and safer than reconciliation heuristics.
- **Alternatives considered**: Full CRDT/last-write-wins sync (double-charge and stock-corruption risk for money — rejected); server-generated IDs only (can't dedupe a retried offline submit — rejected in favor of client-UUID idempotency key).

## Decision: Payments behind a `PaymentProvider` interface; simulated QRIS for MVP

- **Decision**: A `PaymentProvider` abstraction with a `SimulatedQrisProvider` (renders a QR for the exact amount via `qr_flutter`; "mark as paid" confirms). Cash is a first-class local tender. Payment state transitions are validated by the backend.
- **Rationale**: Real QRIS requires PSP onboarding/KYC (weeks) and Livin' Merchant is a competitor, not an API we integrate. The interface lets a real provider (Midtrans/Xendit/DOKU) drop in later with no change to ordering/checkout (Constitution VII; FR-010).
- **Alternatives considered**: Integrate a PSP sandbox now (adds keys + 1–2 weeks, unnecessary for a board demo — deferred); hard-code QRIS logic in the UI (blocks provider swap — rejected).

## Decision: Configurable per-outlet tax rules (not a hard-coded tax type)

- **Decision**: An outlet-level `tax_rule` with a configurable label and rate (supporting Indonesian F&B terminology such as **PBJT** where applicable) plus an optional service charge; amounts computed server-side.
- **Rationale**: Indonesian F&B tax terminology/rates vary by region and merchant; hard-coding "PB1/PPN" would be wrong for many outlets (Constitution VII; FR-004). Server-side computation keeps it authoritative (Principle III).
- **Alternatives considered**: Single global tax constant (inaccurate, inflexible — rejected); client-side tax math (untrusted — rejected).

## Decision: Variants distinct from modifiers; snapshots on order lines

- **Decision**: `ProductVariant` is the sellable unit (own price, later SKU/barcode/stock); `Modifier` groups are additions/customizations only. Order lines snapshot product name, SKU, selling price, cost price, and selected variant/modifiers at sale time.
- **Rationale**: Conflating the two blocks retail (which needs per-variant SKU/stock) and corrupts history when the catalog changes (Constitution IV; FR-001/002/019/031). Snapshots make completed sales reconstructable.
- **Alternatives considered**: One "option group" serving both roles (the original sketch — rejected after review because variants and modifiers have different inventory/identity semantics).

## Decision: Inventory as append-only ledger + transactional projection

- **Decision**: `inventory_movements` is the append-only source of truth; a sale writes a negative movement, a stock-restoring void a positive movement. `inventory_stock.quantity_on_hand` is a projection updated in the same transaction as the movement.
- **Rationale**: A mutable counter cannot be audited or rebuilt and is prone to races; the ledger + projection is both fast to read and fully reconstructable (Constitution IV; FR-019).
- **Alternatives considered**: Update `product.stockQty` directly (unauditable, race-prone — rejected).

## Decision: Auth via JWT with PIN sign-in and roles

- **Decision**: API-issued JWT. Owner signs in with email/password; staff sign in with a PIN mapped to a staff account under the merchant. Roles (owner/cashier) gate sensitive actions.
- **Rationale**: Simple, self-contained for the MVP; supports fast PIN switching at the counter; role gating underpins void/refund/price-edit control and audit (Constitution VI; FR-023).
- **Alternatives considered**: AWS Cognito (more moving parts than the MVP needs — deferred as a later option).

## Decision: Receipt preview mandatory; Bluetooth printing deferred to Tier 2

- **Decision**: An on-screen receipt preview (with share-as-image) is the mandatory demo path; 58mm Bluetooth ESC/POS printing is added after checkout/inventory/reporting work and never blocks a sale.
- **Rationale**: De-risks the demo from hardware/pairing issues; printing is additive (Constitution — verification is behavioral; FR-013/014).
- **Alternatives considered**: Make printing mandatory (hardware dependency risk at the board demo — rejected).

## Open Items (non-blocking, deferred to implementation)

- Exact Bluetooth printing package choice — validate `print_bluetooth_thermal` vs `blue_thermal_printer` against a real 58mm printer during Tier 2.
- API deploy target on AWS — App Runner vs ECS Fargate (both Jakarta); App Runner favored for MVP simplicity.
- Real PSP selection (Midtrans vs Xendit) for the post-MVP live-QRIS phase.
