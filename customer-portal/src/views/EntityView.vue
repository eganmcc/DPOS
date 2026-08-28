<script setup lang="ts">
import { ref, onMounted, reactive } from 'vue';
import { api } from '../api';
import { useAuth } from '../stores/auth';
import Modal from '../components/Modal.vue';

interface Merchant { id: string; name: string; businessType: 'FNB' | 'GROCERY'; logoUrl: string | null }
interface Branch {
  id: string; code: string | null; name: string; address: string | null;
  managerId: string | null; managerName: string | null; paymentMode: string; isActive: boolean;
}
interface Staff { id: string; name: string; role: string }

const auth = useAuth();
const merchant = reactive<Merchant>({ id: '', name: '', businessType: 'FNB', logoUrl: null });
const branches = ref<Branch[]>([]);
const managers = ref<Staff[]>([]);
const loading = ref(true);
const savingCo = ref(false);
const coErr = ref('');
const coOk = ref(false);

const showBranch = ref(false);
const editingBranch = ref<Branch | null>(null);
const bErr = ref('');
const bSaving = ref(false);
const bform = reactive({ code: '', name: '', address: '', managerId: '', paymentMode: 'IMMEDIATE', isActive: true });

async function load() {
  loading.value = true;
  const [m, b, s] = await Promise.all([
    api.get<Merchant>('/admin/entity'),
    api.get<Branch[]>('/admin/entity/branches'),
    api.get<Staff[]>('/admin/staff'),
  ]);
  Object.assign(merchant, m);
  branches.value = b;
  managers.value = s.filter((x) => x.role === 'MANAGER' || x.role === 'OWNER');
  loading.value = false;
}
onMounted(load);

async function saveCompany() {
  coErr.value = '';
  coOk.value = false;
  savingCo.value = true;
  try {
    const m = await api.patch<Merchant>('/admin/entity', {
      name: merchant.name,
      logoUrl: merchant.logoUrl || null,
    });
    auth.setMerchant(m);
    coOk.value = true;
  } catch (e) {
    coErr.value = (e as Error).message;
  } finally {
    savingCo.value = false;
  }
}

function openNewBranch() {
  editingBranch.value = null;
  Object.assign(bform, { code: '', name: '', address: '', managerId: '', paymentMode: 'IMMEDIATE', isActive: true });
  bErr.value = '';
  showBranch.value = true;
}
function openEditBranch(b: Branch) {
  editingBranch.value = b;
  Object.assign(bform, {
    code: b.code ?? '', name: b.name, address: b.address ?? '',
    managerId: b.managerId ?? '', paymentMode: b.paymentMode, isActive: b.isActive,
  });
  bErr.value = '';
  showBranch.value = true;
}
async function saveBranch() {
  bErr.value = '';
  bSaving.value = true;
  try {
    const payload = {
      code: bform.code || undefined,
      name: bform.name,
      address: bform.address || undefined,
      managerId: bform.managerId || undefined,
      paymentMode: auth.isFnb ? bform.paymentMode : 'IMMEDIATE',
    };
    if (editingBranch.value) {
      await api.patch(`/admin/entity/branches/${editingBranch.value.id}`, { ...payload, isActive: bform.isActive });
    } else {
      await api.post('/admin/entity/branches', payload);
    }
    showBranch.value = false;
    await load();
  } catch (e) {
    bErr.value = (e as Error).message;
  } finally {
    bSaving.value = false;
  }
}

function settlementLabel(pm: string) {
  return pm === 'OPEN_BILL' ? 'Pay later (open bill)' : 'Pay now';
}
</script>

