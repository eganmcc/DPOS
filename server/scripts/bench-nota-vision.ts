/**
 * Measure the nota reader: latency and extraction quality per model / effort setting.
 *
 *   npx ts-node scripts/bench-nota-vision.ts <image> [runs]
 *
 * Reads ANTHROPIC_API_KEY from server/.env. Every run is a real, billed call — keep the
 * image count small. Prints a table so the model choice is made on numbers, not on a hunch.
 */
import 'dotenv/config';
import * as fs from 'fs';
import { ClaudeNotaVisionProvider } from '../src/nota/vision/claude.provider';
import { NotaExtraction } from '../src/nota/vision/nota-vision.provider';

type Config = {
  label: string;
  model: string;
  effort: 'low' | 'medium' | 'high';
  thinkingDisabled: boolean;
};

/**
 * The shortlist for "which model reads a real slip well enough".
 *
 * Latency is already settled and is NOT what this script is for — measured on a 600x800 page on
 * EC2, warm: Opus 5 ~2.9s, Sonnet 5 ~2.3s, Haiku 4.5 ~1.4s, and real slips run ~0.8s slower than
 * that. The open question is only whether the faster models still read the handwriting, which
 * needs real slips and therefore has to run on the machine that holds them.
 *
 * `effort` is ignored for Haiku, which rejects the parameter outright.
 */
const CONFIGS: Config[] = [
  { label: 'opus-5 · medium', model: 'claude-opus-5', effort: 'medium', thinkingDisabled: true },
  { label: 'sonnet-5 · medium', model: 'claude-sonnet-5', effort: 'medium', thinkingDisabled: true },
  { label: 'haiku-4-5', model: 'claude-haiku-4-5-20251001', effort: 'low', thinkingDisabled: true },
];

/** A one-line fingerprint of the extraction, so two runs can be compared at a glance. */
function summarize(x: NotaExtraction): string {
  const items = x.items.map((i) => `${i.rawText}@${i.lineTotal ?? '-'}`).join(' | ');
  return `no=${x.notaNumber ?? '-'} date=${x.notaDate ?? '-'} name=${x.customerName ?? '-'} total=${
    x.total ?? '-'
  } conf=${x.confidence} items=[${items}]`;
}

async function main() {
  const [file, runsArg] = process.argv.slice(2);
  if (!file) throw new Error('usage: bench-nota-vision.ts <image> [runs]');
  const runs = Number(runsArg ?? 1);
  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey) throw new Error('ANTHROPIC_API_KEY is not set');

  const image = fs.readFileSync(file);
  const mime = file.endsWith('.png') ? 'image/png' : 'image/jpeg';
  console.log(`image: ${file} (${image.length} bytes), ${runs} run(s) per config\n`);

  for (const c of CONFIGS) {
    const provider = new ClaudeNotaVisionProvider(apiKey, c.model, c.effort, c.thinkingDisabled);
    const times: number[] = [];
    let last = '';
    let failure = '';
    for (let i = 0; i < runs; i++) {
      const t0 = Date.now();
      try {
        last = summarize(await provider.extract(image, mime));
        times.push(Date.now() - t0);
      } catch (e) {
        failure = (e as Error).message.slice(0, 120);
        break;
      }
    }
    const avg = times.length ? Math.round(times.reduce((a, b) => a + b, 0) / times.length) : 0;
    console.log(
      `${c.label.padEnd(30)} ${failure ? 'FAILED: ' + failure : `${String(avg).padStart(6)} ms   ${last}`}`,
    );
  }
}

void main();
