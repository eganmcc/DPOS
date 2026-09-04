<!--
Sync Impact Report
==================
Version change: 1.5.0 → 1.6.0
Bump rationale: MINOR — codify the corrections lifecycle and two additive domains. Corrections: a
  VOID is same-business-day only (Asia/Jakarta) and REQUIRES a reason; older sales are corrected by a
  REFUND, which MAY be full or line-level partial and is recorded as an append-only `Refund` (+
  `RefundLine`) plus a reversal `REFUND` `Payment`, restoring refunded stock through the ledger —
  effective `REFUNDED` derives only when the whole grand total has been returned (a partial refund
  keeps `COMPLETED`). An unpaid open bill (`AWAITING_PAYMENT`) MAY be `CANCELLED` — a new terminal
  stored status that releases the reserved stock via the ledger (no money moves). Authorization: OWNER
  and MANAGER may void/refund/cancel directly; a CASHIER MAY initiate one with a manager/owner PIN
  override, which the server verifies and records as the approver — every correction still writes an
  `AuditLog`. Additive domains: employee ATTENDANCE (clock-in/out spans feeding an owner/manager
  report) and in-app owner/manager REPORTING (the app reads the same server-authoritative
  `/admin/dashboard`). Additive; no money-math or idempotency rule changed, and COMPLETED-immutability
  is preserved (corrections remain append-only compensating records).

Prior — Version change: 1.4.0 → 1.5.0
Bump rationale: MINOR — codify online-delivery sales channels as server-authoritative ingestion: an
  online order (GoFood/GrabFood/ShopeeFood) is a first-class Order created through the same
  computeOrder + inventory + (merchantId, clientOrderId) idempotency pipeline as an in-store sale (no
  client money/stock rule); it carries a `channel` and an `onlineStatus` fulfillment lifecycle
  distinct from payment status, and a platform-paid order lands COMPLETED with a synthetic ONLINE
  payment. One server-side ingestion seam serves both the demo simulator and future provider webhooks;
  the DB (not the platform) is authoritative. Online-order intake is F&B-only. Additive; no
  money/stock/lifecycle rule changed.

Prior — Version change: 1.3.0 → 1.4.0
Bump rationale: MINOR — codify that peripherals are presentation, never a source of truth: the
  grocery barcode scanner resolves a SKU and adds via the same server-authoritative add + stock-cap
  path (no client money/stock rule), and Bluetooth ESC/POS receipt printing is a non-blocking side
  effect of an already-committed order (silent on failure; the DB record, not the paper, is
  authoritative). A scanner POS mode is offered only for grocery. Additive; no money/stock/lifecycle
  rule changed.

Prior — Version change: 1.2.0 → 1.3.0
Bump rationale: MINOR — add the D-Customer Portal (admin web app) governance: admin mutations are
  OWNER-gated, merchant-scoped, hash secrets at rest, and route inventory edits through the
  append-only ledger; introduce `Merchant.businessType` (FNB | GROCERY) as a type-specific
  behaviour driver (e.g. bill-settlement is F&B-only); and codify version discipline (read from
  source, surfaced to users, bumped on user-visible change). Additive; no money/stock/lifecycle
  rule changed.

Prior — Version change: 1.1.0 → 1.2.0
Bump rationale: MINOR — add deferred settlement (open bills) to Principle IV and the Order
  lifecycle. An order may be confirmed without payment as `AWAITING_PAYMENT`, reserving stock at
  confirm time (no more oversell than an immediate sale); settlement is a separate, idempotent,
  single-guarded-transition action that appends a CHARGE and completes the order without touching
  stock again; an outlet holds at most one open bill per table. Immediate-vs-open-bill is a
  per-outlet setting. Additive material guidance, consistent with the existing lifecycle.
