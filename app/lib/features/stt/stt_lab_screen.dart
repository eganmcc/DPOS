import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/app_dialog.dart';
import '../../core/brand.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../data/session.dart';
import '../../l10n/app_localizations.dart';
import 'stt_commands.dart';
import 'stt_engine.dart';
import 'stt_options.dart';
import 'stt_runner.dart';
import 'stt_stock_check.dart';
import 'stt_transcript.dart';

/// The speech-to-text tuning bench — Settings → "Uji coba suara". ANDROID ONLY.
///
/// It exists to answer questions about real handsets before any of this goes near a till: does the
/// recognizer hear Indonesian, under which locale code, how long until the first word, does it
/// throw its buffer away mid-sentence, and which settings make that better. Nothing here touches
/// the cart, an order, or the server.
class SttLabScreen extends ConsumerWidget {
  const SttLabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final session = ref.watch(sessionProvider);
    return Scaffold(
      appBar: BrandAppBar(title: Text(t.sttLabTitle)),
      body: SafeArea(
        child: SttLabBody(
          engine: ref.watch(sttEngineProvider),
          options: ref.watch(sttOptionsProvider),
          onOptions: (o) => ref.read(sttOptionsProvider.notifier).set(o),
          requestMicPermission: () async => (await Permission.microphone.request()).isGranted,
          openSettings: openAppSettings,
          // The live catalog, so a spoken line can be checked against real stock. Empty for a
          // merchant that sells without one (a calculator or nota account).
          catalog: session == null
              ? const []
              : ref.watch(catalogProvider(session.outletId)).valueOrNull?.products ?? const [],
        ),
      ),
    );
  }
}

/// One engine for the app, created outside the widget tree like `core/tts.dart` — navigating away
/// mid-session must not dispose it.
final sttEngineProvider = Provider<SttEngine>((ref) => RealSttEngine());

/// The bench itself. Everything that touches hardware arrives as a parameter so a widget test can
/// drive a whole session with no microphone (the convention of `NotaChatBody`).
class SttLabBody extends StatefulWidget {
  final SttEngine engine;
  final SttOptions options;
  final void Function(SttOptions) onOptions;
  final Future<bool> Function() requestMicPermission;
  final Future<void> Function() openSettings;
  final DateTime Function() clock;

  /// The beat between one continuous session ending and the next starting. Injected so a test
  /// does not have to wait it out.
  final Duration restartDelay;

  /// How often to check that the microphone is really open. Injected for the same reason.
  final Duration watchdogPeriod;

  /// What the catalogue says exists and how much is left.
  final List<Product> catalog;

  const SttLabBody({
    super.key,
    required this.engine,
    required this.options,
    required this.onOptions,
    required this.requestMicPermission,
    required this.openSettings,
    this.clock = DateTime.now,
    this.restartDelay = const Duration(milliseconds: 300),
    this.watchdogPeriod = const Duration(seconds: 1),
    this.catalog = const [],
  });

  @override
  State<SttLabBody> createState() => _SttLabBodyState();
}

class _SttLabBodyState extends State<SttLabBody> {
  final List<String> _log = [];

  /// Check each heard line against the catalogue instead of just showing the words.
  bool _checkStock = false;

  /// The listening itself — the same runner the order sheet uses. This screen is the bench that
  /// earned these rules; keeping a second copy of them here is what let the order sheet drift.
  late final SttRunner _run = SttRunner(
    engine: widget.engine,
    options: widget.options,
    clock: widget.clock,
    restartDelay: widget.restartDelay,
    watchdogPeriod: widget.watchdogPeriod,
    onChanged: () {
      if (mounted) setState(() {});
    },
    onNote: _note,
  );

  SttTranscript get _transcript => _run.transcript;
  SttLocale? get _indonesian {
    for (final l in _run.locales) {
      if (l.isIndonesian) return l;
    }
    return null;
  }

  String? get _effectiveLocale => _run.listenOptions.localeId;

  @override
  void initState() {
    super.initState();
    _run.init();
  }

  @override
  void dispose() {
    _run.dispose();
    super.dispose();
  }

  void _note(String line) {
    final now = widget.clock();
    final stamp = '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}.'
        '${now.millisecond.toString().padLeft(3, '0')}';
    // Newest first, and bounded: a long tuning session must not grow without limit.
    _log.insert(0, '$stamp  $line');
    if (_log.length > 300) _log.removeLast();
  }

