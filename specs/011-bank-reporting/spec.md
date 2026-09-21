# Feature Spec — Bank Reporting & Merchant Data for Credit Scoring

**Feature ID:** 011-bank-reporting
**Status:** In progress
**Applies to:** the customer portal and the API. Every business type and size.
Constitution v1.9.0.

## Why

A bank is going to hand DPOS to its merchants as part of opening an account — new rekening, new
QRIS registration, new EDC, or all three — and wants the resulting transaction data for **credit
scoring**. That is two products from one install, and neither of them is the merchant dashboard
that exists today.

**The half the bank cannot see is the point.** Once it acquires the merchant's QRIS and EDC, the
bank already sees those flows in its own systems. It does not see cash, and for a warung cash is
most of the turnover. DPOS holds both in one ledger.

That is worth more than a revenue claim, because of what sits beside it: DPOS says the merchant
took 41 QRIS payments worth Rp 3,2 juta; the bank's own settlement file says the same. The **cash**
figure recorded in the same tamper-evident ledger is then credible by association. The bank is not
asked to trust self-reported data — it is given one number it can check against its own books and a
second number that travelled with it.

Everything here follows from that: identifiers so the two sides can be joined, a reconciliation
that does the joining, and the figures a scorecard actually eats.

## User Stories & Acceptance

### A. The merchant record carries the bank's own keys

1. A merchant and its outlets can hold the bank's identifiers: **CIF / nomor rekening**, **NMID**
   and **MPAN** (QRIS), **TID** and **MID** (EDC), plus **NIB**, **NPWP** and the **MCC** the bank
   files it under.
2. Onboarding is recorded: which **officer** and **branch** opened the account, and **when**.
3. **Consent is a field, not an assumption.** Sharing a merchant's transaction data with the bank
   is recorded with a timestamp and the text version consented to, and can be withdrawn. No consent,
   no export — enforced at the endpoint, not in the UI.
4. Every field is optional and additive. A merchant with no bank relationship is unaffected.

### B. Reconciliation — DPOS against the bank's settlement

5. The acquirer's settlement lines can be **ingested** (one row: date, method, gross, fee, net, and
   the terminal or NMID it settled under) and are stored as given. They are the bank's record, never
   edited to fit ours.
6. A **reconciliation report** for a period matches DPOS's own non-cash sales against them and
   reports, per day and per method: matched, in DPOS but not settled, settled but not in DPOS, and
   the rupiah on each side.
7. The **match rate** is the headline figure, because it is what makes the cash number believable.
8. A mismatch is never silently corrected. Both sides are shown.

### C. Activation funnel — the distribution story

9. For a cohort of merchants the portal shows: **registered → first login → first sale → active 7d
   → active 30d**, with **days to first sale**.
10. **Dormancy**: merchants with no sale in 7 days, listed, newest silence first.
11. Counted from what already exists — a first sale is the first COMPLETED order, not a new flag.

### D. The credit figures

12. Per merchant, per month, for the last 12: **omzet**, order count, average ticket, **trading
    days**, longest gap with no sales, **cash share**, non-cash share, and the share on the bank's
    own rails.
13. **Consistency** is first-class: a merchant trading 26 days a month is a different risk from one
    trading 9, and no other system tells the bank that.
14. Margin figures (**laba kotor**, HPP) are reported only where the merchant sells from a catalogue.
    A calculator or nota merchant has no cost price **by definition, not by omission**, and the
    payload says so rather than sending a zero or a null to be misread.
15. **Months of history** rides with every payload. A scorecard needs a floor and must be able to
    apply one.

### E. Laporan Laba Rugi Sederhana

16. A printable monthly statement in Indonesian: **Pendapatan**, **HPP**, **Laba Kotor** — the three
    DPOS can prove — with **Beban Usaha** entered by the merchant and **Laba Bersih** derived.
17. It states the period, the outlet, and that the figures come from recorded sales.

### F. Data integrity — why any of it can be believed

18. A report of what could distort the numbers: **void and refund rate**, corrections per 100 sales,
    discount rate, voids by cashier and approver, offline-queued share, and device count.
19. It states plainly that the server recomputes every amount, that corrections are append-only, and
    that the reconciliation match rate above is independent evidence.
20. **It does not claim the data cannot be wrong.** A merchant can under-record cash. What the
    report offers is the anchor, the patterns that betray tampering, and an audit trail — and it
    says which of the three it is relying on.

## Constitution

- **III — the server owns money math.** Nothing here computes money on a client. Every figure is
  derived server-side from recorded orders.
- **IV — immutable financial history.** Reporting is read-only. Settlement rows are stored as the
  bank sent them; a mismatch is reported, never reconciled away.
- **VII — Indonesia-first.** Data stays in `ap-southeast-3`. Merchant consent is explicit and
  recorded, per UU PDP 27/2022 — the residency answer and the consent answer are both asked by every
  bank, and both are ours to give in writing.

## Out of scope

- The scorecard itself. DPOS supplies features; the model is the bank's.
- Automated settlement feeds from a real acquirer. Ingest is an endpoint; who calls it is a later
  integration.
- Loan origination, disbursement, repayment — none of it.
- Editing a settlement row. Ever.

## Demo data

Every report here is a flat line on two days of sales. A seed writes **six months of plausible
history** for the demo merchant — weekday/weekend rhythm, a Ramadan-Lebaran lift, closed days, a
payment mix that moves toward QRIS, matching settlement rows with a deliberate handful of
mismatches, and a few voids. It is clearly marked demo data and touches no other merchant.

## Verification

```bash
cd server && npm test        # includes bank-reporting e2e
cd customer-portal && npm run build
```
