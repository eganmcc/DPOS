# Feature Spec — Corrections (Void / Refund / Cancel), Manager Approval, Attendance & In-App Reporting

**Feature ID:** 005-corrections-attendance
**Status:** Implemented
**Applies to:** All business types (F&B + Grocery). Constitution v1.6.0.

## Why
A real POS must correct finalized and in-flight sales safely, and give owners/managers visibility
into sales and staff. This ships the correction lifecycle (void, refund, open-bill cancel) with the
controls that make it audit-safe (authorization, mandatory reason, time window), plus an
owner/manager reporting home and employee attendance — all on the same server-authoritative,
append-only foundations (Constitution I–VI), never a client-side money or stock rule.

## User Stories & Acceptance

### A. Void a completed sale (same-day)
1. From **Riwayat → a paid sale from today**, an OWNER/MANAGER sees **Batalkan transaksi (Void)**.
2. Void **requires a reason** (quick-pick chips + free text; confirm disabled until non-empty).
3. A sale **older than today** (Asia/Jakarta) cannot be voided — the server refuses with
   `409 VOID_WINDOW_EXPIRED` and the app shows *"Voids are only allowed on the same day — issue a
   refund instead"* with the Void button replaced by **Refund**.
4. Void stays append-only (US3): an `OrderVoid`, stock-restoring movements, a `VOID` reversal
   `Payment` per charge, and an audit entry; effective status derives to **VOIDED**.

### B. Refund a completed sale (full or partial)
1. **Refund** is available to OWNER/MANAGER on any completed in-store sale with money still
   refundable (a partially-refunded sale shows *"Sudah direfund: Rp…"* and stays refundable).
2. The refund sheet offers **Penuh (Full)** or **Per item (line-level)** with per-line quantity
   steppers, a **mandatory reason**, and a live **estimated refund**.
3. A refund restores exactly the refunded quantity's stock and records an append-only `Refund`
   (+ `RefundLine`) plus a `REFUND` reversal `Payment`. **Money is proportional** — a line-level
   refund returns the picked lines' share of the grand total (tax/service/discount included).
4. Several partials are allowed **up to the grand total** (over-refund is refused); effective
   **REFUNDED** derives only when the whole total is returned. Online (platform-paid) sales are
   not refunded in-app (the platform owns that).

### C. Cancel an unpaid open bill
1. On **Pesanan**, each open bill has a **Batalkan pesanan (Cancel)** action.
2. Cancel **requires a reason**, **releases the reserved stock**, and moves the order to the new
   terminal stored status **`CANCELLED`** (kept in history; no money moves).
3. Only an `AWAITING_PAYMENT` bill can be cancelled; a second attempt returns `409`.

### D. Manager PIN override (cashier-initiated corrections)
1. Void/refund/cancel buttons show for **all** staff. OWNER/MANAGER self-authorize.
2. A **CASHIER** who confirms one is prompted for a **manager/owner PIN**. The server verifies it
   against an active OWNER/MANAGER of the merchant and records that staff as **`approvedById`**.
3. A missing PIN → `403 APPROVAL_REQUIRED`; a wrong PIN → `403 APPROVAL_INVALID`.

### E. Employee attendance
1. Any staff clocks in/out; a clock-in span (`Attendance`) is open until clocked out.
2. The app **prompts to clock in after login** and **offers to clock out on logout** (Settings +
   Reports). Clocking out is distinct from logging out (shared terminals stay logged in).
3. Owner/manager see an **Absensi** section in Reports: who clocked in/out in the period, hours,
   and an "on the clock" badge for anyone still in.

### F. Owner/manager reporting home
1. Logging in as **OWNER/MANAGER** lands on a **Laporan (Reports)** home; cashiers land on the POS.
2. Reports shows net sales, orders, avg ticket, payment breakdown, top items, by-outlet, a
   sales-by-day chart, and attendance — over a **Harian / Mingguan / Bulanan** toggle.
3. The **cashier POS stays reachable** ("Buka kasir"); History, Settings, and Logout are on the bar.

## Invariants (Constitution II/III/IV/VI)
- Every correction runs in **one transaction** and is **append-only**: the `COMPLETED` order, its
  lines, and the original `PAID` charge are never rewritten. Effective `VOIDED`/`REFUNDED` derive
  from compensating records; `CANCELLED` is a stored terminal for an **unpaid** open bill only.
- **Stock always moves through the ledger** — void/refund/cancel each write `inventory_movements`
  (+ transactional projection), never an in-place balance edit.
- The **server owns the money**: refund amounts (full = remaining total; partial = proportional
  share) are computed server-side; the app's estimate is display-only.
- **Idempotency**: void via `UNIQUE(orderId)` / `(merchantId, clientVoidId)`; refund via
  `(merchantId, clientRefundId)`; cancel via a conditional `AWAITING_PAYMENT → CANCELLED` flip so a
  retry never double-restores stock.
- **Authorization + audit**: corrections are OWNER/MANAGER, or CASHIER-with-manager-PIN (approver
  recorded); each writes an `AuditLog`. Attendance/reporting never gate a sale.

