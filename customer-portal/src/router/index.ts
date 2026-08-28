import { createRouter, createWebHistory } from 'vue-router';
import { useAuth } from '../stores/auth';

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/login', name: 'login', component: () => import('../views/LoginView.vue'), meta: { guest: true } },
    {
      path: '/',
      component: () => import('../components/AppLayout.vue'),
      children: [
        { path: '', redirect: '/dashboard' },
        { path: 'dashboard', name: 'dashboard', component: () => import('../views/DashboardView.vue') },
        { path: 'resources', name: 'resources', component: () => import('../views/ResourcesView.vue') },
        { path: 'prices', name: 'prices', component: () => import('../views/PricesView.vue') },
        { path: 'entity', name: 'entity', component: () => import('../views/EntityView.vue') },
      ],
    },
    { path: '/:pathMatch(.*)*', redirect: '/dashboard' },
  ],
});

router.beforeEach(async (to) => {
  const auth = useAuth();
  if (to.meta.guest) {
    return auth.isAuthed ? { name: 'dashboard' } : true;
  }
  if (!auth.isAuthed) return { name: 'login' };
  // Ensure merchant (businessType, company name) is loaded before rendering.
  if (!auth.merchant) {
    try {
      await auth.loadMerchant();
    } catch {
      auth.logout();
      return { name: 'login' };
    }
  }
  return true;
});

export default router;
