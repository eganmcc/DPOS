import 'dart:async';

import 'stt_commands.dart';
import 'stt_engine.dart';
import 'stt_options.dart';
import 'stt_transcript.dart';

/// Running a listening session, with every guard the device made necessary — once, for every
/// surface that listens.
///
/// This exists because it was written twice. The tuning bench earned these rules on real hardware
/// over several days; the order sheet then got a simpler copy of them, and was promptly stuck with
/// its stop button showing while the microphone was shut, because the copy had no watchdog. A
/// second implementation of something this fiddly is a second set of the same bugs, arriving
/// later and on the surface that handles money.
///
/// What it owns, and why each one is here:
///
///  - **Intent versus reality.** `wantListening` is what the user asked for; `listening` is what a
///    session is doing. In continuous mode they differ constantly, between utterances.
///  - **The watchdog.** A session can die with no callback at all — Android refuses the start and
///    the plugin returns without arming anything. Polling `engine.isListening` is the only honest
///    answer to whether the microphone is open.
///  - **One ending per session.** Android routinely delivers an error AND a status for the same
///    silence.
///  - **Recovery.** A wedged recognizer is rebuilt; empty runs back off and eventually give up.
class SttRunner {
  SttRunner({
    required this.engine,
    required this.options,
    SttTranscript? transcript,
    this.restartDelay = const Duration(milliseconds: 300),
    this.watchdogPeriod = const Duration(seconds: 1),
    this.onChanged,
    this.onNote,
    this.onUtterance,
    this.onStopPhrase,
    DateTime Function()? clock,
  })  : transcript = transcript ?? SttTranscript(clock: clock);

  final SttEngine engine;
  final SttTranscript transcript;
  final Duration restartDelay;
  final Duration watchdogPeriod;

  /// Anything changed that a screen might draw.
  final void Function()? onChanged;

  /// A diagnostics line, for surfaces that show one.
  final void Function(String line)? onNote;

  /// Called for each utterance the transcript commits, however it was committed — the five
  /// endings all funnel through here, which is what stops a heard line from never being listed.
  final void Function(String utterance)? onUtterance;

  /// The cashier said the stop phrase.
  final void Function()? onStopPhrase;

  SttOptions options;

  bool ready = false;
  bool listening = false;
  bool wantListening = false;
  String status = '—';
  double level = 0;
  int restarts = 0;
  int emptyRuns = 0;

  List<SttLocale> locales = const [];

  Timer? _restartTimer;
  Timer? _watchdog;
  int _watchdogTicks = 0;
  bool _sawEngineListening = false;
  bool _heardThisSession = false;
  bool _reinitBeforeNextSession = false;
  bool _disposed = false;

  /// How many committed utterances have already been handed to [onUtterance].
  int _drained = 0;

  /// Errors meaning "this recognizer object is no good any more", as opposed to "nobody spoke".
  /// `error_no_match` and `error_speech_timeout` are deliberately absent: in a quiet shop they are
  /// the normal end of a session.
  static const Set<String> wedging = {
    'error_busy',
    'error_client',
    'error_server_disconnected',
    'error_too_many_requests',
  };

  /// Enough consecutive silent sessions to conclude the microphone is broken, not the shop quiet.
  static const int maxEmptyRuns = 12;

  /// Ticks allowed for the platform to report "listening" before we conclude it never started.
  static const int startGraceTicks = 2;

  /// The device's own Indonesian, whatever it calls it — `in_ID` on most Android builds.
  String? get indonesianLocale {
    for (final l in locales) {
      if (l.isIndonesian) return l.id;
    }
    return null;
  }

  /// An explicit choice wins; otherwise Indonesian; otherwise the device default, which is all
  /// that is left to try.
  SttOptions get listenOptions {
    final id = indonesianLocale;
    if (options.localeId != null || id == null) return options;
    return options.copyWith(localeId: id);
  }

  void _changed() {
    if (!_disposed) onChanged?.call();
  }

  void _note(String line) => onNote?.call(line);

  Future<void> init({bool restart = false}) async {
    if (!engine.isSupported) {
      status = 'unsupported';
      _changed();
      return;
    }
    final ok = await engine.initialize(
      options: options,
      restart: restart,
      onStatus: (s) {
        if (_disposed) return;
        _note('onStatus: $s');
        status = s;
        if (s == 'done' || s == 'notListening') _endOfSession();
        _changed();
        _maybeRestart();
      },
      onError: (f) {
        if (_disposed) return;
        _note('onError: ${f.code} permanent=${f.permanent}');
        _endOfSession();
        status = f.code;
        if (wedging.contains(f.code)) {
          _reinitBeforeNextSession = true;
          _note('${f.code} — the engine will be rebuilt before the next session');
        }
        // A permanent error will not fix itself by trying again — stop rather than spin.
        if (f.permanent) {
          wantListening = false;
          _note('permanent error — listening stopped');
        }
        _changed();
        _maybeRestart();
      },
    );
    final found = ok ? await engine.locales() : const <SttLocale>[];
    if (_disposed) return;
    ready = ok;
    locales = found;
    _note(restart ? 'initialize (restart) → $ok' : 'initialize → $ok');
    if (!ok) status = 'unavailable';
    _changed();
  }

  /// Begin listening because a person asked. Permission is the caller's business.
  Future<void> start() async {
    wantListening = true;
    restarts = 0;
    emptyRuns = 0;
    // A deliberate start: saying the same thing again now is a repeat on purpose, not the late
    // final of what came before.
    transcript.beginRun();
    _changed();
    await _listen();
  }

