import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/brand.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/api_client.dart';
import '../../data/providers.dart';
import '../../data/session.dart';
import '../../l10n/app_localizations.dart';
import '../nota/nota_models.dart';
import '../nota/nota_reader_screen.dart' show kNotaMaxPixels;
import '../order/open_bills_screen.dart';
import '../payment/payment_screen.dart';
import '../reports/reports_screen.dart';
import '../settings/settings_screen.dart';
import '../transactions/transaction_detail_screen.dart';
import '../transactions/transactions_screen.dart';
import 'nota_sale.dart';

/// The nota chat — home for a High Human Interactions merchant (specs/009-nota-reading-mode).
///
/// Send a photo of a nota; the reply is what it says; confirm it and it becomes an open transaction,
/// paid later through the existing settle flow. This shell owns everything that touches the app —
/// the camera, the server, navigation. The conversation lives in [NotaChatBody], which takes all of
/// that as plain functions so a test can drive the whole exchange with no camera and no network.
class NotaChatScreen extends ConsumerWidget {
  const NotaChatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final session = ref.watch(sessionProvider);
    final catalog =
        session == null ? null : ref.watch(catalogProvider(session.outletId)).valueOrNull;
    final api = ref.read(apiClientProvider);

    void push(Widget page) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

    return Scaffold(
      appBar: BrandAppBar(
        title: Text(t.chatTitle),
        actions: [
          IconButton(
            tooltip: t.openBillsTitle,
            icon: const Icon(Icons.pending_actions_outlined),
            onPressed: () => push(const OpenBillsScreen()),
          ),
          IconButton(
            tooltip: t.historyLabel,
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => push(const TransactionsScreen()),
          ),
          if (session?.isOwnerOrManager ?? false)
            IconButton(
              tooltip: t.reportsTitle,
              icon: const Icon(Icons.insights_outlined),
              onPressed: () => push(const ReportsScreen()),
            ),
          IconButton(
            tooltip: t.settingsTitle,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => push(const SettingsScreen()),
          ),
        ],
      ),
      body: SafeArea(
        child: session == null || catalog?.openAmountVariantId == null
            ? const Center(child: CircularProgressIndicator())
            : NotaChatBody(
                key: ValueKey(session.outletId),
                outletId: session.outletId,
                deviceId: session.deviceId,
                openAmountVariantId: catalog!.openAmountVariantId!,
                pickPhoto: pickNotaPhoto,
                readNota: api.readNota,
                createSale: (payload) async {
                  final json = await api.submitOrder(payload);
                  // A new open transaction: the open-bills list must show it next time it opens.
                  ref.invalidate(openBillsProvider(session.outletId));
                  return json;
                },
                onPay: (orderId, grandTotal) => push(
                    PaymentScreen(grandTotalPreview: grandTotal, settleOrderId: orderId)),
                onViewOrder: (orderId) => push(TransactionDetailScreen(orderId: orderId)),
              ),
      ),
    );
  }
}

/// Takes a photo (or picks one) and downscales it the same way the nota reader does: 600 px keeps
/// the read cheap without losing a legible nota. Null when the cashier backs out.
Future<Uint8List?> pickNotaPhoto(ImageSource source) async {
  final picked = await ImagePicker().pickImage(source: source);
  if (picked == null) return null;
  final resized = await FlutterImageCompress.compressWithFile(
    picked.path,
    minWidth: kNotaMaxPixels.toInt(),
    minHeight: kNotaMaxPixels.toInt(),
    quality: 85,
  );
  return resized ?? await picked.readAsBytes();
}

/// The conversation: every message, and the one question that matters — is this reading right?
class NotaChatBody extends StatefulWidget {
  final String outletId;
  final String? deviceId;
  final String openAmountVariantId;
  final Future<Uint8List?> Function(ImageSource source) pickPhoto;
  final Future<Map<String, dynamic>> Function(Uint8List bytes) readNota;

