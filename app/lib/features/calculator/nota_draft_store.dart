import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'nota_calculator.dart';

/// Where an unfinished nota is kept between app launches.
///
/// An interface so the screen's tests can use memory instead of the device. The real one is
/// [PrefsNotaDraftStore]: a draft is a per-device convenience — which is exactly what
/// shared_preferences is for — and the SALE itself never depends on it, only on the order queue.
abstract class NotaDraftStore {
  Future<NotaDraft?> load();
  Future<void> save(NotaDraft draft);
  Future<void> clear();
}

/// Keyed per outlet, so a phone moved between outlets never offers one outlet's nota to another.
/// Logout clears all preferences, which also discards the draft — the next person at the till
/// should not inherit someone else's half-rung sale.
class PrefsNotaDraftStore implements NotaDraftStore {
  PrefsNotaDraftStore(String outletId) : _key = 'notaDraft:$outletId';

  final String _key;

  @override
  Future<NotaDraft?> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null) return null;
    try {
      return NotaDraft.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // A corrupt draft must never block the till: drop it and start clean.
      await p.remove(_key);
      return null;
    }
  }

  @override
  Future<void> save(NotaDraft draft) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(draft.toJson()));
  }

  @override
  Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_key);
  }
}

/// For tests and for a screen with no session yet: keeps the draft in memory only.
class MemoryNotaDraftStore implements NotaDraftStore {
  NotaDraft? draft;

  @override
  Future<NotaDraft?> load() async => draft;

  @override
  Future<void> save(NotaDraft d) async => draft = d;

  @override
  Future<void> clear() async => draft = null;
}
