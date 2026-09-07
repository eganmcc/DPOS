// DPOS — cost & P/L simulation engine.
//
// Pure functions, zero dependencies. Given an assumption set and the ap-southeast-3
// price sheet, it walks month by month:
//
//   merchants -> demand -> infrastructure sizing -> AWS bill -> P&L
//
// Nothing here is a constant you have to hunt for: every input comes from
// assumptions.mjs, every price from aws-price-sheet.aps3.json.

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
export const PRICES = JSON.parse(readFileSync(join(here, 'aws-price-sheet.aps3.json'), 'utf8'));

const HOURS_PER_MONTH = 730;
const DAYS_PER_MONTH = 30.4;

// ── helpers ────────────────────────────────────────────────────────────────
export function deepMerge(a, b) {
  if (b === undefined) return a;
  if (Array.isArray(a) || Array.isArray(b) || typeof b !== 'object' || b === null) return b;
  const out = { ...a };
  for (const k of Object.keys(b)) out[k] = k in a ? deepMerge(a[k], b[k]) : b[k];
  return out;
}

/** Price a quantity through a tiered rate table ([{uptoX, price}, ...]). */
function tiered(qty, tiers, key) {
  let remaining = qty, prev = 0, total = 0;
  for (const t of tiers) {
    const cap = t[key] === null || t[key] === undefined ? Infinity : t[key];
    const inTier = Math.max(0, Math.min(remaining, cap - prev));
    total += inTier * t.price;
    remaining -= inTier;
    prev = cap;
    if (remaining <= 0) break;
  }
  return total;
}

/** Smallest instance from `specs` meeting the vCPU and RAM floor; null if none fits. */
function pickInstance(specs, priceTable, minVcpu, minRamGb) {
  const candidates = Object.keys(specs)
    .filter((k) => priceTable[k] !== undefined)
    .sort((a, b) => priceTable[a] - priceTable[b]);
  for (const k of candidates) {
    if (specs[k].vcpu >= minVcpu && specs[k].ramGb >= minRamGb) return k;
  }
  return null;
}

// ── tier mix maths ─────────────────────────────────────────────────────────
/** Per-merchant weighted averages across the tier mix. */
export function blendTiers(tiers) {
  let outlets = 0, devices = 0, orders = 0, paidShare = 0, mrrIdr = 0;
  for (const t of Object.values(tiers)) {
    outlets += t.share * t.outlets;
    devices += t.share * t.devices;
    orders  += t.share * t.outlets * t.ordersPerDayPerOutlet;
    mrrIdr  += t.share * t.outlets * t.priceIdr;
    if (t.priceIdr > 0) paidShare += t.share;
  }
  return { outletsPerMerchant: outlets, devicesPerMerchant: devices,
           ordersPerMerchantPerDay: orders, listMrrIdrPerMerchant: mrrIdr, paidShare };
}

// ── demand ─────────────────────────────────────────────────────────────────
export function demandFor(merchants, a) {
  const w = a.workload;
  const mix = blendTiers(a.tiers);

  const outlets = merchants * mix.outletsPerMerchant;
  const devices = merchants * mix.devicesPerMerchant;
  const ordersPerDay = merchants * mix.ordersPerMerchantPerDay;

  const calls = {
    write:  ordersPerDay * w.writeCallsPerOrder,
    read:   ordersPerDay * w.readCallsPerOrder,
    report: merchants * w.reportCallsPerMerchantPerDay,
    portal: merchants * w.portalCallsPerMerchantPerDay,
    sync:   devices * w.syncCallsPerDevicePerDay
            + outlets * w.onlineAttachRate * w.onlinePollCallsPerOutletPerDay,
  };
  const callsPerDay = calls.write + calls.read + calls.report + calls.portal + calls.sync;

  const cu = a.capacity.costUnits;
  const unitsPerDay = calls.write * cu.write + calls.read * cu.read
                    + calls.report * cu.report + calls.portal * cu.read + calls.sync * cu.sync;

  const b = w.bytes;
  const egressBytesPerDay = calls.write * b.writeResp + calls.read * b.read
                          + calls.report * b.report + calls.portal * b.portal + calls.sync * b.sync;
  const ingressBytesPerDay = calls.write * b.writeReq + (callsPerDay - calls.write) * 400;

  const avgRps = callsPerDay / 86400;
  const peak = w.peakToAverageFactor;

  return {
    merchants, outlets, devices, ordersPerDay, calls, callsPerDay, unitsPerDay,
    avgRps, peakRps: avgRps * peak,
    peakUnitsPerSec: (unitsPerDay / 86400) * peak,
    peakOrdersPerSec: (ordersPerDay / 86400) * peak,
    peakWriteCallsPerSec: (calls.write / 86400) * peak,
    peakReadUnitsPerSec: ((calls.read * cu.read + calls.report * cu.report + calls.portal * cu.read) / 86400) * peak,
    ordersPerMonth: ordersPerDay * DAYS_PER_MONTH,
    egressGbPerMonth: (egressBytesPerDay * DAYS_PER_MONTH) / 1e9,
    ingressGbPerMonth: (ingressBytesPerDay * DAYS_PER_MONTH) / 1e9,
    requestsPerMonth: callsPerDay * DAYS_PER_MONTH,
  };
}

