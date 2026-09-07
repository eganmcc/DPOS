// DPOS — cost & P/L simulation: the assumption set.
//
// Every number a reader might argue with lives here, with the reasoning next to it.
// The model (model.mjs) contains no magic constants.
//
// Money is IDR internally for the business side, USD for the AWS side; `fx` bridges them.

export const ASSUMPTIONS = {
  meta: {
    name: 'base',
    horizonMonths: 36,
    fxIdrPerUsd: 15800,          // same rate the DIKASIR pricing deck uses
    region: 'ap-southeast-3',
  },

  // ── Growth ────────────────────────────────────────────────────────────────
  // The brief is "19,000 merchants per year". Modelled as 19,000 *gross* adds
  // per year, ramped over year 1 and flat thereafter, with churn applied — so
  // the merchant base is 19k at end of Y1 (before churn drag) and grows after.
  growth: {
    grossAddsPerYear: 19000,
    year1RampShape: [0.02, 0.03, 0.04, 0.05, 0.07, 0.08, 0.09, 0.10, 0.11, 0.12, 0.14, 0.15], // sums to 1.0
    monthlyChurn: { free: 0.050, paid: 0.025 },   // free churns harder; 2.5%/mo paid ≈ 26%/yr
    freeToPaidUpgradeMonthly: 0.012,              // % of free base converting to Starter each month
  },

  // ── Tier mix (DIKASIR public pricing, scratchpad/dikasir_pricing.html) ────
  // price is per OUTLET per month, in IDR. Shares are of the merchant base.
  tiers: {
    free:     { share: 0.52, priceIdr: 0,      outlets: 1.0, devices: 1, ordersPerDayPerOutlet: 35  },
    starter:  { share: 0.22, priceIdr: 149000, outlets: 1.0, devices: 2, ordersPerDayPerOutlet: 90  },
    pro:      { share: 0.22, priceIdr: 299000, outlets: 1.2, devices: 3, ordersPerDayPerOutlet: 160 },
    business: { share: 0.04, priceIdr: 549000, outlets: 3.0, devices: 6, ordersPerDayPerOutlet: 320 },
  },

  // ── Workload per unit of business ────────────────────────────────────────
  // Derived from the actual API surface (server/src/*/**.controller.ts) and the
  // checkout transaction in server/src/orders/orders.service.ts.
  // NOTE: these are engineering estimates, NOT load-test measurements. The DEVLOG
  // flags load testing as outstanding; replace `capacity` below with real numbers
  // before treating the infra line as a commitment.
  workload: {
    // Per order: POST /orders, plus settle/revise on open bills, plus corrections.
    writeCallsPerOrder: 1.6,
    // Per order: history list, order detail, open-bill poll, catalog price checks.
    readCallsPerOrder: 6,
    reportCallsPerMerchantPerDay: 12,     // owner/manager reporting home
    portalCallsPerMerchantPerDay: 20,     // D-Customer Portal admin session
    syncCallsPerDevicePerDay: 160,        // offline-first drift cache + sync queue heartbeat
    onlinePollCallsPerOutletPerDay: 600,  // GoFood/Grab/Shopee order polling, ~30s during open hours
    onlineAttachRate: 0.35,               // share of outlets with delivery channels enabled

    bytes: { writeReq: 2500, writeResp: 4000, read: 9000, report: 15000, sync: 700, portal: 6000 },

    // DB write amplification per checkout: 1 Order + ~3 OrderLine + ~0.3 OrderDiscount
    // + 1 Payment + ~3 InventoryMovement + ~3 InventoryStock updates (+ AuditLog on corrections).
    dbRowsPerOrder: 11,
    dbBytesPerOrder: 3600,                // rows + btree indexes + bloat, measured-ish estimate

    // F&B traffic is lunch/dinner spiked. Peak-minute rate vs the 24h average.
    peakToAverageFactor: 6,

    // Menu images (S3 + CloudFront). Mostly edge-cached; this is the miss traffic.
    imageMbPerDevicePerMonth: 12,
    imageStorageMbPerMerchant: 40,
    logBytesPerRequest: 350,
    logSamplingRate: 0.25,                // sample non-error request logs to control CloudWatch
    natBytesPerOrder: 400,                // outbound payment-gateway / webhook calls
  },

  // ── Capacity model: how much work one vCPU absorbs ───────────────────────
  // Cost units: read = 1. A checkout transaction is far heavier than a GET.
  capacity: {
    costUnits: { write: 3, read: 1, report: 4, sync: 0.3 },
    apiUnitsPerSecPerVcpu: 250,
    apiTargetUtilisation: 0.60,
    apiNodeType: 'm7g.xlarge',
    apiMinNodes: 2,                       // HA across 2 AZs
    apiSpareNodes: 1,                     // N+1

    dbWriteRowsPerSecPerVcpu: 350,
    dbReadUnitsPerSecPerVcpu: 600,
    dbTargetUtilisation: 0.60,
    dbHotWindowMonths: 1,                 // recency window whose indexes must stay resident
    dbHotIndexFraction: 0.35,             // only the btree/hot columns need to be in RAM, not every row
    baseHotFraction: 0.50,                // half of catalog/staff/settings is touched in a given month
    dbRamHeadroom: 1.35,                  // RAM must exceed hot set by this much
    dbRetentionMonths: 24,                // older orders archived to S3, dropped from RDS
    dbFreeSpaceBuffer: 1.30,              // never run a Postgres volume at 100%
    dbWalOverhead: 1.25,
    baseDbMbPerMerchant: 5,               // catalog, staff, outlets, settings, price lists
    iopsPerWriteRow: 4,                   // heap + WAL + index writes
    iopsPerReadUnit: 2,
    multiAz: true,
    readReplicas: 'auto',                 // sized from read load; min 1 when multiAz
  },

  // ── Commercial discounts on AWS ──────────────────────────────────────────
  discounts: {
    riCoverage: 0.70,                     // share of steady compute on 1yr no-upfront RI/SP
    ec2RiDiscount: 0.34,                  // measured: m7g.xlarge 0.1349 vs 0.204 OD
    rdsRiDiscount: 0.317,                 // measured: db.r6g.xlarge MAZ 0.7366 vs 1.079 OD
    privatePricingDiscount: 0.00,         // EDP/PPA — set once spend justifies one
    includeAwsBusinessSupport: true,
  },

  // ── Revenue ──────────────────────────────────────────────────────────────
  revenue: {
    annualPrepayShare: 0.35,
    annualPrepayDiscount: 0.17,           // "~2 months free"
    extraDeviceIdrPerMonth: 49000,
    extraDevicesPerPaidMerchant: 0.25,
    addonAttachRate: 0.10,                // e-receipt / loyalty / QR menu
    addonIdrPerMonth: 90000,
    onboardingFeeIdr: 600000,             // one-off, charged to a share of new paid merchants
    onboardingFeeAttach: 0.30,

    // Payment attach — the real upside in POS, and the biggest swing factor.
    qris: {
      enabled: true,
      merchantAttachRate: 0.35,           // merchants routing QRIS through DIKASIR
      shareOfTenderQris: 0.45,
      platformFeeRate: 0.002,             // 0.2% on top of the regulated MDR passthrough
      avgTicketIdr: 28000,
    },
  },

  // ── Cost of service (non-AWS COGS) ───────────────────────────────────────
  cogs: {
    paymentCollectionFeeRate: 0.022,      // VA / e-wallet collection on subscription billing
    supportTicketsPerMerchantMonth: 0.35,
    costPerTicketIdr: 11000,              // loaded agent cost ÷ tickets handled
    messagingIdrPerMerchantMonth: 1500,   // OTP + push/WhatsApp notifications
  },

  // ── Operating expense ────────────────────────────────────────────────────
  opex: {
    // Loaded monthly cost per head, Jakarta 2026 mid-market (salary x1.4).
    loadedCostIdrPerHeadMonth: 35000000,
    headcount: {                          // by year: [Y1, Y2, Y3]
      engineering: [8, 12, 16],
      productDesign: [2, 3, 4],
      supportOps: [6, 14, 22],            // scales with base; ticket cost above is separate
      salesMarketing: [10, 18, 24],
      gAndA: [4, 6, 8],
    },
    cacIdrPerGrossAdd: 250000,            // digital + agent commission, blended over all signups
    onboardingCostIdrPerPaidAdd: 400000,  // field visit, device setup, training
    marketingSpendShareOfRevenue: 0.10,
    officeAndToolsIdrPerHeadMonth: 3500000,
    corporateTaxRate: 0.22,               // Indonesia
  },
};