<template>
  <h1>Entity Settings</h1>
  <p class="muted sub">Company profile and branches.</p>

  <div v-if="!loading" class="cols">
    <!-- Company -->
    <div class="card card-pad">
      <h3 class="ch">Company</h3>
      <div class="field"><label>Company name</label><input class="input" v-model="merchant.name" /></div>
      <div class="field">
        <label>Business type</label>
        <div class="ro">
          <span class="badge" :class="auth.isFnb ? 'badge-gold' : 'badge-navy'">{{ merchant.businessType }}</span>
          <span class="muted small">set by DPOS admin</span>
        </div>
      </div>
      <div class="field"><label>Logo URL</label><input class="input" v-model="merchant.logoUrl" placeholder="https://…" /></div>
      <div v-if="merchant.logoUrl" class="logo-prev"><img :src="merchant.logoUrl" alt="logo" /></div>
      <p v-if="coErr" class="err">{{ coErr }}</p>
      <p v-if="coOk" class="ok">Saved.</p>
      <button class="btn btn-primary" @click="saveCompany" :disabled="savingCo">{{ savingCo ? 'Saving…' : 'Save company' }}</button>
    </div>

    <!-- Branches -->
    <div class="card">
      <div class="ch-row">
        <h3 class="ch">Branches</h3>
        <button class="btn btn-primary btn-sm" @click="openNewBranch">+ Branch</button>
      </div>
      <table class="table">
        <thead><tr><th>Code</th><th>Name</th><th>Manager</th><th v-if="auth.isFnb">Settlement</th><th></th></tr></thead>
        <tbody>
          <tr v-for="b in branches" :key="b.id">
            <td class="mono">{{ b.code || '—' }}</td>
            <td><b>{{ b.name }}</b><div class="muted small" v-if="b.address">{{ b.address }}</div></td>
            <td>{{ b.managerName || '—' }}</td>
            <td v-if="auth.isFnb"><span class="badge badge-muted">{{ settlementLabel(b.paymentMode) }}</span></td>
            <td class="right"><button class="btn btn-ghost btn-sm" @click="openEditBranch(b)">Edit</button></td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
  <div v-else class="muted">Loading…</div>

  <Modal :open="showBranch" :title="editingBranch ? 'Edit branch' : 'Add branch'" @close="showBranch = false">
    <div class="two">
      <div class="field"><label>Branch code</label><input class="input" v-model="bform.code" placeholder="HQ, BR01…" /></div>
      <div class="field"><label>Name</label><input class="input" v-model="bform.name" /></div>
    </div>
    <div class="field"><label>Address</label><input class="input" v-model="bform.address" /></div>
    <div class="field"><label>Branch manager</label>
      <select class="select" v-model="bform.managerId">
        <option value="">— none —</option>
        <option v-for="m in managers" :key="m.id" :value="m.id">{{ m.name }} ({{ m.role }})</option>
      </select>
    </div>
    <div class="field" v-if="auth.isFnb"><label>Bill settlement</label>
      <select class="select" v-model="bform.paymentMode">
        <option value="IMMEDIATE">Pay now (immediate)</option>
        <option value="OPEN_BILL">Pay later (open bill / table service)</option>
      </select>
    </div>
    <label class="chk" v-if="editingBranch"><input type="checkbox" v-model="bform.isActive" /> Active</label>
    <p v-if="bErr" class="err">{{ bErr }}</p>
    <template #footer>
      <button class="btn btn-ghost" @click="showBranch = false">Cancel</button>
      <button class="btn btn-primary" @click="saveBranch" :disabled="bSaving">{{ bSaving ? 'Saving…' : 'Save' }}</button>
    </template>
  </Modal>
</template>

<style scoped>
h1 { font-size: 26px; }
.sub { margin: 4px 0 18px; }
.cols { display: grid; grid-template-columns: 380px 1fr; gap: 16px; align-items: start; }
.ch { font-size: 15px; margin-bottom: 12px; }
.ch-row { display: flex; align-items: center; justify-content: space-between; padding: 18px 18px 6px; }
.ch-row .ch { margin: 0; }
.two { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
.small { font-size: 12px; }
.ro { display: flex; align-items: center; gap: 10px; height: 44px; }
.err { color: var(--error); font-size: 13px; }
.ok { color: var(--success); font-size: 13px; }
.logo-prev { margin-bottom: 12px; }
.logo-prev img { max-height: 56px; border-radius: 8px; border: 1px solid var(--outline); }
@media (max-width: 900px) { .cols { grid-template-columns: 1fr; } }
</style>