// ── infrastructure sizing ──────────────────────────────────────────────────
export function sizeInfra(demand, dbOrdersRetained, a) {
  const c = a.capacity, w = a.workload;

  // API tier -------------------------------------------------------------
  const vcpuNeeded = demand.peakUnitsPerSec / (c.apiUnitsPerSecPerVcpu * c.apiTargetUtilisation);
  const nodeSpec = PRICES.ec2.specs[c.apiNodeType];
  const apiNodes = Math.max(c.apiMinNodes,
    Math.ceil(vcpuNeeded / nodeSpec.vcpu) + (demand.merchants > 0 ? c.apiSpareNodes : 0));

  // Database -------------------------------------------------------------
  const writeRowsPerSec = demand.peakOrdersPerSec * w.dbRowsPerOrder;
  const dbVcpuWrite = writeRowsPerSec / (c.dbWriteRowsPerSecPerVcpu * c.dbTargetUtilisation);

  // Reads are served by replicas; the writer keeps a slice of read traffic.
  const readVcpuTotal = demand.peakReadUnitsPerSec / (c.dbReadUnitsPerSecPerVcpu * c.dbTargetUtilisation);
  const writerReadShare = 0.25;
  const dbVcpuWriter = dbVcpuWrite + readVcpuTotal * writerReadShare;

  // Hot working set must sit in RAM or every checkout turns into random I/O.
  const hotGb = ((demand.ordersPerMonth * c.dbHotWindowMonths * w.dbBytesPerOrder * c.dbHotIndexFraction)
                + demand.merchants * c.baseDbMbPerMerchant * 1e6 * c.baseHotFraction) / 1e9;
  const ramNeeded = hotGb * c.dbRamHeadroom;

  const specs = PRICES.rds.specs;
  const priceTable = c.multiAz ? PRICES.rds.postgres.multiAzPerHour : PRICES.rds.postgres.singleAzPerHour;
  const largest = Object.keys(specs).sort((x, y) => specs[y].vcpu - specs[x].vcpu)[0];

  // One writer if it fits; otherwise shard by merchant (DPOS is tenant-scoped throughout).
  let shards = 1;
  while (dbVcpuWriter / shards > specs[largest].vcpu || ramNeeded / shards > specs[largest].ramGb) shards++;

  const writerClass = pickInstance(specs, priceTable,
    Math.max(2, dbVcpuWriter / shards), Math.max(8, ramNeeded / shards)) ?? largest;

  const replicaVcpu = readVcpuTotal * (1 - writerReadShare) / shards;
  const replicaClass = pickInstance(specs, PRICES.rds.postgres.singleAzPerHour,
    Math.max(2, replicaVcpu), Math.max(8, ramNeeded / shards * 0.6)) ?? largest;
  const replicasPerShard = c.readReplicas === 'auto'
    ? Math.max(c.multiAz ? 1 : 0, Math.ceil(replicaVcpu / specs[replicaClass].vcpu))
    : c.readReplicas;

  // Storage --------------------------------------------------------------
  const dataGb = (dbOrdersRetained * w.dbBytesPerOrder + demand.merchants * c.baseDbMbPerMerchant * 1e6) / 1e9;
  const storageGb = Math.max(100, dataGb * c.dbWalOverhead * c.dbFreeSpaceBuffer);

  const iopsNeeded = writeRowsPerSec * c.iopsPerWriteRow + demand.peakReadUnitsPerSec * c.iopsPerReadUnit;
  const extraIops = Math.max(0, Math.ceil(iopsNeeded / shards) - PRICES.rds.storage.gp3IncludedIops);

  return {
    apiNodes, apiNodeType: c.apiNodeType, apiVcpuNeeded: vcpuNeeded,
    shards, writerClass, replicaClass, replicasPerShard,
    dbVcpuWriter, hotGb, storageGbPerShard: storageGb / shards, storageGbTotal: storageGb,
    extraIopsPerShard: extraIops, iopsNeeded,
  };
}

