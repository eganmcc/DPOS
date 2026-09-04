// Static server for the built D-Customer Portal, run under PM2 behind nginx.
// nginx reverse-proxies https://dikapos.ptdika.com/customer-portal/ → this port,
// preserving the /customer-portal path (matches Vite `base`).
import express from 'express';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const dist = join(__dirname, 'dist');
const base = '/customer-portal';
const port = Number(process.env.PORT) || 5001;

const app = express();
app.get('/healthz', (_req, res) => res.json({ ok: true, app: 'customer-portal' }));
app.use(base, express.static(dist, { index: false, maxAge: '1h' }));
// SPA fallback — any non-asset path under the base returns index.html.
app.use(base, (_req, res) => res.sendFile(join(dist, 'index.html')));
app.get('/', (_req, res) => res.redirect(base + '/'));

app.listen(port, '127.0.0.1', () => {
  // eslint-disable-next-line no-console
  console.log(`D-Customer Portal listening on 127.0.0.1:${port} at ${base}/`);
});
