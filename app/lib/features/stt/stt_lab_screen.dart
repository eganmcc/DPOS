import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/app_dialog.dart';
import '../../core/brand.dart';
import '../../l10n/app_localizations.dart';
import 'stt_engine.dart';
import 'stt_options.dart';
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
    return Scaffold(
      appBar: BrandAppBar(title: Text(t.sttLabTitle)),
      body: SafeArea(
        child: SttLabBody(
          engine: ref.watch(sttEngineProvider),
          options: ref.watch(sttOptionsProvider),
          onOptions: (o) => ref.read(sttOptionsProvider.notifier).set(o),
          requestMicPermission: () async => (await Permission.microphone.request()).isGranted,
          openSettings: openAppSettings,
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

  const SttLabBody({
    super.key,
    required this.engine,
    required this.options,
    required this.onOptions,
    required this.requestMicPermission,
    required this.openSettings,
    this.clock = DateTime.now,
  });

  @override
  State<SttLabBody> createState() => _SttLabBodyState();
}

class _SttLabBodyState extends State<SttLabBody> {
  late final SttTranscript _transcript = SttTranscript(clock: widget.clock);
  final List<String> _log = [];
  List<SttLocale> _locales = const [];

  bool _ready = false;
  bool _listening = false;
  String _status = '—';
  double _level = 0;

  @override
  void initState() {
    super.initState();
    _init();
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

  Future<void> _init({bool restart = false}) async {
    if (!widget.engine.isSupported) {
      setState(() => _status = 'unsupported');
      return;
    }
    final ok = await widget.engine.initialize(
      options: widget.options,
      restart: restart,
      onStatus: (s) {
        if (!mounted) return;
        setState(() {
          _note('onStatus: $s');
          _status = s;
          // One of the four ways a session ends — flush, or the words are lost.
          if (s == 'done' || s == 'notListening') {
            _transcript.commit();
            _listening = false;
            _level = 0;
          }
        });
      },
      onError: (f) {
        if (!mounted) return;
        setState(() {
          _note('onError: ${f.code} permanent=${f.permanent}');
          _transcript.commit();
          _listening = false;
          _level = 0;
          _status = f.code;
        });
      },
    );
    final locales = ok ? await widget.engine.locales() : const <SttLocale>[];
    if (!mounted) return;
    setState(() {
      _ready = ok;
      _locales = locales;
      _note(restart ? 'initialize (restart) → $ok' : 'initialize → $ok');
      if (!ok) _status = 'unavailable';
    });
  }

  /// The device's own Indonesian locale, whatever it calls it — `in_ID` on most Android builds.
  SttLocale? get _indonesian {
    for (final l in _locales) {
      if (l.isIndonesian) return l;
    }
    return null;
  }

  String? get _effectiveLocale => widget.options.localeId ?? _indonesian?.id;

  Future<void> _toggle() async {
    final t = AppLocalizations.of(context)!;
    if (_listening) {
      await widget.engine.stop();
      if (!mounted) return;
      setState(() {
        _note('stop (by user)');
        _transcript.commit();
        _listening = false;
        _level = 0;
      });
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

    setState(() {
      _transcript.startSession();
      _listening = true;
      _status = 'listening';
      _note('listen(locale=${_effectiveLocale ?? "default"}, '
          'pauseFor=${widget.options.pauseForSeconds}s, '
          'listenFor=${widget.options.listenForSeconds}s, '
          'partial=${widget.options.partialResults}, onDevice=${widget.options.onDevice})');
    });

    await widget.engine.listen(
      options: widget.options.copyWith(localeId: _effectiveLocale),
      onResult: (text, confidence, isFinal) {
        if (!mounted) return;
        setState(() {
          _note('onResult${isFinal ? " FINAL" : ""}: "$text"'
              '${confidence == null ? "" : " conf=${confidence.toStringAsFixed(2)}"}');
          _transcript.onResult(text, confidence, isFinal: isFinal);
        });
      },
      onSoundLevel: (l) {
        if (mounted) setState(() => _level = l);
      },
    );
  }

  Future<void> _apply(SttOptions next, {bool restart = false}) async {
    widget.onOptions(next);
    if (restart) {
      _note('re-initialising for an initialize-level option');
      await _init(restart: true);
    }
  }

  /// Everything a tuning round produced, in one paste.
  Future<void> _copyDiagnostics() async {
    final t = AppLocalizations.of(context)!;
    final b = StringBuffer()
      ..writeln('DPOS STT diagnostics')
      ..writeln('ready: $_ready  status: $_status  supported: ${widget.engine.isSupported}')
      ..writeln('effective locale: ${_effectiveLocale ?? "(device default)"}')
      ..writeln('locales offered: ${_locales.map((l) => l.id).join(", ")}')
      ..writeln('indonesian detected as: ${_indonesian?.id ?? "NONE"}')
      ..writeln('options:')
      ..writeln(widget.options.describe())
      ..writeln('counters: bufferResets=${_transcript.bufferResets} '
          'duplicatesSuppressed=${_transcript.duplicatesSuppressed} '
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
            child: Text('${t.sttStatus}: $_status',
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
            _transcript.live.isEmpty ? t.sttSaySomething : _transcript.live,
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
          value: (_level.abs() / 10).clamp(0.0, 1.0),
          minHeight: 6,
          backgroundColor: cs.surfaceContainerHighest,
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              key: const ValueKey('stt-mic'),
              onPressed: _ready ? _toggle : null,
              style: _listening
                  ? FilledButton.styleFrom(backgroundColor: cs.error, foregroundColor: cs.onError)
                  : null,
              icon: Icon(_listening ? Icons.stop : Icons.mic),
              label: Text(_listening ? t.sttStop : t.sttListen),
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
        if (!_ready)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(t.sttNoRecognizer, style: TextStyle(color: cs.error, fontSize: 12)),
          ),

        // ---- counters -----------------------------------------------------------------------
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _chip(context, '${t.sttResultsLabel}: ${_transcript.results.length}'),
          _chip(context, 'buffer resets: ${_transcript.bufferResets}',
              key: const ValueKey('stt-resets')),
          _chip(context, 'duplicates: ${_transcript.duplicatesSuppressed}',
              key: const ValueKey('stt-dupes')),
        ]),

        // ---- results ------------------------------------------------------------------------
        const SizedBox(height: 14),
        _header(context, t.sttResultsLabel),
        if (_transcript.results.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(t.sttNoResults, style: TextStyle(color: cs.onSurfaceVariant)),
          )
        else
          for (final r in _transcript.results)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 3),
              child: ListTile(
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
            ),

        // ---- tuning -------------------------------------------------------------------------
        const SizedBox(height: 18),
        _header(context, t.sttTuning),
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
                  for (final l in _locales)
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