// ── AWS bill ───────────────────────────────────────────────────────────────
export function awsBill(demand, infra, a) {
  const d = a.discounts, w = a.workload, c = a.capacity;
  const P = PRICES;
  const line = {};

  // Compute: RI covers the steady base, on-demand the rest.
  const ec2Od = P.ec2.onDemandPerHour[infra.apiNodeType];
  const ec2Eff = ec2Od * (1 - d.riCoverage * d.ec2RiDiscount);
  line.ec2 = infra.apiNodes * ec2Eff * HOURS_PER_MONTH;
  line.ec2Ebs = infra.apiNodes * 50 * P.ebs.gp3GbMonth;

  // Load balancer: LCU is the max of the four dimensions; bytes dominate here.
  const lcuBytes = (demand.egressGbPerMonth + demand.ingressGbPerMonth) * 1e9 / HOURS_PER_MONTH / 3600 / 1e6;
  const lcuConns = demand.peakRps / 25;               // new connections per second per LCU
  const lcuRules = demand.peakRps / 1000;
  line.alb = P.alb.perHour * HOURS_PER_MONTH
           + Math.max(lcuBytes, lcuConns, lcuRules, 1) * P.alb.lcuHour * HOURS_PER_MONTH;

  // RDS
  const writerPrice = (c.multiAz ? P.rds.postgres.multiAzPerHour : P.rds.postgres.singleAzPerHour)[infra.writerClass];
  const writerRi = P.rds.postgres.reserved1yrNoUpfrontMultiAzPerHour[infra.writerClass];
  const writerEff = c.multiAz && writerRi
    ? writerPrice * (1 - d.riCoverage * d.rdsRiDiscount)
    : writerPrice * (1 - d.riCoverage * d.rdsRiDiscount * 0.9);
  line.rdsWriters = infra.shards * writerEff * HOURS_PER_MONTH;

  const replicaPrice = P.rds.postgres.singleAzPerHour[infra.replicaClass];
  line.rdsReplicas = infra.shards * infra.replicasPerShard
    * replicaPrice * (1 - d.riCoverage * d.rdsRiDiscount) * HOURS_PER_MONTH;

  const stGb = c.multiAz ? P.rds.storage.gp3MultiAzGbMonth : P.rds.storage.gp3SingleAzGbMonth;
  const stIops = c.multiAz ? P.rds.storage.gp3ProvisionedIopsMultiAzMonth : P.rds.storage.gp3ProvisionedIopsSingleAzMonth;
  // Replicas carry their own copy of the volume, billed at single-AZ rates.
  line.rdsStorage = infra.shards * infra.storageGbPerShard * stGb
                  + infra.shards * infra.replicasPerShard * infra.storageGbPerShard * P.rds.storage.gp3SingleAzGbMonth;
  line.rdsIops = infra.shards * infra.extraIopsPerShard * stIops;
  // PITR + 35-day snapshots; the provisioned volume is free, the rest is charged.
  line.rdsBackup = Math.max(0, infra.storageGbTotal * 1.4 - infra.storageGbTotal) * P.rds.backupGbMonth;

  // Object storage + CDN
  const s3Gb = demand.merchants * w.imageStorageMbPerMerchant / 1000
             + demand.ordersPerMonth * 0.5 / 1e6;      // archived order exports
  line.s3 = tiered(s3Gb, P.s3.standardGbMonthTiers, 'uptoGb')
          + demand.ordersPerMonth * 0.05 * P.s3.putRequest;
  const cdnGb = demand.devices * w.imageMbPerDevicePerMonth / 1000;
  line.cloudFront = tiered(cdnGb, P.cloudFront.dataOutGbTiers, 'uptoGb')
                  + (cdnGb * 1e9 / 250000) * P.cloudFront.httpsRequest
                  + cdnGb * 0.10 * P.cloudFront.originFetchGb;

  // Egress: API responses leave through the ALB, not the CDN.
  const billableEgress = Math.max(0, demand.egressGbPerMonth - P.dataTransfer.freeTierOutGbMonth);
  line.dataTransferOut = tiered(billableEgress, P.dataTransfer.outToInternetGbTiers, 'uptoGb');

  // Cross-AZ chatter between the API tier and the database.
  const crossAzGb = demand.requestsPerMonth * 3000 / 1e9 * (c.multiAz ? 1 : 0.5);
  line.crossAz = crossAzGb * P.dataTransfer.intraRegionPerGb * 2;

  // NAT for outbound gateway/webhook traffic.
  const natGb = demand.ordersPerMonth * w.natBytesPerOrder / 1e9;
  line.nat = 2 * P.natGateway.perHour * HOURS_PER_MONTH + natGb * P.natGateway.perGb;

  // Observability — at this request volume, logs are a real line item.
  const logGb = demand.requestsPerMonth * w.logBytesPerRequest * w.logSamplingRate / 1e9;
  const metrics = 2000 + infra.apiNodes * 60 + infra.shards * (1 + infra.replicasPerShard) * 80;
  line.cloudWatch = logGb * P.cloudWatch.logsIngestGb
                  + logGb * 3 * P.cloudWatch.logsStorageGbMonth
                  + logGb * 0.4 * P.cloudWatch.logsInsightsScanGb
                  + tiered(metrics, P.cloudWatch.metricMonthTiers, 'uptoMetrics');

  // Route 53, ACM, Secrets Manager, ECR, WAF, SES.
  line.misc = 25 + demand.requestsPerMonth / 1e6 * 0.60 + 8;

  let subtotal = Object.values(line).reduce((s, v) => s + v, 0);
  if (d.privatePricingDiscount > 0) {
    const cut = subtotal * d.privatePricingDiscount;
    for (const k of Object.keys(line)) line[k] *= (1 - d.privatePricingDiscount);
    line._privatePricingCredit = -cut;
    subtotal -= cut;
  }

  let support = 0;
  if (d.includeAwsBusinessSupport) {
    support = Math.max(P.awsSupportBusinessMinimumMonthly,
      tiered(subtotal, P.awsSupportBusinessTiers, 'uptoUsd'));
    line.awsSupport = support;
  }

  return { lines: line, totalUsd: subtotal + support, computeUsd: line.ec2 + line.alb,
           databaseUsd: line.rdsWriters + line.rdsReplicas + line.rdsStorage + line.rdsIops + line.rdsBackup,
           networkUsd: line.dataTransferOut + line.cloudFront + line.crossAz + line.nat };
}

