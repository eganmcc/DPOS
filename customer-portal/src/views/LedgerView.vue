<script setup lang="ts">
/**
 * Jurnal Umum — double-entry postings, one set per day (specs/011).
 *
 * The report an accountant can actually post. Debits and credits are shown side by side and the
 * balance check is displayed rather than assumed: if a day ever fails to balance the screen says
 * so, because a tidy total that hides a disagreement is worse than no report.
 */
import { ref, onMounted } from 'vue';
import { api } from '../api';
import { formatRupiah } from '../format';

interface Posting { account: string; debit: number; credit: number }
interface Entry { day: string; postings: Posting[]; debit: number; credit: number; balanced: boolean; costComplete: boolean }
interface Data {
  range: { from: string; to: string };
  entries: Entry[];
  totals: { debit: number; credit: number; unbalancedDays: number };
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
  data.value = await api.get<Data>(`/admin/journal/general?${qs}`);
  loading.value = false;
}

const print = () => window.print();

onMounted(load);
</script>

<template>
  <div class="head">
    <h1>Jurnal Umum</h1>
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
        <div class="stat-label">Total debit</div>
        <div class="stat-value">{{ formatRupiah(data.totals.debit) }}</div>
      </div>
      <div class="stat">
        <div class="stat-label">Total kredit</div>
        <div class="stat-value">{{ formatRupiah(data.totals.credit) }}</div>
      </div>
      <div class="stat">
        <div class="stat-label">Hari tidak seimbang</div>
        <div class="stat-value" :class="{ bad: data.totals.unbalancedDays > 0 }">
          {{ data.totals.unbalancedDays }}
        </div>
      </div>
    </div>

    <p class="muted small">
      Kas dan Bank didebit dari pembayaran yang diterima; Pendapatan, Pajak Terutang dan Service
      Charge dikredit; HPP didebit dengan Persediaan sebagai lawannya. Transaksi yang dibatalkan
      tidak diposting ke mana pun.
    </p>

    <div class="card card-pad" v-for="e in data.entries" :key="e.day">
      <div class="entry-head">
        <b class="mono">{{ e.day }}</b>
        <span v-if="!e.balanced" class="bad small">TIDAK SEIMBANG</span>
        <span v-else class="muted small">seimbang</span>
      </div>
      <table class="table">
        <thead><tr><th>Akun</th><th class="right">Debit</th><th class="right">Kredit</th></tr></thead>
        <tbody>
          <tr v-for="p in e.postings" :key="p.account">
            <td :class="{ indent: p.credit > 0 }">{{ p.account }}</td>
            <td class="right mono">{{ p.debit ? formatRupiah(p.debit) : '' }}</td>
            <td class="right mono">{{ p.credit ? formatRupiah(p.credit) : '' }}</td>
          </tr>
        </tbody>
        <tfoot>
          <tr class="total-row">
            <td></td>
            <td class="right mono"><b>{{ formatRupiah(e.debit) }}</b></td>
            <td class="right mono"><b>{{ formatRupiah(e.credit) }}</b></td>
          </tr>
        </tfoot>
      </table>
      <p v-if="!e.costComplete" class="muted small">
        Ada barang terjual tanpa harga modal, jadi pasangan HPP / Persediaan hari ini belum lengkap.
      </p>
    </div>
    <p v-if="!data.entries.length" class="muted">Tidak ada transaksi pada rentang ini.</p>
  </template>
</template>

<style scoped>
.stats { display: flex; gap: 16px; flex-wrap: wrap; margin: 12px 0; }
.stat { flex: 1; min-width: 150px; }
.stat-label { font-size: 12px; opacity: 0.7; }
.stat-value { font-size: 20px; font-weight: 700; }
.entry-head { display: flex; justify-content: space-between; align-items: center; margin-bottom: 6px; }
/* Credits sit in from the margin, the way a hand-written journal indents them. */
.indent { padding-left: 28px; }
.bad { color: #9A3324; font-weight: 700; }
.small { font-size: 12px; }
.right { text-align: right; }
.mono { font-variant-numeric: tabular-nums; }
.total-row td { border-top: 2px solid var(--outline); }
@media print { .filters { display: none; } }
</style>
