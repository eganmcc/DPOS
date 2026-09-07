#!/usr/bin/env node
// DPOS — cost & P/L simulation runner.
//
//   node sim/run.mjs                     # base scenario
//   node sim/run.mjs --scenario=lean     # base | lean | conservative | steady19k
//   node sim/run.mjs --all               # every scenario, side by side
//   node sim/run.mjs --csv=out/          # also write the monthly ledger as CSV + JSON
//
// Overrides use dotted paths:
//   node sim/run.mjs --set growth.grossAddsPerYear=25000 --set revenue.qris.enabled=false

import { writeFileSync, mkdirSync } from 'node:fs';
import { ASSUMPTIONS, SCENARIOS } from './assumptions.mjs';
import { simulate, deepMerge, blendTiers, demandFor, sizeInfra, awsBill } from './model.mjs';

// ── argument parsing ───────────────────────────────────────────────────────
const argv = process.argv.slice(2);
const flag = (name, dflt) => {
  const hit = argv.find((x) => x === `--${name}` || x.startsWith(`--${name}=`));
  if (!hit) return dflt;
  return hit.includes('=') ? hit.split('=').slice(1).join('=') : true;
};
const sets = argv.reduce((acc, x, i) => {
  if (x === '--set' && argv[i + 1]) acc.push(argv[i + 1]);
  else if (x.startsWith('--set=')) acc.push(x.slice(6));
  return acc;
}, []);

function applySet(obj, expr) {
  const [path, raw] = expr.split('=');
  const val = raw === 'true' ? true : raw === 'false' ? false : Number.isNaN(Number(raw)) ? raw : Number(raw);
  const keys = path.split('.');
  let node = obj;
  for (const k of keys.slice(0, -1)) node = node[k] ??= {};
  node[keys.at(-1)] = val;
  return obj;
}

// ── formatting ─────────────────────────────────────────────────────────────
const FX = ASSUMPTIONS.meta.fxIdrPerUsd;
const usd = (n, d = 0) => '$' + n.toLocaleString('en-US', { minimumFractionDigits: d, maximumFractionDigits: d });
const idr = (n) => {
  const a = Math.abs(n), sign = n < 0 ? '-' : '';
  if (a >= 1e12) return `${sign}Rp ${(a / 1e12).toFixed(2)} tri`;
  if (a >= 1e9) return `${sign}Rp ${(a / 1e9).toFixed(2)} mlr`; // miliar
  if (a >= 1e6) return `${sign}Rp ${(a / 1e6).toFixed(1)} jt`;
  if (a >= 1e3) return `${sign}Rp ${(a / 1e3).toFixed(0)} rb`;
  return `${sign}Rp ${a.toFixed(0)}`;
};
const num = (n, d = 0) => n.toLocaleString('en-US', { minimumFractionDigits: d, maximumFractionDigits: d });
const pct = (n, d = 1) => (n * 100).toFixed(d) + '%';

function table(headers, rows, align = []) {
  const all = [headers, ...rows].map((r) => r.map((c) => String(c)));
  const w = headers.map((_, i) => Math.max(...all.map((r) => (r[i] ?? '').length)));
  const line = (r) => '  ' + r.map((c, i) => (align[i] === 'r' ? c.padStart(w[i]) : c.padEnd(w[i]))).join('  ');
  const out = [line(all[0]), '  ' + w.map((x) => '─'.repeat(x)).join('  ')];
  for (const r of all.slice(1)) out.push(line(r));
  return out.join('\n');
}
const h1 = (s) => `\n\x1b[1m${s}\x1b[0m\n` + '═'.repeat(Math.min(78, s.length + 4));
const h2 = (s) => `\n\x1b[1m${s}\x1b[0m`;

