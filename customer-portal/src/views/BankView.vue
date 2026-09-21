<script setup lang="ts">
/**
 * Laporan Bank (specs/011-bank-reporting).
 *
 * Five reports the acquiring bank asked for, on one screen, in the order it reads them: can the
 * numbers be believed (rekonsiliasi, integritas), can this merchant repay (profil kredit, laba
 * rugi), and did the merchants we handed this to ever switch it on (aktivasi).
 *
 * Indonesian labels throughout — this screen is read in a branch, not by us.
 */
import { ref, onMounted, computed } from 'vue';
import { api } from '../api';
import { formatRupiah, formatNumber } from '../format';

interface ReconLine {
  day: string; rail: string; dposAmount: number; settledAmount: number;
  difference: number; status: string; feeAmount: number; netAmount: number;
}
interface Recon {
  range: { from: string; to: string };
  lines: ReconLine[];
  summary: {
    dposTotal: number; settledTotal: number; matchedTotal: number; difference: number;
    matchRateBps: number; matched: number; notSettled: number; notInDpos: number; amountDiffers: number;
  };
}
interface CreditMonth {
  month: string; turnover: number; orders: number; avgTicket: number; tradingDays: number;
  avgPerTradingDay: number; cashShareBps: number; bankRailShareBps: number;
  grossProfit: number | null; grossMarginBps: number | null;
}
interface Credit {
  merchant: { name: string; businessType: string; sellsFromCatalogue: boolean; hasQris: boolean; hasEdc: boolean; hasNpwp: boolean; hasNib: boolean };
  series: CreditMonth[];
  summary: {
    monthsOfHistory: number; turnover12m: number; avgMonthlyTurnover: number;
    medianMonthlyTurnover: number; turnoverCvBps: number; worstMonthTurnover: number;
    bestMonthTurnover: number; avgTradingDays: number; longestGapDays: number;
    cashShareBps: number; nonCashShareBps: number; growthBps: number;
  };
}
interface Pnl {
  range: { from: string; to: string }; orderCount: number;
  pendapatan: number; hpp: number; labaKotor: number; bebanUsaha: number; labaBersih: number;
  costComplete: boolean;
}
interface Integrity {
  range: { from: string; to: string }; orders: number; grossSales: number;
  voids: { count: number; amount: number; rateBps: number; byApprover: { name: string; count: number }[] };
  refunds: { count: number; amount: number; rateBps: number };
  discounts: { count: number; amount: number };
  devices: { deviceId: string | null; orders: number }[];
  assurances: Record<string, unknown>;
}
interface Activation {
  funnel: {
    onboarded: number; activated: number; active7d: number; active30d: number;
    consented: number; withQris: number; withEdc: number; medianDaysToFirstSale: number;
  };
  dormant: { name: string; daysSinceLastSale: number; lastSaleAt: string }[];
  merchants: { merchantId: string; name: string; onboardedAt: string; firstSaleAt: string | null; daysToFirstSale: number | null; active30d: boolean; hasQris: boolean; hasEdc: boolean; consented: boolean }[];
}

const recon = ref<Recon | null>(null);
const credit = ref<Credit | null>(null);
const pnl = ref<Pnl | null>(null);
const integrity = ref<Integrity | null>(null);
const activation = ref<Activation | null>(null);
const loading = ref(true);
const consentError = ref(false);

const from = ref('');
const to = ref('');
/** Beban usaha is the merchant's own figure — DPOS records sales, not rent and wages. */
const expenses = ref(0);

const pct = (bps: number) => `${(bps / 100).toFixed(1)}%`;
const maxTurnover = computed(() =>
  Math.max(1, ...(credit.value?.series.map((m) => m.turnover) ?? [1])),
);
const monthLabel = (m: string) => {
  const names = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
  return names[Number(m.slice(5, 7)) - 1] ?? m;
};
const statusLabel = (s: string) =>
  s === 'MATCHED' ? 'Cocok'
  : s === 'NOT_SETTLED' ? 'Belum disettle'
  : s === 'NOT_IN_DPOS' ? 'Tidak ada di DPOS'
  : 'Jumlah beda';

