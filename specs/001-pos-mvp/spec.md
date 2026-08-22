# Feature Specification: DPOS Mobile POS MVP

**Feature Branch**: `001-pos-mvp`

**Created**: 2026-08-21

**Status**: Draft

**Input**: Build a working prototype/MVP mobile POS for Indonesian F&B merchants (café, restaurant, warung), running on phone and tablet, with a minimal web admin, benchmarked against Mandiri Livin' Merchant. Payments are simulated for the board demo but architected for a real provider later. The data model must be extensible toward simple retail.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Take an order and accept payment (Priority: P1)

A cashier at a warung/café serves a customer: they add items from the catalog (choosing variants and modifiers such as size or sugar level), adjust quantities, optionally apply a discount, choose dine-in or takeaway, then take payment by cash or by showing a QRIS code. The system records the sale and produces a receipt.

**Why this priority**: This is the core reason the product exists — it is the smallest slice that delivers value and is demonstrable to the board on its own.

**Independent Test**: On a single device with a seeded catalog, ring up a multi-item order with a modifier and a discount, take a cash payment, and confirm correct change, a recorded transaction, and a receipt — with no other feature present.

**Acceptance Scenarios**:

1. **Given** a seeded catalog, **When** the cashier adds two items (one with a modifier) and applies a 10% order discount, **Then** the system shows a subtotal, discount, tax, service charge, and grand total that match the merchant's configured rules.
2. **Given** an order with a grand total of Rp 50,000, **When** the cashier tenders Rp 100,000 in cash, **Then** the system displays change of Rp 50,000 and records the sale as completed.
3. **Given** an order ready for payment, **When** the cashier selects QRIS, **Then** the system displays a payment QR for the exact amount and, on confirmation of payment, marks the sale paid and shows a receipt.
4. **Given** a completed sale, **When** the cashier views the receipt, **Then** it shows merchant/outlet header, itemized lines, discounts, tax, service charge, total, payment method, timestamp, and an order number.

---

### User Story 2 - Manage the catalog and tax/fee settings (Priority: P2)

An owner sets up what they sell: categories, products, product variants (each a distinct sellable unit that can carry its own price and, later, SKU/stock), and modifier groups (add-ons/customizations). They configure the outlet's tax label and rate and an optional service charge.

**Why this priority**: Without a catalog and correct tax/fee settings, sales cannot be rung up accurately; but it depends on nothing else and can be demonstrated by itself.

**Independent Test**: Create a category, a product with two variants and one modifier group, set an outlet tax label/rate and service charge, then confirm these appear and compute correctly when building an order.

**Acceptance Scenarios**:

1. **Given** the catalog editor, **When** the owner creates a product with variants "Regular" and "Large" at different prices, **Then** both are sellable and each carries its own price.
2. **Given** a product, **When** the owner adds a modifier group "Sugar level" with options, **Then** those options can be selected on an order line and adjust the line price by the configured amount.
3. **Given** outlet settings, **When** the owner sets a tax label (e.g. "PBJT") and rate and a service-charge rate, **Then** subsequent orders apply that label and rate; changing them does not alter already-completed sales.

---

### User Story 3 - Review transactions and void a sale (Priority: P2)

A cashier or owner reviews the day's transactions and, when needed, voids a sale (e.g. wrong order). Voiding requires permission, is recorded in an audit trail, and restores any stock that was deducted. Completed sales are never silently edited or deleted.

**Why this priority**: Corrections are unavoidable in real operations; doing them safely (audited, permission-gated, non-destructive) protects the books and is a key trust story for the board.

**Independent Test**: Complete a sale, void it as an authorized user, and confirm the original sale remains visible as voided, an audit entry records who did it, and stock is restored — then confirm an unauthorized (cashier) role is refused.

**Acceptance Scenarios**:

1. **Given** a completed sale, **When** an authorized user voids it, **Then** the original sale is preserved and marked voided, and an audit entry records the actor and time.
2. **Given** a voided sale that had deducted stock, **When** the void completes, **Then** the affected stock is restored through a new inventory movement rather than by editing the sale.
3. **Given** a user with only the cashier role, **When** they attempt to void a sale, **Then** the action is denied.

---

### User Story 4 - Sell offline and sync safely (Priority: P2)

Because connectivity is intermittent, the cashier can keep taking cash sales, browsing the catalog, and creating orders while offline. When the connection returns, queued sales sync to the central record exactly once, with no duplicates and no double-counted stock.