// ── report ─────────────────────────────────────────────────────────────────
function report(result) {
  const a = result.assumptions;
  const mix = blendTiers(a.tiers);
  const out = [];

  out.push(h1(`DPOS — AWS cost & P/L simulation · scenario "${a.meta.name}"`));
  out.push(`  Region ${a.meta.region} (Jakarta) · list prices retrieved 2026-09-07 · FX Rp ${num(FX)}/USD`);
  out.push(`  Horizon ${a.meta.horizonMonths} months · ${num(a.growth.grossAddsPerYear)} gross merchant adds/year`);
  out.push(`  Blended per merchant: ${mix.outletsPerMerchant.toFixed(2)} outlets · ${mix.devicesPerMerchant.toFixed(2)} devices`
         + ` · ${mix.ordersPerMerchantPerDay.toFixed(0)} orders/day · ${pct(mix.paidShare)} paying`);

  // Demand & infrastructure -------------------------------------------------
  out.push(h2('Demand and the infrastructure it forces'));
  out.push(table(
    ['Year', 'Merchants', 'Paying', 'Paid %', 'Orders/mo', 'Peak req/s', 'API nodes', 'DB shards', 'DB writer', 'Read replicas', 'RDS storage'],
    result.years.map((y) => {
      const i = y.endInfra, m = result.months[y.year * 12 - 1];
      return [
        `Y${y.year}`, num(Math.round(y.endMerchants)), num(Math.round(y.endPaid)),
        pct(y.endMerchants > 0 ? y.endPaid / y.endMerchants : 0, 0),
        (m.demand.ordersPerMonth / 1e6).toFixed(1) + 'M', num(Math.round(m.demand.peakRps)),
        `${i.apiNodes} × ${i.apiNodeType}`, i.shards, i.writerClass,
        `${i.shards * i.replicasPerShard} × ${i.replicaClass}`,
        num(Math.round(i.storageGbTotal)) + ' GB',
      ];
    }),
    ['l', 'r', 'r', 'r', 'r', 'r', 'l', 'r', 'l', 'l', 'r'],
  ));

  // AWS bill ---------------------------------------------------------------
  out.push(h2('AWS monthly bill — composition at each year end (USD)'));
  const keys = [...new Set(result.years.flatMap((y) => Object.keys(y.endAwsLines)))];
  const label = {
    ec2: 'EC2 — API tier', ec2Ebs: 'EBS — API tier', alb: 'Application Load Balancer',
    rdsWriters: 'RDS writers (Multi-AZ)', rdsReplicas: 'RDS read replicas', rdsStorage: 'RDS storage (gp3)',
    rdsIops: 'RDS provisioned IOPS', rdsBackup: 'RDS backup / PITR', s3: 'S3', cloudFront: 'CloudFront',
    dataTransferOut: 'Data transfer out', crossAz: 'Cross-AZ transfer', nat: 'NAT Gateway',
    cloudWatch: 'CloudWatch logs + metrics', misc: 'Route 53 / WAF / Secrets / ECR', awsSupport: 'AWS Business Support',
  };
  const lastMonths = result.years.map((y) => result.months[y.year * 12 - 1]);
  out.push(table(
    ['Line item', ...result.years.map((y) => `Y${y.year} end`), 'Y-end share'],
    [
      ...keys.map((k) => [
        label[k] ?? k,
        ...lastMonths.map((m) => usd(m.aws.lines[k] ?? 0)),
        pct((lastMonths.at(-1).aws.lines[k] ?? 0) / lastMonths.at(-1).awsUsd, 1),
      ]),
      ['─'.repeat(26), ...lastMonths.map(() => '─────────'), '──────'],
      ['TOTAL / month', ...lastMonths.map((m) => usd(m.awsUsd)), '100.0%'],
      ['TOTAL / month (IDR)', ...lastMonths.map((m) => idr(m.awsIdr)), ''],
      ['per merchant / month', ...lastMonths.map((m) => usd(m.unit.awsUsdPerMerchantMonth, 3)), ''],
      ['per merchant / month (IDR)', ...lastMonths.map((m) => idr(m.unit.awsIdrPerMerchantMonth)), ''],
      ['per 1,000 orders', ...lastMonths.map((m) => usd(m.unit.awsUsdPer1kOrders, 3)), ''],
    ],
    ['l', 'r', 'r', 'r', 'r'],
  ));
  out.push(`\n  Annual AWS spend: ` + result.years.map((y) => `Y${y.year} ${usd(Math.round(y.awsUsd))} (${idr(y.awsIdr)})`).join(' · '));

  // P&L --------------------------------------------------------------------
  out.push(h2('Profit & loss (IDR)'));
  const rows = [];
  const row = (name, get, indent = 0) => rows.push([
    '  '.repeat(indent) + name, ...result.years.map((y) => idr(get(y))),
  ]);
  row('Subscription', (y) => y.revenueSplit.subscription, 1);
  row('QRIS platform fee', (y) => y.revenueSplit.qris, 1);
  row('Extra devices', (y) => y.revenueSplit.devices, 1);
  row('Add-on modules', (y) => y.revenueSplit.addons, 1);
  row('Onboarding (one-off)', (y) => y.revenueSplit.onboarding, 1);
  row('REVENUE', (y) => y.revenue);
  rows.push(['', ...result.years.map(() => '')]);
  row('AWS infrastructure', (y) => -y.cogsSplit.aws, 1);
  row('Payment collection fees', (y) => -y.cogsSplit.collectionFee, 1);
  row('Support (per-ticket)', (y) => -y.cogsSplit.support, 1);
  row('Messaging / OTP', (y) => -y.cogsSplit.messaging, 1);
  row('COST OF REVENUE', (y) => -y.cogs);
  row('GROSS PROFIT', (y) => y.grossProfit);
  rows.push(['  Gross margin', ...result.years.map((y) => pct(y.grossMargin))]);
  rows.push(['', ...result.years.map(() => '')]);
  row('Payroll', (y) => -y.opexSplit.payroll, 1);
  row('Office & tools', (y) => -y.opexSplit.officeTools, 1);
  row('Customer acquisition', (y) => -y.opexSplit.cac, 1);
  row('Onboarding delivery', (y) => -y.opexSplit.onboarding, 1);
  row('Marketing', (y) => -y.opexSplit.marketing, 1);
  row('OPERATING EXPENSE', (y) => -y.opex);
  row('EBITDA', (y) => y.ebitda);
  rows.push(['  EBITDA margin', ...result.years.map((y) => pct(y.revenue > 0 ? y.ebitda / y.revenue : 0))]);
  row('Tax', (y) => -y.tax, 1);
  row('NET INCOME', (y) => y.netIncome);
  rows.push(['  Net income (USD)', ...result.years.map((y) => usd(Math.round(y.netIncome / FX)))]);
  rows.push(['  Headcount (year end)', ...result.years.map((y) => num(result.months[y.year * 12 - 1].opexDetail.heads))]);
  out.push(table(['', ...result.years.map((y) => `Year ${y.year}`)], rows, ['l', 'r', 'r', 'r']));

  // Unit economics ---------------------------------------------------------
  const s = result.summary, u = s.unitEconomics;
  out.push(h2('Unit economics (terminal month)'));
  out.push(table(['Metric', 'Value', 'Note'], [
    ['ARPU (all merchants)', idr(s.terminal.arpuIdr) + '/mo', usd(s.terminal.arpuUsd, 2) + '/mo'],
    ['AWS cost to serve', idr(s.terminal.awsUsdPerMerchantMonth * FX) + '/mo', usd(s.terminal.awsUsdPerMerchantMonth, 3) + '/merchant/mo'],
    ['AWS as % of revenue', pct(s.terminal.awsUsdPerMerchantMonth * FX / s.terminal.arpuIdr), 'infrastructure only'],
    ['Gross margin', pct(s.terminal.grossMargin), 'after AWS + support + payment fees'],
    ['Blended monthly churn', pct(u.blendedMonthlyChurn, 2), `≈ ${(1 / u.blendedMonthlyChurn).toFixed(0)} month lifetime`],
    ['CAC per merchant', idr(u.cacIdr), 'acquisition + onboarding delivery'],
    ['LTV (gross profit)', idr(u.ltvIdr), ''],
    ['LTV : CAC', Number.isFinite(u.ltvToCac) ? u.ltvToCac.toFixed(1) + '×' : 'n/a',
      Number.isFinite(u.ltvToCac) ? (u.ltvToCac >= 3 ? 'healthy (≥3×)' : 'thin — below the 3× rule of thumb') : 'no churn modelled in this scenario'],
    ['CAC payback', Number.isFinite(u.paybackMonths) ? u.paybackMonths.toFixed(1) + ' months' : 'n/a',
      u.paybackMonths <= 12 ? 'inside 12 months' : 'beyond 12 months'],
  ], ['l', 'r', 'l']));

  out.push(h2('Cash'));
  out.push(table(['Metric', 'Value'], [
    ['First EBITDA-positive month', s.breakevenMonth ? `month ${s.breakevenMonth} (Y${Math.ceil(s.breakevenMonth / 12)})` : `not within ${a.meta.horizonMonths} months`],
    ['Cumulative-cash-positive month', s.cashBreakevenMonth ? `month ${s.cashBreakevenMonth}` : `not within ${a.meta.horizonMonths} months`],
    ['Peak funding need', (() => { const need = Math.max(0, -s.peakCashNeedIdr);
      return need === 0 ? 'none — cash-positive throughout' : idr(need) + `  (${usd(Math.round(need / FX))})`; })()],
    ['Cumulative P/L at horizon', idr(result.months.at(-1).cumulativeCashPl)],
  ], ['l', 'r']));

  return out.join('\n');
}

