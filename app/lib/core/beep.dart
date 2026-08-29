import 'package:audioplayers/audioplayers.dart';

// Low-latency SoundPool-backed player for the scanner beep. Preloaded so the
// FIRST beep isn't dropped to audio warm-up latency.
final AudioPlayer _beepPlayer = AudioPlayer();
bool _ready = false;

Future<void> _ensureReady() async {
  if (_ready) return;
  await _beepPlayer.setReleaseMode(ReleaseMode.stop);
  await _beepPlayer.setPlayerMode(PlayerMode.lowLatency);
  await _beepPlayer.setSource(AssetSource('sounds/beep.wav'));
  _ready = true;
}

/// Warm up the beep engine (call once when the scanner screen opens) so the
/// first scan beeps immediately.
Future<void> warmUpBeep() async {
  try {
    await _ensureReady();
  } catch (_) {}
}

Future<void> beep() async {
  try {
    await _ensureReady();
    await _beepPlayer.seek(Duration.zero);
    await _beepPlayer.resume();
  } catch (_) {
    // Fallback: play the source directly (covers modes where seek/resume is a no-op).
    try {
      await _beepPlayer.play(AssetSource('sounds/beep.wav'));
    } catch (_) {}
  }
}
