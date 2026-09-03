import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/api_client.dart';
import '../data/providers.dart';
import '../data/session.dart';
import '../l10n/app_localizations.dart';

/// After login, offer to clock in (unless already on the clock). Fire-and-forget;
/// never blocks the app if attendance is unreachable.
Future<void> promptClockInOnLogin(BuildContext context, WidgetRef ref) async {
  try {
    final api = ref.read(apiClientProvider);
    final me = await api.getMyAttendance();
    if (me != null) return; // already clocked in
    if (!context.mounted) return;
    final t = AppLocalizations.of(context)!;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.clockInPromptTitle),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(t.actionLater)),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true), child: Text(t.attendanceClockIn)),
        ],
      ),
    );
    if (yes == true) {
      final outletId = ref.read(sessionProvider)?.outletId;
      await api.clockIn(outletId);
      ref.invalidate(myAttendanceProvider);
    }
  } catch (_) {
    // Attendance is a convenience; don't block the session on its failure.
  }
}

/// On logout, if the user is still on the clock, offer to clock out first. Returns
/// true when the user was logged out, false when they cancelled (stay logged in).
Future<bool> promptClockOutThenLogout(BuildContext context, WidgetRef ref) async {
  final api = ref.read(apiClientProvider);
  Map<String, dynamic>? me;
  try {
    me = await api.getMyAttendance();
  } catch (_) {}

  if (me != null && context.mounted) {
    final t = AppLocalizations.of(context)!;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.clockOutPromptTitle),
        content: Text(t.clockOutPromptBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(t.actionCancel)),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop('logout'), child: Text(t.actionLogoutOnly)),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop('both'),
              child: Text(t.actionClockOutAndLogout)),
        ],
      ),
    );
    if (choice == null) return false; // cancelled — stay logged in
    if (choice == 'both') {
      try {
        await api.clockOut();
      } catch (_) {}
    }
  }
  await ref.read(sessionProvider.notifier).logout();
  return true;
}