**Why this priority**: Reliable offline operation with safe syncing is what makes the product usable in real Indonesian venues and is a core differentiator; it builds on the ordering flow.

**Independent Test**: Put the device offline, complete a cash sale, restore connectivity, and confirm the sale appears once centrally; then force a duplicate sync attempt and confirm it still appears exactly once.

**Acceptance Scenarios**:

1. **Given** no network, **When** the cashier completes a cash sale, **Then** the sale is stored locally and queued for sync.
2. **Given** queued offline sales, **When** connectivity returns, **Then** each sale is submitted to the central record exactly once.
3. **Given** a sale that was already synced, **When** the same submission is retried after a dropped connection, **Then** no duplicate sale and no additional stock movement is created.
4. **Given** the device is offline, **When** the cashier attempts a QRIS payment, **Then** the system clearly indicates QRIS is unavailable offline while still allowing cash.

---

### User Story 5 - Staff sign-in with roles (Priority: P2)

Staff sign in with a PIN. Roles distinguish an owner (who can change prices, void/refund, and see settings) from a cashier (who rings up sales). Every sale is attributed to the staff member and device.

**Why this priority**: Attribution and permission control underpin the void/refund and audit stories and are required for a believable multi-user demo.

**Independent Test**: Create an owner and a cashier, sign in as each, and confirm the cashier is blocked from voiding while the owner is allowed, and that sales record who rang them up.

**Acceptance Scenarios**:

1. **Given** a staff PIN, **When** the staff signs in, **Then** the session reflects their role and permissions.
2. **Given** a completed sale, **When** it is inspected, **Then** it records the staff member and device that created it.

---

### User Story 6 - Multi-outlet and reporting (Priority: P3)

An owner with more than one outlet switches between outlets; catalog and reports are scoped to the selected outlet. The owner views a daily sales total, a breakdown by payment method, and top-selling items.

**Why this priority**: Strengthens the "growing merchant" narrative (matching Livin' Merchant's multi-outlet story) but is not required for the core single-outlet demo.

**Independent Test**: With two outlets seeded, switch outlets and confirm catalog/reporting reflect only the selected outlet; after several sales, confirm the daily total, payment split, and top items match what was rung up.

**Acceptance Scenarios**:

1. **Given** two outlets, **When** the owner selects one, **Then** only that outlet's catalog and transactions are shown.
2. **Given** a set of sales in a day, **When** the owner opens reports, **Then** the daily total, payment-method breakdown, and top items match the sales.

---

### User Story 7 - Web admin (Priority: P3)

An owner uses a web admin to manage products/variants, outlets, and staff, and to view a sales dashboard, without needing the mobile app.

**Why this priority**: A management surface reinforces the multi-outlet/back-office story for the board, but the mobile POS is the primary deliverable.

**Independent Test**: In the web admin, edit a product price and confirm the change is reflected on the mobile app; view the dashboard and confirm it matches recent sales.

**Acceptance Scenarios**:

1. **Given** the web admin, **When** the owner changes a product's price, **Then** the mobile app reflects the new price on subsequent orders.
2. **Given** recent sales, **When** the owner opens the dashboard, **Then** summary figures match the sales recorded.

---

### User Story 8 - Hold open orders (F&B tables) (Priority: P3)

A cashier parks a dine-in order (e.g. assigned to a table) and settles it later, allowing multiple open orders at once.

**Why this priority**: A common F&B need, but the core demo can proceed with immediate settlement.

**Independent Test**: Start an order, hold it against a table label, start a second order, then recall and settle the first.

**Acceptance Scenarios**:

1. **Given** an in-progress dine-in order, **When** the cashier holds it, **Then** it is saved as open and the cashier can start another order.
2. **Given** a held order, **When** the cashier recalls it, **Then** its items are restored and it can be settled.

---

### User Story 9 - Shift / cash drawer (Priority: P3)

A cashier opens a shift at the start and closes it at the end, recording cash in/out and comparing expected versus counted cash. Sales are attributed to the shift.

**Why this priority**: Improves cash accountability and rounds out the operations story, but is not needed for the primary demo.

**Independent Test**: Open a shift, make cash sales, add a cash-out, then close the shift and confirm expected vs counted is computed.

**Acceptance Scenarios**:

1. **Given** an open shift, **When** cash sales and a cash-out occur, **Then** closing the shift shows the expected cash amount to compare against the counted amount.

