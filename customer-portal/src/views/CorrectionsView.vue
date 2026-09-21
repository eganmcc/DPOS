<script setup lang="ts">
/**
 * Jurnal Koreksi — every void, refund and abandoned bill, with its reason and approver (specs/011).
 *
 * This is the append-only trail read back as a report. A system that could not produce this list
 * would have no business claiming its history is immutable.
 */
import { ref, onMounted } from 'vue';
import { api } from '../api';
import { formatRupiah, formatNumber } from '../format';

interface Row {
  kind: string; at: string; orderId: string; orderAt: string; amount: number;
  reason: string | null; by: string | null; approvedBy: string | null; selfApproved: boolean;
}
interface Data {
  range: { from: string; to: string };
  rows: Row[];
  totals: { voids: number; voidAmount: number; refunds: number; refundAmount: number; cancelled: number; selfApproved: number };
}

const data = ref<Data | null>(null);
const loading = ref(true);
const from = ref('');
const to = ref('');

const kindLabel = (k: string) =>
  k === 'VOID' ? 'Pembatalan'
  : k === 'REFUND' ? 'Refund penuh'
  : k === 'PARTIAL_REFUND' ? 'Refund sebagian'
  : 'Bon ditinggalkan';
const time = (iso: string) => iso.slice(0, 16).replace('T', ' ');

async function load() {
  loading.value = true;
  const qs = new URLSearchParams();
  if (from.value) qs.set('from', from.value);
  if (to.value) qs.set('to', to.value);
  data.value = await api.get<Data>(`/admin/journal/corrections?${qs}`);
  loading.value = false;
}

onMounted(load);
</script>

<template>
  <div class="head">
    <h1>Jurnal Koreksi</h1>
    <div class="filters">
      <input class="input" type="date" v-model="from" @change="load" />
      <span class="muted">→</span>
      <input class="input" type="date" v-model="to" @change="load" />
    </div>
  </div>

  <div v-if="loading" class="muted">Memuat…</div>
  <template v-else-if="data">
    <div class="muted small">{{ data.range.from }} → {{ data.range.to }}</div>

    <div class="stats card card-pad">
      <div class="stat">
        <div class="stat-label">Pembatalan</div>
        <div class="stat-value">{{ formatNumber(data.totals.voids) }}</div>
        <div class="muted small">{{ formatRupiah(data.totals.voidAmount) }}</div>
      </div>
      <div class="stat">
        <div class="stat-label">Refund</div>
        <div class="stat-value">{{ formatNumber(data.totals.refunds) }}</div>
        <div class="muted small">{{ formatRupiah(data.totals.refundAmount) }}</div>
      </div>
      <div class="stat">
        <div class="stat-label">Bon ditinggalkan</div>
        <div class="stat-value">{{ formatNumber(data.totals.cancelled) }}</div>
      </div>
      <div class="stat">
        <div class="stat-label">Disetujui sendiri</div>
        <div class="stat-value" :class="{ warn: data.totals.selfApproved > 0 }">
          {{ formatNumber(data.totals.selfApproved) }}
        </div>
      </div>
    </div>

    <p class="muted small">
      Koreksi tidak menghapus apa pun — setiap baris di bawah adalah catatan baru di atas transaksi
      aslinya. "Disetujui sendiri" bukan berarti salah: di toko satu orang, pemilik memang
      penyetujunya. Tapi itulah angka yang ingin dilihat lebih dulu oleh pemeriksa.
    </p>

    <div class="card">
      <table class="table">
        <thead>
          <tr><th>Waktu</th><th>Jenis</th><th>Alasan</th><th>Oleh</th><th>Disetujui</th><th class="right">Nilai</th></tr>
        </thead>
        <tbody>
          <tr v-for="(r, i) in data.rows" :key="r.orderId + i">
            <td class="mono nowrap">{{ time(r.at) }}</td>
            <td>{{ kindLabel(r.kind) }}</td>
            <td>{{ r.reason || '—' }}</td>
            <td class="small">{{ r.by || '—' }}</td>
            <td class="small" :class="{ warn: r.selfApproved }">
              {{ r.approvedBy || (r.selfApproved ? 'sendiri' : '—') }}
            </td>
            <td class="right mono">{{ formatRupiah(r.amount) }}</td>
          </tr>
        </tbody>
      </table>
      <p v-if="!data.rows.length" class="muted pad">Tidak ada koreksi pada rentang ini.</p>
    </div>
  </template>
</template>

<style scoped>
.stats { display: flex; gap: 16px; flex-wrap: wrap; margin: 12px 0; }
.stat { flex: 1; min-width: 150px; }
.stat-label { font-size: 12px; opacity: 0.7; }
.stat-value { font-size: 20px; font-weight: 700; }
.warn { color: #7A5A00; }
.small { font-size: 12px; }
.right { text-align: right; }
.nowrap { white-space: nowrap; }
.mono { font-variant-numeric: tabular-nums; }
.pad { padding: 16px; }
</style>
