import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../core/brand.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/api_client.dart';
import '../../l10n/app_localizations.dart';
import 'nota_models.dart';
import 'nota_photo_viewer.dart';

enum _Stage { idle, reading, done, failed }

/// Longest edge a nota photo is downscaled to before upload. One number, one place, because it
/// is the cost dial for the whole feature (input tokens scale with pixel area).
const double kNotaMaxPixels = 600;

/// Photograph a handwritten nota and show what DPOS reads off it.
///
/// Read-only by design: nothing is saved and no sale is created. This screen exists to find out
/// how well real slips read before anything is built on top of the result.
class NotaReaderScreen extends ConsumerStatefulWidget {
  const NotaReaderScreen({super.key});

  @override
  ConsumerState<NotaReaderScreen> createState() => _NotaReaderScreenState();
}

class _NotaReaderScreenState extends ConsumerState<NotaReaderScreen> {
  final _picker = ImagePicker();

  _Stage _stage = _Stage.idle;
  File? _photo;

  /// The picked photo's bytes, shown via [Image.memory]. Displaying from memory rather than the
  /// file path sidesteps Flutter's path-keyed image cache, which can keep showing the previous
  /// photo when the picker reuses a cache filename.
  Uint8List? _photoBytes;
  NotaReading? _reading;
  String? _error;

  /// Pan/zoom state of the photo viewer; reset whenever a new photo arrives.
  final _viewer = TransformationController();

