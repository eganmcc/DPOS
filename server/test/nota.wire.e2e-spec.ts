import { WireSchema, toExtraction } from '../src/nota/vision/claude.provider';

/**
 * The reader asks the model for short keys (`up`, `lt`) and renames them on the way out, because
 * every output token is ~13ms the cashier waits. That rename is the one place a nota's money can
 * be silently wrong: swap `up` and `lt` and a 4-line slip still returns four lines, still returns
 * plausible rupiah, and still looks right on screen — only the numbers are attached to the wrong
 * column. Nothing else in the suite would catch it, so it is pinned here.
 *
 * A unit test wearing an `.e2e-spec.ts` name only because that is what `test/jest-e2e.json`
 * collects; it starts no app and touches no database.
 */
describe('nota wire mapping', () => {
  it('maps every short key to the public field, without crossing unit price and line total', () => {
    const wire = WireSchema.parse({
      no: '2237',
      dt: '2026-08-02',
      cust: 'Sri',
      it: [
        { raw: '2 M BESAR', q: 2, up: 65000, lt: 130000 },
        { raw: 'A / J FREE', q: null, up: null, lt: null },
      ],
      tot: 130000,
      unc: ['tanggal'],
      conf: 86,
    });

    expect(toExtraction(wire)).toEqual({
      notaNumber: '2237',
      notaDate: '2026-08-02',
      customerName: 'Sri',
      items: [
        { rawText: '2 M BESAR', qty: 2, unitPrice: 65000, lineTotal: 130000 },
        { rawText: 'A / J FREE', qty: null, unitPrice: null, lineTotal: null },
      ],
      total: 130000,
      unclear: ['tanggal'],
      confidence: 86,
    });
  });

  it('keeps an unwritten total null rather than summing the lines', () => {
    const wire = WireSchema.parse({
      no: null,
      dt: null,
      cust: null,
      it: [{ raw: '1 M KECIL', q: 1, up: 60000, lt: 60000 }],
      tot: null,
      unc: ['total'],
      conf: 70,
    });

    // The model is told never to compute; the mapping must not quietly help it along either.
    expect(toExtraction(wire).total).toBeNull();
  });

  it('rejects a reading that is missing a field instead of defaulting it', () => {
    // A half-filled object must fail loudly here rather than reach the screen as a complete read.
    expect(() =>
      WireSchema.parse({ no: '1900', dt: null, cust: null, it: [], tot: null, unc: [] }),
    ).toThrow();
  });
});
