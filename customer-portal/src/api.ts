// Thin REST client for the DPOS admin API. Token is read from localStorage so
// this module has no dependency on the Pinia store (avoids a cycle).
const BASE = import.meta.env.VITE_API_BASE_URL || 'https://dikapos.ptdika.com/api/v1';

export const TOKEN_KEY = 'dcp_token';

export class ApiError extends Error {
  status: number;
  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

async function request<T>(method: string, path: string, body?: unknown): Promise<T> {
  const token = localStorage.getItem(TOKEN_KEY);
  const res = await fetch(BASE + path, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  if (res.status === 204) return undefined as T;
  const data = await res.json().catch(() => null);
  if (!res.ok) {
    // A 401 mid-session means the JWT expired or was revoked. Recover cleanly —
    // drop the dead token and return to login — instead of letting the error
    // bubble into a render and white-screen the app. The login call is exempt so
    // a wrong password shows its own error rather than reloading.
    if (res.status === 401 && path !== '/auth/login') {
      try {
        localStorage.removeItem(TOKEN_KEY);
        localStorage.removeItem('dcp_role');
      } catch (e) {
        /* ignore storage errors */
      }
      const base = import.meta.env.BASE_URL || '/customer-portal/';
      if (!location.pathname.endsWith('/login')) location.assign(base + 'login');
    }
    const msg =
      (data && (Array.isArray(data.message) ? data.message.join(', ') : data.message)) ||
      `Request failed (${res.status})`;
    throw new ApiError(res.status, msg);
  }
  return data as T;
}

export const api = {
  base: BASE,
  get: <T>(p: string) => request<T>('GET', p),
  post: <T>(p: string, b?: unknown) => request<T>('POST', p, b),
  patch: <T>(p: string, b?: unknown) => request<T>('PATCH', p, b),
};
