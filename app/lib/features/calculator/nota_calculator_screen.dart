import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/app_dialog.dart';
import '../../core/brand.dart';
import '../../core/money.dart';
import '../../core/order_math.dart';
import '../../core/theme.dart';
import '../../core/tts.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../data/session.dart';
import '../../l10n/app_localizations.dart';
import '../reports/reports_screen.dart';
import '../scanner/rongta_printer.dart';
import '../settings/settings_screen.dart';
import '../transactions/transactions_screen.dart';
import '../stt/voice_order_screen.dart';
import 'nota_calculator.dart';
import 'nota_counter.dart';
import 'nota_draft_store.dart';
import 'nota_payment_sheet.dart';

/// Calculator-only mode's home screen (specs/008-calculator-only).
///
/// Replaces the till for a merchant with no catalog: the cashier keys bare amounts, and each
/// finished nota is posted as a real order through the same offline-safe queue as every other sale.
/// This shell owns everything that touches the app — session, catalog, the queue, the printer,
/// navigation. The keypad and its rules live in [NotaCalculatorBody], which takes all of that as
/// plain parameters so it can be tested without any of it.
class NotaCalculatorScreen extends ConsumerWidget {
  const NotaCalculatorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final session = ref.watch(sessionProvider);
    final catalog =
        session == null ? null : ref.watch(catalogProvider(session.outletId)).valueOrNull;
    final notaNumber = ref.watch(notaCounterProvider);

    Future<bool> submit(List<int> amounts, int tendered, String clientOrderId) async {
      final variantId = catalog?.openAmountVariantId;
      if (session == null || variantId == null) return false;
      final messenger = ScaffoldMessenger.of(context);
      final payload = buildNotaPayload(
        // Minted by the body and saved in the draft BEFORE this call — see NotaDraft.
        clientOrderId: clientOrderId,
        outletId: session.outletId,
        deviceId: session.deviceId,
        openAmountVariantId: variantId,
        amounts: amounts,
        tendered: tendered,
      );
      try {
        final result = await ref.read(syncQueueProvider).submit(payload);
        await ref.read(notaCounterProvider.notifier).finished();
        if (result == null) {
          // Queued offline: the sale is safe in the local queue and replays on reconnect.
          messenger.showSnackBar(SnackBar(content: Text(t.msgQueuedOffline)));
          return true;
        }
        unawaited(announceReceived(result.grandTotal));
        unawaited(printReceiptSmart(result,
            businessName: catalog?.merchantName, outletName: catalog?.outletName, openDrawer: true));
        // Change from the SERVER's grand total, not the keypad's — the server's figure is the one
        // the customer was actually charged.
        messenger.showSnackBar(SnackBar(
          content: Text(t.calcPaid(formatRupiah(tendered - result.grandTotal))),
          duration: const Duration(seconds: 4),
        ));
        return true;
      } on DioException catch (e) {
        final code = e.response?.data is Map ? (e.response!.data as Map)['code'] : null;
        if (context.mounted) {
          await showAppDialog(
            context,
            kind: AppDialogKind.error,
            message: t.calcSaveFailed('${code ?? e.response?.statusCode ?? 'network'}'),
          );
        }
        // Keep the nota on screen: nothing was recorded, so nothing should be lost.
        return false;
      }
    }

    return Scaffold(
      appBar: BrandAppBar(
        title: Text(t.calcTitle),
        actions: [
          // This merchant never sees the till, so the microphone has to live here. Open-price
          // mode by default — there is no catalogue to check anything against.
          if (VoiceOrderScreen.isAvailable)
            IconButton(
              tooltip: t.voiceOrderTitle,
              icon: const Icon(Icons.mic_none_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const VoiceOrderScreen(mode: VoiceOrderMode.openPrice),
                ),
              ),
            ),
          IconButton(
            tooltip: t.historyLabel,
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const TransactionsScreen())),
          ),
          if (session?.isOwnerOrManager ?? false)
            IconButton(
              tooltip: t.reportsTitle,
              icon: const Icon(Icons.insights_outlined),
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const ReportsScreen())),
            ),
          IconButton(
            tooltip: t.settingsTitle,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: SafeArea(
        child: notaFontScope(
          context,
          NotaCalculatorBody(
            // A fresh body per outlet, so it restores that outlet's draft and no other.
            key: ValueKey(session?.outletId),
            notaNumber: notaNumber,
            taxRule: catalog?.taxRule,
            onSubmit: submit,
            draftStore: session == null
                ? MemoryNotaDraftStore()
                : PrefsNotaDraftStore(session.outletId),
            isCaptured: (id) => ref.read(appDatabaseProvider).isOrderCaptured(id),
          ),
        ),
      ),
    );
  }
}

