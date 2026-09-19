import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The "Nota #N" pill: which nota of the day this is, on this device.
///
/// DISPLAY ONLY. It is never sent to the server and is never an order's identity — the order's id
/// and `clientOrderId` are. Two phones at one kiosk, a reinstall, or a logout (which clears
/// preferences) will all repeat numbers, which is fine for "how many have I done today" and wrong
/// for anything a customer might quote back. A real per-outlet sequence would be a server counter.
///
/// It resets at local midnight and advances only when a nota is FINISHED (paid, or queued offline).
/// Opening the screen or cancelling a nota never moves it — a cancelled nota is not a nota.
class NotaCounterNotifier extends StateNotifier<int> {
  NotaCounterNotifier({DateTime Function()? clock})
      : _clock = clock ?? DateTime.now,
        super(1) {
    _load();
  }

  final DateTime Function() _clock;
  static const _dateKey = 'notaCounterDate';
  static const _doneKey = 'notaCounterDone';

  String get _today {
    final d = _clock();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final done = p.getString(_dateKey) == _today ? (p.getInt(_doneKey) ?? 0) : 0;
    if (mounted) state = done + 1;
  }

  /// Call once a nota is finished. Re-reads the stored day first, so a kiosk left open across
  /// midnight starts the new day at #1 instead of carrying yesterday's count.
  Future<void> finished() async {
    final p = await SharedPreferences.getInstance();
    final today = _today;
    final done = p.getString(_dateKey) == today ? (p.getInt(_doneKey) ?? 0) : 0;
    await p.setString(_dateKey, today);
    await p.setInt(_doneKey, done + 1);
    if (mounted) state = done + 2;
  }
}

final notaCounterProvider =
    StateNotifierProvider<NotaCounterNotifier, int>((ref) => NotaCounterNotifier());