  /// Posts the confirmed nota as an open transaction; throws [DioException] when refused.
  final Future<Map<String, dynamic>> Function(Map<String, dynamic> payload) createSale;
  final void Function(String orderId, int grandTotal) onPay;
  final void Function(String orderId) onViewOrder;

  const NotaChatBody({
    super.key,
    required this.outletId,
    required this.deviceId,
    required this.openAmountVariantId,
    required this.pickPhoto,
    required this.readNota,
    required this.createSale,
    required this.onPay,
    required this.onViewOrder,
  });

  @override
  State<NotaChatBody> createState() => _NotaChatBodyState();
}

enum _Stage { asking, fixRequested, creating, created, duplicate }

sealed class _Msg {}

class _BotText extends _Msg {
  final String text;
  final bool isError;
  _BotText(this.text, {this.isError = false});
}

class _Photo extends _Msg {
  final Uint8List bytes;
  _Photo(this.bytes);
}

class _Typing extends _Msg {}

/// One reading and its answer. The clientOrderId is minted when the reading arrives, so however
/// many times "Tidak" is tapped for it, the server records one transaction (Constitution V).
class _Reading extends _Msg {
  final NotaReading reading;
  final NotaSalePlan plan;
  final String clientOrderId = const Uuid().v4();
  _Stage stage = _Stage.asking;
  String? orderId;
  int? grandTotal;
  _Reading(this.reading) : plan = NotaSalePlan.from(reading);
}

