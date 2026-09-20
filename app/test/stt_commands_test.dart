import 'package:dpos/features/stt/stt_commands.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stopping the till by voice: the order survives, the instruction does not.
void main() {
  group('the stop phrase', () {
    test('on its own, it stops and leaves nothing to record', () {
      final r = readStopPhrase('pesanan selesai');
      expect(r.stop, true);
      expect(r.text, '');
    });

    test('after an order, the order is kept and the instruction removed', () {
      final r = readStopPhrase('ayam bakar dua pesanan selesai');
      expect(r.stop, true);
      expect(r.text, 'ayam bakar dua',
          reason: 'the item must not end up named "ayam bakar dua pesanan selesai"');
    });

    test('however the recognizer capitalised or punctuated it', () {
      expect(readStopPhrase('Pesanan Selesai').stop, true);
      expect(readStopPhrase('nasi goreng 1, pesanan, selesai').stop, true);
      expect(readStopPhrase('nasi goreng 1, pesanan, selesai').text, 'nasi goreng 1,');
    });

    test('the longer and the English-ish forms work too', () {
      expect(readStopPhrase('pesanan sudah selesai').stop, true);
      expect(readStopPhrase('order selesai').stop, true);
    });

    test('an ordinary order does not stop anything', () {
      final r = readStopPhrase('nasi goreng dua es teh manis satu');
      expect(r.stop, false);
      expect(r.text, 'nasi goreng dua es teh manis satu');
    });

    test('half the phrase is not the phrase', () {
      // A single stray word must never end a run — a cashier saying "selesai" to a customer is
      // not talking to the till.
      expect(readStopPhrase('selesai').stop, false);
      expect(readStopPhrase('pesanan').stop, false);
    });
  });
}
