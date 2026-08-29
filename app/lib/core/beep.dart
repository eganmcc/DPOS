import 'package:audioplayers/audioplayers.dart';

// Reused low-latency player for the scanner "beep" on a successful scan/add.
final AudioPlayer _beepPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.stop);

Future<void> beep() async {
  try {
    await _beepPlayer.stop();
    await _beepPlayer.play(AssetSource('sounds/beep.wav'), volume: 1.0);
  } catch (_) {
    /* no audio available */
  }
}