Amendment history:
  - 1.0.0 (2026-08-21): Initial ratification (first adoption).
  - 1.0.1 (2026-08-21): Principle VI tenancy wording reconciled with the Phase 1 schema.
  - 1.0.2 (2026-08-22): Order/Payment lifecycle wording reconciled with the append-only void/
    refund model (derived VOIDED/REFUNDED; immutable original payment).
  - 1.1.0 (2026-08-28): Principle IV gains stock-availability enforcement (no overselling; zero
    on-hand is not orderable; client reflects availability).
  - 1.2.0 (2026-08-28): Principle IV + Order lifecycle gain deferred settlement (open bills):
    confirm-without-payment reserves stock; atomic idempotent settle; one open bill per table;
    per-outlet paymentMode.
  - 1.3.0 (2026-08-28): D-Customer Portal admin governance (OWNER-gated, ledger-routed inventory,
    hashed secrets); Merchant.businessType (FNB | GROCERY); version discipline.
  - 1.4.0 (2026-08-29): peripherals-are-presentation (grocery barcode scanner reuses the
    server-authoritative add/stock path; ESC/POS printing is a non-blocking side effect of a
    committed order); scanner POS mode is grocery-only.
  - 1.5.0 (2026-08-29): external sales channels are server-authoritative ingestion (online-delivery
    orders are first-class Orders via the shared computeOrder/inventory/idempotency pipeline;
    `channel` + `onlineStatus` fulfillment lifecycle; platform-paid → COMPLETED + synthetic ONLINE
    payment; one ingestion seam for the demo simulator + real webhooks); online-order intake is
    F&B-only.
  - 1.6.0 (2026-09-03): corrections lifecycle — same-day-only VOID (Asia/Jakarta) with a mandatory
    reason; full/partial (line-level) REFUND as append-only `Refund`/`RefundLine` + reversal
    `REFUND` `Payment`, stock restored via the ledger, effective `REFUNDED` only when fully
    refunded; unpaid open bills may be `CANCELLED` (new terminal stored status) releasing reserved
    stock; OWNER/MANAGER may correct directly and a CASHIER may initiate with a manager-PIN override
    recorded as the approver, all audited; additive employee ATTENDANCE + in-app owner/manager
    reporting.
Modified principles:
  - IV. Immutable Financial History — added stock-availability enforcement (1.1.0) and deferred
    settlement / open-bill rules (1.2.0); void/refund realized as append-only records; refunds may
    be full or line-level partial (append-only `Refund`/`RefundLine`), a same-day window bounds
    VOID, and an unpaid open bill may be `CANCELLED` releasing reserved stock (1.6.0)
  - VI. Multi-Tenant Scoping — tenancy-key placement wording clarified (1.0.1); corrections gated to
    OWNER/MANAGER, a CASHIER may initiate with a manager-PIN override recorded as the approver, all
    audited (1.6.0)
Modified sections:
  - Technology & Architecture Constraints — Stored Order lifecycle gains a `CANCELLED` terminal for
    abandoned unpaid open bills (stock released via the ledger); employee ATTENDANCE and in-app
    owner/manager reporting are additive (1.6.0); external sales channels are server-authoritative
    ingestion (online-delivery orders as first-class Orders; `channel` + `onlineStatus`; one ingestion
    seam for demo + webhooks); online-order intake is F&B-only (1.5.0); peripherals-are-presentation
    (barcode scanner + ESC/POS printing); grocery-only scanner mode (1.4.0); D-Customer Portal admin
    governance + Merchant.
    businessType (1.3.0); Stored Order lifecycle notes AWAITING_PAYMENT open bills + per-outlet
    paymentMode (1.2.0); "Lifecycles are backend-owned" split into stored lifecycles + derived
    effective states (1.0.2)
  - Development Workflow — version discipline (read from source, surfaced, bumped) (1.3.0)
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
- **Deferred settlement (open bills) reserves stock up front and completes atomically.** An order
  MAY be confirmed without a payment and stored as `AWAITING_PAYMENT`; this still writes the
  negative `inventory_movements` entry and decrements stock at confirm time, so an open bill can no
  more oversell than an immediate sale. Settlement is a **separate** action that appends a `CHARGE`
  `Payment` and advances the stored status to `COMPLETED` through a **single guarded transition** —
  idempotent (a retry or concurrent settle resolves to exactly one `COMPLETED` order with one
  charge) and it **never touches stock again** (already reserved at confirm). An outlet holds at
  most one `AWAITING_PAYMENT` order per table label.