  @override
  void dispose() {
    _viewer.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    final t = AppLocalizations.of(context)!;
    XFile? picked;
    try {
      // Input tokens scale with pixel AREA, so this is the cost dial: measured on one nota,
      // 600px costs ~641 image tokens against ~4,469 at 1600px — roughly Rp 106 vs Rp 416 of
      // input per read. It buys almost no speed (the model takes ~4s either way), only money.
      // The open risk is legibility: a faint pencil digit may not survive the downscale, so
      // compare a real slip at both sizes before treating this as settled.
      picked = await _picker.pickImage(
        source: source,
        maxWidth: kNotaMaxPixels,
        maxHeight: kNotaMaxPixels,
        imageQuality: 85,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.failed;
        _error = t.notaCameraDenied;
      });
      return;
    }
    if (picked == null || !mounted) return; // cancelled
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _photo = File(picked!.path);
      _photoBytes = bytes;
      _reading = null;
      _error = null;
      // A new photo starts un-zoomed, at the top.
      _viewer.value = Matrix4.identity();
    });
    await _read();
  }

  Future<void> _read() async {
    final photo = _photo;
    if (photo == null) return;
    final t = AppLocalizations.of(context)!;
    setState(() => _stage = _Stage.reading);
    try {
      final sentBytes = _photoBytes?.length ?? 0;
      final json = await ref.read(apiClientProvider).readNota(photo.path);
      if (!mounted) return;
      // Logged so a reading can be pulled off the device with `adb logcat -s flutter:V` and
      // compared against the paper. Contains whatever was written on the slip, customer name
      // included — fine while this is being trialled on your own nota, not for a live fleet.
      debugPrint('NOTA_READ sent=${sentBytes}B maxPx=${kNotaMaxPixels.toInt()} '
          'result=${jsonEncode(json)}');
      setState(() {
        _reading = NotaReading.fromJson(json);
        _stage = _Stage.done;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final status = e.response?.statusCode;
      final code =
          e.response?.data is Map ? (e.response!.data as Map)['code'] : null;
      setState(() {
        _stage = _Stage.failed;
        _error = switch ((status, code)) {
          (415, _) => t.notaErrorUnsupported,
          (413, _) => t.notaErrorTooLarge,
          (_, 'NOTA_EXTRACTION_UNPARSEABLE') => t.notaErrorUnreadable,
          _ => t.notaErrorGeneric('${status ?? 'network'}'),
        };
      });
    }
  }

  void _reset() => setState(() {
        _stage = _Stage.idle;
        _photo = null;
        _photoBytes = null;
        _reading = null;
        _error = null;
        _viewer.value = Matrix4.identity();
      });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final hasPhoto = _photoBytes != null;
    return Scaffold(
      appBar: BrandAppBar(title: Text(t.notaTitle)),
      body: SafeArea(
        // The photo viewer sits OUTSIDE the scrolling list. Nested inside it, the list and the
        // viewer fight over every vertical drag and the photo can't be panned up or down; out
        // here it pans freely, and it stays in view while the results below are scrolled —
        // which is exactly when the paper needs comparing against what was read.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasPhoto)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.38,
                  child: _photoViewer(t),
                ),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  if (!hasPhoto) _intro(t),
                  if (!hasPhoto) const SizedBox(height: 16),
                  switch (_stage) {
                    _Stage.idle => const SizedBox.shrink(),
                    _Stage.reading => _readingIndicator(t),
                    _Stage.failed => _errorCard(t),
                    _Stage.done => _ResultView(reading: _reading!),
                  },
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _stage == _Stage.reading ? null : _actions(t),
    );
  }

  Widget _intro(AppLocalizations t) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child:
                Icon(Icons.receipt_long_outlined, size: 34, color: cs.primary),
          ),
          const SizedBox(height: 14),
          Text(t.notaIntro,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _photoViewer(AppLocalizations t) => NotaPhotoViewer(
        bytes: _photoBytes!,
        controller: _viewer,
        hint: t.notaPanHint,
        fitLabel: t.notaFitImage,
        fullscreenLabel: t.notaFullscreen,
        onFullscreen: _openFullscreen,
      );

  /// The whole photo, fitted to the screen, with free pan and zoom — for reading small writing.
  void _openFullscreen() => Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
            body: InteractiveViewer(
              minScale: 1,
              maxScale: 8,
              child: Center(
                  child: Image.memory(_photoBytes!, fit: BoxFit.contain)),
            ),
          ),
        ),
      );

  Widget _readingIndicator(AppLocalizations t) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(t.notaReading,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(t.notaReadingHint,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _errorCard(AppLocalizations t) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: cs.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
              child: Text(_error ?? '',
                  style: TextStyle(color: cs.onErrorContainer))),
        ],
      ),
    );
  }

  Widget _actions(AppLocalizations t) {
    final done = _stage == _Stage.done;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(shape: const StadiumBorder()),
                icon: Icon(done
                    ? Icons.add_a_photo_outlined
                    : Icons.photo_camera_outlined),
                label: Text(
                  done
                      ? t.notaReadAnother
                      : (_photo == null ? t.notaTakePhoto : t.notaRetake),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
                onPressed: () {
                  if (done) _reset();
                  _pick(ImageSource.camera);
                },
              ),
            ),
            const SizedBox(height: 6),
            TextButton.icon(
              icon: const Icon(Icons.photo_library_outlined, size: 18),
              label: Text(t.notaChooseGallery),
              onPressed: () {
                if (done) _reset();
                _pick(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// The extraction, laid out the way the nota itself is: header fields, a line table, the total.
class _ResultView extends StatelessWidget {
  const _ResultView({required this.reading});
  final NotaReading reading;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final r = reading;
    final unreadable = t.notaUnreadable;
    final sum = r.linesSum;
    final mismatch = r.total != null && sum != null && sum != r.total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The server falls back to a fixed sample when no AI key is configured. Without saying so
        // loudly, every photo "reads" the same and it looks as if the new photo was ignored.
        if (r.model == 'stub') ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.science_outlined, color: cs.onErrorContainer),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(t.notaStubBanner,
                      style: TextStyle(
                          color: cs.onErrorContainer,
                          fontWeight: FontWeight.w600,
                          height: 1.35)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        Text(t.notaResultTitle.toUpperCase(),
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: cs.onSurfaceVariant)),
        const SizedBox(height: 8),
        _card(context, [
          _field(context, t.notaNumber, r.notaNumber, unreadable),
          _field(
            context,
            t.notaDate,
            // Day-first and locale-free: it reads exactly like the handwriting it came from, and
            // needs no locale date data (none is initialised in this app).
            r.notaDate == null
                ? null
                : DateFormat('dd-MM-yyyy').format(r.notaDate!),
            unreadable,
          ),
          _field(context, t.notaCustomer, r.customerName, unreadable),
        ]),
        const SizedBox(height: 12),
        _card(context, [
          Text(t.notaItems,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (r.items.isEmpty)
            Text(t.notaNoItems, style: TextStyle(color: cs.onSurfaceVariant))
          else
            _itemsTable(context, t),
          Divider(color: cs.outlineVariant, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(t.notaTotalWritten,
                  style: TextStyle(
                      fontWeight: FontWeight.w800, color: cs.primary)),
              Text(
                r.total == null ? unreadable : formatRupiah(r.total!),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: r.total == null ? cs.error : cs.primary,
                ),
              ),
            ],
          ),
          if (sum != null) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(t.notaLinesSum,
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                Text(formatRupiah(sum),
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              ],
            ),
          ],
          if (mismatch)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _banner(
                  context, Icons.warning_amber_rounded, t.notaTotalMismatch),
            ),
        ]),
        if (r.unclear.isNotEmpty) ...[
          const SizedBox(height: 12),
          _card(context, [
            Row(
              children: [
                Icon(Icons.help_outline, size: 18, color: cs.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(t.notaUnclearTitle,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 6),
            for (final u in r.unclear)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child:
                    Text('•  $u', style: TextStyle(color: cs.onSurfaceVariant)),
              ),
          ]),
        ],
        const SizedBox(height: 12),
        Text(
          '${t.notaConfidence(r.confidence)}  ·  '
          '${t.notaReadBy(r.model, (r.latencyMs / 1000).toStringAsFixed(1))}',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(t.notaRawData,
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SelectableText(
                  const JsonEncoder.withIndent('  ').convert(r.raw),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _itemsTable(BuildContext context, AppLocalizations t) {
    final cs = Theme.of(context).colorScheme;
    final head = TextStyle(
        fontSize: 11, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant);
    String money(int? v) => v == null ? '—' : formatRupiah(v);
    String qty(num? v) =>
        v == null ? '—' : (v == v.roundToDouble() ? '${v.toInt()}' : '$v');

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(3),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(2.2),
        3: FlexColumnWidth(2.2),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(children: [
          Text(t.notaColItem, style: head),
          Text(t.notaColQty, style: head, textAlign: TextAlign.center),
          Text(t.notaColPrice, style: head, textAlign: TextAlign.right),
          Text(t.notaColTotal, style: head, textAlign: TextAlign.right),
        ]),
        for (final l in reading.items)
          TableRow(children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              // Verbatim from the paper, so it reads like the paper.
              child: Text(l.rawText,
                  style: const TextStyle(
                      fontFamily: 'monospace', fontWeight: FontWeight.w600)),
            ),
            Text(qty(l.qty), textAlign: TextAlign.center),
            Text(money(l.unitPrice),
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 12)),
            Text(money(l.lineTotal),
                textAlign: TextAlign.right,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
      ],
    );
  }

  Widget _card(BuildContext context, List<Widget> children) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(16),
        boxShadow: kShadowE2,
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }

  /// A header field. A blank reads "Not readable" in red rather than disappearing, so the gap
  /// is obvious.
  Widget _field(
      BuildContext context, String label, String? value, String unreadable) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(label, style: TextStyle(color: cs.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(
              value ?? unreadable,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: value == null ? cs.error : null,
                fontStyle: value == null ? FontStyle.italic : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _banner(BuildContext context, IconData icon, String text) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: kBrandGold.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: cs.onSurface),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}
