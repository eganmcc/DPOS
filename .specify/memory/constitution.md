<!--
Sync Impact Report
==================
Version change: 1.0.2 → 1.1.0
Bump rationale: MINOR — add a new enforceable rule to Principle IV: stock availability is
  enforced. A stock-tracked variant may not be oversold — the server rejects any order line
  exceeding the outlet's on-hand balance via an atomic conditional decrement inside the checkout
  transaction, so stock can never go negative; a zero-on-hand item is not orderable and the client
  greys it out and caps quantities at remaining stock. New material guidance, not a redefinition —
  additive to the existing append-only ledger rule.
Amendment history:
  - 1.0.0 (2026-08-21): Initial ratification (first adoption).
  - 1.0.1 (2026-08-21): Principle VI tenancy wording reconciled with the Phase 1 schema.
  - 1.0.2 (2026-08-22): Order/Payment lifecycle wording reconciled with the append-only void/
    refund model (derived VOIDED/REFUNDED; immutable original payment).
  - 1.1.0 (2026-08-28): Principle IV gains stock-availability enforcement (no overselling; zero
    on-hand is not orderable; client reflects availability).
Modified principles:
  - IV. Immutable Financial History — added stock-availability enforcement rule (1.1.0); void/refund
    realized as append-only records; wording tightened
  - VI. Multi-Tenant Scoping — tenancy-key placement wording clarified (1.0.1)
Modified sections:
  - Technology & Architecture Constraints — "Lifecycles are backend-owned" split into stored
    lifecycles + derived effective states (1.0.2)
Added principles:
  - I. Postgres Is the Authoritative System of Record
  - II. Atomic Business Operations
  - III. The Server Owns All Money Math
  - IV. Immutable Financial History
  - V. Idempotent, Offline-First Sync
  - VI. Multi-Tenant Scoping, Least Privilege & Auditability
  - VII. Indonesia-First, Simulated Payments Behind a Real Interface
Added sections:
  - Technology & Architecture Constraints (Section 2)
  - Development Workflow (Section 3, Spec-Driven Development via Spec Kit)
  - Governance
Removed sections: none
Templates requiring review:
  - .specify/templates/plan-template.md ✅ (Constitution Check gate will reference these principles)
  - .specify/templates/spec-template.md ✅ (no changes required)
  - .specify/templates/tasks-template.md ✅ (no changes required)
Deferred TODOs: none
-->

# DPOS Constitution

DPOS is a mobile Point-of-Sale platform for Indonesian merchants (F&B first — café,
restaurant, warung — with simple retail to follow), running on phone and tablet with a
minimal web admin. This constitution defines the non-negotiable rules that govern how DPOS
is designed and built. It supersedes convenience, habit, and individual preference.

## Core Principles

### I. Postgres Is the Authoritative System of Record

PostgreSQL is the single source of truth for all business data. The on-device store
(drift/SQLite) is a local operational cache ONLY: it exists so the POS can keep selling with
no network, and it is NEVER authoritative.

- The device MUST treat server state as canonical and reconcile to it on reconnect.
- No feature may depend on device-local data surviving as the truth of record.
- Reads MAY be served from cache; the authoritative value always lives in Postgres.

Rationale: A POS handles money and stock. Divergent "truths" across devices cause lost sales,
wrong balances, and disputes. One authority removes that entire class of bug.

### II. Atomic Business Operations

Any operation that touches orders, payments, and inventory together — checkout, void, refund —
MUST execute inside a single PostgreSQL transaction. Partial commits are PROHIBITED.

- Order + payment + inventory movement + stock projection either ALL commit or ALL roll back.
- No business operation may leave the database in a half-applied state on error or crash.

Rationale: A sale that records payment but not stock (or vice versa) silently corrupts the
books. Atomicity makes every financial operation all-or-nothing.

### III. The Server Owns All Money Math

