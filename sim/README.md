# `sim/` — AWS cost & P/L simulation

A parameterised model of what it costs to run DPOS on AWS for a merchant base of the
order of **19,000 merchants/year**, and what the resulting P/L looks like.

Zero dependencies. Node 20+.

```bash
node sim/run.mjs                          # base scenario, 36 months
node sim/run.mjs --scenario=steady19k     # flat 19,000-merchant book, 12 months
node sim/run.mjs --all                    # every scenario + comparison table
node sim/run.mjs --sensitivity            # tornado over the six knobs that matter
node sim/run.mjs --all --csv=sim/out      # monthly ledger as CSV + summary JSON

# ad-hoc overrides, dotted paths into assumptions.mjs
node sim/run.mjs --set growth.grossAddsPerYear=30000 --set revenue.qris.enabled=false
```

## Files

| File | What it is |
|---|---|
| `aws-price-sheet.aps3.json` | **Real** `ap-southeast-3` (Jakarta) list prices, pulled from the public AWS Price List Bulk API on 2026-09-07. Offer versions are recorded in the file. |
| `assumptions.mjs` | Every business and workload input, with the reasoning inline. Four scenarios: `base`, `lean`, `conservative`, `steady19k`. |
| `model.mjs` | The engine: merchants → demand → infrastructure sizing → AWS bill → P/L. Pure functions, no constants of its own. |
| `run.mjs` | CLI: tables, sensitivity, CSV/JSON export. |
| `out/` | Generated. Gitignored. |

## How it works

The model walks month by month and never assumes a fixed infrastructure — it **sizes the
infrastructure from the demand**:

1. **Merchants.** Gross adds ramp through year 1, then flat; free and paid churn separately;
   a slice of the free base upgrades each month.
2. **Demand.** The tier mix gives outlets, devices and orders/day per merchant. Request volume
   comes from the real API surface (`server/src/**/*.controller.ts`) — checkout writes,
   history/open-bill reads, reporting queries, portal calls, offline-sync heartbeats and
   delivery-channel polling. F&B traffic is spiky, so a peak-to-average factor drives sizing.
3. **Infrastructure.** API nodes from peak weighted request units per vCPU; RDS writer from peak
   write rows/s **and** from the working set that has to stay resident in RAM; read replicas from
   read load; gp3 volume from cumulative retained orders; provisioned IOPS above the free 3,000.
   If no single instance fits, the model shards (DPOS is tenant-scoped end to end, so it can).
4. **Bill.** Every line priced against the real Jakarta price sheet, with RI/Savings-Plan coverage
   and AWS Business Support applied on top.
5. **P/L.** DIKASIR list pricing (`scratchpad/dikasir_pricing.html`) drives revenue; COGS is
   AWS + payment-collection fees + per-ticket support + messaging; opex is headcount, CAC,
   onboarding delivery and marketing. Indonesian 22% corporate tax with loss carry-forward.

Write amplification per checkout (11 rows) is taken from the actual transaction in
`server/src/orders/orders.service.ts`: `Order` + ~3 `OrderLine` + ~0.3 `OrderDiscount` +
`Payment` + ~3 `InventoryMovement` + ~3 `InventoryStock` updates, plus `AuditLog` on corrections.

## What the model says

Run on branch `claude/mobile-pos-cost-simulation-crrm90` (2026-09-07), `base` and `steady19k`:

- **AWS is not the constraint.** A flat 19,000-merchant book costs about **$13.2k/month
  (~Rp 208 jt)** — **$0.69 per merchant per month**, roughly **5% of revenue**. Gross margin
  lands at 90–92%, consistent with the "85–90%+" claim in the pricing deck.
- **The bill is a database bill.** RDS is 65–75% of it (writer + replicas + storage + IOPS +
  backup). EC2 for the whole NestJS API tier is 3–4%. Optimisation effort belongs on retention,
  row width and read-replica sizing — not on the app tier.
- **Storage, not CPU, is what grows.** Compute scales with peak requests and flattens; the gp3
  volume grows monotonically with retained orders and becomes the second-largest line by Y3.
  `capacity.dbRetentionMonths` is the single most effective infrastructure lever: archiving to S3
  after 12 months instead of 24 takes the Y3 storage line from $5,594 to $3,271/month — ~40% off
  that line, ~10% off the whole bill.
- **Sharding starts to matter around 30–35k merchants**, driven by the resident working set
  rather than by CPU. Below that a single Multi-AZ writer plus one replica carries the load.
- **P/L is decided by churn and paid conversion, not by infrastructure.** Halving paid churn is
  worth ~Rp 13 mlr of Y3 EBITDA; doubling the peak-traffic factor costs ~Rp 0.3 mlr. Any hour
  spent on retention beats an hour spent on instance right-sizing by roughly two orders of magnitude.
- **QRIS attach is the largest single revenue swing** — moving it from 0% to 70% of merchants is
  worth ~Rp 20 mlr of Y3 EBITDA, more than the entire AWS bill for three years.

## What this model is not

- **The capacity constants are engineering estimates, not measurements.** `capacity.apiUnitsPerSecPerVcpu`,
  `dbWriteRowsPerSecPerVcpu` and `workload.dbBytesPerOrder` are the three inputs that would move the
  AWS number most, and none of them has been load-tested. The DEVLOG already lists load testing as
  outstanding; until it is done, treat the infrastructure line as an order-of-magnitude estimate
  (right to ±2×, not to ±10%).
- **Prices are public list prices.** No EDP/PPA discount is assumed
  (`discounts.privatePricingDiscount` is 0). At Y3 spend an enterprise agreement is realistic.
- **Nothing here is committed spend.** Reserved-instance coverage of 70% assumes a 1-year
  commitment the business has not made.
