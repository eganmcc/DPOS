<script setup lang="ts">
import { ref, onMounted, computed } from 'vue';
import { api } from '../api';
import { formatRupiah, formatNumber } from '../format';

interface Branch { id: string; name: string }
interface Summary {
  range: { from: string; to: string };
  netSales: number;
  orderCount: number;
  avgTicket: number;
  paymentBreakdown: { method: string; amount: number }[];
  byOutlet: { name: string; sales: number; count: number }[];
  topItems: { name: string; qty: number; sales: number }[];
  salesByDay: { day: string; sales: number }[];
}

const data = ref<Summary | null>(null);
const branches = ref<Branch[]>([]);
const outletId = ref('');
const from = ref('');
const to = ref('');
const loading = ref(true);

const maxDay = computed(() => Math.max(1, ...(data.value?.salesByDay.map((d) => d.sales) ?? [1])));

async function load() {
  loading.value = true;
  const qs = new URLSearchParams();
  if (outletId.value) qs.set('outletId', outletId.value);
  if (from.value) qs.set('from', from.value);
  if (to.value) qs.set('to', to.value);
  data.value = await api.get<Summary>('/admin/dashboard' + (qs.toString() ? `?${qs}` : ''));
  loading.value = false;
}

onMounted(async () => {
  branches.value = await api.get<Branch[]>('/admin/entity/branches');
  await load();
});

function methodLabel(m: string) {
  return m === 'CASH' ? 'Cash' : m === 'QRIS_SIMULATED' ? 'QRIS' : m;
}
</script>

<template>
  <div class="head">
    <h1>Dashboard</h1>
    <div class="filters">
      <select class="select" v-model="outletId" @change="load">
        <option value="">All branches</option>
        <option v-for="b in branches" :key="b.id" :value="b.id">{{ b.name }}</option>
      </select>
      <input class="input" type="date" v-model="from" @change="load" />
      <span class="muted">→</span>
      <input class="input" type="date" v-model="to" @change="load" />
    </div>
  </div>

  <div v-if="loading" class="muted">Loading…</div>
  <template v-else-if="data">
    <div class="muted small">{{ data.range.from }} → {{ data.range.to }}</div>

    <div class="stats">
      <div class="card card-pad stat">
        <div class="stat-label">Net sales</div>
        <div class="stat-value gold-num">{{ formatRupiah(data.netSales) }}</div>
      </div>
      <div class="card card-pad stat">
        <div class="stat-label">Orders</div>
        <div class="stat-value">{{ formatNumber(data.orderCount) }}</div>
      </div>
      <div class="card card-pad stat">
        <div class="stat-label">Avg ticket</div>
        <div class="stat-value">{{ formatRupiah(data.avgTicket) }}</div>
      </div>
    </div>

    <div class="grid">
      <div class="card card-pad">
        <h3 class="ch">Sales by day</h3>
        <div class="bars" v-if="data.salesByDay.length">
          <div v-for="d in data.salesByDay" :key="d.day" class="bar-col" :title="`${d.day}: ${formatRupiah(d.sales)}`">
            <div class="bar" :style="{ height: `${Math.round((d.sales / maxDay) * 120) + 2}px` }"></div>
            <div class="bar-x">{{ d.day.slice(5) }}</div>
          </div>
        </div>
        <p v-else class="muted">No sales in range.</p>
      </div>

      <div class="card card-pad">
        <h3 class="ch">Payment methods</h3>
        <div v-for="p in data.paymentBreakdown" :key="p.method" class="row">
          <span>{{ methodLabel(p.method) }}</span>
          <b class="mono">{{ formatRupiah(p.amount) }}</b>
        </div>
        <p v-if="!data.paymentBreakdown.length" class="muted">—</p>
      </div>
    </div>

    <div class="grid">
      <div class="card">
        <h3 class="ch pad">Top items</h3>
        <table class="table">
          <thead><tr><th>Item</th><th class="right">Qty</th><th class="right">Sales</th></tr></thead>
          <tbody>
            <tr v-for="i in data.topItems" :key="i.name">
              <td>{{ i.name }}</td><td class="right mono">{{ formatNumber(i.qty) }}</td>
              <td class="right mono">{{ formatRupiah(i.sales) }}</td>
            </tr>
          </tbody>
        </table>
      </div>
      <div class="card">
        <h3 class="ch pad">By branch</h3>
        <table class="table">
          <thead><tr><th>Branch</th><th class="right">Orders</th><th class="right">Sales</th></tr></thead>
          <tbody>
            <tr v-for="o in data.byOutlet" :key="o.name">
              <td>{{ o.name }}</td><td class="right mono">{{ o.count }}</td>
              <td class="right mono">{{ formatRupiah(o.sales) }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </template>
</template>

<style scoped>
.head { display: flex; align-items: center; justify-content: space-between; margin-bottom: 6px; flex-wrap: wrap; gap: 12px; }
.head h1 { font-size: 26px; }
.filters { display: flex; align-items: center; gap: 8px; }
.filters .input, .filters .select { height: 40px; }
.small { margin-bottom: 16px; }
.stats { display: grid; grid-template-columns: repeat(3, 1fr); gap: 16px; margin-bottom: 16px; }
.stat-label { font-size: 12px; font-weight: 700; color: var(--on-surface-variant); text-transform: uppercase; letter-spacing: 0.04em; }
.stat-value { font-size: 26px; font-weight: 800; margin-top: 8px; font-variant-numeric: tabular-nums; }
.gold-num { color: var(--navy); }
.grid { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; margin-bottom: 16px; }
.ch { font-size: 15px; margin-bottom: 12px; }
.ch.pad { padding: 18px 18px 0; }
.row { display: flex; justify-content: space-between; padding: 8px 0; border-bottom: 1px solid var(--outline-variant); }
.row:last-child { border-bottom: none; }
.bars { display: flex; align-items: flex-end; gap: 10px; height: 150px; padding-top: 8px; }
.bar-col { display: flex; flex-direction: column; align-items: center; gap: 6px; flex: 1; }
.bar { width: 60%; min-width: 14px; background: var(--gold); border-radius: 6px 6px 0 0; }
.bar-x { font-size: 10px; color: var(--on-surface-variant); }
@media (max-width: 820px) { .stats, .grid { grid-template-columns: 1fr; } }
</style>