// ── the simulation ─────────────────────────────────────────────────────────
export function simulate(assumptions) {
  const a = assumptions;
  const fx = a.meta.fxIdrPerUsd;
  const mix = blendTiers(a.tiers);

  let free = 0, paid = 0;
  if (a._seedMerchants) {
    free = a._seedMerchants * a.tiers.free.share;
    paid = a._seedMerchants * (1 - a.tiers.free.share);
  }

  let dbOrdersRetained = 0;
  let cumulativeCashPl = 0, lossCarryForward = 0;
  const months = [];

  for (let m = 0; m < a.meta.horizonMonths; m++) {
    const year = Math.floor(m / 12);

    // Merchant base -------------------------------------------------------
    const rampWeight = year === 0
      ? a.growth.year1RampShape[m] ?? (1 / 12)
      : 1 / 12;
    const grossAdds = a.growth.grossAddsPerYear * rampWeight;
    const addFree = grossAdds * a.tiers.free.share;
    const addPaid = grossAdds * (1 - a.tiers.free.share);

    const upgrades = free * a.growth.freeToPaidUpgradeMonthly;
    const churnFree = free * a.growth.monthlyChurn.free;
    const churnPaid = paid * a.growth.monthlyChurn.paid;

    free = Math.max(0, free + addFree - upgrades - churnFree);
    paid = Math.max(0, paid + addPaid + upgrades - churnPaid);
    const merchants = free + paid;

    // Demand & infra ------------------------------------------------------
    const demand = demandFor(merchants, a);
    dbOrdersRetained += demand.ordersPerMonth;
    if (m >= a.capacity.dbRetentionMonths) {
      dbOrdersRetained -= months[m - a.capacity.dbRetentionMonths].demand.ordersPerMonth;
    }
    const infra = sizeInfra(demand, dbOrdersRetained, a);
    const aws = awsBill(demand, infra, a);
    const awsIdr = aws.totalUsd * fx;

    // Revenue -------------------------------------------------------------
    // Rebase the tier mix onto the actual free/paid split this month.
    const paidShareNow = merchants > 0 ? paid / merchants : 0;
    const paidMixScale = mix.paidShare > 0 ? paidShareNow / mix.paidShare : 0;
    const subsGross = merchants * mix.listMrrIdrPerMerchant * paidMixScale;
    const prepayDiscount = subsGross * a.revenue.annualPrepayShare * a.revenue.annualPrepayDiscount;
    const subscription = subsGross - prepayDiscount;

    const devicesRev = paid * a.revenue.extraDevicesPerPaidMerchant * a.revenue.extraDeviceIdrPerMonth;
    const addonRev = paid * a.revenue.addonAttachRate * a.revenue.addonIdrPerMonth;
    const onboardingRev = addPaid * a.revenue.onboardingFeeAttach * a.revenue.onboardingFeeIdr;

    const q = a.revenue.qris;
    const gmvIdr = demand.ordersPerMonth * q.avgTicketIdr;
    const qrisRev = q.enabled
      ? gmvIdr * q.merchantAttachRate * q.shareOfTenderQris * q.platformFeeRate
      : 0;

    const revenue = subscription + devicesRev + addonRev + onboardingRev + qrisRev;

    // COGS ----------------------------------------------------------------
    const collectionFee = (subscription + devicesRev + addonRev) * a.cogs.paymentCollectionFeeRate;
    const supportCost = merchants * a.cogs.supportTicketsPerMerchantMonth * a.cogs.costPerTicketIdr;
    const messaging = merchants * a.cogs.messagingIdrPerMerchantMonth;
    const cogs = awsIdr + collectionFee + supportCost + messaging;
    const grossProfit = revenue - cogs;

    // Opex ----------------------------------------------------------------
    const hcYear = Math.min(year, 2);
    const heads = Object.values(a.opex.headcount).reduce((s, arr) => s + arr[hcYear], 0);
    const payroll = heads * a.opex.loadedCostIdrPerHeadMonth;
    const officeTools = heads * a.opex.officeAndToolsIdrPerHeadMonth;
    const cac = grossAdds * a.opex.cacIdrPerGrossAdd;
    const onboardingCost = addPaid * a.opex.onboardingCostIdrPerPaidAdd;
    const marketing = revenue * a.opex.marketingSpendShareOfRevenue;
    const opex = payroll + officeTools + cac + onboardingCost + marketing;

    const ebitda = grossProfit - opex;

    let tax = 0;
    if (ebitda > 0) {
      const taxable = Math.max(0, ebitda - lossCarryForward);
      tax = taxable * a.opex.corporateTaxRate;
      lossCarryForward = Math.max(0, lossCarryForward - ebitda);
    } else {
      lossCarryForward += -ebitda;
    }
    const netIncome = ebitda - tax;
    cumulativeCashPl += netIncome;

    months.push({
      month: m + 1, year: year + 1, free, paid, merchants,
      demand, infra, aws,
      awsUsd: aws.totalUsd, awsIdr,
      revenue: { subscription, devices: devicesRev, addons: addonRev, onboarding: onboardingRev, qris: qrisRev, total: revenue },
      cogs: { aws: awsIdr, collectionFee, support: supportCost, messaging, total: cogs },
      opexDetail: { payroll, officeTools, cac, onboardingCost, marketing, heads },
      grossProfit, grossMargin: revenue > 0 ? grossProfit / revenue : 0,
      opex, ebitda, tax, netIncome, cumulativeCashPl,
      unit: {
        awsUsdPerMerchantMonth: merchants > 0 ? aws.totalUsd / merchants : 0,
        awsIdrPerMerchantMonth: merchants > 0 ? awsIdr / merchants : 0,
        awsUsdPer1kOrders: demand.ordersPerMonth > 0 ? aws.totalUsd / (demand.ordersPerMonth / 1000) : 0,
        arpuIdr: merchants > 0 ? revenue / merchants : 0,
        arppuIdr: paid > 0 ? revenue / paid : 0,
        grossProfitIdrPerMerchant: merchants > 0 ? grossProfit / merchants : 0,
      },
    });
  }

  return { assumptions: a, months, years: annualise(months, a), summary: summarise(months, a) };
}

