import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../data/api_client.dart';
import '../data/models.dart';
import '../data/providers.dart';
import '../data/session.dart';
import '../l10n/app_localizations.dart';

/// Shared correction actions — the reason dialog, the approver-PIN gate, and the
/// whole void flow. Mirrors `core/attendance_actions.dart`: an action that owns its
/// own dialogs and swallows its own errors, so a caller is one `await` away.
///
/// Lives here because three screens need the PIN gate (transaction detail's void and
/// refund, and open bills' cancel) and two need the void flow itself.

/// Whether this correction must be authorized with a manager/owner PIN.
///
/// False for an OWNER/MANAGER (they self-authorize) and false at a UMI merchant,
/// which is one person — there is nobody else to approve. UI ONLY: the server makes
/// the same decision from the database, so a stale catalog costs at most one
/// redundant dialog, never a wrongly-skipped one.
bool needsApproverPin(WidgetRef ref) {
  final session = ref.read(sessionProvider);
  if (session == null || session.isOwnerOrManager) return false;
  final isUmi = ref.read(catalogProvider(session.outletId)).valueOrNull?.isUmi ?? false;
  return !isUmi;
}

/// Ask a manager/owner to authorize a cashier-initiated correction with their PIN.
Future<String?> askApproverPin(BuildContext context) {
  final t = AppLocalizations.of(context)!;
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(t.managerApprovalTitle),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        obscureText: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: t.managerPinLabel, isDense: true),
        onSubmitted: (_) => Navigator.of(ctx).pop(ctrl.text.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(t.actionCancel)),
        FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()), child: Text(t.actionOk)),
      ],
    ),
  );
}

/// Void a sale end to end: reason (mandatory), approver PIN when one is needed, the
/// call, provider invalidation and the result message. Returns true if it voided.
///
/// The reason is never optional — not even for UMI. It IS the audit record.
Future<bool> voidOrderFlow(
  BuildContext context,
  WidgetRef ref,
  OrderResult order, {
  String? clientVoidId,
}) async {
  final t = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);

  final reason = await showDialog<String?>(
    context: context,
    builder: (_) => const VoidReasonDialog(),
  );
  if (reason == null || reason.isEmpty || !context.mounted) return false;

  String? approverPin;
  if (needsApproverPin(ref)) {
    approverPin = await askApproverPin(context);
    if (approverPin == null || approverPin.isEmpty || !context.mounted) return false;
  }

  try {
    final json = await ref.read(apiClientProvider).voidOrder(
          order.id,
          clientVoidId: clientVoidId ?? const Uuid().v4(),
          reason: reason,
          approverPin: approverPin,
        );
    final voided = OrderResult.fromJson(json);
    ref.invalidate(transactionDetailProvider(order.id));
    final outletId = ref.read(sessionProvider)?.outletId;
    if (outletId != null) {
      ref.invalidate(transactionsProvider(outletId));
      ref.invalidate(catalogProvider(outletId)); // stock came back
    }
    messenger.showSnackBar(
      SnackBar(content: Text(voided.isVoided ? t.voidSuccess : t.voidFailed)),
    );
    return voided.isVoided;
  } on DioException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(voidErrorMessage(t, e))));
    return false;
  }
}

/// Map a correction failure to a message. `APPROVAL_REQUIRED` stays handled even
/// though UMI should never see it — a stale catalog could still skip a prompt the
/// server wants, and the user deserves the real reason rather than a generic failure.
String voidErrorMessage(AppLocalizations t, DioException e) {
  final serverCode = e.response?.data is Map ? e.response?.data['code'] : null;
  switch (serverCode) {
    case 'VOID_WINDOW_EXPIRED':
      return t.voidWindowExpired;
    case 'APPROVAL_INVALID':
      return t.approvalInvalid;
    case 'APPROVAL_REQUIRED':
      return t.approvalRequired;
  }
  return e.response?.statusCode == 403 ? t.voidForbidden : t.voidFailed;
}

/// Void confirmation: quick-pick chips + free text. Confirm stays disabled until a
/// reason is present — the server refuses a void without one, and so does this.
class VoidReasonDialog extends StatefulWidget {
  const VoidReasonDialog({super.key});

  @override
  State<VoidReasonDialog> createState() => _VoidReasonDialogState();
}

class _VoidReasonDialogState extends State<VoidReasonDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final presets = [
      t.voidReasonWrongItem,
      t.voidReasonWrongPrice,
      t.voidReasonCustomerCancel,
      t.voidReasonTest,
    ];
    final valid = _reason.text.trim().isNotEmpty;
    return AlertDialog(
      title: Text(t.voidConfirmTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.voidConfirmBody),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final p in presets)
                ActionChip(
                  label: Text(p),
                  onPressed: () => setState(() {
                    _reason.text = p;
                    _reason.selection = TextSelection.collapsed(offset: p.length);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _reason,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: '${t.voidReasonLabel} *', isDense: true),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.actionCancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: cs.error, foregroundColor: cs.onError),
          onPressed: valid ? () => Navigator.of(context).pop(_reason.text.trim()) : null,
          child: Text(t.actionVoidConfirm),
        ),
      ],
    );
  }
}
