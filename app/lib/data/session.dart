import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Session {
  final String token;
  final String merchantId;
  final String role;
  final String outletId;
  final String? deviceId;
  const Session({
    required this.token,
    required this.merchantId,
    required this.role,
    required this.outletId,
    this.deviceId,
  });

  bool get isOwner => role == 'OWNER';
  bool get isManager => role == 'MANAGER';
  bool get isOwnerOrManager => isOwner || isManager;
}

class SessionNotifier extends StateNotifier<Session?> {
  SessionNotifier() : super(null) {
    _load();
  }

  static const _kToken = 'token';
  static const _kMerchant = 'merchantId';
  static const _kRole = 'role';
  static const _kOutlet = 'outletId';
  static const _kDevice = 'deviceId';

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final token = p.getString(_kToken);
    if (token == null) return;
    state = Session(
      token: token,
      merchantId: p.getString(_kMerchant) ?? '',
      role: p.getString(_kRole) ?? 'CASHIER',
      outletId: p.getString(_kOutlet) ?? '',
      deviceId: p.getString(_kDevice),
    );
  }

  Future<void> setSession(Session s) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kToken, s.token);
    await p.setString(_kMerchant, s.merchantId);
    await p.setString(_kRole, s.role);
    await p.setString(_kOutlet, s.outletId);
    if (s.deviceId != null) await p.setString(_kDevice, s.deviceId!);
    state = s;
  }

  Future<void> setOutlet(String outletId) async {
    if (state == null) return;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kOutlet, outletId);
    state = Session(
      token: state!.token,
      merchantId: state!.merchantId,
      role: state!.role,
      outletId: outletId,
      deviceId: state!.deviceId,
    );
  }

  Future<void> logout() async {
    final p = await SharedPreferences.getInstance();
    await p.clear();
    state = null;
  }
}

final sessionProvider = StateNotifierProvider<SessionNotifier, Session?>((ref) => SessionNotifier());

/// Set to true when an authenticated request comes back 401 (token expired or
/// revoked). The login screen reads it to explain why the user was signed out,
/// and clears it on a successful sign-in. It is *not* set by a manual logout.
final sessionExpiredProvider = StateProvider<bool>((ref) => false);
