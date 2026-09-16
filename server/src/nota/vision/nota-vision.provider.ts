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
  extract(image: Buffer, mimeType: string): Promise<NotaExtraction>;
}

export const NOTA_VISION_PROVIDER = Symbol('NOTA_VISION_PROVIDER');
