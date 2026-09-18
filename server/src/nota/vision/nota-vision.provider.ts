import { z } from 'zod';

/**
 * One line as written on the slip. `rawText` is transcribed VERBATIM — abbreviations and all —
 * because identifying the product is a later, separate job that needs the merchant's own
 * shorthand intact ("1. M. KECIL" must not become a guessed "Mie Ayam Kecil").
 */
export const NotaItemSchema = z.object({
  rawText: z.string(),
  qty: z.number().nullable(),
  unitPrice: z.number().int().nullable(),
  lineTotal: z.number().int().nullable(),
});

/**
 * What a vision provider returns for one nota. Every field is nullable on purpose: an admitted
 * blank goes to a human, while a confident wrong number might not.
 */
export const NotaExtractionSchema = z.object({
  notaNumber: z.string().nullable(),
  /** ISO `yyyy-mm-dd`. Indonesian slips are day-first, which the prompt pins down. */
  notaDate: z.string().nullable(),
  customerName: z.string().nullable(),
  items: z.array(NotaItemSchema),
  /** The total AS WRITTEN. Null when it is not on the paper — never summed by the model. */
  total: z.number().int().nullable(),
  /** Fields the model could not read with confidence, named so the reader knows where to look. */
  unclear: z.array(z.string()),
  /** 0–100, advisory only. It never gates anything on its own. */
  confidence: z.number().int(),
});

export type NotaItem = z.infer<typeof NotaItemSchema>;
export type NotaExtraction = z.infer<typeof NotaExtractionSchema>;

/** What the API hands back: the extraction plus how it was produced. */
export interface NotaReadResult extends NotaExtraction {
  model: string;
  latencyMs: number;
}

/**
 * Vision provider abstraction, deliberately the same shape as `PaymentProvider`
 * (`src/payments/payment-provider.ts`): the simulated implementation is the default and a real
 * one drops in behind the same interface — the pattern Constitution VII already blesses.
 */
export interface NotaVisionProvider {
  readonly name: string;
  /**
   * `model` overrides the configured reader for this one request. It exists so two models can be
   * compared on the same real slip without restarting the server or editing its environment —
   * accuracy on real handwriting is the only thing that decides which model to run, and it cannot
   * be answered with a synthetic page.
   */
  extract(image: Buffer, mimeType: string, model?: string): Promise<NotaExtraction>;
}

/**
 * The only models a request may ask for. An allowlist rather than a free-text model name: this is
 * a spend lever reachable over HTTP, so it is limited to the three under evaluation.
 */
export const EVALUATION_MODELS = [
  'claude-opus-5',
  'claude-sonnet-5',
  'claude-haiku-4-5-20251001',
] as const;

export const NOTA_VISION_PROVIDER = Symbol('NOTA_VISION_PROVIDER');
