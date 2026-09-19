import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_dialog.dart';
import '../../core/formatters.dart';
import '../../core/money.dart';
import '../../core/order_math.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';

/// What the cashier chose in the payment dialog.
enum NotaPaymentAction {
  /// Took the cash — submit the nota with [NotaPaymentOutcome.tendered].
  finish,

  /// Closed the dialog to keep editing; nothing changes.
  back,

  /// Abandoned the whole nota, already confirmed inside the dialog.
  cancel,
}

class NotaPaymentOutcome {
  final NotaPaymentAction action;
  final int? tendered;
  const NotaPaymentOutcome(this.action, [this.tendered]);
}

/// Plus Jakarta Sans for the calculator only — not the app-wide theme (specs/008).
///
/// Extracted because dialogs are built under the ROOT navigator and do not inherit a subtree
/// `Theme`: the screen and every dialog it opens must each wrap themselves, or the payment dialog
/// silently reverts to the app font. The font files are bundled in `google_fonts/`, so this never
/// fetches at runtime — which matters on a phone behind a market stall with no signal.
Widget notaFontScope(BuildContext context, Widget child) {
  final base = Theme.of(context);
  return Theme(
    data: base.copyWith(textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme)),
    child: DefaultTextStyle.merge(style: GoogleFonts.plusJakartaSans(), child: child),
  );
}

// Light-mode tints from the design; dark mode falls back to scheme roles so the dialog stays legible.
const _kShortBgLight = Color(0xFFFBEAEA);
const _kShortFgLight = Color(0xFFB23B3B);

/// The Selesai dialog: amount received, and a live Kembalian / Kurang readout.
///
/// Change is computed against [preview.grandTotal] — the tax-inclusive total — never the plain sum
/// of amounts. They are equal today because a calculator merchant has no tax rule; the day one is
/// added, a readout driven by the sum would short-change the cashier on every sale, silently.
Future<NotaPaymentOutcome> showNotaPaymentDialog(
  BuildContext context, {
  required CartPreview preview,
}) async {
  final result = await showDialog<NotaPaymentOutcome>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => notaFontScope(ctx, _NotaPaymentDialog(preview: preview)),
  );
  return result ?? const NotaPaymentOutcome(NotaPaymentAction.back);
}

class _NotaPaymentDialog extends StatefulWidget {
  final CartPreview preview;
  const _NotaPaymentDialog({required this.preview});

  @override
  State<_NotaPaymentDialog> createState() => _NotaPaymentDialogState();
}

class _NotaPaymentDialogState extends State<_NotaPaymentDialog> {
  final _tender = TextEditingController();

  int get _total => widget.preview.grandTotal;
  int? get _tendered => int.tryParse(_tender.text.replaceAll(RegExp(r'[^0-9]'), ''));
  bool get _enough => (_tendered ?? 0) >= _total;

  @override
  void dispose() {
    _tender.dispose();
    super.dispose();
  }

  Future<void> _cancel() async {
    final t = AppLocalizations.of(context)!;
    final yes = await showAppDialog(
      context,
      kind: AppDialogKind.warning,
      title: t.calcCancelTitle,
      message: t.calcCancelBody,
      confirmLabel: t.calcCancelConfirm,
      cancelLabel: t.calcCancelKeep,
    );
    if (yes && mounted) {
      Navigator.of(context).pop(const NotaPaymentOutcome(NotaPaymentAction.cancel));
    }
  }

  /// Fills "Uang diterima" with the amount due, formatted exactly as if it had been typed.
  /// Uses the grand total — the tax-inclusive figure — for the same reason the change readout does.
  void _payExact() {
    setState(() {
      _tender.value = ThousandsTextInputFormatter()
          .formatEditUpdate(const TextEditingValue(), TextEditingValue(text: _total.toString()));
    });
  }

  void _finish() {
    if (!_enough) return;
    Navigator.of(context).pop(NotaPaymentOutcome(NotaPaymentAction.finish, _tendered));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final ext = brandColors(context);
    final light = Theme.of(context).brightness == Brightness.light;
    final tendered = _tendered;
    final diff = (tendered ?? 0) - _total;
    const tabular = [FontFeature.tabularFigures()];

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t.calcTotal,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.9,
                    color: cs.onSurfaceVariant)),
            const SizedBox(height: 2),
            Text(formatRupiah(_total),
                key: const ValueKey('nota-pay-total'),
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: cs.primary,
                    fontFeatures: tabular)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(t.calcAmountReceived,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.6,
                          color: cs.onSurfaceVariant)),
                ),
                // The commonest payment at a warung is the exact amount — one tap instead of
                // retyping the total the cashier is already looking at.
                ActionChip(
                  key: const ValueKey('nota-pay-exact'),
                  label: Text(t.tenderExact),
                  avatar: const Icon(Icons.payments_outlined, size: 16),
                  visualDensity: VisualDensity.compact,
                  onPressed: _payExact,
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              key: const ValueKey('nota-tender-field'),
              controller: _tender,
              autofocus: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              textInputAction: TextInputAction.done,
              inputFormatters: [ThousandsTextInputFormatter()],
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w700, fontFeatures: tabular),
              decoration: const InputDecoration(prefixText: 'Rp '),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _finish(),
            ),
            if (tendered != null) ...[
              const SizedBox(height: 12),
              Container(
                key: const ValueKey('nota-change-readout'),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: diff >= 0
                      ? ext.successContainer
                      : (light ? _kShortBgLight : cs.errorContainer),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(diff >= 0 ? t.labelChange : t.calcShort,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: diff >= 0
                                ? ext.onSuccessContainer
                                : (light ? _kShortFgLight : cs.onErrorContainer))),
                    Text(formatRupiah(diff.abs()),
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            fontFeatures: tabular,
                            color: diff >= 0
                                ? ext.onSuccessContainer
                                : (light ? _kShortFgLight : cs.onErrorContainer))),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('nota-pay-cancel'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: light ? _kShortFgLight : cs.error,
                      side: BorderSide(color: light ? _kShortFgLight : cs.error, width: 1.5),
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: _cancel,
                    child: Text(t.actionCancel),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('nota-pay-back'),
                    style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                    onPressed: () => Navigator.of(context)
                        .pop(const NotaPaymentOutcome(NotaPaymentAction.back)),
                    child: Text(t.calcBack),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    key: const ValueKey('nota-pay-finish'),
                    style: FilledButton.styleFrom(padding: EdgeInsets.zero),
                    // Short cash cannot complete a sale here, and the server refuses it too.
                    onPressed: _enough ? _finish : null,
                    child: Text(t.calcFinish),
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