async function load() {
  loading.value = true;
  consentError.value = false;
  const qs = new URLSearchParams();
  if (from.value) qs.set('from', from.value);
  if (to.value) qs.set('to', to.value);
  const q = qs.toString() ? `?${qs}` : '';
  const pq = new URLSearchParams(qs);
  pq.set('expenses', String(expenses.value || 0));

  const [r, c, p, i, a] = await Promise.allSettled([
    api.get<Recon>(`/admin/bank/reconciliation${q}`),
    api.get<Credit>('/admin/bank/credit-profile'),
    api.get<Pnl>(`/admin/bank/profit-loss?${pq}`),
    api.get<Integrity>(`/admin/bank/integrity${q}`),
    api.get<Activation>('/admin/bank/activation'),
  ]);
  if (r.status === 'fulfilled') recon.value = r.value;
  // The credit profile is the one report consent can refuse, and saying so beats an empty card.
  if (c.status === 'fulfilled') credit.value = c.value;
  else consentError.value = true;
  if (p.status === 'fulfilled') pnl.value = p.value;
  if (i.status === 'fulfilled') integrity.value = i.value;
  if (a.status === 'fulfilled') activation.value = a.value;
  loading.value = false;
}

/** The branch files a printed copy; the filters are hidden in print CSS below. */
const print = () => window.print();

onMounted(load);
</script>