  Future<void> _toggle() async {
    final t = AppLocalizations.of(context)!;
    if (_run.wantListening) {
      await _run.stop('by user');
      return;
    }
    if (!await widget.requestMicPermission()) {
      if (!mounted) return;
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
    await _run.start();
  }

  Future<void> _apply(SttOptions next, {bool restart = false}) async {
    widget.onOptions(next);
    _run.options = next;
    if (restart) {
      _note('re-initialising for an initialize-level option');
      await _run.init(restart: true);
    }
  }

  Future<void> _copyDiagnostics() async {
    final t = AppLocalizations.of(context)!;
    final b = StringBuffer()
      ..writeln('DPOS STT diagnostics')
      ..writeln('ready: ${_run.ready}  status: ${_run.status}  supported: ${widget.engine.isSupported}')
      ..writeln('effective locale: ${_effectiveLocale ?? "(device default)"}')
      ..writeln('locales offered: ${_run.locales.map((l) => l.id).join(", ")}')
      ..writeln('indonesian detected as: ${_indonesian?.id ?? "NONE"}')
      ..writeln('options:')
      ..writeln(widget.options.describe())
      ..writeln('counters: bufferResets=${_transcript.bufferResets} '
          'duplicatesSuppressed=${_transcript.duplicatesSuppressed} '
          'lateResults=${_transcript.lateResults} '
          'timeToFirstPartial=${_transcript.timeToFirstPartial?.inMilliseconds ?? "-"}ms')
      ..writeln('')
      ..writeln('results (newest first):');
    for (final r in _transcript.results) {
      b.writeln('  "${r.text}"  conf=${r.confidence?.toStringAsFixed(2) ?? "-"}  '
          'spoken=${r.spoken?.inMilliseconds ?? "-"}ms');
    }
    b
      ..writeln('')
      ..writeln('log (newest first):');
    for (final l in _log) {
      b.writeln('  $l');
    }
    await Clipboard.setData(ClipboardData(text: b.toString()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.sttCopied)));
    }
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        // ---- status + live ------------------------------------------------------------------
        Row(children: [
          Expanded(
            child: Text('${t.sttStatus}: ${_run.status}',
                key: const ValueKey('stt-status'),
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
          ),
          if (_transcript.timeToFirstPartial != null)
            Text('${t.sttFirstWord}: ${_transcript.timeToFirstPartial!.inMilliseconds} ms',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
        ]),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(minHeight: 64),
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _transcript.live.isNotEmpty
                ? _transcript.live
                // In continuous mode there is a real gap between utterances while the next
                // session starts; saying so stops it looking like the app stopped listening.
                : (_run.wantListening && !_run.listening ? t.sttRestarting : t.sttSaySomething),
            key: const ValueKey('stt-live'),
            style: TextStyle(
              fontStyle: _transcript.live.isEmpty ? FontStyle.italic : FontStyle.normal,
              color: _transcript.live.isEmpty ? cs.onSurfaceVariant : cs.onSurface,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(height: 8),
        // A mic that hears nothing looks exactly like one that mishears — until you watch this.
        LinearProgressIndicator(
          key: const ValueKey('stt-level'),
          value: (_run.level.abs() / 10).clamp(0.0, 1.0),
          minHeight: 6,
          backgroundColor: cs.surfaceContainerHighest,
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              key: const ValueKey('stt-mic'),
              onPressed: _run.ready ? _toggle : null,
              // The button follows the INTENT, not one session: in continuous mode it stays red
              // through the gaps between utterances, because listening has not actually stopped.
              style: _run.wantListening
                  ? FilledButton.styleFrom(backgroundColor: cs.error, foregroundColor: cs.onError)
                  : null,
              icon: Icon(_run.wantListening ? Icons.stop : Icons.mic),
              label: Text(_run.wantListening
                  ? t.sttStop
                  : (widget.options.continuous ? t.sttListenContinuous : t.sttListen)),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: t.sttCopyDiagnostics,
            onPressed: _copyDiagnostics,
            icon: const Icon(Icons.copy_all_outlined),
          ),
          IconButton(
            tooltip: t.sttClear,
            onPressed: _transcript.results.isEmpty
                ? null
                : () => setState(() {
                      _transcript.clear();
                      _log.clear();
                    }),
            icon: const Icon(Icons.delete_outline),
          ),
        ]),
        if (!_run.ready)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(t.sttNoRecognizer, style: TextStyle(color: cs.error, fontSize: 12)),
          ),
        // Worth saying on screen: a stop phrase nobody knows about is not a feature.
        if (_run.wantListening)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(t.sttStopPhraseHint(kStopPhrases.first),
                key: const ValueKey('stt-stop-phrase-hint'),
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
          ),