function annualise(months, a) {
  const out = [];
  for (let y = 0; y * 12 < months.length; y++) {
    const slice = months.slice(y * 12, y * 12 + 12);
    if (!slice.length) break;
    const sum = (f) => slice.reduce((s, m) => s + f(m), 0);
    const end = slice[slice.length - 1];
    out.push({
      year: y + 1,
      endMerchants: end.merchants, endPaid: end.paid, endFree: end.free,
      revenue: sum((m) => m.revenue.total),
      revenueSplit: {
        subscription: sum((m) => m.revenue.subscription),
        qris: sum((m) => m.revenue.qris),
        devices: sum((m) => m.revenue.devices),
        addons: sum((m) => m.revenue.addons),
        onboarding: sum((m) => m.revenue.onboarding),
      },
      awsUsd: sum((m) => m.awsUsd), awsIdr: sum((m) => m.awsIdr),
      cogs: sum((m) => m.cogs.total),
      cogsSplit: {
        aws: sum((m) => m.cogs.aws), collectionFee: sum((m) => m.cogs.collectionFee),
        support: sum((m) => m.cogs.support), messaging: sum((m) => m.cogs.messaging),
      },
      grossProfit: sum((m) => m.grossProfit),
      opex: sum((m) => m.opex),
      opexSplit: {
        payroll: sum((m) => m.opexDetail.payroll), officeTools: sum((m) => m.opexDetail.officeTools),
        cac: sum((m) => m.opexDetail.cac), onboarding: sum((m) => m.opexDetail.onboardingCost),
        marketing: sum((m) => m.opexDetail.marketing),
      },
      ebitda: sum((m) => m.ebitda), tax: sum((m) => m.tax), netIncome: sum((m) => m.netIncome),
      grossMargin: sum((m) => m.revenue.total) > 0 ? sum((m) => m.grossProfit) / sum((m) => m.revenue.total) : 0,
      endInfra: end.infra, endAwsLines: end.aws.lines, endUnit: end.unit,
      ordersForYear: sum((m) => m.demand.ordersPerMonth),
    });
  }
  return out;
}