/// The keypad, the running list, the total and the two bottom actions.
///
/// Everything it needs arrives as a parameter, following the injectable convention of
/// `NotaPhotoViewer`, so a widget test drives it with no provider, no network and no clock.
class NotaCalculatorBody extends StatefulWidget {
  final int notaNumber;

  /// The outlet's tax rule, or null. Null today for every calculator merchant — but the total and
  /// the payment dialog both go through [previewTotals] with it, so a rule added on the server
  /// shows up here with no code change.
  final TaxRule? taxRule;

  /// Posts the nota under [clientOrderId]. Resolves true when it is recorded or safely queued (the
  /// keypad resets), false when it failed (the nota stays, because nothing was saved).
  final Future<bool> Function(List<int> amounts, int tendered, String clientOrderId) onSubmit;

  /// Keeps the unfinished nota across app launches.
  final NotaDraftStore draftStore;

  /// Whether a sale with this `clientOrderId` was already captured on the device. Asked only when
  /// a restored draft shows the app died while Selesai was sending.
  final Future<bool> Function(String clientOrderId) isCaptured;

  /// Injected so tests get a fixed header; defaults to the real clock.
  final DateTime Function() clock;

  const NotaCalculatorBody({
    super.key,
    required this.notaNumber,
    required this.taxRule,
    required this.onSubmit,
    required this.draftStore,
    required this.isCaptured,
    this.clock = DateTime.now,
  });

  @override
  State<NotaCalculatorBody> createState() => _NotaCalculatorBodyState();
}

class _NotaCalculatorBodyState extends State<NotaCalculatorBody> {
  NotaCalculatorState _s = const NotaCalculatorState();
  final _scroll = ScrollController();
  Timer? _tick;
  bool _submitting = false;

  /// The `clientOrderId` of a sale being sent right now; saved with the draft (see [NotaDraft]).
  String? _pendingId;

  @override
  void initState() {
    super.initState();
    // The header clock only shows minutes, so a 30s tick keeps it honest without busy redraws.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    _restore();
  }