---

### Edge Cases

- Connectivity drops mid-QRIS payment → the sale is not marked paid; the cashier can retry or switch to cash; no partial record is left.
- Duplicate sync of the same offline sale → recorded exactly once; stock deducted once.
- App closes/crashes mid-checkout → the sale is either fully recorded or not recorded at all (never half-applied).
- A product's price or the outlet's tax rate changes after a sale is completed → the completed sale is unaffected; its receipt still reflects the values at sale time.
- Voiding a sale whose stock has already changed through other activity → stock is adjusted via a new movement, keeping the ledger consistent.
- A cashier attempts a restricted action (void, refund, price edit) → the action is denied and, if attempted, is visible as a denied attempt.
- Stock would go negative → the system records the movement per policy and surfaces the condition rather than silently corrupting the balance.
- Two merchants on the shared system → neither can see or affect the other's data.

## Requirements *(mandatory)*

### Functional Requirements

**Catalog & settings**
- **FR-001**: Merchants MUST be able to organize sellable items into categories, products, and product variants, where a variant is the actual sellable unit and may carry its own price (and later its own SKU and stock).
- **FR-002**: Merchants MUST be able to define modifier groups (additions/customizations such as size or sugar level) that are selectable on an order line and adjust the line price, kept distinct from variants.
- **FR-003**: Merchants MUST be able to mark items available/unavailable and attach a photo.
- **FR-004**: Each outlet MUST have a configurable tax label and rate (not a hard-coded tax type; supporting Indonesian F&B terminology such as PBJT where applicable) and an optional configurable service charge.

**Ordering**
- **FR-005**: Cashiers MUST be able to build an order by adding items with quantities, selecting variants and modifiers, and adding a per-line note.
- **FR-006**: Cashiers MUST be able to apply discounts at the line level and the order level, as a percentage or a fixed amount.
- **FR-007**: Cashiers MUST be able to mark an order as dine-in or takeaway and optionally record a table label.
- **FR-008**: The system MUST support holding (parking) an order and recalling it later, with multiple open orders at once.

**Payment & amounts**
- **FR-009**: The system MUST support cash payment with tender entry and automatic change calculation.
- **FR-010**: The system MUST support a QRIS payment that presents a code for the exact amount and is confirmed as paid, implemented as a simulated provider for the MVP but replaceable by a real payment provider without changing the ordering/checkout flow.
- **FR-011**: The system MUST compute all authoritative monetary amounts (line totals, discounts, tax, service charge, grand total) centrally from catalog and outlet rules, and MUST NOT trust amounts computed on the device.
- **FR-012**: A checkout MUST record the sale, its payment, and any stock change together as a single all-or-nothing operation; it MUST NOT leave a partially recorded sale.

**Receipts**
- **FR-013**: The system MUST show an on-screen receipt preview containing merchant/outlet header, itemized lines with selected variants/modifiers, discounts, tax, service charge, total, payment method, timestamp, and order number; a shareable image fallback MUST be available.
- **FR-014**: The system SHOULD support printing the receipt to a compatible mobile receipt printer; printing MUST NOT be required for a sale to complete.

**History, void & refund**
- **FR-015**: Users MUST be able to view a list of transactions and open a transaction's detail.
- **FR-016**: A completed sale MUST be immutable: it MUST NOT be overwritten or deleted; corrections happen only through new compensating records.
- **FR-017**: Authorized users MUST be able to void a sale; voiding MUST restore any deducted stock through a new inventory movement and MUST be recorded in an audit trail.
- **FR-018**: The system MUST treat void (cancelling a sale) and refund (reversing money on an already-paid sale) as distinct operations; the MVP MUST provide full void, with refund available as a later capability.

**Inventory**
- **FR-019**: Stock changes MUST be recorded as an append-only ledger of movements (a sale creates a negative movement; a stock-restoring void creates a positive movement); the current balance MUST be a projection derived from the ledger and never edited independently.

**Offline & sync**
- **FR-020**: The POS MUST remain operational offline for supported workflows: cash sales, catalog access, order creation, and local transaction queuing.
- **FR-021**: Online-dependent methods such as QRIS MAY be unavailable offline, and the system MUST clearly indicate this.
- **FR-022**: Syncing offline work MUST be idempotent so that a retried submission never creates a duplicate sale or duplicate stock movement.

