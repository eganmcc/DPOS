import { defineStore } from 'pinia';
import { api, TOKEN_KEY } from '../api';

export type BusinessType = 'FNB' | 'GROCERY';

interface Merchant {
  id: string;
  name: string;
  businessType: BusinessType;
  logoUrl: string | null;
}

interface State {
  token: string | null;
  role: string | null;
  merchant: Merchant | null;
}

export const useAuth = defineStore('auth', {
  state: (): State => ({
    token: localStorage.getItem(TOKEN_KEY),
    role: localStorage.getItem('dcp_role'),
    merchant: null,
  }),
  getters: {
    isAuthed: (s) => !!s.token,
    isFnb: (s) => s.merchant?.businessType === 'FNB',
    companyName: (s) => s.merchant?.name ?? 'D-Customer Portal',
  },
  actions: {
    async login(email: string, password: string) {
      const res = await api.post<{ token: string; role: string }>('/auth/login', {
        email,
        password,
      });
      if (res.role !== 'OWNER') {
        throw new Error('This portal is for account owners only.');
      }
      this.token = res.token;
      this.role = res.role;
      localStorage.setItem(TOKEN_KEY, res.token);
      localStorage.setItem('dcp_role', res.role);
      await this.loadMerchant();
    },
    async loadMerchant() {
      this.merchant = await api.get<Merchant>('/admin/entity');
    },
    setMerchant(m: Merchant) {
      this.merchant = m;
    },
    logout() {
      this.token = null;
      this.role = null;
      this.merchant = null;
      localStorage.removeItem(TOKEN_KEY);
      localStorage.removeItem('dcp_role');
    },
  },
});