## Data model (additive migrations)
- `OrderStatus += CANCELLED` (abandoned unpaid open bill).
- `Refund` *(append-only)*: `id`, `merchant_id`, `outlet_id`, `order_id → Order`,
  `client_refund_id?`, `reason`, `amount`, `is_full`, `refunded_by → Staff`, `approved_by?`,
  `created_at`; `@@unique(merchant_id, client_refund_id)`.
- `RefundLine`: `id`, `refund_id → Refund`, `order_line_id`, `variant_id`, `qty` (Decimal),
  `amount`.
- `OrderVoid += approved_by?` (manager who authorized a cashier-initiated void; null = self).
- `Attendance`: `id`, `merchant_id`, `staff_id → Staff`, `outlet_id?`, `clock_in_at`,
  `clock_out_at?`, `created_at`; indexed `(merchant_id, clock_in_at)` and `(staff_id, clock_in_at)`.
- Order mapping adds derived `refundedAmount`; `REFUNDED` derives when `refundedAmount ≥ grandTotal`.

## API (all guarded, merchant from JWT)
- `POST /orders/:id/void` — `{ clientVoidId?, reason, approverPin? }`. Same-day only; any staff may
  initiate (cashier needs `approverPin`).
- `POST /orders/:id/refund` — `{ clientRefundId?, reason, full?, lines?[{orderLineId, qty}],
  approverPin? }`. Full or line-level; idempotent; multiple partials up to the total.
- `POST /orders/:id/cancel` — `{ reason, approverPin? }`. Open bill → `CANCELLED`, releases stock.
- `GET /attendance/me`, `POST /attendance/clock-in` `{ outletId? }`, `POST /attendance/clock-out` —
  any authenticated staff (self).
- `GET /admin/attendance?from=&to=` — OWNER/MANAGER attendance report.
- `GET /admin/dashboard?from=&to=` — OWNER/MANAGER sales summary (opened from OWNER to OWNER+MANAGER).

Authorization is enforced in the services (not only a role guard) so a cashier can initiate with a
manager PIN: `resolveCorrectionApprover` returns null for OWNER/MANAGER, else verifies the PIN
(bcrypt) against an active OWNER/MANAGER and returns the approver id.

## App
- **Transaction detail** (`features/transactions/transaction_detail_screen.dart`): a bottom bar with
  **Void** (same-day) + **Refund** for all staff; a required-reason void dialog; a refund composer
  sheet (full/by-item, reason, estimate); a manager-PIN dialog for cashiers; server error codes
  (`VOID_WINDOW_EXPIRED`, `APPROVAL_REQUIRED`, `APPROVAL_INVALID`) mapped to messages.
- **Open bills** (`features/order/open_bills_screen.dart`): a Cancel action per bill (reason + PIN,
  invalidates open bills + catalog so released stock shows).
- **Reports** (`features/reports/reports_screen.dart`): owner/manager home via `HomeGate`; period
  toggle; sales sections + attendance section; "Buka kasir" opens `PosHome`.
- **Attendance prompts** (`core/attendance_actions.dart`): `promptClockInOnLogin` (HomeGate,
  post-first-frame) and `promptClockOutThenLogout` (Settings + Reports logout). The manual Settings
  toggle is hidden (the prompts cover it); can return for shared-terminal use.
- **Models**: `OrderResult.refundedAmount` + `refundedQtyByLine` (qty parsed as string-or-number —
  Decimal serializes as a string), `canBeRefunded` / `isPartiallyRefunded`; `AttendanceRecord`,
  `AttendanceRow`, `DashboardSummary`.

## Verification (behavioral, on prod)
- Void: no reason → 400; same-day + reason → VOIDED; prior-day → 409 `VOID_WINDOW_EXPIRED`.
- Refund: reason required; partial (1 of 2) → proportional amount, stock net −1, status stays
  COMPLETED; over-refund → 400; full → REFUNDED; re-refund → 409.
- Cancel: open bill reserves stock; cashier no-PIN → 403 `APPROVAL_REQUIRED`; manager PIN →
  `CANCELLED`, stock fully restored, gone from open bills; re-cancel → 409.
- Approval: cashier void/refund/cancel — no PIN → 403 REQUIRED, wrong PIN → 403 INVALID, manager
  PIN → succeeds with `approvedById` recorded; owner self-serves with no PIN.
- Attendance: clock-in → `/attendance/me` open → owner report row → clock-out records minutes.
- Reporting: manager `/admin/dashboard` and `/admin/attendance` → 200 over the selected range.

## Not in scope (later)
- **Async approval inbox** (a cashier submits a correction request a manager approves remotely +
  general messages + notification counts) — the synchronous PIN override ships now; the inbox is a
  follow-up.
- Shift-based void window (currently same calendar day, Asia/Jakarta) — revisits when shift
  open/close is built.
- Real PSP/cash/platform money movement on refund (the record + stock are reversed; the money step
  is operational/provider).
