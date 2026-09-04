import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'theme.dart';

/// Visual tone of an [AppDialog]. Drives the icon, accent colour and default title.
enum AppDialogKind { info, success, warning, error }

/// Show a branded modal dialog. Pushed on the root navigator (default), so it
/// floats above bottom sheets and other overlays — unlike a SnackBar, which the
/// cart sheet hides.
///
/// Reusable for errors, info, success, and simple confirmations. Returns true
/// when confirmed/acknowledged, false when dismissed or cancelled. Pass
/// [cancelLabel] to turn it into a two-button confirmation.
Future<bool> showAppDialog(
  BuildContext context, {
  required String message,
  String? title,
  AppDialogKind kind = AppDialogKind.info,
  String? confirmLabel,
  String? cancelLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => AppDialog(
      message: message,
      title: title,
      kind: kind,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
    ),
  );
  return result ?? false;
}

class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.message,
    this.title,
    this.kind = AppDialogKind.info,
    this.confirmLabel,
    this.cancelLabel,
  });

  final String message;
  final String? title;
  final AppDialogKind kind;
  final String? confirmLabel;
  final String? cancelLabel;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final ext = brandColors(context);

    final (IconData icon, Color accent, String defaultTitle) = switch (kind) {
      AppDialogKind.info => (Icons.info_outline, cs.primary, t.dialogTitleInfo),
      AppDialogKind.success => (Icons.check_circle_outline, ext.success, t.dialogTitleSuccess),
      AppDialogKind.warning => (Icons.warning_amber_rounded, kBrandGold, t.dialogTitleWarning),
      AppDialogKind.error => (Icons.error_outline, cs.error, t.dialogTitleError),
    };

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration:
                  BoxDecoration(color: accent.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(icon, color: accent, size: 30),
            ),
            const SizedBox(height: 16),
            Text(
              title ?? defaultTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14, height: 1.35),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (cancelLabel != null) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(cancelLabel!),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(confirmLabel ?? t.actionOk),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
