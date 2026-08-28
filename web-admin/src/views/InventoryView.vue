<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { api } from '../api';
import { formatNumber } from '../format';
import Modal from '../components/Modal.vue';

interface Branch { id: string; name: string }
interface Row { variantId: string; productName: string; variantName: string; sku: string | null; quantityOnHand: number }

const branches = ref<Branch[]>([]);
const outletId = ref('');
const rows = ref<Row[]>([]);
const loading = ref(false);

const editing = ref<Row | null>(null);
const qty = ref(0);
const err = ref('');
const saving = ref(false);

async function load() {
  if (!outletId.value) return;
  loading.value = true;
  rows.value = await api.get<Row[]>(`/admin/inventory?outletId=${outletId.value}`);
  loading.value = false;
}

onMounted(async () => {
  branches.value = await api.get<Branch[]>('/admin/entity/branches');
  if (branches.value.length) {
    outletId.value = branches.value[0].id;
    await load();
  }
});

function openAdjust(r: Row) {
  editing.value = r;
  qty.value = r.quantityOnHand;
  err.value = '';
}
async function save() {
  err.value = '';
  saving.value = true;
  try {
    await api.post('/admin/inventory/adjust', {
      outletId: outletId.value,
      variantId: editing.value!.variantId,
      quantityOnHand: qty.value,
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
  <div class="head">
    <div><h1>Inventory</h1><p class="muted">On-hand stock per branch. Adjustments write to the movement ledger.</p></div>
    <select class="select" v-model="outletId" @change="load">
      <option v-for="b in branches" :key="b.id" :value="b.id">{{ b.name }}</option>
    </select>
  </div>

  <div class="card">
    <table class="table" v-if="!loading">
      <thead><tr><th>Product</th><th>Variant</th><th>SKU</th><th class="right">On hand</th><th></th></tr></thead>
      <tbody>
        <tr v-for="r in rows" :key="r.variantId">
          <td><b>{{ r.productName }}</b></td>
          <td class="muted">{{ r.variantName }}</td>
          <td class="mono muted">{{ r.sku || '—' }}</td>
          <td class="right mono" :class="{ low: r.quantityOnHand <= 5 }">{{ formatNumber(r.quantityOnHand) }}</td>
          <td class="right"><button class="btn btn-ghost btn-sm" @click="openAdjust(r)">Adjust</button></td>
        </tr>
        <tr v-if="!rows.length"><td colspan="5" class="muted card-pad">No stock-tracked items.</td></tr>
      </tbody>
    </table>
    <div v-else class="card-pad muted">Loading…</div>
  </div>

  <Modal :open="!!editing" :title="`Adjust — ${editing?.productName} · ${editing?.variantName}`" @close="editing = null">
    <div class="field"><label>New on-hand quantity</label><input class="input" type="number" min="0" v-model.number="qty" /></div>
    <p class="muted small">The difference is recorded as an ADJUSTMENT movement.</p>
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
.head p { margin: 4px 0 0; max-width: 480px; }
.low { color: var(--error); font-weight: 800; }
.err { color: var(--error); font-size: 13px; }
.small { font-size: 12px; margin: 4px 0 0; }
</style>