- VOID and REFUND are distinct operations, both realized as **new append-only records** rather
  than mutations of history: a full VOID is an `OrderVoid`; a REFUND is an append-only `Refund`
  (+ `RefundLine` for line-level detail) accompanied by a reversal `Payment` (`reversalType = REFUND`)
  referencing the original `CHARGE`. The `COMPLETED` order and the original `PAID` payment are
  never rewritten; effective `VOIDED`/`REFUNDED` state is derived from the compensating records.
  - **A VOID is same-business-day only** (Asia/Jakarta): a full reversal of a past business day is
    refused (older sales are corrected by a REFUND instead). Every VOID and REFUND **requires a
    reason** (audit trail).
  - **A REFUND may be full or line-level partial**, and an order MAY carry several partial refunds
    up to its grand total. Each restores exactly the refunded quantity's stock through the ledger
    (an `ADJUSTMENT` movement + transactional projection). Effective `REFUNDED` derives **only when
    the whole grand total has been returned**; a partial refund leaves the stored status `COMPLETED`
    with a tracked refunded amount. A refund reverses the record and stock — real money movement
    (cash returned, PSP refund, platform refund) is a separate operational/provider step.
- **An unpaid open bill may be cancelled.** An `AWAITING_PAYMENT` order MAY advance to a new terminal
  stored status **`CANCELLED`**, which **releases the reserved stock** through the ledger (a positive
  `ADJUSTMENT` movement + projection) and closes the bill. No money moves (nothing was paid); the
  order is retained as a record, never deleted. This is the only stored-status transition permitted
  out of `AWAITING_PAYMENT` besides settlement to `COMPLETED`.

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
- Sensitive actions (VOID, REFUND, open-bill CANCEL, price/catalog edits) MUST be permission-gated
  and MUST write an `AuditLog` entry recording actor, before/after, and timestamp. **OWNER and
  MANAGER** may perform a correction directly. A **CASHIER MAY initiate** a void/refund/cancel only
  with a **manager/owner PIN override**: the server verifies the PIN against an active OWNER/MANAGER
  of the same merchant and records that staff as the **approver** on the record (and in the audit);
  a missing or wrong PIN is refused. Owner/manager-only administrative reads (the sales dashboard)
  and edits stay role-gated.
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
- **Web admin (D-Customer Portal)**: a separate Vue 3 + Vite + TypeScript SPA (Pinia, Vue Router)
  consuming the same REST API. Not Flutter Web. Admin mutations are **OWNER-gated**, merchant-scoped
  from the token, and obey the same invariants as the app: PINs/passwords are bcrypt-hashed at rest
  and NEVER returned; inventory edits go through the append-only ledger (an `ADJUSTMENT` movement +
  transactional projection update, never an in-place balance edit — Principle IV); money stays
  integer rupiah.
- **Auth**: JWT issued by the API — owner email/password; staff PIN mapped to a staff account
  under the merchant. Roles gate sensitive actions.
- **Business type is a merchant attribute** (`Merchant.businessType` ∈ `FNB` | `GROCERY`) and drives
  type-specific behaviour — e.g. the bill-settlement (`Outlet.paymentMode`) setting is surfaced only
  for F&B; a **barcode-scanner POS mode** is offered only for grocery; **online-delivery order intake**
  is offered only for F&B. Adding a type is additive; it MUST NOT change money, stock, or lifecycle
  rules.