// Scenario overrides applied on top of ASSUMPTIONS (deep-merged).
export const SCENARIOS = {
  base: {},

  lean: {
    meta: { name: 'lean' },
    capacity: { multiAz: false, apiSpareNodes: 0, dbRetentionMonths: 12, apiUnitsPerSecPerVcpu: 320 },
    workload: { logSamplingRate: 0.05, peakToAverageFactor: 5 },
    discounts: { riCoverage: 0.90 },
  },

  conservative: {
    meta: { name: 'conservative' },
    workload: {
      writeCallsPerOrder: 2.2, readCallsPerOrder: 9, peakToAverageFactor: 8,
      dbBytesPerOrder: 5200, logSamplingRate: 0.50,
    },
    capacity: { apiUnitsPerSecPerVcpu: 160, dbWriteRowsPerSecPerVcpu: 220, dbRetentionMonths: 36 },
    discounts: { riCoverage: 0.50 },
    tiers: {
      free:     { share: 0.62, priceIdr: 0,      outlets: 1.0, devices: 1, ordersPerDayPerOutlet: 35  },
      starter:  { share: 0.20, priceIdr: 149000, outlets: 1.0, devices: 2, ordersPerDayPerOutlet: 90  },
      pro:      { share: 0.16, priceIdr: 299000, outlets: 1.2, devices: 3, ordersPerDayPerOutlet: 160 },
      business: { share: 0.02, priceIdr: 549000, outlets: 3.0, devices: 6, ordersPerDayPerOutlet: 320 },
    },
    revenue: { qris: { merchantAttachRate: 0.15 } },
    growth: { monthlyChurn: { free: 0.070, paid: 0.040 } },
  },

  // The literal reading of the brief: a flat 19,000-merchant book, no growth.
  steady19k: {
    meta: { name: 'steady-19k', horizonMonths: 12 },
    growth: { grossAddsPerYear: 0, monthlyChurn: { free: 0, paid: 0 }, freeToPaidUpgradeMonthly: 0 },
    _seedMerchants: 19000,
  },
};
