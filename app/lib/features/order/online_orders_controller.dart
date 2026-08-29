import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/settings.dart';
import '../../core/tts.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import 'vendor_icon.dart';

/// Snapshot of the online-order queue for an outlet.
class OnlineOrdersState {
  final List<OrderResult> orders;
  final bool loading;
  const OnlineOrdersState({this.orders = const [], this.loading = true});

  /// NEW (not-yet-accepted) online orders — the red-badge count.
  int get unprocessedCount => orders.where((o) => o.isUnprocessed).length;
  bool get isEmpty => orders.isEmpty;
}

/// Owns the F&B online-order lifecycle for one outlet: polls the server, announces
/// each newly-arrived order via TTS, and (for the demo) injects a random order every
/// 2–5 minutes. Session-scoped — created when the F&B session mounts `HomeGate` and
/// disposed on logout, which cancels both timers.
class OnlineOrdersNotifier extends StateNotifier<OnlineOrdersState> {
  OnlineOrdersNotifier(this._ref, this._outletId) : super(const OnlineOrdersState()) {
    _refresh();
    _poll = Timer.periodic(const Duration(seconds: 15), (_) => _refresh());
    // React to the demo toggle flipping mid-session (schedules or stops the timer).
    _ref.listen<bool>(onlineDemoSettingProvider, (_, __) => _scheduleSim());
    _scheduleSim();
  }

  final Ref _ref;
  final String _outletId;
  final _rng = Random();
  final Set<String> _seen = {}; // order ids already announced (announce once)
  bool _firstLoad = true;
  Timer? _poll;
  Timer? _sim;

  Future<void> _refresh() async {
    try {
      final rows = await _ref.read(apiClientProvider).getOnlineOrders(_outletId);
      final orders = rows.map(OrderResult.fromJson).toList();
      // Announce NEW orders we haven't seen — but never on the first load (those
      // pre-date this session; only genuine arrivals should be spoken).
      final fresh = orders.where((o) => o.isUnprocessed && !_seen.contains(o.id)).toList();
      for (final o in orders) {
        _seen.add(o.id);
      }
      if (!_firstLoad) {
        for (final o in fresh) {
          announceOnlineOrder(o.externalOrderRef ?? o.id, vendorName(o.channel));
        }
      }
      _firstLoad = false;
      if (mounted) state = OnlineOrdersState(orders: orders, loading: false);
    } catch (_) {
      if (mounted) state = OnlineOrdersState(orders: state.orders, loading: false);
    }
  }

  /// Cashier acknowledges an order (Terima). Refreshes so the badge drops.
  Future<void> accept(String orderId) async {
    try {
      await _ref.read(apiClientProvider).acceptOnlineOrder(orderId);
    } catch (_) {
      /* transient — the next poll reconciles */
    }
    await _refresh();
  }

  /// Manual pull-to-refresh from the Pesanan screen.
  Future<void> refresh() => _refresh();

  /// (Re)arm the demo injector for a random 2–5 min interval, or stop it when the
  /// demo toggle is off.
  void _scheduleSim() {
    _sim?.cancel();
    _sim = null;
    if (!_ref.read(onlineDemoSettingProvider)) return;
    final secs = 120 + _rng.nextInt(181); // 120..300s
    _sim = Timer(Duration(seconds: secs), () async {
      _sim = null;
      try {
        await _ref.read(apiClientProvider).simulateOnlineOrder(_outletId);
        await _refresh(); // surface the new order (and its TTS) with minimal delay
      } catch (_) {
        /* ignore — try again next interval */
      }
      _scheduleSim();
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _sim?.cancel();
    super.dispose();
  }
}

/// Session-scoped online-order queue for an outlet. Watched by `HomeGate` (F&B) so
/// it lives for the whole login and is disposed — timers and all — on logout.
final onlineOrdersProvider = StateNotifierProvider.autoDispose
    .family<OnlineOrdersNotifier, OnlineOrdersState, String>(
  (ref, outletId) => OnlineOrdersNotifier(ref, outletId),
);