- **Peripherals are presentation, never a source of truth.** Barcode scanning resolves a scanned
  value to a variant by **SKU** and adds it to the cart through the **same** server-authoritative
  add + stock-cap path as tapping — it introduces no client-side money or stock rule. Receipt
  printing (Bluetooth ESC/POS) is a **non-blocking side effect of an already-committed order**: it
  never gates or alters the sale, a print failure is silent, and the database record — not the
  paper — is authoritative (Principle I).
- **External sales channels are server-authoritative ingestion.** Online-delivery orders (GoFood/
  GrabFood/ShopeeFood) are **first-class Orders**, not a parallel store: they are created through the
  **same** `computeOrder` totals + inventory decrement + `(merchantId, clientOrderId)` idempotency as
  an in-store checkout — the client never computes their money or stock. An order carries a `channel`
  (`POS` in-store; a platform otherwise) and, for online orders, an `onlineStatus` **fulfillment**
  lifecycle (`NEW → ACCEPTED → …`) that is **distinct from** payment status; a platform-paid order
  lands `COMPLETED` with a synthetic `ONLINE` `Payment`. Both the demo simulator and future provider
  webhooks feed **one** ingestion service; the database — not the delivery platform — is authoritative
  (Principle I). A platform cancellation is an append-only `OrderVoid` (Principle IV), never a mutation.
- **Attendance and reporting are additive, server-authoritative, and never gate a sale.** Employee
  attendance is an append-only set of clock-in/out spans (`Attendance`); any staff records their own,
  and an owner/manager report aggregates them. Owner/manager **reporting** (sales summary by day/
  week/month, payment mix, top items, by-outlet, plus the attendance view) reads the **same**
  server-authoritative figures (`/admin/dashboard`, `/admin/attendance`) — the client computes no
  new money. Neither feature touches the money, stock, or order-lifecycle rules.
- **Extensibility (F&B now → retail later)**: variants (the sellable unit — own SKU/barcode/
  price/cost/inventory) MUST be modeled distinctly from modifiers (additions/customizations).
  Retail is additive (populate SKU/barcode/cost, enable stock tracking) with no schema break.
- **Lifecycles are backend-owned**:
  - **Stored Order lifecycle**: `DRAFT → HELD → AWAITING_PAYMENT → COMPLETED`, with an unpaid open
    bill able to terminate at `CANCELLED` instead (`AWAITING_PAYMENT → CANCELLED`, releasing reserved
    stock). The stored status never advances past `COMPLETED`. `AWAITING_PAYMENT` is the **open-bill**
    state (confirm now, settle later); whether an outlet settles immediately or opens a bill is a
    per-outlet setting (`Outlet.paymentMode` ∈ `IMMEDIATE` | `OPEN_BILL`). `VOIDED` and `REFUNDED`
    are **derived effective states** represented by append-only compensating records (an `OrderVoid`;
    a `Refund` + reversal `Payment`); they do **not** mutate a `COMPLETED` order — whereas `CANCELLED`
    is a **stored** terminal for an open bill that was never paid. An order also carries a `channel`
    (`POS` | `GOFOOD` | `GRABFOOD` | `SHOPEEFOOD`); an online order additionally tracks an
    `onlineStatus` **fulfillment** lifecycle (`NEW → ACCEPTED → PREPARING → READY → COMPLETED`,
    or `CANCELLED`) that is separate from — and never a substitute for — the stored payment status.
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
- **Versions are read from source, never hardcoded**: each deployable (server `package.json`,
  Flutter `pubspec.yaml`, portal `package.json`) owns its version; the app and portal read their
  own at build time and the backend's from the public `GET /version` endpoint, and surface both to
  the user (app Settings; portal login + nav). A user-visible behaviour change ships with a version
  bump.

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

**Version**: 1.6.0 | **Ratified**: 2026-08-21 | **Last Amended**: 2026-09-03
