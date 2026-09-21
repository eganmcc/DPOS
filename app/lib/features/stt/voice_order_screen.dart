import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../../core/app_dialog.dart';
import '../../core/brand.dart';
import '../../core/money.dart';
import '../../core/order_math.dart';

import '../../data/models.dart';
import '../../data/providers.dart';
import '../../data/session.dart';
import '../../l10n/app_localizations.dart';
import '../calculator/nota_counter.dart';
import '../calculator/nota_payment_sheet.dart';
import '../order/staged_order.dart';
import 'stt_commands.dart';
import 'stt_engine.dart';
import 'stt_lab_screen.dart' show sttEngineProvider;
import 'stt_options.dart';
import 'stt_runner.dart';
import 'stt_stock_check.dart';
import 'stt_transcript.dart';
import 'voice_order_parse.dart';

/// How a spoken line is read.
enum VoiceOrderMode {
  /// Against the catalogue: the words name an item and how many, the price comes from the shop.
  catalogue,

  /// Open amounts: the words name an item and what it costs, because there is no catalogue.
  openPrice,
}

/// Taking an order by voice.
///
/// Deliberately a separate surface from the till rather than a mode of it: a cashier speaking an
/// order needs to SEE what was heard before it becomes money, and that review list is the whole
/// point. Lines stage here, and only Selesai (or Tambah ke keranjang) commits them.
class VoiceOrderScreen extends ConsumerWidget {
  const VoiceOrderScreen({super.key, this.mode});

  /// Forced mode; normally null, and the merchant decides it.
  final VoiceOrderMode? mode;

  /// Whether to offer voice at all on this build.
  static bool get isAvailable => sttSupported;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final session = ref.watch(sessionProvider);
    final catalog = session == null
        ? null
        : ref.watch(catalogProvider(session.outletId)).valueOrNull;
    // A merchant with no catalogue can only speak prices; one with a catalogue should be checked
    // against it. The radio exists for the rare shop that does both.
    final initial = mode ??
        ((catalog?.isCalculatorOnly ?? false) || (catalog?.isNotaReading ?? false)
            ? VoiceOrderMode.openPrice
            : VoiceOrderMode.catalogue);

    return Scaffold(
      appBar: BrandAppBar(title: Text(t.voiceOrderTitle)),
      body: SafeArea(
        child: VoiceOrderBody(
          engine: ref.watch(sttEngineProvider),
          options: ref.watch(sttOptionsProvider),
          catalog: catalog?.products ?? const [],
          taxRule: catalog?.taxRule,
          initialMode: initial,
          requestMicPermission: () async => (await Permission.microphone.request()).isGranted,
          openSettings: openAppSettings,
          onAddToCart: (checks) => _addToCart(ref, checks),
          onFinish: (mode, checks, priced) =>
              _finish(context, ref, mode: mode, checks: checks, priced: priced),
        ),
      ),
    );
  }

  /// Spoken catalogue lines go into the SAME cart as tapped ones, so an order can be half spoken
  /// and half tapped and still be one bill.
  static void _addToCart(WidgetRef ref, List<SttStockCheck> checks) =>
      addStagedToCart(ref, checks);

  /// Selesai. What it means depends on the mode, because the two sell differently: an open-price
  /// sale is a counter sale paid now, a catalogue order is usually served before it is paid.
  static Future<bool> _finish(
    BuildContext context,
    WidgetRef ref, {
    required VoiceOrderMode mode,
    required List<SttStockCheck> checks,
    required List<PricedLine> priced,
  }) async {
    if (mode == VoiceOrderMode.catalogue) {
      // The existing open-bill / payment path — one money path, shared with the nota reader.
      return finishStagedOrder(context, ref, checks);
    }
    return _finishOpenPrice(context, ref, priced);
  }

  static Future<bool> _finishOpenPrice(
    BuildContext context,
    WidgetRef ref,
    List<PricedLine> priced,
  ) async {
    final t = AppLocalizations.of(context)!;
    final session = ref.read(sessionProvider);
    final catalog =
        session == null ? null : ref.read(catalogProvider(session.outletId)).valueOrNull;
    final variantId = catalog?.openAmountVariantId;
    if (session == null || variantId == null) return false;

    final usable = priced.where((l) => !l.isIncomplete).toList();
    if (usable.isEmpty) return false;

    final preview = previewTotals(
      subtotal: usable.fold(0, (a, l) => a + l.total),
      tax: catalog?.taxRule,
    );
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await showNotaPaymentDialog(context, preview: preview);
    if (outcome.action != NotaPaymentAction.finish) return false;

    final payload = buildVoiceSalePayload(
      clientOrderId: const Uuid().v4(),
      outletId: session.outletId,
      deviceId: session.deviceId,
      openAmountVariantId: variantId,
      lines: usable,
      tendered: outcome.tendered!,
    );
    final result = await ref.read(syncQueueProvider).submit(payload);
    await ref.read(notaCounterProvider.notifier).finished();
    if (result == null) {
      messenger.showSnackBar(SnackBar(content: Text(t.msgQueuedOffline)));
      return true;
    }
    // Change from the SERVER's grand total — the figure the customer was actually charged.
    messenger.showSnackBar(SnackBar(
      content: Text(t.calcPaid(formatRupiah(outcome.tendered! - result.grandTotal))),
      duration: const Duration(seconds: 4),
    ));
    return true;
  }
}