The backend MUST recalculate every authoritative monetary amount — line totals, discounts,
tax (per the merchant's configurable tax rules), service charge, and grand total — from catalog
data and rules at submit time.

- Client-computed totals are display-only and MUST be discarded server-side.
- The client MUST NOT be trusted to determine what a customer owes.

Rationale: Amounts a device sends can be stale, buggy, or tampered with. Deriving money on the
server guarantees a single, correct, auditable calculation.

### IV. Immutable Financial History

Completed orders are immutable. Once an order is `COMPLETED`, its lines and totals MUST NEVER
be overwritten or physically deleted. Corrections happen only through new, compensating events.

- Order lines MUST snapshot product name, SKU, selling price, cost price, and selected
  variant/modifiers at sale time, so later catalog edits never rewrite history.
- Inventory MUST use an append-only `inventory_movements` ledger as the source of truth; a sale
  writes a negative movement and a stock-restoring void writes a positive movement. The
  `inventory_stock` balance is a projection maintained transactionally from the ledger and is
  NEVER edited on its own. A bare `stockQty` MUST NOT be overwritten.
- **Stock availability is enforced.** For a stock-tracked variant, the server MUST reject any order
  line whose quantity exceeds the current on-hand balance for the outlet — checked atomically
  inside the checkout transaction (a conditional decrement), so an order can never oversell or
  drive stock negative. An item with **zero on-hand MUST NOT be orderable**; the client reflects
  this by disabling/greying the item and capping quantities at the remaining stock. Remaining
  quantity is read from the outlet-scoped catalog.
- VOID and REFUND are distinct operations, both realized as **new append-only records** rather
  than mutations of history: a full VOID is an `OrderVoid`; a REFUND is a reversal `Payment`
  referencing the original `CHARGE`. The `COMPLETED` order and the original `PAID` payment are
  never rewritten; effective `VOIDED`/`REFUNDED` state is derived from the compensating records.

Rationale: Financial and stock records are evidence. Append-only history with snapshots makes
the past reconstructable and audit-safe; in-place edits destroy that.

### V. Idempotent, Offline-First Sync

The POS MUST remain operational offline for supported offline workflows, including cash sales,
catalog access, order creation, and local transaction queuing. Online-dependent payment methods
such as QRIS MAY be unavailable while offline. Syncing offline work MUST be idempotent.

- Every order carries a client-generated `clientOrderId` (UUID); the server enforces
  `UNIQUE(merchantId, clientOrderId)` and the submit endpoint is insert-or-return-existing.
- A retried submission after a dropped connection MUST NOT double-post a sale or double-apply a
  stock movement.
- Financial and operational records (orders, payments, inventory movements, shifts) MUST NOT use
  last-write-wins; they are append-mostly and event-based. LWW is permitted only for benign
  catalog metadata (e.g. a product photo), never for money or stock.

Rationale: Indonesian connectivity is intermittent. Idempotency is what makes "sell now, sync
later" safe instead of a source of duplicate charges.

### VI. Multi-Tenant Scoping, Least Privilege & Auditability

Tenant isolation and accountability are built in from the first migration, not retrofitted.

- Every major transactional record (Order, Payment, InventoryMovement, Shift, AuditLog) MUST
  carry `merchantId` directly (and `outletId` where applicable). Deeply nested child tables MAY
  inherit tenant ownership through a required, non-nullable parent foreign key instead of
  duplicating `merchantId`, provided ownership is unambiguous. The API MUST enforce tenant
  scoping/authorization from migration one — even where multi-outlet UI ships later.
- Sensitive actions (VOID, REFUND, price edits) MUST be permission-gated by role and MUST write
  an `AuditLog` entry recording actor, before/after, and timestamp.
- A merchant MUST NOT be able to read or write another merchant's data.

Rationale: A shared backend that leaks across merchants, or lets any cashier void sales
untracked, is unshippable. Scoping and audit from day one prevent expensive rewrites.

### VII. Indonesia-First, Simulated Payments Behind a Real Interface

DPOS is designed for the Indonesian market and for a payment story that can go live later without
rework.

- The product MUST use Rupiah formatting, Bahasa Indonesia UI (English fallback), and QRIS as the
  primary digital rail.
- Tax MUST be driven by configurable merchant tax rules, NOT a hard-coded tax type. The tax label
  and rate MUST be configurable per outlet (supporting Indonesian F&B terminology such as PBJT
  where applicable), alongside a configurable service charge.
- Payments MUST go through a `PaymentProvider` abstraction. For the MVP a simulated QRIS provider
  is used; a real PSP (e.g. Midtrans/Xendit/DOKU) MUST be able to drop in behind the same
  interface with no change to order/checkout logic.
- Payment state transitions MUST be owned and validated by the backend.
- Data residency MUST be respected: production data lives in an Indonesia region.

Rationale: Building for local rails and regulation up front — while keeping payments swappable —
lets the MVP demo convincingly today and go live without re-architecting.

## Technology & Architecture Constraints

- **Mobile app**: Flutter (single codebase, phone + tablet responsive), Riverpod for state.
- **Backend API**: Node.js + TypeScript (NestJS) with Prisma; a mobile app MUST NOT connect to
  Postgres directly — the API is the only client of the database.
- **Database**: PostgreSQL. Early development runs local Postgres via Docker Compose; production/
  UAT/board-demo promotes to AWS RDS for PostgreSQL in the Jakarta region (`ap-southeast-3`) once
  the core schema and migrations stabilize. Same engine + Prisma migrations in both places.
- **Web admin**: a separate Vue 3 + Vite + TypeScript SPA (Pinia, Vue Router) consuming the same
  REST API. Not Flutter Web.
- **Auth**: JWT issued by the API — owner email/password; staff PIN mapped to a staff account
  under the merchant. Roles gate sensitive actions.
- **Extensibility (F&B now → retail later)**: variants (the sellable unit — own SKU/barcode/
  price/cost/inventory) MUST be modeled distinctly from modifiers (additions/customizations).
  Retail is additive (populate SKU/barcode/cost, enable stock tracking) with no schema break.
- **Lifecycles are backend-owned**:
  - **Stored Order lifecycle**: `DRAFT → HELD → AWAITING_PAYMENT → COMPLETED`. The stored status
    never advances past `COMPLETED`. `VOIDED` and `REFUNDED` are **derived effective states**
    represented by append-only compensating records (an `OrderVoid`; a reversal `Payment`); they
    do **not** mutate a `COMPLETED` order.
  - **Stored Payment lifecycle**: `CREATED → PENDING → PAID`, with `FAILED` / `EXPIRED` /
    `CANCELLED` alternatives. A refund/reversal is a **new** `Payment` record referencing the
    original `CHARGE`; the original `PAID` payment remains **immutable** (never rewritten to
    `REFUNDED`).
  - Only the backend advances these states.

## Development Workflow

- **Spec-Driven Development (Spec Kit)**: work flows through Constitution → Specify → Plan →
  Tasks → Implement. Each artifact is reviewed at a checkpoint before the next is generated.
- **This constitution is the top gate**: `spec.md`, `plan.md`, and `tasks.md` MUST be consistent
  with these principles. The plan template's Constitution Check MUST fail any design that
  violates a principle unless an explicit, documented exception is approved.
- **Verification is behavioral**: features are proven by exercising the end-to-end flow (real
  sale, offline+idempotent retry, server-authoritative recompute, immutability + audit on void,
  inventory ledger movements) — not by assertion alone.
- **No unscoped scope creep**: changes that add money/stock behavior MUST state how they uphold
  Principles I–VI.

## Governance

- This constitution supersedes all other practices and conventions in the DPOS repository.
- **Amendments** require: a written change to this document, a semantic version bump per the
  policy below, an updated Sync Impact Report, and reviewer approval. Amendments that weaken a
  financial-integrity principle (I–VI) additionally require an explicit rationale and a migration/
  mitigation note.
- **Versioning policy** (this document):
  - MAJOR — backward-incompatible governance/principle removals or redefinitions.
  - MINOR — a new principle/section added or materially expanded guidance.
  - PATCH — clarifications, wording, or non-semantic refinements.
- **Compliance review**: every spec, plan, and task set MUST be checked against these principles
  before implementation proceeds; every PR touching money or stock MUST demonstrate compliance
  with the relevant principles. Complexity that appears to violate a principle MUST be justified
  in writing or removed.

**Version**: 1.1.0 | **Ratified**: 2026-08-21 | **Last Amended**: 2026-08-28
