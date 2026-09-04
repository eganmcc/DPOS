# Phase 1 Data Model: DPOS Mobile POS MVP

Authoritative schema lives in PostgreSQL (Prisma). This document is the conceptual model that `schema.prisma` implements. **Major transactional records (`Order`, `Payment`, `InventoryMovement`, `Shift`, `AuditLog`, `OrderVoid`) carry `merchant_id` directly** (and `outlet_id` where applicable); **deeply nested child tables (e.g. `OrderLine`, `OrderDiscount`, `Modifier`) inherit tenant ownership through a required, non-nullable parent FK** rather than duplicating `merchant_id` (Constitution VI, v1.0.1). The API scopes/authorizes every read and write by tenant from the first migration. Monetary values are stored as **integer rupiah** (IDR has no practical sub-unit; this avoids floating-point error); currency is IDR for the MVP.

## Conventions

- Primary keys: server-generated UUID (`id`), unless noted.
- Timestamps: `created_at`, `updated_at` (catalog only); financial/operational rows are append-based and avoid mutation.
- Money: integer rupiah (e.g. Rp 12.500 is stored as `12500`). Format to the `Rp 12.500` display form at the edge (app/admin), never in the DB.
- Quantities: **`NUMERIC(12,3)`**, not integer, so future weighted/unit-based retail (e.g. 0.250 kg) needs no schema redesign. F&B uses whole numbers today (`2.000`).
- Rates: tax/service rates are stored as **basis points** (`rate_bps`, integer; 1000 = 10%).
- Soft rules that the API MUST enforce are marked **[RULE]**.

## Tenancy & Identity

### Merchant
- `id`, `name`, `created_at`
- The top-level tenant. Owns all other rows.

### Outlet
- `id`, `merchant_id → Merchant`, `name`, `address?`, `is_active`
- **[RULE]** Catalog availability, `tax_rules`, stock, shifts, orders, and reports are scoped by `outlet_id`.

### Staff
- `id`, `merchant_id → Merchant`, `name`, `role` (`OWNER` | `MANAGER` | `CASHIER` | `SERVER`), `pin_hash`, `demo_pin?` (demo login prefill only), `email?`, `password_hash?` (owner/manager), `is_active`
- **[RULE]** `pin_hash`/`password_hash` are hashed (bcrypt/argon2), never stored plain.
- **[RULE]** Corrections (void / refund / open-bill cancel) and price/catalog edits are gated to `OWNER`/`MANAGER`. A `CASHIER` MAY **initiate** a correction only with a manager/owner **PIN override**, verified server-side and recorded as the approver (Constitution VI, v1.6.0). The owner/manager sales dashboard is likewise role-gated.

### Device
- `id` (client-provided device UUID), `merchant_id`, `outlet_id?`, `label?`, `last_seen_at`
- Identifies the physical device for sale attribution and sync diagnostics.

## Catalog

### Category
- `id`, `merchant_id`, `outlet_id?`, `name`, `sort_order`, `is_active`

### Product
- `id`, `merchant_id`, `category_id → Category`, `name`, `image_url?`, `is_available`, `type` (`FNB` default; retail-ready)
- A sellable concept; presentation-level. **Not** directly sold — a variant is.

### ProductVariant
- `id`, `product_id → Product`, `name` (e.g. "Regular", "Large"), `price` (rupiah), `cost_price?` (rupiah), `sku?`, `barcode?`, `is_default`, `is_available`, `track_inventory` (bool, default `false`)
- **[RULE]** Every product has ≥1 variant. **The variant is the sellable unit.** Stock movements are written **only** for variants with `track_inventory = true` (F&B variants may opt in; retail variants set it true).
- Retail-later fields (`sku`, `barcode`, `cost_price`, `track_inventory`) exist now but are optional for F&B.

### ProductOutlet  *(per-outlet product assignment/availability)*
- `id`, `merchant_id`, `outlet_id → Outlet`, `product_id → Product`, `is_available` (bool), `price_override?` (rupiah, nullable — reserved for later)
- `UNIQUE(outlet_id, product_id)`
- **[RULE]** Availability can differ by outlet: `Product.is_available` is the merchant-wide default; a `ProductOutlet` row overrides it for a specific outlet. `price_override` is defined now but stays unused in the MVP (variant price applies).