// ── sensitivity ────────────────────────────────────────────────────────────
function sensitivity(baseAssumptions) {
  const knobs = [
    ['Orders/day per outlet', 'workload.*ordersPerDay', [0.5, 0.75, 1, 1.5, 2]],
    ['Paying share of base', 'tiers.paidShare', [0.6, 0.8, 1, 1.2, 1.4]],
    ['Peak-to-average factor', 'workload.peakToAverageFactor', [0.67, 0.83, 1, 1.33, 1.67]],
    ['DB bytes per order', 'workload.dbBytesPerOrder', [0.5, 0.75, 1, 1.5, 2]],
    ['Paid monthly churn', 'growth.monthlyChurn.paid', [0.5, 0.75, 1, 1.5, 2]],
    ['QRIS attach rate', 'revenue.qris.merchantAttachRate', [0, 0.5, 1, 1.5, 2]],
  ];
  const rows = [];
  for (const [name, path, mults] of knobs) {
    const cells = mults.map((mult) => {
      const a = structuredClone(baseAssumptions);
      if (path === 'workload.*ordersPerDay') {
        for (const t of Object.values(a.tiers)) t.ordersPerDayPerOutlet *= mult;
      } else if (path === 'tiers.paidShare') {
        // Shift share between free and the paid tiers, keeping the paid mix ratio.
        const paid0 = 1 - a.tiers.free.share;
        const paid1 = Math.min(0.95, paid0 * mult);
        for (const k of ['starter', 'pro', 'business']) a.tiers[k].share *= paid1 / paid0;
        a.tiers.free.share = 1 - paid1;
      } else {
        const keys = path.split('.');
        let node = a;
        for (const k of keys.slice(0, -1)) node = node[k];
        node[keys.at(-1)] *= mult;
      }
      const r = simulate(a);
      const y3 = r.years.at(-1);
      const last = r.months.at(-1);
      return {
        mult, aws: last.unit.awsUsdPerMerchantMonth, gm: y3.grossMargin,
        ebitda: y3.ebitda, awsYear: y3.awsUsd,
      };
    });
    rows.push([name,
      ...cells.map((c) => `${(c.mult * 100).toFixed(0)}%`),
    ]);
    rows.push(['  AWS $/merchant/mo', ...cells.map((c) => usd(c.aws, 3))]);
    rows.push(['  Y3 gross margin', ...cells.map((c) => pct(c.gm))]);
    rows.push(['  Y3 EBITDA', ...cells.map((c) => idr(c.ebitda))]);
    rows.push(['', '', '', '', '', '']);
  }
  return h2('Sensitivity — each knob scaled against the base scenario')
       + '\n' + table(['Knob / metric', 'low', 'lower', 'BASE', 'higher', 'high'], rows, ['l', 'r', 'r', 'r', 'r', 'r']);
}

