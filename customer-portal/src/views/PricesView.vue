<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { api } from '../api';
import { formatRupiah, formatNumber } from '../format';
import Modal from '../components/Modal.vue';

interface Branch { id: string; name: string }
interface Variant { id: string; name: string; price: number; costPrice: number | null; sku: string | null; isAvailable: boolean; trackInventory: boolean }
interface Product { id: string; name: string; categoryName: string; variants: Variant[] }
interface StockRow { variantId: string; quantityOnHand: number }

const products = ref<Product[]>([]);
const branches = ref<Branch[]>([]);
const outletId = ref('');
const stock = ref<Record<string, number>>({});
const loading = ref(true);

const editing = ref<{ product: string; v: Variant } | null>(null);
const price = ref(0);
const cost = ref<number | null>(null);
const sku = ref('');
const available = ref(true);
const onHand = ref(0);
const err = ref('');
const saving = ref(false);

async function loadStock() {
  if (!outletId.value) return;
  const rows = await api.get<StockRow[]>(`/admin/inventory?outletId=${outletId.value}`);
  stock.value = Object.fromEntries(rows.map((r) => [r.variantId, r.quantityOnHand]));
}

async function load() {
  loading.value = true;
  products.value = await api.get<Product[]>('/admin/products');
  await loadStock();
  loading.value = false;
}

onMounted(async () => {
  branches.value = await api.get<Branch[]>('/admin/entity/branches');
  if (branches.value.length) outletId.value = branches.value[0].id;
  await load();
});

function openEdit(product: string, v: Variant) {
  editing.value = { product, v };
  price.value = v.price;
  cost.value = v.costPrice;
  sku.value = v.sku ?? '';
  available.value = v.isAvailable;
  onHand.value = stock.value[v.id] ?? 0;
  err.value = '';
}

async function save() {
  err.value = '';
  saving.value = true;
  try {
    const v = editing.value!.v;
    await api.patch(`/admin/products/variants/${v.id}`, {
      price: price.value,
      costPrice: cost.value ?? undefined,
      isAvailable: available.value,
      sku: sku.value.trim(), // '' clears it server-side
    });
    // Update stock for the selected branch when the variant is tracked and changed.
    if (v.trackInventory && onHand.value !== (stock.value[v.id] ?? 0)) {
      await api.post('/admin/inventory/adjust', {
        outletId: outletId.value,
        variantId: v.id,
        quantityOnHand: onHand.value,
      });
    }
    editing.value = null;
    await load();
  } catch (e) {
    err.value = (e as Error).message;
  } finally {
    saving.value = false;
  }
}
</script>

<template>
  <div class="head">
    <div><h1>Prices</h1><p class="muted">Selling / cost price, availability, and on-hand stock per branch.</p></div>
    <div class="branch">
      <span class="muted">Branch</span>
      <select class="select" v-model="outletId" @change="loadStock">
        <option v-for="b in branches" :key="b.id" :value="b.id">{{ b.name }}</option>
      </select>
    </div>
  </div>

  <div class="card">
    <table class="table" v-if="!loading">
      <thead><tr><th>Product</th><th>Variant</th><th>SKU</th><th class="right">Price</th><th class="right">Cost</th><th class="right">On hand</th><th>Available</th><th></th></tr></thead>
      <tbody>
        <template v-for="p in products" :key="p.id">
          <tr v-for="(v, i) in p.variants" :key="v.id">
            <td><b v-if="i === 0">{{ p.name }}</b><span v-else></span><div v-if="i === 0" class="muted small">{{ p.categoryName }}</div></td>
            <td class="muted">{{ v.name }}</td>
            <td class="mono muted">{{ v.sku || '—' }}</td>
            <td class="right mono"><b>{{ formatRupiah(v.price) }}</b></td>
            <td class="right mono muted">{{ v.costPrice != null ? formatRupiah(v.costPrice) : '—' }}</td>
            <td class="right mono" :class="{ low: v.trackInventory && (stock[v.id] ?? 0) <= 5 }">
              {{ v.trackInventory ? formatNumber(stock[v.id] ?? 0) : '—' }}
            </td>
            <td><span class="badge" :class="v.isAvailable ? 'badge-green' : 'badge-muted'">{{ v.isAvailable ? 'Yes' : 'No' }}</span></td>
            <td class="right"><button class="btn btn-ghost btn-sm" @click="openEdit(p.name, v)">Edit</button></td>
          </tr>
        </template>
      </tbody>
    </table>
    <div v-else class="card-pad muted">Loading…</div>
  </div>

  <Modal :open="!!editing" :title="`Edit — ${editing?.product} · ${editing?.v.name}`" @close="editing = null">
    <div class="field"><label>Selling price (Rp)</label><input class="input" type="number" min="0" v-model.number="price" /></div>
    <div class="field"><label>Cost price (Rp)</label><input class="input" type="number" min="0" v-model.number="cost" /></div>
    <div class="field"><label>SKU / Barcode</label><input class="input" v-model="sku" placeholder="e.g. 8991234567890" /></div>
    <div class="field" v-if="editing?.v.trackInventory">
      <label>On hand — {{ branches.find((b) => b.id === outletId)?.name }}</label>
      <input class="input" type="number" min="0" v-model.number="onHand" />
    </div>
    <label class="chk"><input type="checkbox" v-model="available" /> Available for sale</label>
    <p v-if="err" class="err">{{ err }}</p>
    <template #footer>
      <button class="btn btn-ghost" @click="editing = null">Cancel</button>
      <button class="btn btn-primary" @click="save" :disabled="saving">{{ saving ? 'Saving…' : 'Save' }}</button>
    </template>
  </Modal>
</template>

<style scoped>
.head { display: flex; align-items: flex-start; justify-content: space-between; margin-bottom: 16px; gap: 12px; }
.head h1 { font-size: 26px; }
.head p { margin: 4px 0 0; }
.branch { display: flex; align-items: center; gap: 8px; }
.branch .select { height: 40px; }
.small { font-size: 12px; }
.low { color: var(--error); font-weight: 800; }
.chk { display: flex; align-items: center; gap: 8px; font-size: 14px; margin: 4px 0 8px; }
.err { color: var(--error); font-size: 13px; }
</style>
