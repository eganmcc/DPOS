/* eslint-disable no-console */
/**
 * Fetch a REAL product photo for each grocery item and copy it to S3.
 *   1) Open Food Facts (search-a-licious) — actual product packaging for brands.
 *   2) Wikimedia Commons image search — fallback for generic produce/household.
 * Uploads to the public `menu/` S3 prefix as `<slug>_v2.jpg`.
 *
 * Run ON EC2 (uses the instance IAM role via the AWS CLI — no access keys):
 *   cd /opt/dpos/server && npx ts-node scripts/provision-grocery-images.ts
 *   DRY_RUN=1 …   # look images up + report, upload nothing
 */
import { execFileSync } from 'child_process';
import { mkdirSync, writeFileSync } from 'fs';
import { GROCERY, slugify } from '../prisma/grocery-data';

const BUCKET = process.env.S3_BUCKET ?? 'amzn-s3-dkpos-bucket';
const REGION = process.env.AWS_REGION ?? 'ap-southeast-3';
const PREFIX = process.env.S3_PREFIX ?? 'menu';
const DRY_RUN = process.env.DRY_RUN === '1';
const WORK_DIR = '/tmp/dpos-grocery-images';
const UA = 'DPOS-demo/1.0 (https://github.com/eganmcc/DPOS; edward.gan@ptdika.co.id)';

const sleep = (ms: number): Promise<void> => new Promise((r) => setTimeout(r, ms));

async function getJson(url: string): Promise<any | null> {
  for (let attempt = 1; attempt <= 3; attempt += 1) {
    try {
      const res = await fetch(url, { headers: { 'User-Agent': UA, Accept: 'application/json' } });
      if (res.ok) return await res.json();
    } catch {
      /* retry */
    }
    await sleep(attempt * 1500);
  }
  return null;
}

/** Open Food Facts: first search hit that has a front image. */
async function offImage(term: string): Promise<string | null> {
  const url = `https://search.openfoodfacts.org/search?q=${encodeURIComponent(term)}&page_size=10`;
  const j = await getJson(url);
  const hits: any[] = j?.hits ?? [];
  for (const h of hits) {
    const img = h.image_front_url || h.image_url;
    if (img && /\.(jpe?g|png)/i.test(img)) return img as string;
  }
  return null;
}

/** Wikimedia Commons: first image-namespace search result (500px thumb). */
async function commonsImage(term: string): Promise<string | null> {
  const url =
    'https://commons.wikimedia.org/w/api.php?action=query&format=json&generator=search' +
    `&gsrsearch=${encodeURIComponent(term)}&gsrnamespace=6&gsrlimit=6` +
    '&prop=imageinfo&iiprop=url&iiurlwidth=500';
  const j = await getJson(url);
  const pages: any[] = Object.values(j?.query?.pages ?? {});
  pages.sort((a, b) => (a.index ?? 0) - (b.index ?? 0));
  for (const p of pages) {
    const info = p.imageinfo?.[0];
    const u = info?.thumburl || info?.url;
    if (u && /\.(jpe?g|png)(\?|$)/i.test(u)) return u as string;
  }
  return null;
}

async function download(url: string, dest: string): Promise<number> {
  for (let attempt = 1; attempt <= 4; attempt += 1) {
    try {
      const res = await fetch(url, { headers: { 'User-Agent': UA }, redirect: 'follow' });
      if (res.ok) {
        const buf = Buffer.from(await res.arrayBuffer());
        writeFileSync(dest, buf);
        return buf.length;
      }
    } catch {
      /* retry */
    }
    await sleep(attempt * 1500);
  }
  throw new Error(`download failed: ${url}`);
}

async function main(): Promise<void> {
  mkdirSync(WORK_DIR, { recursive: true });
  console.log(`${GROCERY.length} items -> s3://${BUCKET}/${PREFIX}/  (${DRY_RUN ? 'DRY RUN' : 'live'})`);
  let uploaded = 0;
  const failures: string[] = [];
  for (const item of GROCERY) {
    const slug = slugify(item.name);
    const local = `${WORK_DIR}/${slug}.jpg`;
    const key = `${PREFIX}/${slug}_v2.jpg`;
    try {
      let src: string | null = item.off ? await offImage(item.off) : null;
      let via = 'OFF';
      if (!src) {
        src = await commonsImage(item.commons);
        via = 'Commons';
      }
      if (!src) throw new Error('no image found');
      const bytes = await download(src, local);
      if (!DRY_RUN) {
        execFileSync(
          'aws',
          ['s3', 'cp', local, `s3://${BUCKET}/${key}`, '--region', REGION, '--content-type', 'image/jpeg', '--only-show-errors'],
          { stdio: 'pipe' },
        );
        uploaded += 1;
      }
      console.log(`  ok  [${via.padEnd(7)}] ${item.name.padEnd(20)} ${String(Math.round(bytes / 1024)).padStart(4)} KB -> ${key}`);
    } catch (e) {
      failures.push(item.name);
      console.log(`  FAIL          ${item.name.padEnd(20)} ${(e as Error).message}`);
    }
    await sleep(800);
  }
  console.log(`\nuploaded ${uploaded}/${GROCERY.length}${failures.length ? `, failed: ${failures.join(', ')}` : ''}`);
  if (failures.length) process.exit(1);
}

void main();
