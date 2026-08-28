# D-Customer Portal

Admin web portal for DPOS — sales dashboard, resource (staff) management, inventory,
price setting, and entity/branch settings. Vue 3 + Vite + TypeScript + Pinia, styled with
the DIKA-Bold theme. Business-type aware (F&B vs grocery).

## Run

```bash
cd web-admin
npm install
npm run dev          # http://localhost:5173
```

The API target defaults to the live backend (`.env` → `VITE_API_BASE_URL`). To point at a
local API instead:

```bash
echo "VITE_API_BASE_URL=http://localhost:3000/api/v1" > .env.local
```

## Login

Owner (account admin) accounts only. Seeded demo logins:

- **F&B:** `owner@warungdemo.id` / `owner123` (Warung Kopi Demo)
- **Grocery:** `admin@sembako.id` / `admin123` (Toko Sembako Demo)

## Versioning

- Portal version comes from `package.json` (injected at build via `__APP_VERSION__`).
- Server version is read live from `GET /version`.
- Both are shown on the login screen and behind the version button in the left nav.

## Build

```bash
npm run build        # type-check + bundle to dist/
```
