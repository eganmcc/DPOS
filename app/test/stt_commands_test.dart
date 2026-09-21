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

    test('a bare "selesai" IS the instruction, because the recognizer splits the phrase', () {
      // From the device on 20 Sep: "pesanan selesai" arrived as two results, neither of which
      // matched the two-word phrase — so the run did not stop and "selesai" was staged as an item.
      expect(readStopPhrase('selesai').stop, true);
      expect(readStopPhrase('selesai').text, '');
      expect(readStopPhrase('sudah selesai').stop, true);
    });

    test('but an ordinary word on its own is not', () {
      expect(readStopPhrase('pesanan').stop, false, reason: 'no "selesai", no instruction');
      expect(readStopPhrase('nasi goreng selesai').stop, false,
          reason: 'an item is named, so this is an order — not a bare command');
    });
  });

  group('a phrase split across two results', () {
    test('the leading half does not stick to the item name', () {
      expect(stripTrailingCommandWords('air mineral tiga pesanan'), 'air mineral tiga');
      expect(stripTrailingCommandWords('nasi goreng dua pesanan sudah'), 'nasi goreng dua');
    });

    test('an ordinary line is left exactly as it was', () {
      expect(stripTrailingCommandWords('Air Mineral 3'), 'Air Mineral 3',
          reason: 'untouched, punctuation and capitals and all');
    });

    test('a line that is nothing but the command is recognised as one', () {
      expect(isStopCommand('selesai'), true);
      expect(isStopCommand('Pesanan, selesai'), true);
      expect(isStopCommand('air mineral'), false);
      expect(isStopCommand(''), false);
    });
  });
}
