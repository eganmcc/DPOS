import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import 'sync_queue.dart';

/// Drains the offline sale queue whenever the phone can reach the server again.
///
/// `SyncQueue.flush()` was written with the queue and then never called by anything — so a sale
/// taken in airplane mode sat in the local database for ever while the till told the cashier
/// "Tersimpan offline — akan tersinkron saat online" (Constitution V, specs/001 FR-020/FR-022).
/// This is the half that makes that sentence true.
///
/// Three triggers, because no single one is reliable on a phone behind a market stall:
///   * connectivity regained — the usual case, and immediate;
///   * app resumed — the cashier reopens the till in a spot with signal, and Android may not
///     report a connectivity change that happened while the process was backgrounded;
///   * a slow timer — a "connected" Wi-Fi that reaches no gateway reports no change at all.
///
/// Replay is safe at any moment: every queued order carries its original `clientOrderId` and the
/// server dedups on it, so a flush racing a live submit cannot record the same sale twice.
class SyncFlusher with WidgetsBindingObserver {
  SyncFlusher(this._queue, {Connectivity? connectivity, Duration? period})
      : _connectivity = connectivity ?? Connectivity(),
        _period = period ?? const Duration(minutes: 1);

  final OrderQueue _queue;
  final Connectivity _connectivity;
  final Duration _period;

  StreamSubscription<List<ConnectivityResult>>? _conn;
  Timer? _timer;
  bool _running = false;

  /// Pending sales waiting to go up, for the till's badge. Rebuilt after every pass.
  final ValueNotifier<int> pending = ValueNotifier<int>(0);

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _conn = _connectivity.onConnectivityChanged.listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) flush();
    });
    _timer = Timer.periodic(_period, (_) => flush());
    flush(); // anything left over from the last run
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _conn?.cancel();
    _timer?.cancel();
    pending.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) flush();
  }

  /// One drain pass. Overlapping calls are dropped rather than queued — three triggers can fire
  /// within a second of each other, and a second pass would only re-post what the first is
  /// already posting.
  Future<void> flush() async {
    if (_running) return;
    _running = true;
    try {
      await _queue.flush();
    } catch (_) {
      // Never surfaces: this runs in the background, with no screen to own the error. A failure
      // leaves the rows queued for the next pass, which is the whole point of the queue.
    } finally {
      _running = false;
      try {
        pending.value = await _queue.pendingCount();
      } catch (_) {
        // The count is a badge, not a fact worth crashing a background pass for.
      }
    }
  }
}

/// Session-lifetime flusher, started by the app root. Kept alive by `keepAlive` so a rebuild
/// never drops the observer and the timer.
final syncFlusherProvider = Provider<SyncFlusher>((ref) {
  final flusher = SyncFlusher(ref.watch(syncQueueProvider));
  ref.onDispose(flusher.dispose);
  return flusher;
});