### ModifierGroup
- `id`, `product_id → Product`, `name` (e.g. "Sugar level"), `min_select`, `max_select`, `required`

### Modifier
- `id`, `modifier_group_id → ModifierGroup`, `name`, `price_delta` (rupiah)
- **[RULE]** Modifiers are additions/customizations only — never inventory-tracked units, never conflated with variants.

### TaxRule
- `id`, `merchant_id`, `outlet_id → Outlet`, `label` (configurable, e.g. "PBJT"), `rate_bps` (basis points, e.g. 1000 = 10%), `service_charge_bps?`, `is_active`
- **[RULE]** Per-outlet; **not** a hard-coded tax type (Constitution VII). Amounts derived server-side.

## Orders & Payments

### Order
- `id` (server UUID), `client_order_id` (client UUID), `merchant_id`, `outlet_id`, `device_id`, `cashier_id → Staff`, `shift_id?`, `type` (`DINE_IN` | `TAKEAWAY` | `RETAIL`), `table_label?`, `status`
- Server-authoritative money fields: `subtotal`, `discount_total`, `tax_total`, `service_charge_total`, `grand_total` (all rupiah)
- Tax/service snapshots (captured at completion): `tax_label_snapshot`, `tax_rate_bps_snapshot`, `service_charge_label_snapshot?`, `service_charge_rate_bps_snapshot?`
- `created_at`, `closed_at?`
- **[RULE]** `UNIQUE(merchant_id, client_order_id)` — the idempotency key (Constitution V).
- **[RULE]** All money fields are recomputed server-side on submit; client-supplied totals are ignored (Constitution III).
- **[RULE]** Once `status = COMPLETED`, the Order row and its lines are **immutable — never updated or deleted**. A void does **not** change `status`; it is recorded as a separate `OrderVoid` (below). The **effective transaction state** (`COMPLETED` / `VOIDED` / `REFUNDED`) is **derived**: `VOIDED` when an `OrderVoid` exists; `REFUNDED` when the total of `Refund.amount` (equivalently, PAID `REVERSAL`/`REFUND` payments) **≥ `grand_total`** — a *partial* refund keeps the stored/effective status `COMPLETED` with a tracked `refundedAmount`. A `VOID`-type reversal does **not** make the order `REFUNDED` (Constitution IV).
- **[RULE]** A void is **same-business-day only** (Asia/Jakarta) and **requires a reason**; older sales are corrected by a refund. A refund **requires a reason** and MAY be **full or line-level partial** (Constitution IV, v1.6.0).
- **[RULE]** An unpaid open bill (`AWAITING_PAYMENT`) MAY be **cancelled** → stored terminal `CANCELLED`, which **releases the reserved stock** via the ledger. This is the only exit from `AWAITING_PAYMENT` besides settlement to `COMPLETED`; no money moves.

**Order status lifecycle (stored)**: `DRAFT → HELD → AWAITING_PAYMENT → COMPLETED`, with an unpaid open bill able to terminate at `CANCELLED`. The stored `status` never advances past `COMPLETED`; a draft/held order may be discarded before completion. `VOIDED`/`REFUNDED` are **derived effective states**, not stored mutations; `CANCELLED` is a **stored** terminal for an open bill that was never paid.

```
Stored status:   DRAFT ──► HELD ──► AWAITING_PAYMENT ──► COMPLETED   (terminal stored state)
                   │         │              │  └────────► CANCELLED   (unpaid bill abandoned; stock released)
                   └─────────┴──────────────┘  (discard before completion)

Derived effective state of a COMPLETED order:
   COMPLETED  ──(an OrderVoid exists)──►   VOIDED
   COMPLETED  ──(total refunded ≥ grand_total)──►   REFUNDED   (partial refund keeps COMPLETED)
   (a reversal_type=VOID payment does NOT imply REFUNDED — the OrderVoid already means VOIDED)
```

### OrderLine
- `id`, `order_id → Order` (inherits tenancy), `variant_id → ProductVariant`, `qty` (**NUMERIC(12,3)**)
- Snapshots (captured at sale time): `product_name_snapshot`, `sku_snapshot?`, `unit_price_snapshot` (rupiah), `cost_price_snapshot?` (rupiah), `selected_variant_snapshot`, `selected_modifiers_snapshot` (JSON: `[{name, price_delta}]`)
- `line_discount` (rupiah, calculated snapshot), `line_total` (rupiah)
- **[RULE]** Snapshots make completed sales immune to later catalog edits (Constitution IV; FR-016/SC-004).

