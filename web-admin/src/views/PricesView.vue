<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { api } from '../api';
import { formatRupiah } from '../format';
import Modal from '../components/Modal.vue';

interface Variant { id: string; name: string; price: number; costPrice: number | null; sku: string | null; isAvailable: boolean }
interface Product { id: string; name: string; categoryName: string; variants: Variant[] }

const products = ref<Product[]>([]);
const loading = ref(true);
const editing = ref<{ product: string; v: Variant } | null>(null);
const price = ref(0);
const cost = ref<number | null>(null);
const available = ref(true);
const err = ref('');
const saving = ref(false);

async function load() {
  loading.value = true;
  products.value = await api.get<Product[]>('/admin/products');
  loading.value = false;
}
onMounted(load);

function openEdit(product: string, v: Variant) {
  editing.value = { product, v };
  price.value = v.price;
  cost.value = v.costPrice;
  available.value = v.isAvailable;
  err.value = '';
}
async function save() {
  err.value = '';
  saving.value = true;
  try {
    await api.patch(`/admin/products/variants/${editing.value!.v.id}`, {
      price: price.value,
      costPrice: cost.value ?? undefined,
      isAvailable: available.value,
    });
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
  <div class="head"><div><h1>Prices</h1><p class="muted">Selling and cost prices per variant.</p></div></div>

  <div class="card">
    <table class="table" v-if="!loading">
      <thead><tr><th>Product</th><th>Variant</th><th>SKU</th><th class="right">Price</th><th class="right">Cost</th><th>Available</th><th></th></tr></thead>
      <tbody>
        <template v-for="p in products" :key="p.id">
          <tr v-for="(v, i) in p.variants" :key="v.id">
            <td><b v-if="i === 0">{{ p.name }}</b><span v-else></span><div v-if="i === 0" class="muted small">{{ p.categoryName }}</div></td>
            <td class="muted">{{ v.name }}</td>
            <td class="mono muted">{{ v.sku || '—' }}</td>
            <td class="right mono"><b>{{ formatRupiah(v.price) }}</b></td>
            <td class="right mono muted">{{ v.costPrice != null ? formatRupiah(v.costPrice) : '—' }}</td>
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
    <label class="chk"><input type="checkbox" v-model="available" /> Available for sale</label>
    <p v-if="err" class="err">{{ err }}</p>
    <template #footer>
      <button class="btn btn-ghost" @click="editing = null">Cancel</button>
      <button class="btn btn-primary" @click="save" :disabled="saving">{{ saving ? 'Saving…' : 'Save' }}</button>
    </template>
  </Modal>
</template>

<style scoped>
.head { margin-bottom: 16px; }
.head h1 { font-size: 26px; }
.head p { margin: 4px 0 0; }
.small { font-size: 12px; }
.chk { display: flex; align-items: center; gap: 8px; font-size: 14px; margin: 4px 0 8px; }
.err { color: var(--error); font-size: 13px; }
</style>
