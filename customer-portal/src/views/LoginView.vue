<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { useAuth } from '../stores/auth';
import { APP_VERSION, fetchServerVersion } from '../version';
import logoUrl from '../assets/logo.png';

const auth = useAuth();
const router = useRouter();
const email = ref('');
const password = ref('');
const error = ref('');
const busy = ref(false);
const serverVersion = ref('…');

onMounted(async () => {
  serverVersion.value = await fetchServerVersion();
});

async function submit() {
  error.value = '';
  busy.value = true;
  try {
    await auth.login(email.value.trim(), password.value);
    router.replace({ name: 'dashboard' });
  } catch (e) {
    error.value = (e as Error).message || 'Sign-in failed';
  } finally {
    busy.value = false;
  }
}
</script>

<template>
  <div class="login">
    <div class="hero">
      <img class="brand-mark" :src="logoUrl" alt="D-Customer Portal" />
      <h1>D-Customer Portal</h1>
      <p>Manage sales, staff, inventory, prices and branches for your business.</p>
      <div class="hero-ver">Portal v{{ APP_VERSION }} · Server v{{ serverVersion }}</div>
    </div>

    <div class="panel">
      <div class="card card-pad form">
        <h2>Sign in</h2>
        <p class="muted sub">Account owner access only.</p>
        <form @submit.prevent="submit">
          <div class="field">
            <label>Email</label>
            <input class="input" type="email" v-model="email" placeholder="owner@company.id" autocomplete="username" />
          </div>
          <div class="field">
            <label>Password</label>
            <input class="input" type="password" v-model="password" autocomplete="current-password" />
          </div>
          <p v-if="error" class="err">{{ error }}</p>
          <button class="btn btn-primary" style="width: 100%" :disabled="busy">
            {{ busy ? 'Signing in…' : 'Sign in' }}
          </button>
        </form>
      </div>
      <div class="foot muted">v{{ APP_VERSION }}</div>
    </div>
  </div>
</template>

<style scoped>
.login {
  display: grid;
  grid-template-columns: 1fr 1fr;
  min-height: 100vh;
}
.hero {
  background: linear-gradient(160deg, var(--grad-top), var(--grad-bottom));
  color: #fff;
  padding: 64px;
  display: flex;
  flex-direction: column;
  justify-content: center;
}
.hero .brand-mark {
  width: 64px;
  height: 64px;
  border-radius: 50%;
  object-fit: contain;
  margin-bottom: 24px;
}
.hero h1 {
  font-size: 34px;
}
.hero p {
  color: rgba(255, 255, 255, 0.78);
  max-width: 360px;
  line-height: 1.5;
  margin-top: 12px;
}
.hero-ver {
  margin-top: 28px;
  font-size: 12px;
  font-weight: 700;
  color: var(--gold);
}
.panel {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 12px;
  padding: 32px;
}
.form {
  width: 100%;
  max-width: 380px;
}
.form h2 {
  font-size: 22px;
}
.sub {
  margin: 4px 0 18px;
}
.err {
  color: var(--error);
  font-size: 13px;
  margin: 0 0 12px;
}
.foot {
  font-size: 12px;
}
@media (max-width: 820px) {
  .login {
    grid-template-columns: 1fr;
  }
  .hero {
    padding: 40px;
  }
}
</style>
