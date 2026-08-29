import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---- Locale (default Indonesian) ----
class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('id')) {
    _load();
  }
  static const _key = 'locale';

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final code = p.getString(_key);
    if (code != null) state = Locale(code);
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, locale.languageCode);
  }

  Future<void> toggle() => setLocale(state.languageCode == 'id' ? const Locale('en') : const Locale('id'));
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) => LocaleNotifier());

// ---- Theme mode (default system) ----
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _load();
  }
  static const _key = 'themeMode';

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    switch (p.getString(_key)) {
      case 'light':
        state = ThemeMode.light;
      case 'dark':
        state = ThemeMode.dark;
      case 'system':
        state = ThemeMode.system;
    }
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, mode.name);
  }

  /// Cycle light → dark (used by the AppBar toggle).
  Future<void> toggle(Brightness current) =>
      set(current == Brightness.dark ? ThemeMode.light : ThemeMode.dark);
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) => ThemeModeNotifier());

/// Barcode-scanner POS mode (grocery). 'auto' = on only when a DPOSP printer is
/// paired; 'on'/'off' force it. Persisted so it survives restarts.
class ScannerModeNotifier extends StateNotifier<String> {
  ScannerModeNotifier() : super('auto') {
    _load();
  }
  static const _key = 'scannerMode';

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final v = p.getString(_key);
    if (v == 'auto' || v == 'on' || v == 'off') state = v!;
  }

  Future<void> set(String mode) async {
    state = mode;
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, mode);
  }
}

final scannerModeSettingProvider =
    StateNotifierProvider<ScannerModeNotifier, String>((ref) => ScannerModeNotifier());

/// Demo generator for F&B online-delivery orders. When on (default), a logged-in
/// F&B cashier session fabricates a random GoFood/GrabFood/ShopeeFood order every
/// 2–5 minutes. Off disables the simulation (real orders would still arrive).
class OnlineDemoNotifier extends StateNotifier<bool> {
  OnlineDemoNotifier() : super(true) {
    _load();
  }
  static const _key = 'onlineDemo';

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final v = p.getBool(_key);
    if (v != null) state = v;
  }

  Future<void> set(bool on) async {
    state = on;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_key, on);
  }
}

final onlineDemoSettingProvider =
    StateNotifierProvider<OnlineDemoNotifier, bool>((ref) => OnlineDemoNotifier());
