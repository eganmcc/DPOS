import { api } from './api';

/** Portal version, injected from package.json at build time (never hardcoded). */
export const APP_VERSION: string = __APP_VERSION__;

/** Backend version, queried live from the public /version endpoint. */
export async function fetchServerVersion(): Promise<string> {
  try {
    const v = await api.get<{ version: string }>('/version');
    return v.version;
  } catch {
    return '—';
  }
}