**Accounts, tenancy & audit**
- **FR-023**: Staff MUST sign in with a PIN, and the system MUST distinguish at least owner and cashier roles, gating sensitive actions (void, refund, price edits) by role.
- **FR-024**: Every sale MUST be attributed to the staff member, device, and (when open) shift that created it.
- **FR-025**: All data MUST be scoped per merchant (and per outlet where applicable), and one merchant MUST NOT be able to read or affect another merchant's data.
- **FR-026**: Sensitive actions MUST write an audit entry capturing actor, before/after, and timestamp.

**Multi-outlet, reporting & admin**
- **FR-027**: Owners MUST be able to register multiple outlets and switch the active outlet, with catalog and reporting scoped to the selected outlet.
- **FR-028**: The system MUST provide daily sales total, payment-method breakdown, and top-selling items.
- **FR-029**: A web admin MUST allow managing products/variants, outlets, and staff and viewing a sales dashboard, reflecting the same central data as the mobile app.

**Localization**
- **FR-030**: The product MUST present amounts in Indonesian Rupiah and use Bahasa Indonesia as the primary interface language (with an English fallback).

**Extensibility**
- **FR-031**: The design MUST allow simple retail to be added later (SKU/barcode per variant, stock tracking, barcode entry) without breaking the existing F&B model or historical records.

### Key Entities *(include if feature involves data)*

- **Merchant**: The business account that owns all data; the top-level tenant.
- **Outlet**: A physical location under a merchant; scopes catalog availability, tax/fee settings, stock, and reporting.
- **Staff**: A person who signs in with a PIN and holds a role (owner/cashier) under a merchant.
- **Category / Product**: Grouping and the sellable concept presented in the catalog.
- **Product Variant**: The concrete sellable unit with its own price (and later SKU/barcode/stock).
- **Modifier Group / Modifier**: Selectable additions/customizations that adjust a line's price; not stock-tracked units.
- **Tax Rule**: An outlet-configurable tax label and rate; plus an optional service charge.
- **Order / Order Line**: A sale in progress or completed; lines snapshot name, price, cost, and selected variant/modifiers at sale time.
- **Payment**: A tender against an order with a lifecycle (created → pending → paid, and alternate terminal states) and method (cash, simulated QRIS).
- **Inventory Movement / Stock Balance**: The append-only ledger of stock changes and the derived current balance per variant per outlet.
- **Shift**: A cashier's working period with opening/closing cash counts; attributes sales.
- **Audit Log**: A record of sensitive actions (void/refund/price edits) with actor and before/after state.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A cashier can complete a typical two-to-three item sale (including one modifier and a payment) in under 30 seconds on both a phone and a tablet.
- **SC-002**: For 100% of sales, the total the customer is charged matches the centrally computed total (device-computed figures never determine the charge).
- **SC-003**: A sale completed while offline appears in the central record exactly once after reconnection, even when its submission is retried — zero duplicates across 100 repeated retry attempts.
- **SC-004**: 100% of completed sales remain unaltered after later catalog/tax changes; their receipts still reflect sale-time values.
- **SC-005**: Every void restores the correct stock and produces an audit entry identifying the actor, in 100% of cases; cashier-role void attempts are refused 100% of the time.
- **SC-006**: No sale is ever left partially recorded (payment without stock, or sale without payment) across induced failures such as app kill during checkout.
- **SC-007**: Reports (daily total, payment-method split, top items) match the underlying sales exactly for a test day.
- **SC-008**: No merchant can retrieve or modify another merchant's data in any tested path.
- **SC-009**: The end-to-end demo (take order → pay by cash and by simulated QRIS → receipt → view transaction → void) runs successfully on a phone and a tablet without a physical printer.

## Assumptions

- The MVP centers on F&B (café/restaurant/warung); simple retail is a planned later extension, so the model must not lock out retail.
- Payments are simulated for the board demo; no live payment-provider onboarding is in scope, but the flow must be provider-swappable.
- Target devices are primarily Android phones and tablets, consistent with the Indonesian market.
- A single currency (Indonesian Rupiah) is used throughout the MVP.
- QRIS acceptance requires connectivity; cash is the guaranteed offline tender.
- A minimal web admin is in scope for this MVP; advanced back-office features (online store, kiosk/QR-table self-order, distributor stock purchasing, settlement/withdrawal) are out of scope.
- Central data lives in an Indonesia region to respect data residency.