/// The screen's body, with every dependency injected so a widget test can speak a whole order
/// without a microphone — the convention of `NotaChatBody` and `SttLabBody`.
class VoiceOrderBody extends StatefulWidget {
  final SttEngine engine;
  final SttOptions options;
  final List<Product> catalog;
  final TaxRule? taxRule;
  final VoiceOrderMode initialMode;
  final Future<bool> Function() requestMicPermission;
  final Future<void> Function() openSettings;
  final void Function(List<SttStockCheck>) onAddToCart;
  final Future<bool> Function(
    VoiceOrderMode mode,
    List<SttStockCheck> checks,
    List<PricedLine> priced,
  ) onFinish;
  final Duration restartDelay;

  /// How often to check that the microphone is really open. Injected so a test need not wait.
  final Duration watchdogPeriod;

  const VoiceOrderBody({
    super.key,
    required this.engine,
    required this.options,
    required this.catalog,
    required this.taxRule,
    required this.initialMode,
    required this.requestMicPermission,
    required this.openSettings,
    required this.onAddToCart,
    required this.onFinish,
    this.restartDelay = const Duration(milliseconds: 300),
    this.watchdogPeriod = const Duration(seconds: 1),
  });

  @override
  State<VoiceOrderBody> createState() => _VoiceOrderBodyState();
}

class _VoiceOrderBodyState extends State<VoiceOrderBody> {


