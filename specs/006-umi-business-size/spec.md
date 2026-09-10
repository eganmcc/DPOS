# Feature Spec — UMI (Ultra Mikro) Business Size

**Feature ID:** 006-umi-business-size
**Status:** In progress
**Applies to:** All business types (F&B + Grocery) — business size is orthogonal to business type.
Constitution v1.7.0.

## Why
**UMi = Ultra Mikro** is the very bottom of Indonesia's micro-business segment: individual
entrepreneurs at very small scale, many still unbankable or unable to access normal bank financing
or KUR — street-food vendors, tiny warungs, home-based sellers, small barbers, market traders.

In DPOS terms a UMI merchant is **a one-person operation**, and today's product assumes more than
one person: a correction expects a second party to approve it, catalog and price management live
only in the D-Customer Portal, and reporting is portal-first. This adds a `businessSize` axis and
makes UMI self-sufficient inside the Flutter app — no portal, in-app gross-profit reporting, in-app
item/price management with a **30-item cap** (so a larger business cannot take UMI pricing), no user
management, and corrections that don't demand a PIN nobody else can supply.

The base POS is stabilizing, so every server change is an `if (isUmi)` at a leaf: no refactor of the
correction path, no new abstraction in the money engine, and nothing changes for a `GENERAL` merchant.

## User Stories & Acceptance

### A. Business size on the merchant
1. `Merchant.businessSize` ∈ `GENERAL` | `UMKM` | `UMI`, defaulting to **`GENERAL`**, orthogonal to
   `businessType` — a UMI merchant is still F&B *or* grocery.
2. Both existing demo merchants ("Warung Kopi Demo", "Toko Sembako Demo") are **`GENERAL`**.
3. Size is set by **DPOS provisioning** (`prisma/set-business-size.ts` or SQL) and is **read-only**
   over the API: returned by `GET /admin/entity` and `GET /catalog`, accepted by **no** endpoint. A
   merchant MUST NOT be able to change its own size.

### B. Corrections without a manager PIN
1. A UMI merchant's operator voids / refunds / cancels **without an approver PIN, whatever their
   role** — there is no second person to approve.
2. **The reason stays mandatory.** A void with no reason is refused (`400`) exactly as today; it IS
   the audit record.
3. Everything else about a correction is unchanged: append-only `OrderVoid` / `Refund`, stock
   restored through the ledger, a reversal `Payment`, an `AuditLog`, and the same-business-day VOID
   window (Asia/Jakarta).
4. Every correction — UMI or not — records an **approval basis** (`SELF` | `UMI_BYPASS` |
   `APPROVER_PIN`) in its `AuditLog`, so a null `approvedById` is never ambiguous.
5. A `GENERAL` merchant is **unaffected**: a cashier still gets `403 APPROVAL_REQUIRED` without a
   PIN and `403 APPROVAL_INVALID` with a wrong one.

### C. No portal access
1. A UMI owner's **email/password login is refused** with `403 PORTAL_NOT_AVAILABLE` and a
   plain-language message: *"This account manages its business in the DPOS app."*
2. **PIN login is unaffected** — the operator signs into the app normally and still receives
   `role: OWNER`, which is what the in-app admin features depend on.
3. **No user management**: `POST /admin/staff` returns `403 UMI_SINGLE_USER`. The sole owner can
   still rename themselves and rotate their own PIN.

### D. In-app profit & loss (gross margin)
1. Reports gains a **Laba Kotor** card: Pendapatan (revenue) − Modal barang (COGS) = Laba kotor,
   with the margin percentage.
2. COGS comes from `OrderLine.costPriceSnapshot` (already written on every sale) × line qty. **No
   schema change.**
3. Revenue is **`netRevenue` = Σ (subtotal − discountTotal)** — tax and service charge excluded, so
   margin is not inflated for a merchant with a `taxRule`. The existing `netSales` is unchanged.
4. Items with **no cost price are surfaced, never swallowed**: a visible warning states how many
   sales lines lack a cost and links straight to the Items screen to fix them.
5. It is labelled **gross** profit ("Laba Kotor"), never bare "Laba" — it excludes rent, gas,
   packaging and the operator's own time.

### E. In-app item & price management (30-item cap)
1. A UMI owner manages items in the app: list, add, and edit price / cost price / SKU /
   availability, plus on-hand when the variant tracks inventory.
2. The catalog is capped at **30 products**. The 31st `POST /admin/products` is refused with
   `400 ITEM_LIMIT_REACHED`.
3. **The cap is a hard stop by design** — there is no self-service way to free a slot, so the
   message says *contact DPOS*, never "switch one off".
4. The app shows the count (`24 / 30`) and disables **Add** at the limit; the server is nonetheless
   authoritative, and its refusal is surfaced as a localized message.

### F. A UMI operator lands on the till
1. A UMI owner logging in by PIN lands on the **POS**, not Reports — their next action is always
   ringing up a customer. Reports stays one tap away on the app bar.
2. **Attendance is suppressed** for UMI (no clock-in prompt, no attendance section, and the report
   is not even fetched) — a one-person business has nobody to track.
3. A `GENERAL` merchant's home, attendance and prompts are **unchanged**.

## Invariants (Constitution II/III/IV/VI)
- **The bypass changes only WHO may authorize a correction, never what a correction does.**
  Append-only compensating records, ledger-routed stock, the same-day VOID window, the mandatory
  reason, and the `AuditLog` are all unchanged.
- **Business size never touches money, stock, or lifecycle rules.** It gates authorization, surface
  availability, and a catalog cap — nothing else.
- **The server is authoritative for every UMI rule.** The item cap, the staff block, the portal
  lockout and the approval bypass are enforced server-side; the app's copies are UX only.