        // ---- counters -----------------------------------------------------------------------
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _chip(context, '${t.sttResultsLabel}: ${_transcript.results.length}'),
          _chip(context, 'buffer resets: ${_transcript.bufferResets}',
              key: const ValueKey('stt-resets')),
          _chip(context, 'duplicates: ${_transcript.duplicatesSuppressed}',
              key: const ValueKey('stt-dupes')),
          _chip(context, 'late: ${_transcript.lateResults}', key: const ValueKey('stt-late')),
          if (widget.options.continuous)
            _chip(context, 'restarts: ${_run.restarts}', key: const ValueKey('stt-restarts')),
        ]),

        // ---- what to do with what it hears ---------------------------------------------------
        const SizedBox(height: 14),
        _header(context, t.sttModeLabel),
        RadioGroup<bool>(
          groupValue: _checkStock,
          onChanged: (v) => setState(() => _checkStock = v ?? false),
          child: Column(children: [
            RadioListTile<bool>(
              key: const ValueKey('stt-mode-plain'),
              value: false,
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(t.sttModePlain),
            ),
            RadioListTile<bool>(
              key: const ValueKey('stt-mode-stock'),
              value: true,
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(t.sttModeStock),
            ),
          ]),
        ),
        if (_checkStock && widget.catalog.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(t.sttStockNoCatalog, style: TextStyle(color: cs.error, fontSize: 12)),
          ),

        // ---- results ------------------------------------------------------------------------
        const SizedBox(height: 14),
        _header(context, t.sttResultsLabel),
        if (_transcript.results.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(t.sttNoResults, style: TextStyle(color: cs.onSurfaceVariant)),
          )
        else
          // Its OWN scroll area, with a floor and a ceiling. A long continuous run produces
          // dozens of lines, and letting them push the tuning panel off the bottom of the page
          // means scrolling past the whole transcript to reach a dial mid-session.
          Container(
            constraints: const BoxConstraints(minHeight: 120, maxHeight: 320),
            decoration: BoxDecoration(
              border: Border.all(color: cs.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: Scrollbar(
              child: ListView.builder(
                key: const ValueKey('stt-results'),
                padding: const EdgeInsets.symmetric(vertical: 4),
                shrinkWrap: true,
                itemCount: _transcript.results.length,
                itemBuilder: (context, i) {
                  final r = _transcript.results[i];
                  return Card(
                    margin: const EdgeInsets.fromLTRB(6, 3, 6, 3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          dense: true,
                          title: Text(r.text),
                          subtitle: Text([
                            '${r.at.hour.toString().padLeft(2, '0')}:'
                                '${r.at.minute.toString().padLeft(2, '0')}:'
                                '${r.at.second.toString().padLeft(2, '0')}',
                            if (r.confidence != null && r.confidence! > 0)
                              'conf ${r.confidence!.toStringAsFixed(2)}',
                            if (r.spoken != null) '${r.spoken!.inMilliseconds} ms',
                          ].join('  ·  ')),
                          onLongPress: () async {
                            await Clipboard.setData(ClipboardData(text: r.text));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(content: Text(t.sttCopied)));
                            }
                          },
                        ),
                        // One badge PER ITEM: a cashier says several in a breath, and each one
                        // needs its own answer — with the number actually left, not just "no".
                        if (_checkStock)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final c in checkUtterance(r.text, widget.catalog))
                                  _verdict(context, c),
                              ],
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

        // ---- tuning -------------------------------------------------------------------------
        const SizedBox(height: 18),
        _header(context, t.sttTuning),
        // First, because it changes what the mic button means.
        _switch(context, 'continuous', widget.options.continuous,
            (v) => _apply(widget.options.copyWith(continuous: v)),
            hint: t.sttContinuousHint),
        _localeRow(context),
        _stepper(
          context,
          label: 'pauseFor',
          // The trap from the field guide, written where it can be read while tuning.
          hint: t.sttPauseForHint,
          value: widget.options.pauseForSeconds,
          suffix: 's',
          onChange: (v) => _apply(widget.options.copyWith(pauseForSeconds: v)),
        ),
        _stepper(
          context,
          label: 'listenFor',
          value: widget.options.listenForSeconds,
          suffix: 's',
          step: 5,
          onChange: (v) => _apply(widget.options.copyWith(listenForSeconds: v)),
        ),
        _switch(context, 'partialResults', widget.options.partialResults,
            (v) => _apply(widget.options.copyWith(partialResults: v))),
        _switch(context, 'cancelOnError', widget.options.cancelOnError,
            (v) => _apply(widget.options.copyWith(cancelOnError: v))),
        _switch(context, 'onDevice', widget.options.onDevice,
            (v) => _apply(widget.options.copyWith(onDevice: v)),
            hint: t.sttOnDeviceHint),

        const SizedBox(height: 14),
        _header(context, t.sttTuningInit),
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(t.sttTuningInitHint,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
        ),
        _stepper(
          context,
          label: 'finalTimeout',
          value: widget.options.finalTimeoutMs,
          suffix: 'ms',
          step: 500,
          onChange: (v) => _apply(widget.options.copyWith(finalTimeoutMs: v), restart: true),
        ),
        _switch(context, 'androidNoBluetooth', widget.options.androidNoBluetooth,
            (v) => _apply(widget.options.copyWith(androidNoBluetooth: v), restart: true),
            hint: t.sttNoBluetoothHint),
        _switch(context, 'androidIntentLookup', widget.options.androidIntentLookup,
            (v) => _apply(widget.options.copyWith(androidIntentLookup: v), restart: true),
            hint: t.sttIntentLookupHint),
        _switch(context, 'androidAlwaysUseStop', widget.options.androidAlwaysUseStop,
            (v) => _apply(widget.options.copyWith(androidAlwaysUseStop: v), restart: true)),
        _switch(context, 'debugLogging', widget.options.debugLogging,
            (v) => _apply(widget.options.copyWith(debugLogging: v), restart: true),
            hint: t.sttDebugLoggingHint),
        // listenMode and friends are iOS-only in this plugin version; saying so is more useful
        // than offering a dial that turns nothing.
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(t.sttIosOnlyNote, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
        ),

        // ---- log ----------------------------------------------------------------------------
        const SizedBox(height: 18),
        _header(context, t.sttLog),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            _log.isEmpty ? '—' : _log.take(40).join('\n'),
            key: const ValueKey('stt-log'),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
          ),
        ),
      ],
    );
  }

  /// The catalogue's answer for one item, as a coloured badge.
  Widget _verdict(BuildContext context, SttStockCheck c) {
    final t = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final ext = brandColors(context);
    final name = c.displayName;
    final left = c.remaining ?? 0;

    final (String label, Color bg, Color fg) = switch (c.status) {
      SttStockStatus.notFound => (t.sttStockNotFound, cs.errorContainer, cs.onErrorContainer),
      SttStockStatus.unavailable =>
        (t.sttStockUnavailable(name), cs.errorContainer, cs.onErrorContainer),
      SttStockStatus.outOfStock => (t.sttStockOut(name), cs.errorContainer, cs.onErrorContainer),
      // Short stock is not an error, it is a number the cashier has to work with.
      SttStockStatus.insufficient => (
          t.sttStockShort(name, left, c.qty),
          const Color(0xFFFFF1CC),
          const Color(0xFF7A5A00),
        ),
      SttStockStatus.ok => (
          c.remaining == null
              ? t.sttStockOkUntracked(name, c.qty)
              : t.sttStockOk(name, c.qty, left),
          ext.successContainer,
          ext.onSuccessContainer,
        ),
    };

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 190),
      child: Container(
        key: ValueKey('stt-verdict-${c.status.name}'),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Text(label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
      ),
    );
  }

  Widget _header(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text.toUpperCase(),
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );

  Widget _chip(BuildContext context, String label, {Key? key}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _localeRow(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final id = _indonesian;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Expanded(child: Text('localeId')),
            Flexible(
              child: DropdownButton<String?>(
                key: const ValueKey('stt-locale'),
                isExpanded: true,
                value: widget.options.localeId,
                hint: Text(id == null ? t.sttLocaleAuto : '${t.sttLocaleAuto} (${id.id})'),
                items: [
                  DropdownMenuItem(value: null, child: Text(t.sttLocaleAuto)),
                  for (final l in _run.locales)
                    DropdownMenuItem(
                      value: l.id,
                      child: Text('${l.id}${l.isIndonesian ? '  ★' : ''}',
                          overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => _apply(
                    v == null ? widget.options.copyWith(clearLocale: true)
                              : widget.options.copyWith(localeId: v)),
              ),
            ),
          ]),
          Text(
            id == null ? t.sttNoIndonesian : t.sttIndonesianFound(id.id),
            style: TextStyle(fontSize: 11, color: id == null ? cs.error : cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _stepper(
    BuildContext context, {
    required String label,
    required int value,
    required String suffix,
    required void Function(int) onChange,
    int step = 1,
    String? hint,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(label)),
            IconButton(
              key: ValueKey('stt-$label-down'),
              onPressed: () => onChange(value - step),
              icon: const Icon(Icons.remove_circle_outline),
            ),
            SizedBox(
              width: 74,
              child: Text('$value $suffix',
                  key: ValueKey('stt-$label-value'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            IconButton(
              key: ValueKey('stt-$label-up'),
              onPressed: () => onChange(value + step),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ]),
          if (hint != null)
            Text(hint, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _switch(BuildContext context, String label, bool value, void Function(bool) onChange,
      {String? hint}) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(label)),
            Switch(key: ValueKey('stt-$label'), value: value, onChanged: onChange),
          ]),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(hint, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            ),
        ],
      ),
    );
  }
}
