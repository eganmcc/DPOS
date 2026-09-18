/**
 * Where does the nota reader's ~4s actually go — waiting to start, or generating?
 *
 *   npx ts-node scripts/bench-nota-ttft.ts <image> [runs]
 *
 * `latencyMs` in the server log is one opaque number. This splits it:
 *
 *   TTFT      t0 -> first content delta   (prefill + the Jakarta->US leg + queueing)
 *   generate  first delta -> done         (output tokens, one at a time)
 *
 * and that split decides two open questions. If TTFT is small, streaming the reading to the app
 * is worth building, because the cashier sees the nota number while the rest is still arriving.
 * If generation dominates, then trimming what we ask the model to WRITE — the free-form
 * Indonesian sentences in unclear[] — buys real seconds, and the per-token figure below prices
 * that cut instead of guessing at it.
 *
 * Run 1 pays a cold TLS handshake and runs 2+ reuse the connection, so the gap between them
 * prices a keep-alive. Same model, effort, prompt and schema as the live reader, so the numbers
 * transfer. Intended to be run against a SYNTHETIC page (scripts/make-latency-probe.js): image
 * tokens scale with pixel area, not with what is written, so a fake slip measures latency exactly
 * as well as a real one and keeps real customer slips out of it.
 */
import 'dotenv/config';
import * as fs from 'fs';
import Anthropic from '@anthropic-ai/sdk';
import { zodOutputFormat } from '@anthropic-ai/sdk/helpers/zod';
import { SYSTEM_PROMPT } from '../src/nota/vision/claude.provider';
import { NotaExtractionSchema } from '../src/nota/vision/nota-vision.provider';

const MODEL = process.env.NOTA_VISION_MODEL ?? 'claude-opus-5';
const EFFORT = (process.env.NOTA_VISION_EFFORT ?? 'medium') as 'low' | 'medium' | 'high';

type Run = { ttft: number; total: number; inTok: number; outTok: number; chars: number };

async function once(client: Anthropic, image: Buffer, mime: string): Promise<Run> {
  const t0 = Date.now();
  let ttft = 0;
  let chars = 0;

  const stream = client.messages.stream({
    model: MODEL,
    max_tokens: 4096,
    thinking: { type: 'disabled' },
    system: SYSTEM_PROMPT,
    messages: [
      {
        role: 'user',
        content: [
          {
            type: 'image',
            source: { type: 'base64', media_type: mime as 'image/png', data: image.toString('base64') },
          },
          { type: 'text', text: 'Read this nota.' },
        ],
      },
    ],
    output_config: { format: zodOutputFormat(NotaExtractionSchema), effort: EFFORT },
  });

  for await (const event of stream) {
    if (event.type === 'content_block_delta') {
      if (!ttft) ttft = Date.now() - t0;
      const d = event.delta as { text?: string; partial_json?: string };
      chars += (d.text ?? d.partial_json ?? '').length;
    }
  }
  const final = await stream.finalMessage();
  return {
    ttft,
    total: Date.now() - t0,
    inTok: final.usage.input_tokens,
    outTok: final.usage.output_tokens,
    chars,
  };
}

async function main() {
  const [file, runsArg] = process.argv.slice(2);
  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey || !file) throw new Error('usage: bench-nota-ttft.ts <image> [runs]');
  const runs = Number(runsArg ?? 3);
  const image = fs.readFileSync(file);
  const mime = file.endsWith('.png') ? 'image/png' : 'image/jpeg';
  const client = new Anthropic({ apiKey, timeout: 45_000, maxRetries: 1 });

  console.log(`${MODEL} · effort ${EFFORT} · thinking off · ${(image.length / 1024).toFixed(0)} kB\n`);
  console.log('  run        TTFT    generate     total    in tok   out tok    ms/out tok');

  const all: Run[] = [];
  for (let i = 1; i <= runs; i++) {
    const r = await once(client, image, mime);
    all.push(r);
    const gen = r.total - r.ttft;
    console.log(
      `  ${String(i).padEnd(3)} ${(r.ttft + ' ms').padStart(9)} ${(gen + ' ms').padStart(11)} ` +
        `${(r.total + ' ms').padStart(9)} ${String(r.inTok).padStart(9)} ${String(r.outTok).padStart(9)} ` +
        `${(r.outTok ? (gen / r.outTok).toFixed(1) : '-').padStart(13)}`,
    );
  }

  // Runs 2+ reuse the connection; run 1 is the cold one. Averaging them together would hide
  // exactly the thing we are trying to price.
  const warm = all.slice(1);
  const avg = (xs: number[]) => Math.round(xs.reduce((a, b) => a + b, 0) / (xs.length || 1));
  if (warm.length) {
    const msPerTok = avg(warm.map((r) => r.total - r.ttft)) / avg(warm.map((r) => r.outTok));
    console.log(
      `\n  warm avg: TTFT ${avg(warm.map((r) => r.ttft))} ms · generate ${avg(
        warm.map((r) => r.total - r.ttft),
      )} ms · total ${avg(warm.map((r) => r.total))} ms`,
    );
    console.log(`  cold run 1 was ${all[0].total - avg(warm.map((r) => r.total))} ms slower than warm`);
    console.log(`  ~${msPerTok.toFixed(1)} ms per output token → cutting 40 tokens of prose saves ~${Math.round(msPerTok * 40)} ms`);
  }
}

void main();