  /// Brings back the nota that was on screen when the app was closed.
  ///
  /// One case needs care: the app died while Selesai was sending. The sale may already be safe in
  /// the order queue, and restoring the list would invite charging it twice — so ask the queue.
  /// Captured: drop the draft and say so. Not captured: the send never began, so restore the list
  /// and forget the id (the next Selesai mints a new one).
  Future<void> _restore() async {
    final draft = await widget.draftStore.load();
    if (!mounted || draft == null) return;
    final id = draft.pendingClientOrderId;
    if (id != null && await widget.isCaptured(id)) {
      await widget.draftStore.clear();
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.calcPreviousSaved)));
      return;
    }
    if (!mounted) return;
    // Only if the cashier hasn't already started typing in the moment the load took.
    if (_s.isEmpty) setState(() => _s = draft.state);
    if (id != null) _persist();
  }

  /// Saves the current nota, or removes the draft when there is nothing to keep.
  Future<void> _persist() {
    if (_s.isEmpty && _pendingId == null) return widget.draftStore.clear();
    return widget.draftStore.save(NotaDraft(_s, pendingClientOrderId: _pendingId));
  }

  @override
  void dispose() {
    _tick?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _apply(NotaCalculatorState next) {
    final added = next.count > _s.count;
    setState(() => _s = next);
    _persist();
    if (added) {
      // Scroll after layout: maxScrollExtent is only meaningful once the new row exists.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
        }
      });
    }
  }

  Future<void> _confirmCancel() async {
    final t = AppLocalizations.of(context)!;
    final yes = await showAppDialog(
      context,
      kind: AppDialogKind.warning,
      title: t.calcCancelTitle,
      message: t.calcCancelBody,
      confirmLabel: t.calcCancelConfirm,
      cancelLabel: t.calcCancelKeep,
    );
    // The nota number deliberately does NOT move: a cancelled nota is not a nota.
    if (yes && mounted) {
      setState(() => _s = _s.reset());
      _persist();
    }
  }

  Future<void> _finish() async {
    final pending = _s.pendingAmounts;
    if (pending.isEmpty || _submitting) return;
    final preview = previewTotals(
        subtotal: pending.fold(0, (a, b) => a + b), tax: widget.taxRule);
    final outcome = await showNotaPaymentDialog(context, preview: preview);
    if (!mounted) return;
    switch (outcome.action) {
      case NotaPaymentAction.back:
        return;
      case NotaPaymentAction.cancel:
        setState(() => _s = _s.reset());
        _persist();
        return;
      case NotaPaymentAction.finish:
        // Mint the id and write it down BEFORE sending. If the app dies mid-send, the next launch
        // can look this id up in the order queue instead of guessing whether the sale went through.
        final id = const Uuid().v4();
        _pendingId = id;
        await _persist();
        if (!mounted) return;
        setState(() => _submitting = true);
        final ok = await widget.onSubmit(pending, outcome.tendered!, id);
        // Either way the send is over: recorded (clear everything) or refused (nothing was
        // recorded, so the id has no sale behind it and the next attempt gets a fresh one).
        _pendingId = null;
        if (mounted) {
          setState(() {
            _submitting = false;
            if (ok) _s = _s.reset();
          });
        } else if (ok) {
          _s = _s.reset();
        }
        await _persist();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final c = _NotaColors.of(context);
    final now = widget.clock();
    final preview = previewTotals(subtotal: _s.subtotal, tax: widget.taxRule);
    const tabular = [FontFeature.tabularFigures()];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Meta row: date · Nota #N · time.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(notaDateLabel(now),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.muted)),
              ),
              Container(
                key: const ValueKey('nota-number'),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration:
                    BoxDecoration(color: c.pillBg, borderRadius: BorderRadius.circular(999)),
                child: Text(t.calcNotaNumber(widget.notaNumber),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.pillFg)),
              ),
              Expanded(
                child: Text(notaTimeLabel(now),
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.muted)),
              ),
            ],
          ),
        ),
        // Nilai saat ini — the amount being typed, grouped as it grows.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(t.calcCurrentValue.toUpperCase(),
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                      color: c.muted)),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(formatRupiah(_s.currentValue),
                    key: const ValueKey('nota-current-value'),
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: c.navy,
                        fontFeatures: tabular)),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: Row(
            children: [
              Text(t.calcItemCountLabel,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.muted)),
              const Spacer(),
              Text(t.calcItemCount(_s.count),
                  key: const ValueKey('nota-item-count'),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.muted)),
            ],
          ),
        ),
        // The committed amounts. Flutter's own Scrollbar renders reliably, so the design's
        // hand-built thumb (a workaround for a web preview) isn't needed here.
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: c.listBg,
              border: Border.all(color: c.border),
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: _s.amounts.isEmpty
                ? Center(
                    child: Text(t.calcEmptyList,
                        style: TextStyle(fontSize: 12, color: c.muted)),
                  )
                : Scrollbar(
                    controller: _scroll,
                    thumbVisibility: true,
                    child: ListView.builder(
                      key: const ValueKey('nota-list'),
                      controller: _scroll,
                      itemCount: _s.amounts.length,
                      itemBuilder: (_, i) => Container(
                        color: i.isOdd ? c.altRow : null,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            Text(t.calcItemLine(i + 1),
                                style: TextStyle(fontSize: 13, color: c.muted)),
                            const Spacer(),
                            Text(formatRupiah(_s.amounts[i]),
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: c.navy,
                                    fontFeatures: tabular)),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ),
        // Total bar — fixed, never scrolls.
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border(top: BorderSide(color: c.border, width: 1.5)),
          ),
          child: Column(
            children: [
              // Only when a tax rule exists — today never, for a calculator merchant. Switching
              // tax on is a server-side data change and this appears without a layout change.
              if (preview.taxTotal > 0 || preview.serviceChargeTotal > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    children: [
                      Text(
                          t.calcTaxLine(widget.taxRule?.label ?? '',
                              ((widget.taxRule?.rateBps ?? 0) / 100).toStringAsFixed(0)),
                          style: TextStyle(fontSize: 11, color: c.muted)),
                      const Spacer(),
                      Text(formatRupiah(preview.taxTotal + preview.serviceChargeTotal),
                          style: TextStyle(fontSize: 11, color: c.muted, fontFeatures: tabular)),
                    ],
                  ),
                ),
              Row(
                children: [
                  Text(t.calcTotal,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: c.navy)),
                  const Spacer(),
                  Text(formatRupiah(preview.grandTotal),
                      key: const ValueKey('nota-total'),
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: c.navy,
                          fontFeatures: tabular)),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: _Keypad(onKey: (k) {
            switch (k) {
              case '⌫':
                _apply(_s.backspace());
              case 'C':
                _apply(_s.clear());
              case '↵':
                _apply(_s.commit());
              default:
                _apply(_s.key(k));
            }
          }),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: OutlinedButton(
                    key: const ValueKey('nota-batal'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.danger,
                      side: BorderSide(color: c.danger, width: 1.5),
                    ),
                    onPressed: _s.isEmpty || _submitting ? null : _confirmCancel,
                    child: Text(t.actionCancel),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 50,
                  child: FilledButton(
                    key: const ValueKey('nota-selesai'),
                    onPressed: _s.canFinish && !_submitting ? _finish : null,
                    child: _submitting
                        ? const SizedBox(
                            width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(t.calcFinish,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 3 × 5: `1 2 3 / 4 5 6 / 7 8 9 / 00 0 000 / ⌫ C ↵`.
class _Keypad extends StatelessWidget {
  final void Function(String key) onKey;
  const _Keypad({required this.onKey});

  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['00', '0', '000'],
    ['⌫', 'C', '↵'],
  ];

  static String _keyName(String k) => switch (k) {
        '⌫' => 'backspace',
        'C' => 'clear',
        '↵' => 'enter',
        _ => k,
      };

  @override
  Widget build(BuildContext context) {
    final c = _NotaColors.of(context);
    return Column(
      children: [
        for (final row in _rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                for (var i = 0; i < row.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(child: _key(context, c, row[i])),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _key(BuildContext context, _NotaColors c, String k) {
    final (Color bg, Color fg) = switch (k) {
      '↵' => (c.navy, c.onNavy),
      '⌫' || 'C' => (c.dangerBg, c.danger),
      '00' || '000' => (c.zeroBg, c.navy),
      _ => (c.surface, c.digitFg),
    };
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: ValueKey('nota-key-${_keyName(k)}'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => onKey(k),
        child: Container(
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: k == '↵' ? null : Border.all(color: c.border),
          ),
          child: k == '⌫'
              ? Icon(Icons.backspace_outlined, color: fg, size: 22)
              : Text(k,
                  style: TextStyle(fontSize: k == '↵' ? 22 : 20, fontWeight: FontWeight.w700, color: fg)),
        ),
      ),
    );
  }
}

/// The design's palette. Light mode uses its exact tans and tints; dark mode maps each role to a
/// scheme colour, because cream on near-black is unreadable rather than on-brand.
class _NotaColors {
  final Color navy, onNavy, surface, listBg, altRow, border, muted, pillBg, pillFg;
  final Color zeroBg, dangerBg, danger, digitFg;

  const _NotaColors({
    required this.navy,
    required this.onNavy,
    required this.surface,
    required this.listBg,
    required this.altRow,
    required this.border,
    required this.muted,
    required this.pillBg,
    required this.pillFg,
    required this.zeroBg,
    required this.dangerBg,
    required this.danger,
    required this.digitFg,
  });

  factory _NotaColors.of(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (Theme.of(context).brightness == Brightness.light) {
      return const _NotaColors(
        navy: kBrandNavy,
        onNavy: Colors.white,
        surface: Colors.white,
        listBg: Colors.white,
        altRow: Color(0xFFEFEBDD),
        border: Color(0xFFE1DED2),
        muted: Color(0xFF8A8368),
        pillBg: Color(0xFFEDE7D2),
        pillFg: kBrandNavy,
        zeroBg: Color(0xFFF0ECDD),
        dangerBg: Color(0xFFF7DCDC),
        danger: Color(0xFFB23B3B),
        digitFg: Color(0xFF1D1B16),
      );
    }
    return _NotaColors(
      navy: cs.primary,
      onNavy: cs.onPrimary,
      surface: cs.surfaceContainer,
      listBg: cs.surfaceContainerLow,
      altRow: cs.surfaceContainerHigh,
      border: cs.outlineVariant,
      muted: cs.onSurfaceVariant,
      pillBg: cs.secondaryContainer,
      pillFg: cs.onSecondaryContainer,
      zeroBg: cs.surfaceContainerHighest,
      dangerBg: cs.errorContainer,
      danger: cs.error,
      digitFg: cs.onSurface,
    );
  }
}