// ── main ───────────────────────────────────────────────────────────────────
function build(scenarioName) {
  let a = deepMerge(ASSUMPTIONS, SCENARIOS[scenarioName] ?? {});
  for (const s of sets) a = applySet(structuredClone(a), s);
  return a;
}

const names = flag('all') ? Object.keys(SCENARIOS) : [String(flag('scenario', 'base'))];
const results = {};
for (const n of names) {
  if (!SCENARIOS[n]) { console.error(`unknown scenario "${n}" — have: ${Object.keys(SCENARIOS).join(', ')}`); process.exit(1); }
  const r = simulate(build(n));
  results[n] = r;
  console.log(report(r));
}

if (names.length > 1) {
  console.log(h1('Scenario comparison — terminal month'));
  console.log(table(
    ['Scenario', 'Merchants', 'AWS $/mo', 'AWS $/merchant', 'AWS % of rev', 'Gross margin', 'Final-year EBITDA', 'LTV:CAC'],
    names.map((n) => {
      const s = results[n].summary, y = results[n].years.at(-1);
      return [n, num(Math.round(s.terminal.merchants)), usd(Math.round(s.terminal.awsUsdPerMonth)),
        usd(s.terminal.awsUsdPerMerchantMonth, 3),
        pct(s.terminal.awsUsdPerMerchantMonth * FX / s.terminal.arpuIdr),
        pct(s.terminal.grossMargin), idr(y.ebitda),
        Number.isFinite(s.unitEconomics.ltvToCac) ? s.unitEconomics.ltvToCac.toFixed(1) + '×' : 'n/a'];
    }),
    ['l', 'r', 'r', 'r', 'r', 'r', 'r', 'r'],
  ));
}

