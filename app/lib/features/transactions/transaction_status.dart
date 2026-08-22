import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';

/// First 8 chars of the order UUID — what the receipt and the history list both show.
String shortOrderId(String id) => id.length <= 8 ? id : id.substring(0, 8);

/// Localized label for a DERIVED effective status (the app never computes it itself).
String statusLabel(BuildContext context, String status) {
  final t = AppLocalizations.of(context)!;
  switch (status) {
    case 'VOIDED':
      return t.statusVoided;
    case 'REFUNDED':
      return t.statusRefunded;
    case 'COMPLETED':
      return t.statusCompleted;
    default:
      return status;
  }
}

/// Pill showing the effective status: green for a live sale, red once it is voided/refunded.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status, this.dense = false});
  final String status;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = brandColors(context);
    final reversed = status == 'VOIDED' || status == 'REFUNDED';
    final bg = reversed ? cs.errorContainer : ext.successContainer;
    final fg = reversed ? cs.onErrorContainer : ext.onSuccessContainer;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 12, vertical: dense ? 3 : 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)),
      child: Text(
        statusLabel(context, status),
        style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: dense ? 11 : 12),
      ),
    );
  }
}
