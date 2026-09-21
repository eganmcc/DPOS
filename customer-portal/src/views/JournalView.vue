<script setup lang="ts">
/**
 * Jurnal Transaksi — every transaction in the period, newest first (specs/011).
 *
 * Voided and refunded sales stay IN the list, labelled. A journal that filters its corrections out
 * is the one nobody can audit, and the status column is the reason a bank asks for this at all.
 */
import { ref, onMounted, computed } from 'vue';
import { api } from '../api';
import { formatRupiah, formatNumber } from '../format';

interface Row {
  id: string; at: string; outlet: string; cashier: string; type: string; channel: string;
  ref: string | null; customer: string | null; items: number; description: string;
  subtotal: number; discount: number; tax: number; service: number; total: number;
  methods: string[]; refunded: number; status: string; voidReason: string | null;
}
interface Data { range: { from: string; to: string }; total: number; limit: number; offset: number; rows: Row[] }

const data = ref<Data | null>(null);
const loading = ref(true);
const from = ref('');
const to = ref('');
const offset = ref(0);
const LIMIT = 100;

const statusLabel = (s: string) =>
  s === 'VOIDED' ? 'Dibatalkan'
  : s === 'REFUNDED' ? 'Refund penuh'
  : s === 'PARTIAL_REFUND' ? 'Refund sebagian'
  : s === 'AWAITING_PAYMENT' ? 'Belum dibayar'
  : s === 'CANCELLED' ? 'Bon dibatalkan'
  : 'Selesai';
const isProblem = (s: string) => s !== 'COMPLETED';
const methodLabel = (m: string) =>
  m === 'CASH' ? 'Tunai' : m === 'QRIS_SIMULATED' ? 'QRIS' : m === 'ONLINE' ? 'Online' : m.replace(/_/g, ' ');
const time = (iso: string) => iso.slice(0, 16).replace('T', ' ');

const pages = computed(() => (data.value ? Math.ceil(data.value.total / LIMIT) : 0));
const page = computed(() => Math.floor(offset.value / LIMIT) + 1);

async function load() {
  loading.value = true;
  const qs = new URLSearchParams({ limit: String(LIMIT), offset: String(offset.value) });
  if (from.value) qs.set('from', from.value);
  if (to.value) qs.set('to', to.value);
  data.value = await api.get<Data>(`/admin/journal/transactions?${qs}`);
  loading.value = false;
}

function move(by: number) {
  offset.value = Math.max(0, offset.value + by * LIMIT);
  load();
}

/** A journal nobody can take away is half a journal — the bank will want it in Excel. */
function exportCsv() {
  const rows = data.value?.rows ?? [];
  const head = ['Waktu', 'Outlet', 'Kasir', 'Keterangan', 'Subtotal', 'Diskon', 'Pajak', 'Servis', 'Total', 'Metode', 'Status'];
  const body = rows.map((r) => [
    time(r.at), r.outlet, r.cashier, r.description, r.subtotal, r.discount, r.tax, r.service,
    r.total, r.methods.map(methodLabel).join(' + '), statusLabel(r.status),
  ]);
  const csv = [head, ...body]
    .map((line) => line.map((c) => `"${String(c ?? '').replace(/"/g, '""')}"`).join(','))
    .join('\n');
  const url = URL.createObjectURL(new Blob(['﻿' + csv], { type: 'text/csv;charset=utf-8' }));
  const a = document.createElement('a');
  a.href = url;
  a.download = `jurnal-transaksi-${data.value?.range.from}-${data.value?.range.to}.csv`;
  a.click();
  URL.revokeObjectURL(url);
}

onMounted(load);
</script>

<template>
  <div class="head">
    <h1>Jurnal Transaksi</h1>
    <div class="filters">
      <input class="input" type="date" v-model="from" @change="offset = 0; load()" />
      <span class="muted">→</span>
      <input class="input" type="date" v-model="to" @change="offset = 0; load()" />
      <button class="btn" @click="exportCsv">Ekspor CSV</button>
    </div>
  </div>

  <div v-if="loading" class="muted">Memuat…</div>
  <template v-else-if="data">
    <div class="muted small">
      {{ data.range.from }} → {{ data.range.to }} · {{ formatNumber(data.total) }} transaksi
      <template v-if="pages > 1"> · halaman {{ page }} dari {{ pages }}</template>
    </div>

    <div class="card">
      <table class="table">
        <thead>
          <tr>
            <th>Waktu</th><th>Keterangan</th><th>Kasir</th>
            <th class="right">Subtotal</th><th class="right">Pajak</th><th class="right">Total</th>
            <th>Metode</th><th>Status</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="r in data.rows" :key="r.id" :class="{ bad: isProblem(r.status) }">
            <td class="mono nowrap">{{ time(r.at) }}</td>
            <td>
              {{ r.description }}
              <div v-if="r.voidReason" class="muted small">alasan: {{ r.voidReason }}</div>
              <div v-else-if="r.customer" class="muted small">{{ r.customer }}</div>
            </td>
            <td class="small">{{ r.cashier }}</td>
            <td class="right mono">{{ formatRupiah(r.subtotal) }}</td>
            <td class="right mono">{{ r.tax ? formatRupiah(r.tax) : '—' }}</td>
            <td class="right mono"><b>{{ formatRupiah(r.total) }}</b></td>
            <td class="small">{{ r.methods.map(methodLabel).join(' + ') || '—' }}</td>
            <td class="small">{{ statusLabel(r.status) }}</td>
          </tr>
        </tbody>
      </table>
      <p v-if="!data.rows.length" class="muted pad">Tidak ada transaksi pada rentang ini.</p>
    </div>

    <div class="pager" v-if="pages > 1">
      <button class="btn" :disabled="offset === 0" @click="move(-1)">← Sebelumnya</button>
      <span class="muted small">{{ page }} / {{ pages }}</span>
      <button class="btn" :disabled="page >= pages" @click="move(1)">Berikutnya →</button>
    </div>
  </template>
</template>

<style scoped>
.bad { color: #9A3324; }
.small { font-size: 12px; }
.right { text-align: right; }
.nowrap { white-space: nowrap; }
.mono { font-variant-numeric: tabular-nums; }
.pad { padding: 16px; }
.pager { display: flex; gap: 12px; align-items: center; justify-content: center; margin-top: 14px; }
</style>