function summarise(months, a) {
  const last = months[months.length - 1];
  const fx = a.meta.fxIdrPerUsd;

  // Unit economics at the terminal month.
  const arpuIdr = last.unit.arpuIdr;
  const gmPerMerchant = last.unit.grossProfitIdrPerMerchant;
  const blendedChurn = last.merchants > 0
    ? (last.free * a.growth.monthlyChurn.free + last.paid * a.growth.monthlyChurn.paid) / last.merchants
    : 0;
  const cacPerAdd = a.opex.cacIdrPerGrossAdd
    + a.opex.onboardingCostIdrPerPaidAdd * (1 - a.tiers.free.share);
  const lifetimeMonths = blendedChurn > 0 ? 1 / blendedChurn : Infinity;
  const ltv = gmPerMerchant * lifetimeMonths;

  const breakevenMonth = months.find((m) => m.ebitda > 0)?.month ?? null;
  const cashBreakevenMonth = months.find((m) => m.cumulativeCashPl > 0)?.month ?? null;
  const peakCashNeed = Math.min(...months.map((m) => m.cumulativeCashPl));

  return {
    scenario: a.meta.name,
    terminal: {
      month: last.month, merchants: last.merchants, paid: last.paid,
      awsUsdPerMonth: last.awsUsd,
      awsUsdPerMerchantMonth: last.unit.awsUsdPerMerchantMonth,
      awsUsdPer1kOrders: last.unit.awsUsdPer1kOrders,
      arpuIdr, arpuUsd: arpuIdr / fx,
      grossMargin: last.grossMargin,
      infra: last.infra,
    },
    unitEconomics: {
      cacIdr: cacPerAdd, ltvIdr: ltv, ltvToCac: cacPerAdd > 0 ? ltv / cacPerAdd : Infinity,
      paybackMonths: gmPerMerchant > 0 ? cacPerAdd / gmPerMerchant : Infinity,
      blendedMonthlyChurn: blendedChurn,
    },
    breakevenMonth, cashBreakevenMonth, peakCashNeedIdr: peakCashNeed,
  };
}