if (flag('sensitivity')) console.log(sensitivity(build(names[0])));

const csvDir = flag('csv');
if (csvDir) {
  const dir = csvDir === true ? 'sim/out' : csvDir;
  mkdirSync(dir, { recursive: true });
  for (const [n, r] of Object.entries(results)) {
    const cols = [
      ['month', (m) => m.month], ['merchants', (m) => Math.round(m.merchants)],
      ['paying', (m) => Math.round(m.paid)], ['orders_per_month', (m) => Math.round(m.demand.ordersPerMonth)],
      ['peak_rps', (m) => Math.round(m.demand.peakRps)], ['api_nodes', (m) => m.infra.apiNodes],
      ['db_shards', (m) => m.infra.shards], ['db_writer_class', (m) => m.infra.writerClass],
      ['rds_storage_gb', (m) => Math.round(m.infra.storageGbTotal)],
      ['aws_usd', (m) => m.awsUsd.toFixed(2)], ['aws_usd_per_merchant', (m) => m.unit.awsUsdPerMerchantMonth.toFixed(4)],
      ['revenue_idr', (m) => Math.round(m.revenue.total)], ['cogs_idr', (m) => Math.round(m.cogs.total)],
      ['gross_profit_idr', (m) => Math.round(m.grossProfit)], ['gross_margin', (m) => m.grossMargin.toFixed(4)],
      ['opex_idr', (m) => Math.round(m.opex)], ['ebitda_idr', (m) => Math.round(m.ebitda)],
      ['net_income_idr', (m) => Math.round(m.netIncome)], ['cumulative_pl_idr', (m) => Math.round(m.cumulativeCashPl)],
    ];
    const csv = [cols.map((c) => c[0]).join(','),
      ...r.months.map((m) => cols.map((c) => c[1](m)).join(','))].join('\n');
    writeFileSync(`${dir}/${n}-monthly.csv`, csv + '\n');
    writeFileSync(`${dir}/${n}-summary.json`, JSON.stringify({
      scenario: n, assumptions: r.assumptions, summary: r.summary, years: r.years,
    }, null, 2) + '\n');
  }
  console.log(`\n  wrote CSV + JSON for ${Object.keys(results).join(', ')} → ${dir}/`);
}
