import 'package:dpos/features/stt/stt_transcript.dart';
import 'package:flutter_test/flutter_test.dart';

/// The three speech-recognition behaviours that only show up on real hardware, pinned here so a
/// later tidy-up cannot quietly undo them. Every case is named for the failure it prevents.
void main() {
  late DateTime now;
  SttTranscript make() => SttTranscript(clock: () => now);

  setUp(() => now = DateTime(2026, 9, 20, 10, 0, 0));

  group('a partial that keeps growing', () {
    test('overwrites the live text and commits nothing until the final', () {
      final t = make();
      t.startSession();
      t.onResult('buncis', null, isFinal: false);
      t.onResult('buncis dua', null, isFinal: false);
      expect(t.live, 'buncis dua');
      expect(t.results, isEmpty);

      t.onResult('buncis dua puluh', 0.9, isFinal: true);
      expect(t.results.single.text, 'buncis dua puluh');
      expect(t.results.single.confidence, 0.9);
      expect(t.live, isEmpty);
      expect(t.bufferResets, 0);
    });

    test('is not confused by a change of case', () {
      final t = make();
      t.startSession();
      t.onResult('Nasi', null, isFinal: false);
      t.onResult('nasi goreng', null, isFinal: false);
      expect(t.bufferResets, 0, reason: 'same words, different case, is not a reset');
      expect(t.results, isEmpty);
    });
  });

  group('the recognizer throwing its buffer away mid-sentence', () {
    test('keeps the words already heard instead of letting them vanish', () {
      // The real bug: "buncis 20" then a partial back to "" with no final, no status, no error.
      final t = make();
      t.startSession();
      t.onResult('buncis 20', null, isFinal: false);
      t.onResult('', null, isFinal: false);

      expect(t.results.single.text, 'buncis 20');
      expect(t.bufferResets, 1);
      expect(t.live, isEmpty);
    });

    test('also catches a reset that starts different words rather than emptying', () {
      final t = make();
      t.startSession();
      t.onResult('tomat lima', null, isFinal: false);
      t.onResult('bawang', null, isFinal: false);

      expect(t.results.single.text, 'tomat lima');
      expect(t.bufferResets, 1);
      expect(t.live, 'bawang', reason: 'the new sentence carries on live');
    });
  });

  group('a final that arrives late, after a status flush', () {
    test('is not recorded twice', () {
      final t = make();
      t.startSession();
      t.onResult('dua puluh lima ribu', 0.8, isFinal: false);
      t.commit(); // the onStatus('done') safety net

      now = now.add(const Duration(milliseconds: 400));
      t.onResult('dua puluh lima ribu', 0.8, isFinal: true); // the late genuine final

      expect(t.results, hasLength(1));
      expect(t.duplicatesSuppressed, 1);
    });

    test('but the same sentence said again later IS a second result', () {
      final t = make();
      t.startSession();
      t.onResult('satu', null, isFinal: true);

      now = now.add(const Duration(seconds: 6)); // beyond the dedupe window
      t.onResult('satu', null, isFinal: true);

      expect(t.results, hasLength(2));
      expect(t.duplicatesSuppressed, 0);
    });
  });

  group('every way a session can end', () {
    // final result / status done / error / the user tapping stop — the caller flushes from all
    // four, so the flush must be idempotent.
    test('commit is safe to call repeatedly and keeps one result', () {
      final t = make();
      t.startSession();
      t.onResult('halo', null, isFinal: false);
      t.commit();
      t.commit();
      t.commit();
      expect(t.results, hasLength(1));
      expect(t.duplicatesSuppressed, 0, reason: 'an empty live text is a no-op, not a duplicate');
    });

    test('committing nothing records nothing', () {
      final t = make();
      t.startSession();
      t.commit();
      t.onResult('   ', null, isFinal: true);
      expect(t.results, isEmpty);
    });
  });

  test('records how long the utterance took and when it landed', () {
    final t = make();
    t.startSession();
    now = now.add(const Duration(milliseconds: 900));
    t.onResult('tiga ribu', 0.7, isFinal: true);

    expect(t.results.single.spoken, const Duration(milliseconds: 900));
    expect(t.results.single.at, now);
  });

  test('time to first partial is the gap between listening and the first word', () {
    final t = make();
    t.startSession();
    expect(t.timeToFirstPartial, isNull);
    now = now.add(const Duration(milliseconds: 650));
    t.onResult('a', null, isFinal: false);
    expect(t.timeToFirstPartial, const Duration(milliseconds: 650));
  });

  test('clearing resets the board and the counters', () {
    final t = make();
    t.startSession();
    t.onResult('satu dua', null, isFinal: false);
    t.onResult('', null, isFinal: false);
    expect(t.results, isNotEmpty);
    expect(t.bufferResets, 1);

    t.clear();
    expect(t.results, isEmpty);
    expect(t.bufferResets, 0);
    expect(t.duplicatesSuppressed, 0);
  });
}