### OrderDiscount  *(audit-friendly discount record)*
- `id`, `order_id → Order` (inherits tenancy), `order_line_id?` (set when scope = LINE), `scope` (`ORDER` | `LINE`), `kind` (`PERCENT` | `AMOUNT`), `value` (percent-bps or rupiah per `kind`), `discount_amount` (rupiah, **calculated**), `reason?`, `applied_by → Staff`, `approved_by? → Staff`
- **[RULE]** `discount_amount` is computed server-side from `kind`/`value` against the applicable base; it is the authoritative figure. `Order.discount_total` and `OrderLine.line_discount` remain as calculated snapshots (sums of the relevant `OrderDiscount.discount_amount`).
- **[RULE]** Discounts above a configurable threshold MAY require `approved_by` (owner); the API enforces the policy and records both `applied_by` and `approved_by`.

### OrderVoid  *(append-only, immutable — records a full void without mutating the order)*
- `id`, `merchant_id`, `outlet_id`, `order_id → Order`, `client_void_id?` (client UUID), `reason` (**required**), `voided_by → Staff`, `approved_by? → Staff` (manager/owner who authorized a cashier-initiated void; null = self), `created_at`
- **[RULE]** Fully **immutable and append-only** — no fields are ever updated. **No "unvoid" in the MVP.**
- **[RULE]** `UNIQUE(order_id)` — **one full void per order** (a completed order can never receive two void records or two stock restorations). If the device may submit/retry the void, `client_void_id` carries a client-generated idempotency UUID with `UNIQUE(merchant_id, client_void_id)`, so a retried void is a no-op that returns the existing record.
- **[RULE]** The **existence** of an `OrderVoid` for an order makes its effective state `VOIDED`. Full void only (no partial). A void is **same-business-day only** (Asia/Jakarta) — a prior-day sale is refused (`VOID_WINDOW_EXPIRED`) and corrected by a refund instead.
- **[RULE]** Creating an `OrderVoid` also appends compensating `InventoryMovement`(s) (`VOID_RESTORE`), a reversal `Payment` (`direction = REVERSAL`, `reversal_type = VOID`) where a charge was captured, and an `AuditLog` entry — all in one transaction (Constitution II/IV).
- *Future note*: if "unvoid"/correction is ever needed, model it as a new append-only `OrderVoidReversal` record — never by editing `OrderVoid`.

### Refund / RefundLine  *(append-only — full or line-level partial refunds; v1.6.0)*
- **Refund**: `id`, `merchant_id`, `outlet_id`, `order_id → Order`, `client_refund_id?` (client UUID), `reason` (**required**), `amount` (rupiah), `is_full`, `refunded_by → Staff`, `approved_by? → Staff` (manager/owner authorizing a cashier-initiated refund), `created_at`; `UNIQUE(merchant_id, client_refund_id)`.
- **RefundLine**: `id`, `refund_id → Refund` (inherits tenancy), `order_line_id`, `variant_id`, `qty` (**NUMERIC(12,3)**), `amount` (rupiah).
- **[RULE]** Append-only; the `COMPLETED` order and original `CHARGE` are never rewritten. An order MAY carry **several partial refunds up to `grand_total`** (over-refund is refused).
- **[RULE]** Money is **server-computed**: full = the remaining total; a line-level partial returns the picked lines' **proportional share** of `grand_total` (order discount + tax + service included). Each refund appends `InventoryMovement`(s) (`ADJUSTMENT`, `ref_type = ORDER_REFUND`) restoring the refunded quantity's stock, a reversal `Payment` (`reversal_type = REFUND`), and an `AuditLog` — one transaction (Constitution II/IV).
- **[RULE]** Effective `REFUNDED` derives only when the summed refund amount **≥ `grand_total`**; a partial refund keeps `COMPLETED`.

