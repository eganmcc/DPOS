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
- `id`, `merchant_id → Merchant`, `name`, `role` (`OWNER` | `CASHIER`), `pin_hash`, `email?`, `password_hash?` (owners), `is_active`
- **[RULE]** `pin_hash`/`password_hash` are hashed (bcrypt/argon2), never stored plain.
- **[RULE]** `CASHIER` cannot void/refund or edit prices; `OWNER` can (enforced by API guard).

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
- **[RULE]** Once `status = COMPLETED`, the Order row and its lines are **immutable — never updated or deleted**. A void does **not** change `status`; it is recorded as a separate `OrderVoid` (below). The **effective transaction state** (`COMPLETED` / `VOIDED` / `REFUNDED`) is **derived**: `VOIDED` when an `OrderVoid` exists; `REFUNDED` when a successful `Payment` with `direction = REVERSAL` and `reversal_type = REFUND` exists. A `VOID`-type reversal does **not** make the order `REFUNDED` (Constitution IV).

**Order status lifecycle (stored)**: `DRAFT → HELD → AWAITING_PAYMENT → COMPLETED`. The stored `status` never advances past `COMPLETED`; a draft/held order may be discarded before completion. `VOIDED`/`REFUNDED` are **derived effective states**, not stored mutations.

```
Stored status:   DRAFT ──► HELD ──► AWAITING_PAYMENT ──► COMPLETED   (terminal stored state)
                   │         │              │
                   └─────────┴──────────────┘  (discard before completion)

Derived effective state of a COMPLETED order:
   COMPLETED  ──(an OrderVoid exists)──►   VOIDED
   COMPLETED  ──(a successful REVERSAL Payment, reversal_type=REFUND)──►   REFUNDED
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
- `id`, `merchant_id`, `outlet_id`, `order_id → Order`, `client_void_id?` (client UUID), `reason?`, `voided_by → Staff`, `created_at`
- **[RULE]** Fully **immutable and append-only** — no fields are ever updated. **No "unvoid" in the MVP.**
- **[RULE]** `UNIQUE(order_id)` — **one full void per order** (a completed order can never receive two void records or two stock restorations). If the device may submit/retry the void, `client_void_id` carries a client-generated idempotency UUID with `UNIQUE(merchant_id, client_void_id)`, so a retried void is a no-op that returns the existing record.
- **[RULE]** The **existence** of an `OrderVoid` for an order makes its effective state `VOIDED`. Full void only (no partial).
- **[RULE]** Creating an `OrderVoid` also appends compensating `InventoryMovement`(s) (`VOID_RESTORE`), a reversal `Payment` (`direction = REVERSAL`, `reversal_type = VOID`) where a charge was captured, and an `AuditLog` entry — all in one transaction (Constitution II/IV).
- *Future note*: if "unvoid"/correction is ever needed, model it as a new append-only `OrderVoidReversal` record — never by editing `OrderVoid`.

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
- `id`, `merchant_id`, `outlet_id`, `variant_id → ProductVariant`, `qty_delta` (**NUMERIC(12,3)**, signed), `reason` (`SALE` | `VOID_RESTORE` | `ADJUSTMENT` | `RECEIVE`), `ref_type` (e.g. `ORDER`, `ORDER_VOID`), `ref_id`, `created_by → Staff`, `created_at`
- **[RULE]** Never updated or deleted. A `SALE` writes a negative delta; a stock-restoring void writes a positive delta with `reason = VOID_RESTORE` and `ref_type = ORDER_VOID` (Constitution IV; FR-019).

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

## Audit

### AuditLog  *(append-only)*
- `id`, `merchant_id`, `outlet_id?`, `actor_id → Staff`, `action` (`VOID` | `REFUND` | `PRICE_EDIT` | ...), `entity_type`, `entity_id`, `before` (JSON), `after` (JSON), `created_at`
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