- **Never gate a server-side rule on the cached flag.** The app's `businessSize` arrives on the
  catalog, which is cached as an opaque blob, so it defaults to `GENERAL` (fail-closed) when absent.
- **Size is read-only over the API** — provisioned by DPOS, not settable by the merchant.

## Data model (additive migration)
- `BusinessSize` enum: `GENERAL` | `UMKM` | `UMI` (a **new** enum — `CREATE TYPE` is
  transaction-safe, unlike `ALTER TYPE … ADD VALUE`; `BusinessType` is a separate axis and is not
  extended).
- `Merchant += businessSize BusinessSize @default(GENERAL)` — `ADD COLUMN NOT NULL DEFAULT` is
  metadata-only on PG 11+, so no rewrite of the live `merchants` table and existing rows backfill to
  `GENERAL`.
- **No other schema change.** The P/L reads `OrderLine.costPriceSnapshot`, which already exists and
  is already populated; the approval basis rides the existing `AuditLog.after` JSON blob, so
  `OrderVoid.approvedById` and `Refund.approvedById` keep their meaning.

## API (all guarded, merchant from JWT)
- `GET /catalog` — **+ `businessSize`** (drives UMI-only app UI), beside the existing `businessType`.
- `GET /admin/entity` — **+ `businessSize`**, read-only. `UpdateMerchantDto` does **not** accept it;
  `ValidationPipe({whitelist:true})` strips it from any PATCH body.
- `GET /admin/dashboard` — **+ `netRevenue`, `cogs`, `grossProfit`, `grossMarginBps`,
  `costCoverage{linesTotal, linesMissingCost, itemsMissingCost}`**. Purely additive; every existing
  key, `netSales` included, is byte-identical.
- `POST /auth/login` (email + password) — `403 PORTAL_NOT_AVAILABLE` for a UMI merchant, checked
  **after** the password comparison so an unauthenticated prober cannot enumerate emails.
- `POST /admin/products` — `400 ITEM_LIMIT_REACHED` at 30 products for a UMI merchant.
- `POST /admin/staff` — `403 UMI_SINGLE_USER` for a UMI merchant. `PATCH` and the PIN reset stay open.
- `POST /orders/:id/{void,refund,cancel}` — unchanged signatures; `approverPin` is simply unused for
  a UMI merchant.

Authorization stays in the services rather than a role guard: `resolveCorrectionApprover` returns
early for OWNER/MANAGER, **then** for a UMI merchant, and only otherwise requires the PIN.

## App
- **Catalog model** (`data/models.dart`): `Catalog.businessSize` + `isUmi`, defaulting to `'GENERAL'`
  in `fromJson` so a stale cached catalog decodes and fails closed.
- **Corrections** (`features/transactions/`, `features/order/open_bills_screen.dart`): the
  approver-PIN prompt is skipped when `isUmi`; a void action moves onto the history tile so the path
  is 2 taps instead of 5, reason intact. Shared logic lands in `core/void_actions.dart`, mirroring
  `core/attendance_actions.dart`.
- **Reports** (`features/reports/reports_screen.dart`): a Laba Kotor card built from the existing
  `_SectionCard` / `_Row` widgets; attendance suppressed for UMI; an Items entry point on the app bar.
- **Items** (`features/items/items_screen.dart`, UMI-only): mirrors the portal's `PricesView.vue`
  phone-shaped, minus the branch picker (a UMI merchant has one outlet). New `AdminProduct` /
  `AdminVariant` models carrying `costPrice` — **`/catalog` is deliberately not widened with
  `costPrice`**, which would push cost prices into every cashier device's offline cache.
- **Home** (`features/scanner/home_gate.dart`): a UMI owner lands on `PosHome`, not `ReportsScreen`.

## Verification (integrity suite + device)
- **`server/test/umi.e2e-spec.ts`**: a UMI cashier voids / cancels / refunds with **no** `approverPin`
  (200, records written, stock restored, audit basis `UMI_BYPASS`); a UMI void with **no reason** →
  400 and nothing written; 30 products → `ITEM_LIMIT_REACHED`; `POST /admin/staff` → `UMI_SINGLE_USER`;
  UMI owner password login → `PORTAL_NOT_AVAILABLE` while a GENERAL owner still gets a token; and the
  P/L arithmetic including a missing-cost line, asserting `netSales` is unchanged.
- **Regression fence** — `orders.void`, `orders.cancel` and `orders.refund` e2e specs are GENERAL and
  MUST stay green **untouched**. Editing one means the UMI check has leaked into the general path.
- **Device**: provision a demo merchant to UMI → portal login refused → app PIN login lands on the
  POS → sale → 2-tap void with a reason and no PIN → Reports shows Laba Kotor + the missing-cost
  warning → Items adds an item and refuses at 30 → revert to GENERAL and confirm the PIN prompt,
  portal login and portal-managed items all return.

## Not in scope (later)
- **A DPOS super-admin surface** to manage business entity type/size and other platform functions.
  Until it exists, size is set in the database. When it arrives it MUST get its own auth path rather
  than reusing `loginOwner`, or the UMI portal check ends up in the wrong place.
- **Deducting refunds from reported revenue and COGS.** `live` excludes voided orders only, so a
  partially-refunded sale still contributes full revenue and full COGS. Pre-existing and consistent
  with today's `netSales`; fixing it changes an existing number and needs its own change.
- **A product-level availability toggle**, which would turn the item cap into a self-service limit
  ("switch one off to add another") instead of a hard stop.
- **UMKM-specific behaviour.** The enum carries `UMKM` so the axis is complete, but only `UMI`
  changes behaviour today; `UMKM` behaves as `GENERAL`.