### Payment
- `id`, `merchant_id`, `order_id → Order`, `direction` (`CHARGE` | `REVERSAL`, default `CHARGE`), `reversal_type?` (`VOID` | `REFUND`; **null for `CHARGE`**, required for `REVERSAL`), `reverses_payment_id? → Payment` (set for `REVERSAL`), `method` (`CASH` | `QRIS_SIMULATED`), `amount` (rupiah), `status`, `provider_ref?`, `tendered?` (cash, rupiah), `change?` (cash, rupiah), `created_at`, `paid_at?`
- **[RULE]** Backend owns and validates transitions.
- **[RULE]** A refund/reversal is a **new** `Payment` row with `direction = REVERSAL` referencing the original `CHARGE` via `reverses_payment_id`. The original PAID payment is **never mutated** into a different history (Constitution IV).
- **[RULE]** `reversal_type` disambiguates why the reversal exists: a void-driven reversal is `VOID`; a customer refund is `REFUND`. **A `VOID` reversal MUST NOT make the order derive as `REFUNDED`** — the void is already reflected by the `OrderVoid` (effective `VOIDED`).

**Payment status lifecycle**: `CREATED → PENDING → PAID`; alternate terminals `FAILED` / `EXPIRED` / `CANCELLED`. There is no `REFUNDED` status — a refund is represented by the existence of a successful `REVERSAL` payment with `reversal_type = REFUND`.

```
CHARGE:   CREATED ──► PENDING ──► PAID          (CASH may go CREATED ──► PAID directly on tender)
              │           └──► FAILED / EXPIRED / CANCELLED
REVERSAL: new Payment(direction=REVERSAL, reversal_type=VOID|REFUND, reverses_payment_id=<charge>) ──► PAID
          reversal_type=VOID   → accompanies an OrderVoid (order effective state VOIDED)
          reversal_type=REFUND → order effective state REFUNDED   (MVP: full only)
```

## Inventory (ledger + projection)

### InventoryMovement  *(append-only — source of truth)*
- `id`, `merchant_id`, `outlet_id`, `variant_id → ProductVariant`, `qty_delta` (**NUMERIC(12,3)**, signed), `reason` (`SALE` | `VOID_RESTORE` | `ADJUSTMENT` | `RECEIVE`), `ref_type` (e.g. `ORDER`, `ORDER_VOID`, `ORDER_REFUND`, `ORDER_CANCEL`, `ORDER_REVISE`, `ADMIN`), `ref_id`, `created_by → Staff`, `created_at`
- **[RULE]** Never updated or deleted. A `SALE` writes a negative delta; a stock-restoring void writes a positive delta (`reason = VOID_RESTORE`, `ref_type = ORDER_VOID`). A **refund** and an **open-bill cancel** likewise restore stock with positive `ADJUSTMENT` deltas (`ref_type = ORDER_REFUND` / `ORDER_CANCEL`) (Constitution IV; FR-019, v1.6.0).

### InventoryStock  *(projection — fast current balance)*
- `id`, `merchant_id`, `outlet_id`, `variant_id → ProductVariant`, `quantity_on_hand` (**NUMERIC(12,3)**), `updated_at`
- `UNIQUE(outlet_id, variant_id)`
- **[RULE]** Updated **only** inside the same DB transaction that appends a movement; equals `SUM(qty_delta)` for that (outlet, variant). Never edited standalone.

## Shifts

### Shift
- `id`, `merchant_id`, `outlet_id`, `opened_by → Staff`, `opened_at`, `opening_cash` (rupiah), `closed_by?`, `closed_at?`, `counted_cash?` (rupiah), `expected_cash?` (rupiah), `status` (`OPEN` | `CLOSED`)
- Orders created during an open shift carry its `shift_id`.

### CashMovement
- `id`, `shift_id → Shift`, `type` (`CASH_IN` | `CASH_OUT` | `SALE` | `PAYOUT`), `amount` (rupiah), `note?`, `created_by`, `created_at`

## Attendance  *(v1.6.0)*

### Attendance  *(append-only clock-in/out spans)*
- `id`, `merchant_id`, `staff_id → Staff`, `outlet_id?` (where they clocked in), `clock_in_at`, `clock_out_at?` (null = still on the clock), `created_at`; indexed `(merchant_id, clock_in_at)` and `(staff_id, clock_in_at)`
- **[RULE]** Any authenticated staff records **their own** attendance (clock-in is idempotent while an open span exists; clock-out closes the latest open span). An owner/manager report aggregates spans over a date range (worked minutes per staff). Attendance is a convenience — it **never gates a sale** (Constitution: additive).

## Audit

