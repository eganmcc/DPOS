# Feature Spec — F&B Online-Delivery Orders (GoFood / GrabFood / ShopeeFood)

**Feature ID:** 004-online-orders
**Status:** Implemented (MVP demo) — designed for real provider integration
**Applies to:** FNB business type. Grocery is unaffected.

## Why
F&B outlets receive a large share of orders from Indonesian delivery platforms (GoFood,
GrabFood, ShopeeFood). The cashier must be told the moment one arrives and be able to
acknowledge it. This ships a working **demo** (a simulator injects orders) on top of the
**real, production-shaped pipeline**, so connecting the actual platforms later is an
adapter, not a rewrite.

## User Stories & Acceptance
1. **Arrival.** While an F&B cashier is logged in, online orders arrive (demo: one every
   **2–5 min**, random vendor, random in-stock items). Each new order **counts up a red badge**
   on the **"Pesanan"** button and triggers a **TTS** announcement:
   *"Ada Online Order Baru dengan nomor {ref} Dari {vendor}"*.
2. **Visibility.** On an immediate-pay F&B outlet the "Pesanan" button is hidden until the first
   online order arrives, then appears (badge = count of unprocessed orders). Open-bill outlets
   show it as before; the Pesanan screen lists **Online orders** (NEW pinned first, vendor icon,
   `#ref · Vendor`, a **Baru** chip) above **Open bills**.
3. **Process.** A single **Terima (Accept)** tap acknowledges an order (NEW → ACCEPTED), which
   removes it from the badge count. Processed orders remain in the list and open their receipt.
4. **Lifecycle.** The demo generator + polling **start on login and stop on logout** — nothing
   runs while signed out or on a grocery session. A Settings toggle (F&B only) disables the demo.

## Invariants (Constitution I/III/IV)
- Online orders are **first-class server Orders**, not a parallel table: same `Order`/`OrderLine`
  rows, **server-authoritative** totals via `computeOrder`, same inventory decrement + `(merchantId,
  clientOrderId)` idempotency guard as an in-store checkout. The **DB is the source of truth**; the
  app only displays and polls.
- A platform order is **paid by the platform**, so it lands `status=COMPLETED` with a synthetic
  `Payment{method=ONLINE, status=PAID}` and `onlineStatus=NEW` (fulfillment, tracked separately).
  It counts as a real sale in history/reporting.
- Money stays integer rupiah; the client never computes a total.

## Data model
`OrderChannel { POS GOFOOD GRABFOOD SHOPEEFOOD }`, `OnlineOrderStatus { NEW ACCEPTED PREPARING
READY COMPLETED CANCELLED }`, `PaymentMethod += ONLINE`. On `Order`: `channel` (default POS),
`onlineStatus?`, `externalOrderRef?`, `customerName?`, `@@index([outletId, onlineStatus])`. Additive
migration — existing rows become `channel=POS`.

## API (all guarded, merchant from JWT)
- `GET /online-orders?outletId=&status=` — queue (NEW first).
- `POST /online-orders/:id/accept` — NEW → ACCEPTED (conditional update, idempotent).
- `POST /online-orders/simulate` — **DEMO** injection (random vendor + in-stock items).

## The ingestion seam (why it isn't throwaway)
Both the demo simulator and future webhooks call one `OnlineOrdersService.ingest(normalizedInput)`
that owns the server-authoritative transaction. Real integration adds, per provider, a **public**
webhook controller that verifies the platform signature, maps `externalStoreId → outletId` and
`externalItemId → variantId` (future `ChannelStoreMapping` / `ChannelItemMapping` tables), normalizes
the payload, and calls the same `ingest`. Platform cancellations map to the existing `OrderVoid`
(derived VOIDED). The `simulate` endpoint is the only demo-specific surface to remove.

## App
- `announceOnlineOrder(ref, vendor)` in `core/tts.dart` (id-ID, rate 0.5, fire-and-forget).
- `OnlineOrdersNotifier` (`features/order/online_orders_controller.dart`): 15s poll (announces new
  arrivals), 2–5 min demo timer, `accept`; session-scoped via `HomeGate` watching it (F&B only).
- Badge on the "Pesanan" button (`order_screen.dart`); Online section in the Pesanan screen
  (`open_bills_screen.dart`); vendor icon (`vendor_icon.dart`) — official PNG when bundled in
  `assets/images/`, else a brand-colour monogram fallback.

## Out of scope
Real provider webhook adapters + signature verification + store/menu mapping tables (seam designed,
not built); KDS prep lifecycle beyond Accept; iOS. Online orders appear in History automatically as
COMPLETED sales.

## Verification
Server: `POST /online-orders/simulate` (F&B cashier) → COMPLETED online order; `GET /online-orders`
lists it NEW; `POST /:id/accept` → ACCEPTED; `GET /orders` shows it with `payment.method=ONLINE`;
inventory decremented. App (F&B): within 2–5 min the badge + TTS fire; Pesanan → Online list; Terima
clears the badge; Settings toggle Off stops it; grocery login → feature absent.
