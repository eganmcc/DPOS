<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { RouterView, useRouter } from 'vue-router';
import { useAuth } from '../stores/auth';
import { APP_VERSION, fetchServerVersion } from '../version';

const auth = useAuth();
const router = useRouter();
const serverVersion = ref('…');
const showVersion = ref(false);

const nav = [
  { to: '/dashboard', label: 'Dashboard', icon: '📊' },
  { to: '/resources', label: 'Resources', icon: '👥' },
  { to: '/prices', label: 'Prices', icon: '🏷️' },
  { to: '/entity', label: 'Entity Settings', icon: '🏢' },
];

onMounted(async () => {
  serverVersion.value = await fetchServerVersion();
});

function logout() {
  auth.logout();
  router.replace({ name: 'login' });
}
</script>

<template>
  <div class="shell">
    <aside class="side">
      <div class="brand">
        <div class="brand-mark">D</div>
        <div>
          <div class="brand-name">D-Customer</div>
          <div class="brand-sub">Portal</div>
        </div>
      </div>

      <nav class="nav">
        <RouterLink v-for="n in nav" :key="n.to" :to="n.to" class="nav-item" active-class="active">
          <span class="ico">{{ n.icon }}</span>{{ n.label }}
        </RouterLink>
      </nav>

      <div class="side-foot">
        <button class="ver-btn" @click="showVersion = !showVersion">
          <span>ⓘ v{{ APP_VERSION }}</span>
          <span class="chev">{{ showVersion ? '▾' : '▸' }}</span>
        </button>
        <div v-if="showVersion" class="ver-pop">
          <div class="ver-row"><span class="muted">Portal</span><b class="mono">{{ APP_VERSION }}</b></div>
          <div class="ver-row"><span class="muted">Server</span><b class="mono">{{ serverVersion }}</b></div>
        </div>
      </div>
    </aside>

    <div class="main">
      <header class="topbar">
        <div class="company">
          <b>{{ auth.companyName }}</b>
          <span class="badge" :class="auth.isFnb ? 'badge-gold' : 'badge-navy'">
            {{ auth.merchant?.businessType }}
          </span>
        </div>
        <button class="btn btn-ghost btn-sm" @click="logout">Log out ⏻</button>
      </header>
      <main class="content">
        <RouterView />
      </main>
    </div>
  </div>
</template>

<style scoped>
.shell {
  display: flex;
  min-height: 100vh;
}
.side {
  width: 232px;
  background: linear-gradient(160deg, var(--grad-top), var(--grad-bottom));
  color: #fff;
  display: flex;
  flex-direction: column;
  padding: 20px 14px;
  position: sticky;
  top: 0;
  height: 100vh;
}
.brand {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 4px 8px 20px;
}
.brand-mark {
  width: 40px;
  height: 40px;
  border-radius: 12px;
  background: var(--gold);
  color: var(--grad-top);
  font-weight: 800;
  font-size: 22px;
  display: grid;
  place-items: center;
}
.brand-name {
  font-weight: 800;
  font-size: 15px;
}
.brand-sub {
  font-size: 12px;
  color: rgba(255, 255, 255, 0.7);
}
.nav {
  display: flex;
  flex-direction: column;
  gap: 4px;
  flex: 1;
}
.nav-item {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 11px 12px;
  border-radius: 10px;
  color: rgba(255, 255, 255, 0.82);
  font-weight: 600;
  font-size: 14px;
}
.nav-item:hover {
  background: rgba(255, 255, 255, 0.08);
  color: #fff;
}
.nav-item.active {
  background: rgba(214, 173, 7, 0.18);
  color: var(--gold);
}
.ico {
  width: 20px;
  text-align: center;
}
.side-foot {
  border-top: 1px solid rgba(255, 255, 255, 0.12);
  padding-top: 10px;
}
.ver-btn {
  width: 100%;
  display: flex;
  justify-content: space-between;
  align-items: center;
  background: rgba(255, 255, 255, 0.06);
  border: 1px solid rgba(255, 255, 255, 0.12);
  color: rgba(255, 255, 255, 0.85);
  border-radius: 10px;
  padding: 9px 12px;
  font-size: 12px;
  font-weight: 700;
  cursor: pointer;
}
.ver-pop {
  margin-top: 8px;
  background: rgba(0, 0, 0, 0.22);
  border-radius: 10px;
  padding: 10px 12px;
}
.ver-row {
  display: flex;
  justify-content: space-between;
  font-size: 12px;
  padding: 2px 0;
}
.ver-row .muted {
  color: rgba(255, 255, 255, 0.6);
}
.main {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
}
.topbar {
  height: 64px;
  background: var(--surface);
  border-bottom: 1px solid var(--outline);
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 24px;
  position: sticky;
  top: 0;
  z-index: 10;
}
.company {
  display: flex;
  align-items: center;
  gap: 10px;
  font-size: 15px;
}
.content {
  padding: 24px;
  max-width: 1120px;
  width: 100%;
}
</style>
