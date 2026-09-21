import { createRouter, createWebHistory } from 'vue-router';
import { useAuth } from '../stores/auth';

const router = createRouter({
  // Matches Vite `base`; keep in sync with the nginx location.
  history: createWebHistory(import.meta.env.BASE_URL),
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
        // Laporan — every report under one path, so the sidebar group and the URL agree.
        { path: 'laporan/jurnal', name: 'laporan-jurnal', component: () => import('../views/JournalView.vue') },
        { path: 'laporan/harian', name: 'laporan-harian', component: () => import('../views/DailyView.vue') },
        { path: 'laporan/koreksi', name: 'laporan-koreksi', component: () => import('../views/CorrectionsView.vue') },
        { path: 'laporan/pajak', name: 'laporan-pajak', component: () => import('../views/TaxView.vue') },
        { path: 'laporan/umum', name: 'laporan-umum', component: () => import('../views/LedgerView.vue') },
        { path: 'laporan/bank', name: 'laporan-bank', component: () => import('../views/BankView.vue') },
        // The old link, kept working: it was live for an afternoon and may be in a bookmark.
        { path: 'bank', redirect: '/laporan/bank' },
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
