/// What a listen session produces, and the rules that stop it losing words — pure Dart.
///
/// No Flutter import on purpose (the convention of `features/calculator/nota_calculator.dart`):
/// these rules were paid for with real-device debugging in `stt_id_tester`, and the only way to
/// keep them honest is to test them without a microphone.
///
/// Three behaviours matter, none of them obvious from the plugin's documentation:
///
///  1. **The recognizer can silently reset its buffer mid-sentence.** `onResult` arrives with the
///     words shrinking back toward "" and NO final/status/error to announce it. Overwriting blindly
///     loses everything said so far, with nothing on screen to show it happened.
///  2. **A genuine final can arrive late**, after a status callback already flushed the same text —
///     so the same sentence lands twice.
///  3. **A session can end four different ways** (final result, status done/notListening, error, or
///     the user tapping stop) and it is not guaranteed which fires, or that only one does. So the
///     commit must be idempotent and called from all four.
///  4. **Words arrive after the session that produced them has ended.** The device log for 20 Sep
///     shows three result callbacks landing 20-180 ms AFTER "Stop listening", with the next session
///     starting 300 ms later. Anything still live at that point belongs to the session just gone,
///     so a new session commits before it clears — an item vanished without trace this way.
library;

/// One finished utterance.
class SttResult {
  final String text;
  final double? confidence;
  final DateTime at;

  /// How long this utterance took, from the start of the session that produced it.
  final Duration? spoken;

  const SttResult({required this.text, this.confidence, required this.at, this.spoken});
}

/// Accumulates one listening session's partials and commits finished utterances.
///
/// Deliberately mutable: it models a stream of callbacks arriving over time, and the lab screen
/// reads counters off it between events. [clock] is injected so tests control time.
class SttTranscript {
  SttTranscript({
    DateTime Function()? clock,
    this.dedupeWindow = const Duration(seconds: 5),
  }) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  /// How long after committing a text the same text is treated as the late duplicate of it.
  final Duration dedupeWindow;

  /// Finished utterances, newest first.
  final List<SttResult> results = [];

  /// The partial being spoken right now.
  String live = '';
  double? liveConfidence;

  String? _lastCommittedText;
  DateTime? _lastCommittedAt;

  DateTime? _sessionStartedAt;
  DateTime? _firstPartialAt;

  /// How many times the recognizer threw its buffer away mid-sentence and we caught it (bug 1).
  int bufferResets = 0;

  /// How many late duplicate finals were suppressed (bug 2).
  int duplicatesSuppressed = 0;

  /// Time from `listen()` to the first partial of the current session — the number that says
  /// whether the recognizer is responding at all, as distinct from mishearing.
  Duration? get timeToFirstPartial => (_sessionStartedAt == null || _firstPartialAt == null)
      ? null
      : _firstPartialAt!.difference(_sessionStartedAt!);

  bool get hasLive => live.trim().isNotEmpty;

  /// Words that arrived after their session had already ended, and were carried over rather than
  /// thrown away (bug 4).
  int lateResults = 0;

  /// A NEW run, started by a person: the mic button was tapped, or the order sheet was opened.
  ///
  /// Forgets what was last committed, so the duplicate window cannot swallow it. Saying "air
  /// mineral tiga", stopping, and saying it again is a cashier adding an item — not the late final
  /// of the previous one, which is the only thing the window exists to catch. An automatic restart
  /// inside a continuous run deliberately does NOT call this: there the stragglers are real.
  void beginRun() {
    _lastCommittedText = null;
    _lastCommittedAt = null;
  }

  void startSession() {
    // Results keep arriving AFTER a session ends — the recognizer's last words land while the
    // next session is already being asked for. Whatever is still live belongs to the session that
    // just finished, and clearing it without committing loses it with no trace anywhere: not in
    // the results, not in a counter, not in the log. Commit FIRST, then reset.
    if (hasLive) {
      lateResults++;
      commit();
    }
    _sessionStartedAt = _clock();
    _firstPartialAt = null;
    live = '';
    liveConfidence = null;
  }

  /// A result from the recognizer — partial or final.
  void onResult(String text, double? confidence, {required bool isFinal}) {
    final incoming = text.trim();
    final previous = live.trim();
    _firstPartialAt ??= _clock();

    // Bug 1: the incoming text no longer continues what we had, so the recognizer started over.
    // Commit what was said before letting the overwrite below discard it.
    if (previous.isNotEmpty &&
        incoming != previous &&
        !incoming.toLowerCase().startsWith(previous.toLowerCase())) {
      bufferResets++;
      commit();
    }

    live = text;
    liveConfidence = confidence;
    if (isFinal) commit();
  }

  /// Commit whatever is live. Idempotent — safe to call from every exit path (bug 3), and it is
  /// exactly that defensiveness that fixed the dropped words on real hardware.
  void commit() {
    final text = live.trim();
    if (text.isEmpty) {
      live = '';
      liveConfidence = null;
      return;
    }
    final now = _clock();

    // Bug 2: the same text again, moments after we already kept it, is the late final of it —
    // and so is a FRAGMENT of it, because a straggling partial from the session just ended is a
    // prefix of what was already committed, not a second order for half the item.
    final isDuplicate = _lastCommittedText != null &&
        _lastCommittedAt != null &&
        now.difference(_lastCommittedAt!) < dedupeWindow &&
        _lastCommittedText!.toLowerCase().startsWith(text.toLowerCase());
    if (isDuplicate) {
      duplicatesSuppressed++;
    } else {
      results.insert(
        0,
        SttResult(
          text: text,
          confidence: liveConfidence,
          at: now,
          spoken: _sessionStartedAt == null ? null : now.difference(_sessionStartedAt!),
        ),
      );
      _lastCommittedText = text;
      _lastCommittedAt = now;
    }
    live = '';
    liveConfidence = null;
  }

  /// Clears the results but NOT the counters' meaning — they reset too, since a cleared board is a
  /// fresh measurement.
  void clear() {
    results.clear();
    live = '';
    liveConfidence = null;
    _lastCommittedText = null;
    _lastCommittedAt = null;
    bufferResets = 0;
    duplicatesSuppressed = 0;
    lateResults = 0;
  }
}