class _NotaChatBodyState extends State<NotaChatBody> {
  final List<_Msg> _msgs = [];
  final _scroll = ScrollController();
  bool _busy = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _add(_Msg m) {
    setState(() => _msgs.add(m));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send(ImageSource source) async {
    final t = AppLocalizations.of(context)!;
    Uint8List? bytes;
    try {
      bytes = await widget.pickPhoto(source);
    } catch (_) {
      if (mounted) _add(_BotText(t.notaCameraDenied, isError: true));
      return;
    }
    if (bytes == null || !mounted) return;

    _add(_Photo(bytes));
    final typing = _Typing();
    _add(typing);
    setState(() => _busy = true);
    try {
      final json = await widget.readNota(bytes);
      if (!mounted) return;
      setState(() => _msgs.remove(typing));
      _add(_Reading(NotaReading.fromJson(json)));
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _msgs.remove(typing));
      final status = e.response?.statusCode;
      final code = e.response?.data is Map ? (e.response!.data as Map)['code'] : null;
      _add(_BotText(
        switch ((status, code)) {
          (415, _) => t.notaErrorUnsupported,
          (413, _) => t.notaErrorTooLarge,
          (_, 'NOTA_EXTRACTION_UNPARSEABLE') => t.notaErrorUnreadable,
          _ => t.chatReadFailed('${code ?? status ?? 'network'}'),
        },
        isError: true,
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// "Ya" — corrections are not built yet, so nothing is recorded and the chat says so.
  void _fix(_Reading r) {
    setState(() => r.stage = _Stage.fixRequested);
    _add(_BotText(AppLocalizations.of(context)!.chatFixNotYet));
  }

  /// "Tidak" — record the nota as an open transaction.
  Future<void> _confirm(_Reading r) async {
    final t = AppLocalizations.of(context)!;
    setState(() {
      r.stage = _Stage.creating;
      _busy = true;
    });
    try {
      final json = await widget.createSale(r.plan.payload(
        clientOrderId: r.clientOrderId,
        outletId: widget.outletId,
        deviceId: widget.deviceId,
        openAmountVariantId: widget.openAmountVariantId,
        notaNumber: r.reading.notaNumber,
        customerName: r.reading.customerName,
      ));
      if (!mounted) return;
      setState(() {
        r.stage = _Stage.created;
        r.orderId = json['id'] as String?;
        r.grandTotal = (json['grandTotal'] as num?)?.toInt();
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final data = e.response?.data is Map ? e.response!.data as Map : const {};
      if (data['code'] == 'NOTA_ALREADY_RECORDED') {
        // One nota, one sale: the server refused a second transaction for this number.
        setState(() {
          r.stage = _Stage.duplicate;
          r.orderId = data['orderId'] as String?;
        });
      } else {
        // Nothing was recorded, so the question stays open and the cashier can try again.
        setState(() => r.stage = _Stage.asking);
        _add(_BotText(
            t.chatCreateFailed('${data['code'] ?? e.response?.statusCode ?? 'network'}'),
            isError: true));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Expanded(
          child: ListView(
            key: const ValueKey('chat-list'),
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            children: [
              _bubble(context, fromMe: false, child: Text(t.chatWelcome)),
              for (final m in _msgs) _render(context, m),
            ],
          ),
        ),
        // The input bar: a nota comes in as a photo, so camera and gallery are the keyboard.
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          decoration: BoxDecoration(
            color: cs.surface,
            border: Border(top: BorderSide(color: cs.outlineVariant)),
          ),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  key: const ValueKey('chat-camera'),
                  onPressed: _busy ? null : () => _send(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(t.chatCamera),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('chat-gallery'),
                  onPressed: _busy ? null : () => _send(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(t.chatGallery),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _render(BuildContext context, _Msg m) {
    final t = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return switch (m) {
      _BotText(:final text, :final isError) => _bubble(context,
          fromMe: false,
          tint: isError ? cs.errorContainer : null,
          child: Text(text, style: TextStyle(color: isError ? cs.onErrorContainer : null))),
      _Photo(:final bytes) => _bubble(context,
          fromMe: true,
          padding: const EdgeInsets.all(4),
          child: GestureDetector(
            onTap: () => showDialog(
              context: context,
              builder: (_) => Dialog(
                insetPadding: const EdgeInsets.all(8),
                child: InteractiveViewer(maxScale: 6, child: Image.memory(bytes)),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(bytes, height: 200, fit: BoxFit.cover),
            ),
          )),
      _Typing() => _bubble(context,
          fromMe: false,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 10),
            Text(t.chatReading, style: TextStyle(color: cs.onSurfaceVariant)),
          ])),
      _Reading() => _readingCard(context, m),
    };
  }

  Widget _readingCard(BuildContext context, _Reading r) {
    final t = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final ext = brandColors(context);
    final reading = r.reading;
    final plan = r.plan;
    final muted = TextStyle(color: cs.onSurfaceVariant, fontSize: 12);
    final header = [
      reading.notaNumber == null ? t.chatNoNumber : t.chatNotaHeader(reading.notaNumber!),
      if (reading.notaDate != null) DateFormat('dd-MM-yyyy').format(reading.notaDate!),
      if (reading.customerName?.isNotEmpty ?? false) reading.customerName!,
    ].join('  ·  ');

    return _bubble(
      context,
      fromMe: false,
      wide: true,
      child: Column(
        key: ValueKey('chat-reading-${r.clientOrderId}'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (reading.model == 'stub')
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: cs.errorContainer, borderRadius: BorderRadius.circular(8)),
              child: Text(t.notaStubBanner,
                  style: TextStyle(color: cs.onErrorContainer, fontSize: 12)),
            ),
          Text(header, style: const TextStyle(fontWeight: FontWeight.w700)),
          const Divider(height: 16),
          // Every line as written. Priced lines show their price; the rest say they won't be charged.
          for (final item in reading.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Text(item.rawText.isEmpty ? '—' : item.rawText)),
                  const SizedBox(width: 8),
                  _lineAmount(item, plan, t, muted),
                ],
              ),
            ),
          const Divider(height: 16),
          if (reading.total != null)
            _totalRow(t.chatWrittenTotal, formatRupiah(reading.total!), muted.copyWith(fontSize: 13)),
          if (plan.canRecord)
            _totalRow(t.chatLinesTotal, formatRupiah(plan.linesTotal),
                TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: cs.primary),
                key: const ValueKey('chat-charge-total')),
          if (plan.totalsDisagree)
            _note(context, t.chatTotalsDisagree(formatRupiah(plan.linesTotal)), warn: true),
          if (plan.usesWrittenTotal) _note(context, t.chatTotalOnly),
          if (reading.unclear.isNotEmpty)
            _note(context, t.chatUnclear(reading.unclear.join(', '))),
          const SizedBox(height: 10),
          if (!plan.canRecord)
            _note(context, t.chatNothingToCharge, warn: true)
          else
            switch (r.stage) {
              _Stage.asking => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(t.chatAskFix, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          key: const ValueKey('chat-fix-yes'),
                          onPressed: _busy ? null : () => _fix(r),
                          child: Text(t.chatFixYes, textAlign: TextAlign.center),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          key: const ValueKey('chat-fix-no'),
                          onPressed: _busy ? null : () => _confirm(r),
                          child: Text(t.chatFixNo, textAlign: TextAlign.center),
                        ),
                      ),
                    ]),
                  ],
                ),
              _Stage.fixRequested => Text('— ${t.chatFixYes}', style: muted),
              _Stage.creating => Row(children: [
                  const SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 10),
                  Text(t.chatCreating),
                ]),
              _Stage.created => Container(
                  key: const ValueKey('chat-created'),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: ext.successContainer, borderRadius: BorderRadius.circular(10)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(t.chatCreated,
                          style: TextStyle(
                              color: ext.onSuccessContainer, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      if (r.orderId != null)
                        FilledButton.icon(
                          key: const ValueKey('chat-pay'),
                          onPressed: () =>
                              widget.onPay(r.orderId!, r.grandTotal ?? plan.linesTotal),
                          icon: const Icon(Icons.payments_outlined),
                          label: Text(t.chatPayNow),
                        ),
                    ],
                  ),
                ),
              _Stage.duplicate => Column(
                  key: const ValueKey('chat-duplicate'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _note(context, t.chatAlreadyRecorded(reading.notaNumber ?? '?'), warn: true),
                    if (r.orderId != null)
                      OutlinedButton(
                        onPressed: () => widget.onViewOrder(r.orderId!),
                        child: Text(t.chatViewTransaction),
                      ),
                  ],
                ),
            },
        ],
      ),
    );
  }

  Widget _lineAmount(NotaLine item, NotaSalePlan plan, AppLocalizations t, TextStyle muted) {
    // When the sale is the written total, individual lines are descriptions, not charges.
    if (plan.usesWrittenTotal) return const SizedBox.shrink();
    // The same price rule the sale uses, per line — never a lookup by text, which would show the
    // wrong price when two lines read the same.
    final amount = notaLineAmount(item);
    if (amount != null) {
      return Text(formatRupiah(amount),
          style: const TextStyle(fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()]));
    }
    return Text(t.chatNotCharged, style: muted.copyWith(fontStyle: FontStyle.italic));
  }

  Widget _totalRow(String label, String value, TextStyle style, {Key? key}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(child: Text(label, style: style.copyWith(fontWeight: FontWeight.w600))),
          Text(value, key: key, style: style.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
        ]),
      );

  Widget _note(BuildContext context, String text, {bool warn = false}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: warn ? cs.errorContainer : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 12, color: warn ? cs.onErrorContainer : cs.onSurfaceVariant)),
    );
  }

  Widget _bubble(BuildContext context,
      {required bool fromMe,
      required Widget child,
      bool wide = false,
      Color? tint,
      EdgeInsets padding = const EdgeInsets.fromLTRB(12, 10, 12, 10)}) {
    final cs = Theme.of(context).colorScheme;
    final maxW = MediaQuery.sizeOf(context).width * (wide ? 0.9 : 0.78);
    return Align(
      alignment: fromMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxW),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: padding,
        decoration: BoxDecoration(
          color: tint ?? (fromMe ? cs.primaryContainer : cs.surface),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(fromMe ? 16 : 4),
            bottomRight: Radius.circular(fromMe ? 4 : 16),
          ),
          boxShadow: kShadowE2,
        ),
        child: child,
      ),
    );
  }
}
