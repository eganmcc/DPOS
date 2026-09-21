<script setup lang="ts">
/** Rekap Pajak — what was collected as tax and service charge, at the rate it was charged. */
import { ref, onMounted } from 'vue';
import { api } from '../api';
import { formatRupiah, formatNumber } from '../format';

interface Row { day: string; base: number; tax: number; service: number; orders: number }
interface Data {
  range: { from: string; to: string };
  label: string | null;
  rateBps: number | null;
  rows: Row[];
  totals: { base: number; tax: number; service: number; orders: number };
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
  data.value = await api.get<Data>(`/admin/journal/tax?${qs}`);
  loading.value = false;
}

const print = () => window.print();

onMounted(load);
</script>

<template>
  <div class="head">
    <h1>Rekap Pajak</h1>
    <div class="filters">
      <input class="input" type="date" v-model="from" @change="load" />
      <span class="muted">→</span>
      <input class="input" type="date" v-model="to" @change="load" />
      <button class="btn" @click="print">Cetak</button>
    </div>
  </div>

  <div v-if="loading" class="muted">Memuat…</div>
  <template v-else-if="data">
    <div class="muted small">
      {{ data.range.from }} → {{ data.range.to }}
      <template v-if="data.label"> · {{ data.label }} {{ ((data.rateBps ?? 0) / 100).toFixed(1) }}%</template>
    </div>

    <div class="stats card card-pad">
      <div class="stat">
        <div class="stat-label">Dasar pengenaan</div>
        <div class="stat-value">{{ formatRupiah(data.totals.base) }}</div>
      </div>
      <div class="stat">
        <div class="stat-label">Pajak terutang</div>
        <div class="stat-value gold-num">{{ formatRupiah(data.totals.tax) }}</div>
      </div>
      <div class="stat">
        <div class="stat-label">Service charge</div>
        <div class="stat-value">{{ formatRupiah(data.totals.service) }}</div>
      </div>
      <div class="stat">
        <div class="stat-label">Transaksi</div>
        <div class="stat-value">{{ formatNumber(data.totals.orders) }}</div>
      </div>
    </div>

    <p v-if="!data.label" class="muted small">
      Outlet ini tidak punya aturan pajak, jadi tidak ada pajak yang dipungut. Itu keadaan datanya,
      bukan kolom yang belum diisi.
    </p>

    <div class="card" v-if="data.rows.length">
      <div class="table-scroll">
        <table class="table">
          <thead>
            <tr><th>Tanggal</th><th class="right">Transaksi</th><th class="right">Dasar pengenaan</th><th class="right">Pajak</th><th class="right">Servis</th></tr>
          </thead>
          <tbody>
            <tr v-for="r in data.rows" :key="r.day">
              <td class="mono nowrap">{{ r.day }}</td>
              <td class="right mono">{{ formatNumber(r.orders) }}</td>
              <td class="right mono">{{ formatRupiah(r.base) }}</td>
              <td class="right mono"><b>{{ formatRupiah(r.tax) }}</b></td>
              <td class="right mono">{{ formatRupiah(r.service) }}</td>
            </tr>
          </tbody>
          <tfoot>
            <tr class="total-row">
              <td><b>Total</b></td>
              <td class="right mono"><b>{{ formatNumber(data.totals.orders) }}</b></td>
              <td class="right mono"><b>{{ formatRupiah(data.totals.base) }}</b></td>
              <td class="right mono"><b>{{ formatRupiah(data.totals.tax) }}</b></td>
              <td class="right mono"><b>{{ formatRupiah(data.totals.service) }}</b></td>
            </tr>
          </tfoot>
        </table>
      </div>
    </div>
  </template>
</template>

<style scoped>
.stats { display: flex; gap: 16px; flex-wrap: wrap; margin: 12px 0; }
.stat { flex: 1; min-width: 150px; }
.stat-label { font-size: 12px; opacity: 0.7; }
.stat-value { font-size: 20px; font-weight: 700; }
.small { font-size: 12px; }
.right { text-align: right; }
.nowrap { white-space: nowrap; }
.mono { font-variant-numeric: tabular-nums; }
.total-row td { border-top: 2px solid var(--outline); }
@media print { .filters { display: none; } }
</style>
