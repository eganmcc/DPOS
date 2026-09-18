/**
 * Does a smaller photo read faster? Times one model/effort setting across image sizes.
 *
 *   npx ts-node scripts/bench-nota-size.ts <image...>
 *
 * Model latency is only half the story: the phone also has to upload the bytes, so the script
 * prints an estimated upload time on a slow mobile link alongside the measured read time.
 * Every run is a real, billed call.
 */
import 'dotenv/config';
import * as fs from 'fs';
import { ClaudeNotaVisionProvider } from '../src/nota/vision/claude.provider';

const MODEL = process.env.NOTA_VISION_MODEL ?? 'claude-opus-5';
const EFFORT = (process.env.NOTA_VISION_EFFORT ?? 'medium') as 'low' | 'medium' | 'high';

/** A pessimistic but realistic Indonesian mobile uplink, in bits per second. */
const SLOW_UPLINK_BPS = 1_000_000;

async function main() {
  const files = process.argv.slice(2);
  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey || files.length === 0) throw new Error('usage: bench-nota-size.ts <image...>');

  const provider = new ClaudeNotaVisionProvider(apiKey, MODEL, EFFORT, true);
  console.log(`${MODEL} · effort ${EFFORT} · thinking off\n`);
  console.log('  image                 size     read      upload@1Mbps   total    extraction');

  for (const file of files) {
    const image = fs.readFileSync(file);
    const mime = file.endsWith('.png') ? 'image/png' : 'image/jpeg';
    const t0 = Date.now();
    let summary: string;
    try {
      const x = await provider.extract(image, mime);
      summary = `no=${x.notaNumber ?? '-'} date=${x.notaDate ?? '-'} total=${x.total ?? '-'} items=${x.items.length} conf=${x.confidence}`;
    } catch (e) {
      summary = 'FAILED: ' + (e as Error).message.slice(0, 80);
    }
    const read = Date.now() - t0;
    const uploadMs = Math.round((image.length * 8 * 1000) / SLOW_UPLINK_BPS);
    const kb = (image.length / 1024).toFixed(0);
    console.log(
      `  ${file.split(/[\\/]/).pop()!.padEnd(20)} ${(kb + ' kB').padStart(7)}  ${(read + ' ms').padStart(8)}  ${(uploadMs + ' ms').padStart(10)}     ${(read + uploadMs + ' ms').padStart(8)}   ${summary}`,
    );
  }
}

void main();
