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
import { SYSTEM_PROMPT, WireSchema } from '../src/nota/vision/claude.provider';

const MODEL = process.env.NOTA_VISION_MODEL ?? 'claude-opus-5';
const EFFORT = (process.env.NOTA_VISION_EFFORT ?? 'medium') as 'low' | 'medium' | 'high';
/** NOTA_BENCH_CACHE=1 marks the system block cacheable, to see whether the prefix qualifies. */
const CACHE = process.env.NOTA_BENCH_CACHE === '1';
/**
 * NOTA_BENCH_FREEFORM=1 drops structured output and asks for the same JSON in the prompt.
 *
 * Structured output constrains every token as it is decoded, and the measured ~13-22ms per output
 * token is slow enough to suspect that constraint is being paid for. If free-form generation is
 * materially faster, the reader can parse and validate the JSON itself and keep the same guarantee
 * — a reading either satisfies the schema or is rejected — without paying for it during decoding.
 */
const FREEFORM = process.env.NOTA_BENCH_FREEFORM === '1';
/**
 * NOTA_BENCH_NOSTREAM=1 uses `messages.parse()` — exactly what the live reader does.
 *
 * Worth isolating because the benchmark and production disagree: streamed reads of a 600x800 page
 * finish in ~3.0s while the live endpoint reports 3.6-5.7s for a slip of the same dimensions. If a
 * non-streaming request is simply slower to deliver, the reader can stream internally, accumulate,
 * and still hand the app one complete JSON response — a speed win that costs no contract change.
 */
const NOSTREAM = process.env.NOTA_BENCH_NOSTREAM === '1';

/** The schema, spelled out for the model when structured output is not doing it for us. */
const FREEFORM_INSTRUCTION = `Reply with ONLY a JSON object, no markdown fence and no commentary:
{"no":string|null,"dt":string|null,"cust":string|null,"it":[{"raw":string,"q":number|null,"up":number|null,"lt":number|null}],"tot":number|null,"unc":[string],"conf":number}`;

type Run = {
  ttft: number;
  total: number;
  inTok: number;
  outTok: number;
  chars: number;
  cacheWrite: number;
  cacheRead: number;
  valid: boolean;
};

async function once(client: Anthropic, image: Buffer, mime: string): Promise<Run> {
  const t0 = Date.now();
  let ttft = 0;
  let chars = 0;

  const request = {
    model: MODEL,
    max_tokens: 4096,
    thinking: { type: 'disabled' },
    system: CACHE
      ? [
          {
            type: 'text' as const,
            text: FREEFORM ? `${SYSTEM_PROMPT}\n\n${FREEFORM_INSTRUCTION}` : SYSTEM_PROMPT,
            cache_control: { type: 'ephemeral' as const },
          },
        ]
      : FREEFORM
        ? `${SYSTEM_PROMPT}\n\n${FREEFORM_INSTRUCTION}`
        : SYSTEM_PROMPT,
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
    ...(FREEFORM
      ? { output_config: { effort: EFFORT } }
      : { output_config: { format: zodOutputFormat(WireSchema), effort: EFFORT } }),
  } as Parameters<typeof client.messages.stream>[0];

  // No first-token event exists without streaming, so TTFT is reported as the whole wait — which
  // is precisely the point being measured.
  if (NOSTREAM) {
    const res = await client.messages.parse(request as never);
    const total = Date.now() - t0;
    const text = res.content
      .map((b) => ('text' in b ? b.text : ''))
      .join('');
    let ok: boolean;
    try {
      WireSchema.parse(res.parsed_output ?? JSON.parse(text));
      ok = true;
    } catch {
      ok = false;
    }
    return {
      ttft: total,
      total,
      inTok: res.usage.input_tokens,
      outTok: res.usage.output_tokens,
      chars: text.length,
      cacheWrite: res.usage.cache_creation_input_tokens ?? 0,
      cacheRead: res.usage.cache_read_input_tokens ?? 0,
      valid: ok,
    };
  }

  const stream = client.messages.stream(request);

  let body = '';
  for await (const event of stream) {
    if (event.type === 'content_block_delta') {
      if (!ttft) ttft = Date.now() - t0;
      const d = event.delta as { text?: string; partial_json?: string };
      const piece = d.text ?? d.partial_json ?? '';
      chars += piece.length;
      body += piece;
    }
  }
  if (process.env.NOTA_BENCH_SHOW === '1') console.log(`    first 110 chars: ${body.slice(0, 110)}`);
  const final = await stream.finalMessage();
  // A faster reading that does not satisfy the schema is not a faster reading. Free-form mode has
  // to clear the same bar structured output clears for free.
  let valid: boolean;
  try {
    WireSchema.parse(JSON.parse(body.replace(/^```(?:json)?|```$/g, '').trim()));
    valid = true;
  } catch {
    valid = false;
  }
  return {
    ttft,
    total: Date.now() - t0,
    inTok: final.usage.input_tokens,
    outTok: final.usage.output_tokens,
    chars,
    cacheWrite: final.usage.cache_creation_input_tokens ?? 0,
    cacheRead: final.usage.cache_read_input_tokens ?? 0,
    valid,
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

  console.log(
    `${MODEL} · effort ${EFFORT} · thinking off · ${(image.length / 1024).toFixed(0)} kB` +
      `${CACHE ? ' · prompt caching ON' : ''}\n`,
  );

  // Where the non-image input tokens live. The system prompt is only part of it — structured
  // output injects the JSON schema too — and that split decides whether marking the system block
  // cacheable can even reach the model's minimum cacheable prefix.
  const bare = await client.messages.countTokens({
    model: MODEL,
    system: SYSTEM_PROMPT,
    messages: [{ role: 'user', content: [{ type: 'text', text: 'Read this nota.' }] }],
  });
  const withSchema = await client.messages.countTokens({
    model: MODEL,
    system: SYSTEM_PROMPT,
    messages: [{ role: 'user', content: [{ type: 'text', text: 'Read this nota.' }] }],
    output_config: { format: zodOutputFormat(WireSchema) },
  });
  console.log(
    `  system prompt + instruction: ${bare.input_tokens} tok · with schema: ${withSchema.input_tokens} tok ` +
      `(schema costs ${withSchema.input_tokens - bare.input_tokens})\n`,
  );

  console.log('  run        TTFT    generate     total    in tok   out tok    ms/out tok   cache w/r');

  const all: Run[] = [];
  for (let i = 1; i <= runs; i++) {
    const r = await once(client, image, mime);
    all.push(r);
    const gen = r.total - r.ttft;
    console.log(
      `  ${String(i).padEnd(3)} ${(r.ttft + ' ms').padStart(9)} ${(gen + ' ms').padStart(11)} ` +
        `${(r.total + ' ms').padStart(9)} ${String(r.inTok).padStart(9)} ${String(r.outTok).padStart(9)} ` +
        `${(r.outTok ? (gen / r.outTok).toFixed(1) : '-').padStart(13)}   ${r.cacheWrite}/${r.cacheRead}  ${r.valid ? 'ok' : 'BAD JSON'}`,
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
