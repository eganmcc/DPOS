<script setup lang="ts">
/**
 * Rekap Harian — one row per day, the figures a merchant reconciles the drawer against (specs/011).
 */
import { ref, onMounted } from 'vue';
import { api } from '../api';
import { formatRupiah, formatNumber } from '../format';

interface Row {
  day: string; orders: number; voided: number; subtotal: number; discount: number;
  tax: number; service: number; gross: number; refunded: number; cash: number; nonCash: number;
  byMethod: { method: string; amount: number }[];
}
interface Data {
  range: { from: string; to: string };
  rows: Row[];
  totals: Omit<Row, 'day' | 'byMethod'>;
}

const data = ref<Data | null>(null);
const loading = ref(true);
const from = ref('');
const to = ref('');


async function load() {
  loading.value = true;
  const qs = new URLSearchParams();
  if (from.value) qs.set('from', from.value);
  if (to.value) qs.set('to', to.value);
  data.value = await api.get<Data>(`/admin/journal/daily?${qs}`);
  loading.value = false;
}

const print = () => window.print();

onMounted(load);
</script>

<template>
  <div class="head">
    <h1>Rekap Harian</h1>
    <div class="filters">
      <input class="input" type="date" v-model="from" @change="load" />
      <span class="muted">→</span>
      <input class="input" type="date" v-model="to" @change="load" />
      <button class="btn" @click="print">Cetak</button>
    </div>
  </div>

  <div v-if="loading" class="muted">Memuat…</div>
  <template v-else-if="data">
    <div class="muted small">{{ data.range.from }} → {{ data.range.to }}</div>

    <div class="stats card card-pad">
      <div class="stat">
        <div class="stat-label">Penjualan kotor</div>
        <div class="stat-value gold-num">{{ formatRupiah(data.totals.gross) }}</div>
      </div>
      <div class="stat">
        <div class="stat-label">Tunai</div>
        <div class="stat-value">{{ formatRupiah(data.totals.cash) }}</div>
      </div>
      <div class="stat">
        <div class="stat-label">Non-tunai</div>
        <div class="stat-value">{{ formatRupiah(data.totals.nonCash) }}</div>
      </div>
      <div class="stat">
        <div class="stat-label">Transaksi</div>
        <div class="stat-value">{{ formatNumber(data.totals.orders) }}</div>
      </div>
    </div>

    <div class="card">
      <div class="table-scroll">
        <table class="table">
          <thead>
            <tr>
              <th>Tanggal</th><th class="right">Transaksi</th><th class="right">Subtotal</th>
              <th class="right">Diskon</th><th class="right">Pajak + servis</th>
              <th class="right">Tunai</th><th class="right">Non-tunai</th><th class="right">Kotor</th>
              <th class="right">Batal</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="r in data.rows" :key="r.day">
              <td class="mono nowrap">{{ r.day }}</td>
              <td class="right mono">{{ formatNumber(r.orders) }}</td>
              <td class="right mono">{{ formatRupiah(r.subtotal) }}</td>
              <td class="right mono">{{ r.discount ? formatRupiah(r.discount) : '—' }}</td>
              <td class="right mono">{{ formatRupiah(r.tax + r.service) }}</td>
              <td class="right mono">{{ formatRupiah(r.cash) }}</td>
              <td class="right mono">{{ formatRupiah(r.nonCash) }}</td>
              <td class="right mono"><b>{{ formatRupiah(r.gross) }}</b></td>
              <!-- Voided sales are counted but never banked; a blank here would hide them. -->
              <td class="right mono" :class="{ bad: r.voided > 0 }">{{ r.voided || '—' }}</td>
            </tr>
          </tbody>
          <tfoot>
            <tr class="total-row">
              <td><b>Total</b></td>
              <td class="right mono"><b>{{ formatNumber(data.totals.orders) }}</b></td>
              <td class="right mono"><b>{{ formatRupiah(data.totals.subtotal) }}</b></td>
              <td class="right mono"><b>{{ formatRupiah(data.totals.discount) }}</b></td>
              <td class="right mono"><b>{{ formatRupiah(data.totals.tax + data.totals.service) }}</b></td>
              <td class="right mono"><b>{{ formatRupiah(data.totals.cash) }}</b></td>
              <td class="right mono"><b>{{ formatRupiah(data.totals.nonCash) }}</b></td>
              <td class="right mono"><b>{{ formatRupiah(data.totals.gross) }}</b></td>
              <td class="right mono"><b>{{ data.totals.voided || '—' }}</b></td>
            </tr>
          </tfoot>
        </table>
      </div>
      <p v-if="!data.rows.length" class="muted pad">Tidak ada penjualan pada rentang ini.</p>
    </div>
  </template>
</template>

<style scoped>
.stats { display: flex; gap: 16px; flex-wrap: wrap; margin: 12px 0; }
.stat { flex: 1; min-width: 150px; }
.stat-label { font-size: 12px; opacity: 0.7; }
.stat-value { font-size: 20px; font-weight: 700; }
.bad { color: #9A3324; }
.small { font-size: 12px; }
.right { text-align: right; }
.nowrap { white-space: nowrap; }
.mono { font-variant-numeric: tabular-nums; }
.pad { padding: 16px; }
.total-row td { border-top: 2px solid var(--outline); }
@media print { .filters { display: none; } }
</style>
