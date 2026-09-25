import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dpos/data/sync_flusher.dart';
import 'package:dpos/data/sync_queue.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// A queue that records how often it was drained, and can be held mid-pass.
class _FakeQueue implements OrderQueue {
  int flushCalls = 0;
  int pending = 0;
  Completer<void>? hold;

  @override
  Future<int> flush() async {
    flushCalls++;
    if (hold != null) await hold!.future;
    final drained = pending;
    pending = 0;
    return drained;
  }

  @override
  Future<int> pendingCount() async => pending;
}

/// Drives the connectivity stream by hand — no platform channel, no real radio.
class _FakeConnectivity implements Connectivity {
  final _controller = StreamController<List<ConnectivityResult>>.broadcast();

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => _controller.stream;

  void emit(List<ConnectivityResult> results) => _controller.add(results);

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => [ConnectivityResult.wifi];

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeQueue queue;
  late _FakeConnectivity conn;
  late SyncFlusher flusher;

  setUp(() {
    queue = _FakeQueue();
    conn = _FakeConnectivity();
    flusher = SyncFlusher(queue, connectivity: conn, period: const Duration(hours: 1));
  });

  tearDown(() => flusher.dispose());

  test('drains once at start, so a queue left over from last run goes up', () async {
    queue.pending = 2;
    flusher.start();
    await pumpEventQueue();
    expect(queue.flushCalls, 1);
    expect(flusher.pending.value, 0);
  });

  test('drains when connectivity comes back', () async {
    flusher.start();
    await pumpEventQueue();
    final atStart = queue.flushCalls;

    conn.emit([ConnectivityResult.mobile]);
    await pumpEventQueue();

    expect(queue.flushCalls, atStart + 1);
  });

  test('does NOT drain on a connectivity event that reports no connection', () async {
    flusher.start();
    await pumpEventQueue();
    final atStart = queue.flushCalls;

    conn.emit([ConnectivityResult.none]);
    await pumpEventQueue();

    expect(queue.flushCalls, atStart);
  });

  test('drains when the app is resumed', () async {
    flusher.start();
    await pumpEventQueue();
    final atStart = queue.flushCalls;

    flusher.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await pumpEventQueue();

    expect(queue.flushCalls, atStart + 1);
  });

  test('overlapping triggers do not start a second pass', () async {
    // Three triggers can land within a second of each other; a second pass would only re-post
    // what the first is already posting.
    queue.hold = Completer<void>();
    flusher.start();
    await pumpEventQueue();
    expect(queue.flushCalls, 1);

    conn.emit([ConnectivityResult.wifi]);
    flusher.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await pumpEventQueue();
    expect(queue.flushCalls, 1, reason: 'still inside the first pass');

    queue.hold!.complete();
    await pumpEventQueue();

    conn.emit([ConnectivityResult.wifi]);
    await pumpEventQueue();
    expect(queue.flushCalls, 2, reason: 'the pass finished, so the next trigger runs');
  });

  test('a throwing pass is swallowed and the flusher keeps working', () async {
    final throwing = _ThrowingQueue();
    final f = SyncFlusher(throwing, connectivity: conn, period: const Duration(hours: 1));
    addTearDown(f.dispose);

    f.start();
    await pumpEventQueue();

    conn.emit([ConnectivityResult.wifi]);
    await pumpEventQueue();

    expect(throwing.flushCalls, 2, reason: 'a failed pass must not kill the drainer');
  });

  test('the badge count follows the queue', () async {
    queue.pending = 3;
    flusher.start();
    await pumpEventQueue();
    expect(flusher.pending.value, 0);

    queue.pending = 5;
    await flusher.flush();
    expect(flusher.pending.value, 0);
  });
}

class _ThrowingQueue implements OrderQueue {
  int flushCalls = 0;

  @override
  Future<int> flush() async {
    flushCalls++;
    throw Exception('server on fire');
  }

  @override
  Future<int> pendingCount() async => 1;
}

