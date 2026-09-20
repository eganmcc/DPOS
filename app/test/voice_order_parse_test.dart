import 'package:dpos/features/stt/voice_order_parse.dart';
import 'package:flutter_test/flutter_test.dart';

/// What a customer gets charged, from what a cashier said. Tested without a microphone.
void main() {
  group('how a price was said', () {
    test('a bare number is thousands, the way a warung says it', () {
      expect(spokenPrice(100), 100000, reason: '"Pecel lele 100" is a hundred thousand');
      expect(spokenPrice(25), 25000);
    });

    test('a number said in full is not multiplied again', () {
      expect(spokenPrice(100000), 100000, reason: '"seratus ribu" already IS the amount');
      expect(spokenPrice(25000), 25000);
    });

    test('a misheard number cannot exceed what the server would accept', () {
      expect(spokenPrice(999999999999), kMaxSpokenPrice);
    });
  });

  group('reading a spoken bill', () {
    test('the phrase from the plan', () {
      expect(parsePricedLines('Pecel lele 100'), [
        const PricedLine(label: 'pecel lele', qty: 1, price: 100000),
      ]);
    });

    test('a number before the name is how many, not how much', () {
      final lines = parsePricedLines('dua pecel lele 100');
      expect(lines.single.qty, 2);
      expect(lines.single.price, 100000);
      expect(lines.single.total, 200000);
    });

    test('several items in one breath', () {
      expect(parsePricedLines('pecel lele 100 es teh 5'), [
        const PricedLine(label: 'pecel lele', qty: 1, price: 100000),
        const PricedLine(label: 'es teh', qty: 1, price: 5000),
      ]);
    });

    test('spelled-out numbers work the same', () {
      final lines = parsePricedLines('nasi goreng dua puluh lima ribu');
      expect(lines.single.label, 'nasi goreng');
      expect(lines.single.price, 25000, reason: 'said in full, so taken as spoken');
    });

    test('an item with no price is kept and marked, never dropped', () {
      final lines = parsePricedLines('pecel lele');
      expect(lines.single.label, 'pecel lele');
      expect(lines.single.isIncomplete, true);
    });

    test('a trailing item whose price never arrived is also kept', () {
      final lines = parsePricedLines('pecel lele 100 es teh');
      expect(lines.length, 2);
      expect(lines[1].label, 'es teh');
      expect(lines[1].isIncomplete, true, reason: 'the cashier can see what to say again');
    });

    test('a complete line is not incomplete', () {
      expect(parsePricedLines('ayam bakar 32').single.isIncomplete, false);
    });

    test('silence parses to nothing at all', () {
      expect(parsePricedLines('   '), isEmpty);
    });
  });
}
