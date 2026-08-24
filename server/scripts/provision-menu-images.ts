/* eslint-disable no-console */
/**
 * Copy every menu photo into the S3 bucket the app reads from.
 *
 * Run it ON THE EC2 INSTANCE: it shells out to the AWS CLI, which picks up the
 * instance's IAM role from the metadata service. No access keys are used, read,
 * or stored — that is deliberate, don't "fix" it by adding credentials.
 *
 *   cd /opt/dpos/server && npx ts-node scripts/provision-menu-images.ts
 *   DRY_RUN=1 …                 # download + report, upload nothing
 *   S3_BUCKET=other-bucket …    # default: amzn-s3-dkpos-bucket
 *
 * Sources are Wikimedia Commons, which rate-limits bursts (HTTP 429), so
 * downloads are sequential with a delay and retries. Uploads are set
 * `Content-Type: image/jpeg` — without it S3 serves application/octet-stream
 * and some clients refuse to render the image.
 */
import { execFileSync } from 'child_process';
import { mkdirSync, writeFileSync, statSync } from 'fs';
import { MENU, slugify, menuImageUrl } from '../prisma/menu-data';

const BUCKET = process.env.S3_BUCKET ?? 'amzn-s3-dkpos-bucket';
const REGION = process.env.AWS_REGION ?? 'ap-southeast-3';
const PREFIX = process.env.S3_PREFIX ?? 'menu';
const DRY_RUN = process.env.DRY_RUN === '1';
const WORK_DIR = '/tmp/dpos-menu-images';
const UA = 'DPOS-menu-provisioning/1.0 (https://github.com/eganmcc/DPOS)';

const sleep = (ms: number): Promise<void> => new Promise((r) => setTimeout(r, ms));

async function download(url: string, dest: string): Promise<number> {
  for (let attempt = 1; attempt <= 4; attempt += 1) {
    const res = await fetch(url, { headers: { 'User-Agent': UA } });
    if (res.ok) {
      const buf = Buffer.from(await res.arrayBuffer());
      writeFileSync(dest, buf);
      return buf.length;
    }
    if (res.status !== 429 && res.status !== 503) throw new Error(`HTTP ${res.status} for ${url}`);
    await sleep(attempt * 5000); // Commons throttling: back off and retry
  }
  throw new Error(`gave up after retries: ${url}`);
}

async function main(): Promise<void> {
  mkdirSync(WORK_DIR, { recursive: true });
  console.log(`${MENU.length} items -> s3://${BUCKET}/${PREFIX}/  (${DRY_RUN ? 'DRY RUN' : 'live'})`);

  let uploaded = 0;
  const failures: string[] = [];

  for (const item of MENU) {
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
      console.log(`  ok   ${item.name.padEnd(16)} ${String(Math.round(bytes / 1024)).padStart(4)} KB -> ${key}`);
    } catch (e) {
      failures.push(item.name);
      console.log(`  FAIL ${item.name.padEnd(16)} ${(e as Error).message}`);
    }
    await sleep(1200); // stay under Commons' rate limit
  }

  console.log(`\nuploaded ${uploaded}/${MENU.length}${failures.length ? `, failed: ${failures.join(', ')}` : ''}`);
  console.log(`app will load e.g. ${menuImageUrl(MENU[0].name)}`);
  if (failures.length) process.exit(1);
}

void main();