### AuditLog  *(append-only)*
- `id`, `merchant_id`, `outlet_id?`, `actor_id → Staff`, `action` (`VOID` | `REFUND` | `CANCEL_OPEN_BILL` | `PRICE_EDIT` | ...), `entity_type`, `entity_id`, `before` (JSON), `after` (JSON), `created_at`
- **[RULE]** A cashier-initiated correction records the authorizing manager/owner (`approved_by`) on both the correction record and the audit `after` (Constitution VI, v1.6.0).
- **[RULE]** Written for every sensitive action; part of the same transaction as the action (Constitution VI; FR-026).

## Transactional Invariants (Constitution II — atomic operations)

These operations MUST run inside a single PostgreSQL transaction; partial commits are prohibited:

- **Checkout (complete a sale)**: recompute amounts (incl. `OrderDiscount` rows and tax/service snapshots) → insert `Order` (or return existing by `client_order_id`) → insert `OrderLine`s + `OrderDiscount`s with snapshots → insert `Payment` (`direction = CHARGE`) → for each variant with `track_inventory`, insert negative `InventoryMovement` + update `InventoryStock` → set order `status = COMPLETED`. All-or-nothing (FR-012; SC-006).
- **Void (full, idempotent)**: verify permission → insert append-only `OrderVoid` (**the `Order` row and its lines/totals are NOT rewritten**; `status` stays `COMPLETED`) → insert positive `VOID_RESTORE` `InventoryMovement`(s) + update `InventoryStock` → insert a `Payment` (`direction = REVERSAL`, `reversal_type = VOID`, `reverses_payment_id`) where a charge was captured → write `AuditLog`. All-or-nothing. `UNIQUE(order_id)` (and `UNIQUE(merchant_id, client_void_id)` when supplied) makes a retried void a no-op returning the existing `OrderVoid` — never a second stock restoration. Effective state derives to `VOIDED`.
- **Idempotent submit**: the checkout transaction keys on `UNIQUE(merchant_id, client_order_id)`; a retry returns the existing order without new lines/discounts/movements (FR-022; SC-003).

## Relationship Summary

```
Merchant 1─* Outlet 1─* {Order, TaxRule, InventoryStock, Shift, ProductOutlet}
Merchant 1─* Staff
Merchant 1─* Category 1─* Product 1─* ProductVariant
Product 1─* ModifierGroup 1─* Modifier
Product 1─* ProductOutlet *─1 Outlet        (per-outlet availability / price override)
Order 1─* OrderLine *─1 ProductVariant
Order 1─* OrderDiscount (scope ORDER|LINE; LINE rows also → OrderLine)
Order 1─* Payment (CHARGE) ;  Payment(REVERSAL) *─1 Payment(CHARGE)
Order 1─* OrderVoid (append-only; active row ⇒ effective VOIDED)
ProductVariant 1─* InventoryMovement ;  (Outlet,Variant) 1─1 InventoryStock
Shift 1─* CashMovement ;  Shift 1─* Order
Staff 1─* AuditLog ;  Staff 1─* OrderDiscount (applied_by / approved_by)
```

## Validation Rules (selected, API-enforced)

- Order `grand_total` = `subtotal − discount_total + tax_total + service_charge_total`, all recomputed server-side; `discount_total` = sum of `OrderDiscount.discount_amount`.
- `tax_total` derived from the outlet's active `TaxRule.rate_bps` (snapshotted into `tax_rate_bps_snapshot`/`tax_label_snapshot`); `service_charge_total` from `service_charge_bps` (snapshotted likewise).
- Each `OrderDiscount.discount_amount` is computed from `kind`/`value`; discounts over a configured threshold require `approved_by` (owner).
- A completing sale's captured `Payment(CHARGE)` MUST cover `grand_total` (cash: `tendered ≥ grand_total`, `change = tendered − grand_total`).
- Void allowed only for `COMPLETED` orders and only for `OWNER` role (MVP); it appends an immutable `OrderVoid` (at most one per order via `UNIQUE(order_id)`) and never mutates the order. Refund (a `REVERSAL` payment with `reversal_type = REFUND`) is deferred; partial refund is out of MVP scope.
- Stock movements only for variants with `track_inventory = true`.
- Effective transaction state is derived, not stored: `VOIDED` iff an `OrderVoid` exists (`UNIQUE(order_id)` ⇒ at most one); `REFUNDED` iff a successful `REVERSAL` payment with `reversal_type = REFUND` exists. A `reversal_type = VOID` payment never implies `REFUNDED`.
