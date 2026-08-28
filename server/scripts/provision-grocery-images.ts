/* eslint-disable no-console */
/**
 * Copy every grocery photo into the S3 bucket the app reads from (public `menu/`
 * prefix — grocery slugs don't collide with the F&B menu).
 *
 * Run it ON THE EC2 INSTANCE (uses the instance IAM role via the AWS CLI — no
 * access keys):
 *   cd /opt/dpos/server && npx ts-node scripts/provision-grocery-images.ts
 *   DRY_RUN=1 …   # download + report, upload nothing
 */
import { execFileSync } from 'child_process';
import { mkdirSync, writeFileSync } from 'fs';
import { GROCERY, slugify } from '../prisma/grocery-data';

const BUCKET = process.env.S3_BUCKET ?? 'amzn-s3-dkpos-bucket';
const REGION = process.env.AWS_REGION ?? 'ap-southeast-3';
const PREFIX = process.env.S3_PREFIX ?? 'menu';
const DRY_RUN = process.env.DRY_RUN === '1';
const WORK_DIR = '/tmp/dpos-grocery-images';

const sleep = (ms: number): Promise<void> => new Promise((r) => setTimeout(r, ms));

async function download(url: string, dest: string): Promise<number> {
  for (let attempt = 1; attempt <= 4; attempt += 1) {
    try {
      const res = await fetch(url, { redirect: 'follow' });
      if (res.ok) {
        const buf = Buffer.from(await res.arrayBuffer());
        writeFileSync(dest, buf);
        return buf.length;
      }
      if (res.status !== 429 && res.status !== 503) throw new Error(`HTTP ${res.status}`);
    } catch (e) {
      if (attempt === 4) throw e;
    }
    await sleep(attempt * 2000);
  }
  throw new Error(`gave up: ${url}`);
}

async function main(): Promise<void> {
  mkdirSync(WORK_DIR, { recursive: true });
  console.log(`${GROCERY.length} items -> s3://${BUCKET}/${PREFIX}/  (${DRY_RUN ? 'DRY RUN' : 'live'})`);
  let uploaded = 0;
  const failures: string[] = [];
  for (const item of GROCERY) {
    const slug = slugify(item.name);
    const local = `${WORK_DIR}/${slug}.jpg`;
    const key = `${PREFIX}/${slug}.jpg`;
    try {
      const bytes = await download(item.sourceImageUrl, local);
      if (!DRY_RUN) {
        execFileSync(
          'aws',
          ['s3', 'cp', local, `s3://${BUCKET}/${key}`, '--region', REGION, '--content-type', 'image/jpeg', '--only-show-errors'],
          { stdio: 'pipe' },
        );
        uploaded += 1;
      }
      console.log(`  ok   ${item.name.padEnd(20)} ${String(Math.round(bytes / 1024)).padStart(4)} KB -> ${key}`);
    } catch (e) {
      failures.push(item.name);
      console.log(`  FAIL ${item.name.padEnd(20)} ${(e as Error).message}`);
    }
    await sleep(600);
  }
  console.log(`\nuploaded ${uploaded}/${GROCERY.length}${failures.length ? `, failed: ${failures.join(', ')}` : ''}`);
  if (failures.length) process.exit(1);
}

void main();
