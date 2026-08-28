# Feature Spec — D-Customer Portal (Admin Web App)

**Feature ID:** 002-customer-portal
**Status:** Implemented (MVP)
**Owner login:** account OWNER only

## Why
Merchants need a back-office to run their business beyond the cashier app: see how sales are
doing, manage their people, keep stock and prices correct, and configure the company and its
branches. The portal is a Vue 3 + Vite SPA on the existing REST API, styled with the DIKA theme,
and adapts to the merchant's **business type** (F&B vs general groceries).

## Who
- **Owner / account admin** — the only role that signs into the portal (email + password).
- Manages **staff** who use the cashier app (cashier, server, manager) and their PINs.

## User Stories & Acceptance
1. **Sign in & see versions.** As an owner I sign in with email/password; the login screen and the
   left nav show the portal version and the live backend version. Non-owners are refused.
2. **Sales dashboard.** I see net sales, order count, average ticket, sales-by-day, and breakdowns
   by payment method / branch / top items, filterable by branch and date range. Voided sales are
   excluded from revenue.
3. **Resource (staff) management.**
   - Personal info: name, phone (+ email for owner/manager web login). An **employee ID**
     (`EMP0001…`) is generated on create.
   - Role: cashier · server · manager (· owner).
   - Assignment: HQ / all branches (no outlet) or a specific branch.
   - PIN management: assign on create, update anytime. PINs are bcrypt-hashed and never returned.
4. **Inventory management.** Per branch, I see on-hand quantities and can adjust them; an adjustment
   writes an `ADJUSTMENT` movement to the ledger and updates the projection atomically.
5. **Price setting.** I edit each variant's selling price, cost price, and availability.
6. **Entity settings.**
   - Company: name, business type (FNB | GROCERY), logo URL.
   - **F&B-specific:** per-branch **bill settlement** — pay now (immediate) or pay later (open
     bill). Hidden for grocery.
   - Branch management: branch **code** (unique per merchant), name, address, branch **manager**.
7. **Seeded admin.** An owner login exists for both a seeded **F&B** merchant and a seeded
   **grocery** merchant so the type-specific behaviour can be demonstrated.

## Functional Requirements
- All admin endpoints are **OWNER-gated** and **merchant-scoped** from the JWT (Constitution VI).
- Secrets (PIN, password) are bcrypt-hashed at rest and never serialized back.
- Inventory edits never write the balance directly — they append to `inventory_movements` and
  update `inventory_stock` in one transaction (Constitution IV).
- Money is integer rupiah end-to-end; the server owns all money math (Constitution III).
- Branch code is unique per merchant; a duplicate is rejected.
- Business type is a `Merchant` attribute; it only toggles presentation/behaviour, never money,
  stock, or lifecycle rules.

## Entities (additions to the Phase-1 data model)
- `Merchant.businessType` (FNB | GROCERY), `Merchant.logoUrl`.
- `StaffRole` adds `MANAGER`, `SERVER` (alongside `OWNER`, `CASHIER`).
- `Staff.employeeId` (unique per merchant), `Staff.phone`, `Staff.outletId` (null = HQ).
- `Outlet.code` (unique per merchant), `Outlet.managerId`.

## API (all under `/api/v1`, OWNER-gated unless noted)
- `GET /version` (public) — backend version.
- `GET/PATCH /admin/entity` — company profile.
- `GET/POST /admin/entity/branches`, `PATCH /admin/entity/branches/:id` — branches.
- `GET/POST /admin/staff`, `PATCH /admin/staff/:id`, `POST /admin/staff/:id/pin` — resources.
- `GET /admin/products`, `PATCH /admin/products/variants/:id` — prices/availability.
- `GET /admin/inventory?outletId=`, `POST /admin/inventory/adjust` — stock.
- `GET /admin/dashboard?outletId=&from=&to=` — sales summary.

## Verification
- Build: `customer-portal` `npm run build` type-checks and bundles; backend `tsc` clean.
- End-to-end (live API): owner login → each section loads; create staff yields an employee ID;
  duplicate branch code is rejected (400); price update, stock adjust (writes a movement), and
  company/branch edits persist; dashboard aggregates match seeded/live sales; grocery vs F&B login
  shows the bill-settlement setting only for F&B.

## Out of scope (this MVP)
- Production hosting of the portal (runs locally against the live API for now).
- Logo file upload (URL only), shifts/cash-drawer admin, product/category create-delete,
  tax-rule editing, and per-manager (non-owner) portal access.
