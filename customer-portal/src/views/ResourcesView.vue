<script setup lang="ts">
import { ref, onMounted, reactive } from 'vue';
import { api } from '../api';
import Modal from '../components/Modal.vue';

interface Branch { id: string; name: string }
interface Staff {
  id: string; employeeId: string | null; name: string; phone: string | null;
  role: string; outletId: string | null; outletName: string | null; email: string | null; isActive: boolean;
}

const staff = ref<Staff[]>([]);
const branches = ref<Branch[]>([]);
const loading = ref(true);
const roles = ['CASHIER', 'SERVER', 'MANAGER', 'OWNER'];

const editing = ref<Staff | null>(null);
const showForm = ref(false);
const pinFor = ref<Staff | null>(null);
const pin = ref('');
const err = ref('');
const saving = ref(false);

const form = reactive({ name: '', phone: '', role: 'CASHIER', outletId: '', email: '', password: '', pin: '', isActive: true });

async function load() {
  loading.value = true;
  [staff.value, branches.value] = await Promise.all([
    api.get<Staff[]>('/admin/staff'),
    api.get<Branch[]>('/admin/entity/branches'),
  ]);
  loading.value = false;
}
onMounted(load);

function openNew() {
  editing.value = null;
  Object.assign(form, { name: '', phone: '', role: 'CASHIER', outletId: '', email: '', password: '', pin: '', isActive: true });
  err.value = '';
  showForm.value = true;
}
function openEdit(s: Staff) {
  editing.value = s;
  Object.assign(form, { name: s.name, phone: s.phone ?? '', role: s.role, outletId: s.outletId ?? '', email: s.email ?? '', password: '', pin: '', isActive: s.isActive });
  err.value = '';
  showForm.value = true;
}

async function save() {
  err.value = '';
  saving.value = true;
  try {
    const outletId = form.outletId || undefined;
    if (editing.value) {
      await api.patch(`/admin/staff/${editing.value.id}`, {
        name: form.name, phone: form.phone || null, role: form.role, outletId, email: form.email || null, isActive: form.isActive,
      });
    } else {
      await api.post('/admin/staff', {
        name: form.name, phone: form.phone || undefined, role: form.role, outletId,
        pin: form.pin, email: form.email || undefined, password: form.password || undefined,
      });
    }
    showForm.value = false;
    await load();
  } catch (e) {
    err.value = (e as Error).message;
  } finally {
    saving.value = false;
  }
}

async function savePin() {
  err.value = '';
  saving.value = true;
  try {
    await api.post(`/admin/staff/${pinFor.value!.id}/pin`, { pin: pin.value });
    pinFor.value = null;
    pin.value = '';
  } catch (e) {
    err.value = (e as Error).message;
  } finally {
    saving.value = false;
  }
}

function roleBadge(r: string) {
  return r === 'OWNER' ? 'badge-navy' : r === 'MANAGER' ? 'badge-gold' : 'badge-muted';
}
</script>

<template>
  <div class="head">
    <div><h1>Resources</h1><p class="muted">Staff, roles, assignments and PINs.</p></div>
    <button class="btn btn-primary" @click="openNew">+ Add staff</button>
  </div>

  <div class="card">
    <table class="table" v-if="!loading">
      <thead>
        <tr><th>Emp ID</th><th>Name</th><th>Role</th><th>Assignment</th><th>Phone</th><th>Status</th><th></th></tr>
      </thead>
      <tbody>
        <tr v-for="s in staff" :key="s.id">
          <td class="mono">{{ s.employeeId || '—' }}</td>
          <td><b>{{ s.name }}</b><div class="muted small" v-if="s.email">{{ s.email }}</div></td>
          <td><span class="badge" :class="roleBadge(s.role)">{{ s.role }}</span></td>
          <td>{{ s.outletName || 'HQ / all branches' }}</td>
          <td class="muted">{{ s.phone || '—' }}</td>
          <td><span class="badge" :class="s.isActive ? 'badge-green' : 'badge-muted'">{{ s.isActive ? 'Active' : 'Inactive' }}</span></td>
          <td class="right nowrap">
            <button class="btn btn-ghost btn-sm" @click="openEdit(s)">Edit</button>
            <button class="btn btn-ghost btn-sm" @click="pinFor = s; pin = ''; err = ''">PIN</button>
          </td>
        </tr>
      </tbody>
    </table>
    <div v-else class="card-pad muted">Loading…</div>
  </div>

  <!-- Add / edit -->
  <Modal :open="showForm" :title="editing ? 'Edit staff' : 'Add staff'" @close="showForm = false">
    <div class="field"><label>Name</label><input class="input" v-model="form.name" /></div>
    <div class="two">
      <div class="field"><label>Role</label>
        <select class="select" v-model="form.role"><option v-for="r in roles" :key="r" :value="r">{{ r }}</option></select>
      </div>
      <div class="field"><label>Assignment</label>
        <select class="select" v-model="form.outletId">
          <option value="">HQ / all branches</option>
          <option v-for="b in branches" :key="b.id" :value="b.id">{{ b.name }}</option>
        </select>
      </div>
    </div>
    <div class="field"><label>Phone</label><input class="input" v-model="form.phone" placeholder="08xx" /></div>
    <template v-if="!editing">
      <div class="field"><label>PIN (4–6 digits)</label><input class="input" v-model="form.pin" inputmode="numeric" maxlength="6" /></div>
    </template>
    <div class="field"><label>Email (owner/manager login, optional)</label><input class="input" v-model="form.email" /></div>
    <div class="field" v-if="!editing"><label>Password (optional, for email login)</label><input class="input" type="password" v-model="form.password" /></div>
    <label class="chk" v-if="editing"><input type="checkbox" v-model="form.isActive" /> Active</label>
    <p v-if="err" class="err">{{ err }}</p>
    <template #footer>
      <button class="btn btn-ghost" @click="showForm = false">Cancel</button>
      <button class="btn btn-primary" @click="save" :disabled="saving">{{ saving ? 'Saving…' : 'Save' }}</button>
    </template>
  </Modal>

  <!-- PIN -->
  <Modal :open="!!pinFor" :title="`Set PIN — ${pinFor?.name}`" @close="pinFor = null">
    <div class="field"><label>New PIN (4–6 digits)</label><input class="input" v-model="pin" inputmode="numeric" maxlength="6" /></div>
    <p v-if="err" class="err">{{ err }}</p>
    <template #footer>
      <button class="btn btn-ghost" @click="pinFor = null">Cancel</button>
      <button class="btn btn-primary" @click="savePin" :disabled="saving">Update PIN</button>
    </template>
  </Modal>
</template>

<style scoped>
.head { display: flex; align-items: flex-start; justify-content: space-between; margin-bottom: 16px; }
.head h1 { font-size: 26px; }
.head p { margin: 4px 0 0; }
.small { font-size: 12px; }
.nowrap { white-space: nowrap; }
.two { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
.err { color: var(--error); font-size: 13px; }
.chk { display: flex; align-items: center; gap: 8px; font-size: 14px; margin: 4px 0 8px; }
</style>
