import 'package:dpos/features/nota/nota_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Correcting a reading, and saying by how much the paper disagrees with itself.
///
/// The nota behind these numbers is real: Warung Kopi #07, 22 Sep 2026, photographed by a tester.
/// Its own JUMLAH column adds to 286.000 while the written total says 261.000 — the person who
/// totalled it counted the 2 x 25.000 cappuccino once. The reader was right; the paper was not.
void main() {
  NotaReading readingOf(List<NotaLine> items, {int? total}) => NotaReading(
        items: items,
        unclear: const [],
        confidence: 92,
        model: 'test',
        latencyMs: 0,
        raw: const {},
        total: total,
      );

  NotaLine line(String name, num qty, int price) =>
      NotaLine(rawText: name, qty: qty, unitPrice: price, lineTotal: (qty * price).round());

  /// Nota #07 as it was actually written.
  final nota07 = readingOf(
    [
      line('Ayam bakar', 2, 32000),
      line('Bakso', 3, 24000),
      line('Ayam Geprek', 1, 28000),
      line('Cappucino', 2, 25000),
      line('Es Jeruk', 1, 12000),
      line('Jus Alpukat', 1, 20000),
      line('Kopi susu', 1, 18000),
      line('Gado-Gado', 1, 22000),
    ],
    total: 261000,
  );

  group('how far apart the two totals are', () {
    test('the difference is the lines minus the written total', () {
      expect(nota07.linesSum, 286000);
      expect(nota07.totalDifference, 25000,
          reason: 'exactly one cappuccino — the size of it is what tells a cashier that');
    });

    test('a paper that over-totals its own lines reads negative', () {
      final r = readingOf([line('Kopi', 1, 18000)], total: 20000);
      expect(r.totalDifference, -2000);
    });

    test('agreement is not a difference', () {
      final r = readingOf([line('Kopi', 1, 18000)], total: 18000);
      expect(r.totalDifference, isNull);
    });

    test('nothing to compare against is not a difference either', () {
      expect(readingOf([line('Kopi', 1, 18000)]).totalDifference, isNull);
      expect(readingOf(const [], total: 18000).totalDifference, isNull);
    });
  });

  group('what the cashier typed', () {
    test('a price is digits — the dot on a nota means thousands, not decimals', () {
      expect(parseRupiahInput('28.000'), 28000);
      expect(parseRupiahInput('28000'), 28000);
      expect(parseRupiahInput('Rp 28.000'), 28000,
          reason: 'reading it as 28.0 would undercharge by a thousand times');
    });

    test('an empty price stays unreadable rather than becoming free', () {
      expect(parseRupiahInput(''), isNull);
      expect(parseRupiahInput('   '), isNull);
      expect(parseRupiahInput('-'), isNull);
    });

    test('a quantity CAN have a decimal, because a nota can say 1,5 kg', () {
      expect(parseQtyInput('1,5'), 1.5);
      expect(parseQtyInput('1.5'), 1.5);
      expect(parseQtyInput('3'), 3);
    });

    test('a quantity that is not a number is not a quantity', () {
      expect(parseQtyInput('dua'), isNull);
      expect(parseQtyInput(''), isNull);
      expect(parseQtyInput('-2'), isNull);
    });
  });

  group('correcting a line', () {
    test('a misread price is fixed and the line total follows it', () {
      // What the tester's photo did to this line: 28.000 read as 20.000.
      final misread = NotaLine(rawText: 'Ayam Geprek', qty: 1, unitPrice: 20000, lineTotal: 20000);
      final fixed = misread.corrected(unitPrice: 28000);

      expect(fixed.unitPrice, 28000);
      expect(fixed.lineTotal, 28000, reason: 'recomputed, never carried over');
      expect(fixed.edited, true);
    });

    test('the total is always quantity times price, whatever it used to be', () {
      final odd = NotaLine(rawText: 'Bakso', qty: 3, unitPrice: 24000, lineTotal: 999);
      expect(odd.corrected(qty: 3).lineTotal, 72000);
    });

    test('a name can be fixed without touching the money', () {
      final fixed = line('Bakro', 3, 24000).corrected(rawText: 'Bakso');
      expect(fixed.rawText, 'Bakso');
      expect(fixed.lineTotal, 72000);
    });

    test('a price that is still unreadable stays null, and does not become zero', () {
      final blank = const NotaLine(rawText: 'Teh', qty: 1);
      final still = blank.corrected(rawText: 'Teh manis');
      expect(still.unitPrice, isNull);
      expect(still.lineTotal, isNull, reason: 'nobody can be charged for a line with no price');
    });

    test('correcting the misread line makes the reading agree with the paper', () {
      // The other half of the story: with Ayam Geprek fixed to 28.000 the lines come to 286.000,
      // and the paper is STILL 25.000 out — because the paper is the one that is wrong.
      final asPhotographed = readingOf(
        [...nota07.items]..[2] = const NotaLine(
            rawText: 'Ayam Geprek', qty: 1, unitPrice: 20000, lineTotal: 20000),
        total: 261000,
      );
      expect(asPhotographed.linesSum, 278000, reason: 'what the tester saw');

      final corrected = asPhotographed.withLine(2, asPhotographed.items[2].corrected(unitPrice: 28000));
      expect(corrected.linesSum, 286000);
      expect(corrected.totalDifference, 25000);
      expect(corrected.hasEdits, true);
    });

    test('an untouched reading carries no edits', () {
      expect(nota07.hasEdits, false);
    });

    test('replacing a line leaves every other line alone', () {
      final r = nota07.withLine(0, nota07.items[0].corrected(qty: 4));
      expect(r.items.length, nota07.items.length);
      expect(r.items[0].lineTotal, 128000);
      expect(r.items[1].rawText, 'Bakso');
      expect(r.total, 261000, reason: 'the written total is what the paper says, not ours to edit');
    });
  });
}
