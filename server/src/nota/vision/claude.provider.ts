import { Injectable, Logger, ServiceUnavailableException } from '@nestjs/common';
import Anthropic from '@anthropic-ai/sdk';
import { zodOutputFormat } from '@anthropic-ai/sdk/helpers/zod';
import {
  NotaExtraction,
  NotaExtractionSchema,
  NotaVisionProvider,
} from './nota-vision.provider';

/**
 * Everything the model must get right about an Indonesian handwritten nota.
 *
 * The rules here were written against real slips, and each one exists because getting it wrong is
 * both easy and silent:
 *  - transcribing verbatim keeps the merchant's shorthand intact for later matching,
 *  - `.` is a thousands separator in Indonesia, so "65.000" is sixty-five thousand, not sixty-five,
 *  - dates are day-first, so 11-7-2026 is 11 July — month-first would be wrong for 12 days a month
 *    and right for the rest, which is the worst kind of bug,
 *  - and a total that was never written must come back null rather than be quietly computed,
 *    because an invented total is indistinguishable from a read one.
 */
/** Exported so scripts/bench-nota-tokens.ts measures the real prompt, not an approximation. */
export const SYSTEM_PROMPT = `You read photographs of Indonesian handwritten sales receipts (nota) and return structured data.

TRANSCRIPTION
- Transcribe each item line VERBATIM into rawText, including abbreviations, punctuation and capitalisation exactly as written ("1. M. KECIL", "1 M BESAR").
- Do NOT expand, translate, correct or guess at what an abbreviation means. Identifying the product is someone else's job; yours is to read the paper.

NUMBERS (Indonesian formatting)
- "." is a thousands separator and "," is the decimal separator: "65.000" is 65000, "130.000" is 130000, "8.500" is 8500.
- "15rb", "15 rb" and "15k" all mean 15000.
- Return every money value as an integer number of rupiah with no separators and no currency symbol.

DATES
- Indonesian dates are DAY FIRST: "11-7-2026" is 11 July 2026, "2-8-2026" is 2 August 2026.
- Two-digit years are 20xx. Return notaDate as ISO yyyy-mm-dd.

HONESTY
- Never compute anything. If the total is not written on the paper, return total: null — do not sum the lines.
- If the paper's own arithmetic is wrong, report what is written. The discrepancy is information.
- Anything you cannot read confidently: return null for that field and add a short description of it to unclear[].
- Write every unclear[] entry in Bahasa Indonesia — the cashier reading it works in Indonesian (e.g. "angka di bawah harga", "nomor nota").
- Never guess a digit, a name or an amount. An admitted blank is far more useful than a confident mistake.

CONTEXT
- Ignore pre-printed letterhead, addresses, phone numbers, terms and conditions, and stamps.
- Read only the handwriting and the values that belong to this sale.
- confidence is your overall 0-100 confidence in the transcription.`;

/**
 * Real reader: Claude with a vision input and a schema-constrained response.
 *
 * Structured output means the response either validates against the schema or comes back unparsed —
 * there is no half-object to persist and no hand-rolled JSON parsing to get subtly wrong.
 */
@Injectable()
export class ClaudeNotaVisionProvider implements NotaVisionProvider {
  private readonly logger = new Logger(ClaudeNotaVisionProvider.name);
  private readonly client: Anthropic;
  readonly name: string;

  constructor(
    apiKey: string,
    private readonly model: string,
    /**
     * How hard the model works before answering. Reading a slip is perception, not deduction, so
     * the default is `low`: at `high` (the API default) the model spends many seconds thinking
     * about a task where thinking buys very little, and the cashier waits for it.
     */
    private readonly effort: 'low' | 'medium' | 'high' | 'xhigh' | 'max' = 'low',
    /** Set false to let the model think first — slower, worth measuring against on hard slips. */
    private readonly thinkingDisabled = true,
  ) {
    // 45s covers a slow mobile-network round trip on a large photo; one retry, because the SDK
    // already retries 429/5xx itself and a second attempt at a hard failure just doubles the bill.
    this.client = new Anthropic({ apiKey, timeout: 45_000, maxRetries: 1 });
    this.name = model;
  }

  async extract(image: Buffer, mimeType: string): Promise<NotaExtraction> {
    const response = await this.client.messages.parse({
      model: this.model,
      max_tokens: 4096,
      ...(this.thinkingDisabled ? { thinking: { type: 'disabled' as const } } : {}),
      system: SYSTEM_PROMPT,
      messages: [
        {
          role: 'user',
          content: [
            {
              type: 'image',
              source: {
                type: 'base64',
                media_type: mimeType as 'image/jpeg' | 'image/png' | 'image/webp',
                data: image.toString('base64'),
              },
            },
            { type: 'text', text: 'Read this nota.' },
          ],
        },
      ],
      output_config: {
        format: zodOutputFormat(NotaExtractionSchema),
        effort: this.effort,
      },
    });

    // parsed_output is null when the model's answer did not satisfy the schema. Surfacing that as
    // a failure is deliberate: a partial extraction shown as if it were complete is worse than an
    // error the operator can act on by retaking the photo.
    const parsed = response.parsed_output;
    if (!parsed) {
      this.logger.warn(`Extraction did not match the schema (message ${response.id})`);
      throw new ServiceUnavailableException({
        code: 'NOTA_EXTRACTION_UNPARSEABLE',
        message: 'The reader could not produce a usable result. Try a clearer photo.',
      });
    }
    return parsed;
  }
}