<template>
  <div class="head">
    <h1>Laporan Bank</h1>
    <div class="filters">
      <input class="input" type="date" v-model="from" @change="load" />
      <span class="muted">→</span>
      <input class="input" type="date" v-model="to" @change="load" />
      <button class="btn" @click="load">Muat ulang</button>
      <button class="btn" @click="print">Cetak</button>
    </div>
  </div>

  <div v-if="loading" class="muted">Memuat…</div>
  <template v-else>
    <!-- 1 — reconciliation. The report the rest lean on. -->
    <div class="card card-pad" v-if="recon">
      <h3 class="ch">Rekonsiliasi DPOS ↔ settlement bank</h3>
      <p class="muted small">
        Penjualan non-tunai yang kami catat, dibandingkan dengan yang disettle acquirer. Angka tunai
        di laporan lain berdiri di atas hasil ini.
      </p>
      <div class="stats">
        <div class="stat">
          <div class="stat-label">Tingkat kecocokan</div>
          <div class="stat-value gold-num">{{ pct(recon.summary.matchRateBps) }}</div>
        </div>
        <div class="stat">
          <div class="stat-label">Menurut DPOS</div>
          <div class="stat-value">{{ formatRupiah(recon.summary.dposTotal) }}</div>
        </div>
        <div class="stat">
          <div class="stat-label">Disettle bank</div>
          <div class="stat-value">{{ formatRupiah(recon.summary.settledTotal) }}</div>
        </div>
        <div class="stat">
          <div class="stat-label">Selisih</div>
          <div class="stat-value" :class="{ bad: recon.summary.difference !== 0 }">
            {{ formatRupiah(Math.abs(recon.summary.difference)) }}
          </div>
        </div>
      </div>
      <div class="table-scroll" v-if="recon.lines.length">
        <table class="table">
          <thead>
            <tr><th>Tanggal</th><th>Jalur</th><th class="right">DPOS</th><th class="right">Settlement</th><th class="right">Selisih</th><th>Status</th></tr>
          </thead>
          <tbody>
            <!-- Findings first: a clean line teaches nobody anything. -->
            <tr v-for="l in [...recon.lines].sort((a, b) => (a.status === 'MATCHED' ? 1 : 0) - (b.status === 'MATCHED' ? 1 : 0))"
                :key="l.day + l.rail" :class="{ bad: l.status !== 'MATCHED' }">
              <td class="mono">{{ l.day }}</td>
              <td>{{ l.rail }}</td>
              <td class="right mono">{{ formatRupiah(l.dposAmount) }}</td>
              <td class="right mono">{{ formatRupiah(l.settledAmount) }}</td>
              <td class="right mono">{{ l.difference === 0 ? '—' : formatRupiah(l.difference) }}</td>
              <td>{{ statusLabel(l.status) }}</td>
            </tr>
          </tbody>
        </table>
      </div>
      <p v-else class="muted">Tidak ada transaksi non-tunai pada rentang ini.</p>
    </div>

    <!-- 2 — the credit figures -->
    <div class="card card-pad" v-if="credit">
      <h3 class="ch">Profil kredit — {{ credit.summary.monthsOfHistory }} bulan riwayat</h3>
      <div class="stats">
        <div class="stat">
          <div class="stat-label">Omzet rata-rata / bulan</div>
          <div class="stat-value gold-num">{{ formatRupiah(credit.summary.avgMonthlyTurnover) }}</div>
        </div>
        <div class="stat">
          <div class="stat-label">Bulan terendah</div>
          <div class="stat-value">{{ formatRupiah(credit.summary.worstMonthTurnover) }}</div>
        </div>
        <div class="stat">
          <div class="stat-label">Hari buka / bulan</div>
          <div class="stat-value">{{ credit.summary.avgTradingDays }}</div>
        </div>
        <div class="stat">
          <div class="stat-label">Porsi tunai</div>
          <div class="stat-value">{{ pct(credit.summary.cashShareBps) }}</div>
        </div>
      </div>
      <p class="muted small">
        Naik-turun omzet {{ pct(credit.summary.turnoverCvBps) }} · jeda terpanjang tanpa penjualan
        {{ credit.summary.longestGapDays }} hari · pertumbuhan {{ pct(credit.summary.growthBps) }}.
        Porsi tunai adalah bagian yang tidak terlihat di rekening — itulah yang ditambahkan DPOS.
      </p>
      <div class="bars" v-if="credit.series.length">
        <div v-for="m in credit.series" :key="m.month" class="bar-col"
             :title="`${m.month}: ${formatRupiah(m.turnover)} · ${m.tradingDays} hari buka`">
          <div class="bar" :style="{ height: `${Math.round((m.turnover / maxTurnover) * 120) + 2}px` }"></div>
          <div class="bar-x">{{ monthLabel(m.month) }}</div>
        </div>
      </div>
      <div class="table-scroll">
        <table class="table">
          <thead>
            <tr><th>Bulan</th><th class="right">Omzet</th><th class="right">Transaksi</th><th class="right">Hari buka</th><th class="right">Tunai</th><th class="right">Margin</th></tr>
          </thead>
          <tbody>
            <tr v-for="m in credit.series" :key="m.month">
              <td class="mono">{{ m.month }}</td>
              <td class="right mono">{{ formatRupiah(m.turnover) }}</td>
              <td class="right mono">{{ formatNumber(m.orders) }}</td>
              <td class="right mono">{{ m.tradingDays }}</td>
              <td class="right mono">{{ pct(m.cashShareBps) }}</td>
              <!-- No catalogue, no cost price, no margin. Said, not sent as a zero. -->
              <td class="right mono">{{ m.grossMarginBps === null ? '—' : pct(m.grossMarginBps) }}</td>
            </tr>
          </tbody>
        </table>
      </div>
      <p v-if="!credit.merchant.sellsFromCatalogue" class="muted small">
        Pedagang ini menjual tanpa katalog, jadi harga modal tidak ada menurut definisinya — bukan
        karena belum diisi. Kolom margin sengaja dikosongkan.
      </p>
    </div>
    <div class="card card-pad" v-else-if="consentError">
      <h3 class="ch">Profil kredit</h3>
      <p class="muted">
        Pedagang ini belum menyetujui pembagian data transaksi dengan bank. Tanpa persetujuan itu,
        laporan ini tidak dikeluarkan.
      </p>
    </div>

    <div class="grid">
      <!-- 3 — the simple P&L a branch files -->
      <div class="card card-pad" v-if="pnl">
        <h3 class="ch">Laporan Laba Rugi Sederhana</h3>
        <div class="muted small">{{ pnl.range.from }} → {{ pnl.range.to }} · {{ formatNumber(pnl.orderCount) }} transaksi</div>
        <div class="row"><span>Pendapatan</span><b class="mono">{{ formatRupiah(pnl.pendapatan) }}</b></div>
        <div class="row"><span>Harga Pokok Penjualan</span><b class="mono">{{ formatRupiah(pnl.hpp) }}</b></div>
        <div class="row strong"><span>Laba Kotor</span><b class="mono">{{ formatRupiah(pnl.labaKotor) }}</b></div>
        <div class="row">
          <span>Beban Usaha</span>
          <input class="input right mono" type="number" v-model.number="expenses" @change="load" />
        </div>
        <div class="row strong"><span>Laba Bersih</span><b class="mono gold-num">{{ formatRupiah(pnl.labaBersih) }}</b></div>
        <p class="muted small">
          Pendapatan dan HPP berasal dari penjualan yang tercatat. Beban usaha diisi pedagang —
          DPOS mencatat penjualan, bukan sewa dan gaji.
        </p>
        <p v-if="!pnl.costComplete" class="muted small bad">
          Ada barang terjual tanpa harga modal, jadi laba kotor di atas terlalu tinggi.
        </p>
      </div>

      <!-- 4 — why any of it can be believed -->
      <div class="card card-pad" v-if="integrity">
        <h3 class="ch">Integritas data</h3>
        <div class="row"><span>Transaksi</span><b class="mono">{{ formatNumber(integrity.orders) }}</b></div>
        <div class="row"><span>Pembatalan (void)</span><b class="mono">{{ integrity.voids.count }} · {{ pct(integrity.voids.rateBps) }}</b></div>
        <div class="row"><span>Refund</span><b class="mono">{{ integrity.refunds.count }} · {{ pct(integrity.refunds.rateBps) }}</b></div>
        <div class="row" v-for="a in integrity.voids.byApprover" :key="a.name">
          <span class="muted small">Disetujui {{ a.name }}</span><b class="mono small">{{ a.count }}</b>
        </div>
        <ul class="assure">
          <li>Semua nilai dihitung ulang di server — ponsel tidak bisa menetapkan harga.</li>
          <li>Koreksi bersifat menambah: void, refund dan pembatalan menulis catatan baru.</li>
          <li>Void memerlukan persetujuan penyelia.</li>
          <li>Data disimpan di wilayah Jakarta (ap-southeast-3).</li>
        </ul>
        <p class="muted small">
          Ini tidak berarti datanya pasti benar — penjualan tunai masih bisa tidak dicatat. Yang
          ditawarkan adalah jangkar rekonsiliasi di atas, jejak koreksi, dan pola yang tampak bila
          angka diubah belakangan.
        </p>
      </div>
    </div>

    <!-- 5 — the distribution story -->
    <div class="card card-pad" v-if="activation">
      <h3 class="ch">Aktivasi pedagang</h3>
      <div class="stats">
        <div class="stat"><div class="stat-label">Didaftarkan</div><div class="stat-value">{{ activation.funnel.onboarded }}</div></div>
        <div class="stat"><div class="stat-label">Pernah transaksi</div><div class="stat-value gold-num">{{ activation.funnel.activated }}</div></div>
        <div class="stat"><div class="stat-label">Aktif 30 hari</div><div class="stat-value">{{ activation.funnel.active30d }}</div></div>
        <div class="stat"><div class="stat-label">Median hari ke transaksi pertama</div><div class="stat-value">{{ activation.funnel.medianDaysToFirstSale }}</div></div>
      </div>
      <div class="muted small">
        QRIS terpasang {{ activation.funnel.withQris }} · EDC {{ activation.funnel.withEdc }} ·
        menyetujui berbagi data {{ activation.funnel.consented }}
      </div>
      <template v-if="activation.dormant.length">
        <h3 class="ch">Tidak ada penjualan ≥ 7 hari</h3>
        <div class="table-scroll">
          <table class="table">
            <thead><tr><th>Pedagang</th><th class="right">Penjualan terakhir</th><th class="right">Hari diam</th></tr></thead>
            <tbody>
              <tr v-for="d in activation.dormant" :key="d.name" class="bad">
                <td>{{ d.name }}</td><td class="right mono">{{ d.lastSaleAt }}</td>
                <td class="right mono">{{ d.daysSinceLastSale }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </template>
    </div>
  </template>
</template>

<style scoped>
.stats { display: flex; gap: 16px; flex-wrap: wrap; margin: 12px 0; }
.stat { flex: 1; min-width: 150px; }
.stat-label { font-size: 12px; opacity: 0.7; }
.stat-value { font-size: 20px; font-weight: 700; }
.row { display: flex; justify-content: space-between; align-items: center; padding: 6px 0; border-bottom: 1px solid rgba(0,0,0,0.06); }
.row.strong { font-weight: 700; }
.bars { display: flex; gap: 8px; align-items: flex-end; height: 140px; margin: 12px 0; }
.bar-col { flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: flex-end; }
.bar { width: 100%; background: #133A68; border-radius: 4px 4px 0 0; }
.bar-x { font-size: 10px; opacity: 0.7; margin-top: 4px; }
.bad { color: #9A3324; }
.assure { font-size: 12px; opacity: 0.85; margin: 10px 0 4px; padding-left: 18px; }
.assure li { margin: 3px 0; }
.small { font-size: 12px; }
.right { text-align: right; }
.mono { font-variant-numeric: tabular-nums; }
@media print {
  .filters { display: none; }
}
</style>