  /// Tabular figures keep the price column from dancing as amounts change.
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];
  late VoiceOrderMode _mode = widget.initialMode;

  /// The staged bill. Only one of these is in play at a time — the mode cannot change once there
  /// is anything to lose.
  final List<SttStockCheck> _checks = [];
  final List<PricedLine> _priced = [];




  bool _submitting = false;




  @override
  void initState() {
    super.initState();
    _run.init();
  }

  @override
  void didUpdateWidget(VoiceOrderBody old) {
    super.didUpdateWidget(old);
    // The runner took a COPY of the options when it was built. Tuning saved on the bench arrives
    // here as a rebuild, and without this the till would go on listening with whatever happened
    // to be loaded the moment it opened — including the defaults, on a cold start that beat
    // SharedPreferences to it.
    _run.options = _tillOptions;
  }

  @override
  void dispose() {
    _run.dispose();
    super.dispose();
  }

  bool get _isEmpty => _mode == VoiceOrderMode.catalogue ? _checks.isEmpty : _priced.isEmpty;

  /// A line the server would refuse. Selesai waits until these are gone: an order that silently
  /// drops what it could not understand is how a customer is charged for the wrong thing, and one
  /// the server refuses for stock is a sale that fails at the till with the customer waiting.
  int get _blocking => _mode == VoiceOrderMode.catalogue
      ? _checks.where((c) => c.blocksSale).length
      : _priced.where((l) => l.isIncomplete).length;

  int get _subtotal => _mode == VoiceOrderMode.catalogue
      ? _checks.fold(0, (a, c) => a + _unitPrice(c) * c.qty)
      : _priced.fold(0, (a, l) => a + l.total);

  int _unitPrice(SttStockCheck c) => c.variant?.price ?? 0;

  /// Everything about running a listening session lives in [SttRunner] — the same one the tuning
  /// bench uses. This screen only decides what to DO with what it hears.
  /// What the till listens with, as opposed to what the bench is set to.
  ///
  /// Two deliberate overrides, because this surface is not the bench:
  ///
  ///  - **continuous is always on.** Taking an order is one long turn with thinking in it, and
  ///    this screen already has two ways to end it — the stop button and "pesanan selesai". The
  ///    device log for 21:57 shows the alternative: a session ended at exactly 3.010s of quiet
  ///    and the whole run ended with it, so every item needed its own tap.
  ///  - **a floor under pauseFor**, since that timer starts at `listen()` and not at the first
  ///    word. Three seconds is a fine number to experiment with and a bad one to sell with.
  ///
  /// Everything else the bench tunes — the locale, listenFor, the android flags — comes through
  /// untouched, which is the point of tuning it there.
  static const int _minPauseSeconds = 6;

  SttOptions get _tillOptions => widget.options.copyWith(
        continuous: true,
        pauseForSeconds: widget.options.pauseForSeconds < _minPauseSeconds
            ? _minPauseSeconds
            : widget.options.pauseForSeconds,
      );

  late final SttRunner _run = SttRunner(
    engine: widget.engine,
    options: _tillOptions,
    restartDelay: widget.restartDelay,
    watchdogPeriod: widget.watchdogPeriod,
    onChanged: () {
      if (mounted) setState(() {});
    },
    onUtterance: _take,
    // To logcat, not to the screen: this surface has no room for a diagnostics panel, and when
    // something goes wrong here the question is always "what did it actually hear". Gated on the
    // bench's debugLogging so it can be turned off — the words are a customer's order, and they
    // must not be in a real merchant's logs.
    onNote: widget.options.debugLogging ? (line) => debugPrint('STT $line') : null,
  );

  SttTranscript get _transcript => _run.transcript;

  Future<void> _toggle() async {
    if (_run.wantListening) {
      await _run.stop('by user');
      return;
    }
    if (!await widget.requestMicPermission()) {
      if (!mounted) return;
      final t = AppLocalizations.of(context)!;
      final open = await showAppDialog(
        context,
        kind: AppDialogKind.warning,
        title: t.sttMicDeniedTitle,
        message: t.sttMicDeniedBody,
        confirmLabel: t.sttOpenSettings,
        cancelLabel: t.actionCancel,
      );
      if (open) await widget.openSettings();
      return;
    }
    final dupesBefore = _transcript.duplicatesSuppressed;
    await _run.start();
    _warnIfSwallowed(dupesBefore);
  }

  /// A line held back as a repeat has to SAY so. Silently dropping something the cashier watched
  /// the screen hear is the one failure this surface must not have.
  void _warnIfSwallowed(int before) {
    if (!mounted || _transcript.duplicatesSuppressed <= before) return;
    final t = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(t.voiceRepeatIgnored),
      duration: const Duration(seconds: 2),
    ));
  }

  /// One finished utterance becomes one or more staged lines.
  /// A number on its own belongs to the line before it.
  ///
  /// "ayam geprek keju 5" does not always arrive in one piece: the device log for 22:05 shows the
  /// words, a 5.9-second gap, and then the rest — and the recognizer had thrown its buffer away
  /// in between, so the name was committed on its own (at a quantity of one, because none had
  /// been said yet) and the number came through as an item nobody sells. Nobody orders "5".
  ///
  /// Returns true when the number was used, so the caller does not also stage it as an item.
  bool _applyLooseNumber(String utterance) {
    final words = normaliseSpoken(utterance).split(' ').where((w) => w.isNotEmpty).toList();
    final n = spokenNumber(words);
    if (n == null || n <= 0) return false;

    if (_mode == VoiceOrderMode.catalogue) {
      if (_checks.isEmpty) return false;
      final last = _checks.last;
      if (last.product == null) return false; // nothing sensible to attach it to
      // Rebuilt, not patched: whether there is enough stock depends on the quantity.
      _checks[_checks.length - 1] = checkItem(
        qty: n,
        item: last.spokenItem,
        products: widget.catalog,
      );
      return true;
    }

    if (_priced.isEmpty) return false;
    final last = _priced.last;
    // In this mode the missing half is usually the price — "pecel lele", then "100".
    _priced[_priced.length - 1] = last.price <= 0
        ? PricedLine(label: last.label, qty: last.qty, price: spokenPrice(n))
        : PricedLine(label: last.label, qty: n, price: last.price);
    return true;
  }

  void _take(String rawUtterance) {
    // An instruction that arrived on its own is not an item — and a trailing "pesanan" is the
    // first half of one, left behind when the recognizer split the phrase.
    if (isStopCommand(rawUtterance)) return;
    final utterance = stripTrailingCommandWords(rawUtterance);
    if (utterance.trim().isEmpty) return;
    if (_applyLooseNumber(utterance)) return;
    if (_mode == VoiceOrderMode.catalogue) {
      _checks.addAll(checkUtterance(utterance, widget.catalog));
    } else {
      _priced.addAll(parsePricedLines(utterance));
    }
  }

  void _removeAt(int i) => setState(() {
        if (_mode == VoiceOrderMode.catalogue) {
          _checks.removeAt(i);
        } else {
          _priced.removeAt(i);
        }
      });

  Future<void> _finish() async {
    if (_isEmpty || _blocking > 0 || _submitting) return;
    setState(() => _submitting = true);
    final ok = await widget.onFinish(_mode, List.of(_checks), List.of(_priced));
    if (!mounted) return;
    setState(() {
      _submitting = false;
      if (ok) {
        _checks.clear();
        _priced.clear();
      }
    });
    if (ok && mounted) Navigator.of(context).maybePop();
  }

  void _addToCart() {
    widget.onAddToCart(List.of(_checks));
    setState(_checks.clear);
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    if (!widget.engine.isSupported) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(t.sttAndroidOnly, textAlign: TextAlign.center),
        ),
      );
    }

    final preview = previewTotals(subtotal: _subtotal, tax: widget.taxRule);
    final rows = _mode == VoiceOrderMode.catalogue ? _checks.length : _priced.length;

    return Column(
      children: [
        // ---- what is being heard ------------------------------------------------------------
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _transcript.live.isNotEmpty
                      ? _transcript.live
                      : (_run.wantListening && !_run.listening ? t.sttRestarting : t.sttSaySomething),
                  key: const ValueKey('voice-live'),
                  style: TextStyle(
                    fontSize: 15,
                    fontStyle: _transcript.live.isEmpty ? FontStyle.italic : FontStyle.normal,
                    color: _transcript.live.isEmpty ? cs.onSurfaceVariant : cs.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: (_run.level.abs() / 10).clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: cs.surfaceContainerHighest,
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 48,
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('voice-mic'),
                  onPressed: _run.ready ? _toggle : null,
                  style: _run.wantListening
                      ? FilledButton.styleFrom(
                          backgroundColor: cs.error, foregroundColor: cs.onError)
                      : null,
                  icon: Icon(_run.wantListening ? Icons.stop : Icons.mic),
                  label: Text(_run.wantListening
                      ? t.sttStop
                      : (_run.options.continuous ? t.sttListenContinuous : t.sttListen)),
                ),
              ),
              if (!_run.ready)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(t.sttNoRecognizer,
                      style: TextStyle(color: cs.error, fontSize: 12)),
                ),
              if (_run.wantListening)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(t.sttStopPhraseHint(kStopPhrases.first),
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11)),
                ),
            ],
          ),
        ),

        // ---- mode -----------------------------------------------------------------------------
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SegmentedButton<VoiceOrderMode>(
            key: const ValueKey('voice-mode'),
            segments: [
              ButtonSegment(value: VoiceOrderMode.catalogue, label: Text(t.voiceModeCatalogue)),
              ButtonSegment(value: VoiceOrderMode.openPrice, label: Text(t.voiceModeOpenPrice)),
            ],
            selected: {_mode},
            // Locked once there are lines: switching would leave a staged bill nobody can see.
            onSelectionChanged: (_checks.isEmpty && _priced.isEmpty)
                ? (s) => setState(() => _mode = s.first)
                : null,
          ),
        ),

        // ---- the bill --------------------------------------------------------------------------
        const SizedBox(height: 10),
        _headerRow(context),
        Expanded(
          child: rows == 0
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(t.voiceEmpty,
                        key: const ValueKey('voice-empty'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: cs.onSurfaceVariant)),
                  ),
                )
              : ListView.builder(
                  key: const ValueKey('voice-lines'),
                  itemCount: rows,
                  itemBuilder: (context, i) => _mode == VoiceOrderMode.catalogue
                      ? _catalogueRow(context, i)
                      : _pricedRow(context, i),
                ),
        ),

        // ---- totals and actions ------------------------------------------------------------
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: cs.outlineVariant, width: 1.5)),
          ),
          child: Column(
            children: [
              if (preview.taxTotal > 0 || preview.serviceChargeTotal > 0)
                Row(children: [
                  Text(t.labelTax, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  const Spacer(),
                  Text(formatRupiah(preview.taxTotal + preview.serviceChargeTotal),
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                ]),
              Row(children: [
                Text(t.labelTotal,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text(formatRupiah(preview.grandTotal),
                    key: const ValueKey('voice-total'),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              ]),
              if (_blocking > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(t.voiceFixLines(_blocking),
                      key: const ValueKey('voice-blocked'),
                      style: TextStyle(fontSize: 12, color: cs.error)),
                ),
              const SizedBox(height: 8),
              Row(children: [
                if (_mode == VoiceOrderMode.catalogue)
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        key: const ValueKey('voice-add-to-cart'),
                        onPressed: _isEmpty || _blocking > 0 || _submitting ? null : _addToCart,
                        child: Text(t.voiceAddToCart, textAlign: TextAlign.center),
                      ),
                    ),
                  ),
                if (_mode == VoiceOrderMode.catalogue) const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 48,
                    child: FilledButton(
                      key: const ValueKey('voice-selesai'),
                      onPressed: _isEmpty || _blocking > 0 || _submitting ? null : _finish,
                      child: _submitting
                          ? const SizedBox(
                              width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(t.calcFinish,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _headerRow(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final style =
        TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Row(children: [
        Expanded(flex: 5, child: Text(t.voiceColItem, style: style)),
        Expanded(flex: 2, child: Text(t.voiceColQty, style: style, textAlign: TextAlign.center)),
        Expanded(flex: 3, child: Text(t.voiceColPrice, style: style, textAlign: TextAlign.right)),
        Expanded(flex: 3, child: Text(t.voiceColTotal, style: style, textAlign: TextAlign.right)),
        const SizedBox(width: 36),
      ]),
    );
  }

  Widget _catalogueRow(BuildContext context, int i) {
    final c = _checks[i];
    final problem = c.status != SttStockStatus.ok ? _problemText(context, c) : null;
    return _row(
      context,
      index: i,
      name: c.displayName,
      qty: c.qty,
      price: _unitPrice(c),
      problem: problem,
      fatal: c.blocksSale,
    );
  }

  Widget _pricedRow(BuildContext context, int i) {
    final t = AppLocalizations.of(context)!;
    final l = _priced[i];
    return _row(
      context,
      index: i,
      name: l.label,
      qty: l.qty,
      price: l.price,
      problem: l.isIncomplete ? t.voiceNeedsPrice : null,
      fatal: l.isIncomplete,
    );
  }

  String _problemText(BuildContext context, SttStockCheck c) {
    final t = AppLocalizations.of(context)!;
    final left = c.remaining ?? 0;
    return switch (c.status) {
      SttStockStatus.notFound => t.sttStockNotFound,
      SttStockStatus.unavailable => t.sttStockUnavailable(c.displayName),
      SttStockStatus.outOfStock => t.sttStockOut(c.displayName),
      SttStockStatus.insufficient => t.sttStockShort(c.displayName, left, c.qty),
      SttStockStatus.ok => '',
    };
  }

  Widget _row(
    BuildContext context, {
    required int index,
    required String name,
    required int qty,
    required int price,
    required String? problem,
    required bool fatal,
  }) {
    final t = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: index.isOdd ? cs.surfaceContainerHighest.withValues(alpha: 0.4) : null,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.isEmpty ? '—' : name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                if (problem != null)
                  Text(problem,
                      key: ValueKey('voice-problem-$index'),
                      style: TextStyle(
                          fontSize: 11,
                          // Red stops the order (the server would refuse it); amber only warns.
                          color: fatal ? cs.error : const Color(0xFF7A5A00))),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text('$qty',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, fontFeatures: tabular)),
          ),
          Expanded(
            flex: 3,
            child: Text(formatRupiah(price),
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 13, fontFeatures: tabular)),
          ),
          Expanded(
            flex: 3,
            child: Text(formatRupiah(price * qty),
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, fontFeatures: tabular)),
          ),
          SizedBox(
            width: 36,
            child: IconButton(
              key: ValueKey('voice-remove-$index'),
              tooltip: t.removeItem,
              visualDensity: VisualDensity.compact,
              onPressed: () => _removeAt(index),
              icon: Icon(Icons.close, size: 18, color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
