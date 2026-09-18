/**
 * How many input tokens does a nota photo cost, by image size?
 *
 *   npx ts-node scripts/bench-nota-tokens.ts <image...>
 *
 * Uses the token-counting endpoint (no generation, so effectively free) with the same system
 * prompt and image block the reader sends, and prices the result at the configured model's rate.
 */
import 'dotenv/config';
import * as fs from 'fs';
import Anthropic from '@anthropic-ai/sdk';

const MODEL = process.env.NOTA_VISION_MODEL ?? 'claude-opus-5';

/** Input $/MTok, for turning a token count into rupiah. */
const INPUT_RATE: Record<string, number> = {
  'claude-opus-5': 5,
  'claude-sonnet-5': 2,
  'claude-haiku-4-5': 1,
};
const IDR_PER_USD = 16_200;

async function main() {
  const files = process.argv.slice(2);
  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey || files.length === 0) throw new Error('usage: bench-nota-tokens.ts <image...>');
  const client = new Anthropic({ apiKey });

  // The same system prompt the provider uses, so the baseline is honest.
  const { SYSTEM_PROMPT } = await import('../src/nota/vision/claude.provider');

  console.log(`${MODEL} · input $${INPUT_RATE[MODEL] ?? '?'}/MTok\n`);
  console.log('  image              bytes      input tokens   image tokens   input cost');

  let promptOnly = 0;
  for (const file of files) {
    const image = fs.readFileSync(file);
    const mime = file.endsWith('.png') ? 'image/png' : 'image/jpeg';
    const res = await client.messages.countTokens({
      model: MODEL,
      system: SYSTEM_PROMPT,
      messages: [
        {
          role: 'user',
          content: [
            {
              type: 'image',
              source: { type: 'base64', media_type: mime as 'image/jpeg', data: image.toString('base64') },
            },
            { type: 'text', text: 'Read this nota.' },
          ],
        },
      ],
    });
    if (!promptOnly) {
      const bare = await client.messages.countTokens({
        model: MODEL,
        system: SYSTEM_PROMPT,
        messages: [{ role: 'user', content: [{ type: 'text', text: 'Read this nota.' }] }],
      });
      promptOnly = bare.input_tokens;
    }
    const idr = (res.input_tokens / 1e6) * (INPUT_RATE[MODEL] ?? 0) * IDR_PER_USD;
    console.log(
      `  ${file.split(/[\\/]/).pop()!.padEnd(18)} ${String(image.length).padStart(7)}  ${String(
        res.input_tokens,
      ).padStart(12)}   ${String(res.input_tokens - promptOnly).padStart(12)}   Rp ${idr.toFixed(0)}`,
    );
  }
  console.log(`\n  (system prompt + instruction alone: ${promptOnly} tokens)`);
}

void main();