  /// Stop for good — the button, or the spoken phrase. One path, because they mean the same thing.
  Future<void> stop(String why) async {
    // Clear the intent BEFORE stopping: the stop produces a status callback, and in continuous
    // mode that callback would otherwise start the very session the user just ended.
    wantListening = false;
    _restartTimer?.cancel();
    _watchdog?.cancel();
    await engine.stop();
    if (_disposed) return;
    _note('stop ($why)');
    transcript.commit();
    _drain();
    listening = false;
    level = 0;
    status = 'stopped';
    _changed();
  }

  void dispose() {
    _disposed = true;
    _restartTimer?.cancel();
    _watchdog?.cancel();
    // Leaving a live recognizer behind would hold the microphone after the screen is gone.
    if (wantListening) engine.cancel();
  }

  /// One session ended, however it ended. Flush first — always — and only once.
  void _endOfSession() {
    if (!listening) return;
    _watchdog?.cancel();
    transcript.commit();
    _drain();
    listening = false;
    level = 0;
    if (!options.continuous) {
      wantListening = false;
      return;
    }
    // A stretch that heard nothing is normal in a quiet shop; a long run of them is a broken mic.
    // Measured from whether any result arrived, NOT from the live text — a final is already
    // committed by the time the status lands, so live is empty either way.
    emptyRuns = _heardThisSession ? 0 : emptyRuns + 1;
  }

  void _maybeRestart() {
    if (_disposed || !wantListening || !options.continuous) return;
    if (emptyRuns >= maxEmptyRuns) {
      wantListening = false;
      status = 'stopped';
      _note('stopped after $emptyRuns sessions with nothing heard');
      _changed();
      return;
    }
    _restartTimer?.cancel();
    // A beat before restarting: Android does not reliably accept a new session in the same frame
    // the old one ended. Sessions that keep coming back empty back off instead of hammering it.
    _restartTimer = Timer(restartDelay * (1 + emptyRuns.clamp(0, 5)), () {
      if (_disposed || !wantListening) return;
      restarts++;
      _note('restart #$restarts (continuous)');
      _listen();
    });
  }

  Future<void> _listen() async {
    if (_reinitBeforeNextSession) {
      _reinitBeforeNextSession = false;
      await init(restart: true);
      if (_disposed || !wantListening) return;
    }
    transcript.startSession();
    _drain(); // a straggler from the last session commits here
    _heardThisSession = false;
    listening = true;
    status = 'listening';
    _note('listen(locale=${listenOptions.localeId ?? "default"}, '
        'pauseFor=${options.pauseForSeconds}s, continuous=${options.continuous})');
    _changed();

    final started = await engine.listen(
      options: listenOptions,
      onResult: (text, confidence, isFinal) {
        if (_disposed) return;
        _heardThisSession = true;
        _note('onResult${isFinal ? " FINAL" : ""}: "$text"');
        // "ayam bakar dua pesanan selesai" is an order AND an instruction: keep the order, obey
        // the instruction.
        final cmd = readStopPhrase(text);
        transcript.onResult(cmd.text, confidence, isFinal: isFinal || cmd.stop);
        _drain();
        _changed();
        if (cmd.stop) {
          onStopPhrase?.call();
          stop('stop phrase');
        }
      },
      onSoundLevel: (l) {
        if (_disposed) return;
        level = l;
        _changed();
      },
    );
    if (_disposed) return;
    if (!started) {
      // A refusal we were told about. No callback follows, so the session ends here and now —
      // otherwise the button would promise to stop something that is not running.
      _note('listen() refused — session did not start');
      _endOfSession();
      if (!wantListening) status = 'stopped';
      _changed();
      _maybeRestart();
      return;
    }
    _armWatchdog();
  }

  /// Watch the ENGINE, because a session can die in silence: Android refuses the start, the plugin
  /// returns without arming anything, and no status or error ever arrives.
  void _armWatchdog() {
    _watchdog?.cancel();
    _watchdogTicks = 0;
    _sawEngineListening = false;
    _watchdog = Timer.periodic(watchdogPeriod, (timer) {
      if (_disposed || !listening) {
        timer.cancel();
        return;
      }
      _watchdogTicks++;
      if (engine.isListening) {
        if (!_sawEngineListening) _note('engine reports listening');
        _sawEngineListening = true;
        return;
      }
      if (!_sawEngineListening && _watchdogTicks < startGraceTicks) return;
      timer.cancel();
      _note(_sawEngineListening
          ? 'session ended without a callback — recovered by watchdog'
          : 'session never started (engine not listening) — recovered by watchdog');
      _endOfSession();
      if (!wantListening) status = 'stopped';
      _changed();
      _maybeRestart();
    });
  }

  /// Hand over every utterance committed since last time, oldest first.
  ///
  /// A DRAIN, not a callback: an utterance is committed by a final result, by the session's
  /// status, by an error, by the user stopping, and by the next session finding something left
  /// over. Listening to one of those five is how a line gets heard and never listed.
  void _drain() {
    if (onUtterance == null) {
      _drained = transcript.results.length;
      return;
    }
    // Newest first, so the ones not yet handed over are at the front.
    for (var i = transcript.results.length - _drained - 1; i >= 0; i--) {
      onUtterance!(transcript.results[i].text);
    }
    _drained = transcript.results.length;
  }
}
