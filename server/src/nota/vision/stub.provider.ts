import { Injectable } from '@nestjs/common';
import { NotaExtraction, NotaVisionProvider } from './nota-vision.provider';

/**
 * Deterministic stand-in for the real reader.
 *
 * This is the DEFAULT provider whenever `ANTHROPIC_API_KEY` is unset, which makes two things true
 * that matter: the integrity suite never makes a paid external call, and a developer can run the
 * whole nota flow end to end with no credentials at all.
 *
 * The canned answer mirrors a real Orchid Laundromat slip so the app's rendering — including a
 * null field and a flagged `unclear` entry — is exercised honestly rather than against a
 * suspiciously perfect fixture.
 */
@Injectable()
export class StubNotaVisionProvider implements NotaVisionProvider {
  readonly name = 'stub';

  async extract(image: Buffer, _mimeType: string): Promise<NotaExtraction> {
    // Vary one field with the image so a test can prove the response actually came from
    // the bytes it sent rather than a hardcoded constant.
    const marker = image.length % 1000;
    return {
      notaNumber: String(1900 + marker),
      notaDate: '2026-07-11',
      customerName: 'Edward',
      items: [{ rawText: '1. M. KECIL', qty: 1, unitPrice: 65000, lineTotal: 65000 }],
      total: 65000,
      unclear: ['angka tulisan tangan di bawah harga'],
      confidence: 80,
    };
  }
}
