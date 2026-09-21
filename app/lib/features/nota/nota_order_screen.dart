import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/brand.dart';
import '../../core/money.dart';
import '../../core/order_math.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../data/session.dart';
import '../../l10n/app_localizations.dart';
import '../order/staged_order.dart';
import '../stt/stt_stock_check.dart';
import 'nota_models.dart';
import 'nota_order.dart';

/// A read nota, turned into the till's order — the same way a spoken order is.
///
/// Every line is checked against the catalogue with the voice matcher and shown in voice's four
/// columns; lines can be removed; a line that is not in the catalogue blocks Selesai. Then it ends
/// where voice ends — **Tambah ke keranjang** into the till's cart, or **Selesai** through the
/// existing open-bill or payment flow (`staged_order.dart`). This screen adds no money path.
///
/// The shop's price is charged. Where the paper says otherwise the line shows it, and that is all.
class NotaOrderScreen extends ConsumerWidget {
  const NotaOrderScreen({super.key, required this.reading});

  final NotaReading reading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final session = ref.watch(sessionProvider);
    final catalog = session == null
        ? null
        : ref.watch(catalogProvider(session.outletId)).valueOrNull;
    return Scaffold(
      appBar: BrandAppBar(title: Text(t.notaOrderTitle)),
      body: SafeArea(
        child: NotaOrderBody(
          lines: stageNotaReading(reading, catalog?.products ?? const []),
          notaNumber: reading.notaNumber,
          taxRule: catalog?.taxRule,
          onAddToCart: (checks) => addStagedToCart(ref, checks),
          onFinish: (checks) => finishStagedOrder(context, ref, checks),
        ),
      ),
    );
  }
}

/// The staged list itself. Injectable so it is tested without a catalogue provider or a server.
class NotaOrderBody extends StatefulWidget {
  const NotaOrderBody({
    super.key,
    required this.lines,
    required this.taxRule,
    required this.onAddToCart,
    required this.onFinish,
    this.notaNumber,
  });

  final List<NotaOrderLine> lines;
  final String? notaNumber;
  final TaxRule? taxRule;
  final void Function(List<SttStockCheck>) onAddToCart;
  final Future<bool> Function(List<SttStockCheck>) onFinish;

  @override
  State<NotaOrderBody> createState() => _NotaOrderBodyState();
}

class _NotaOrderBodyState extends State<NotaOrderBody> {
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  late final List<NotaOrderLine> _lines = List.of(widget.lines);
  bool _submitting = false;

  int get _blocking => _lines.where((l) => l.blocks).length;
  int get _subtotal => _lines.fold(0, (a, l) => a + l.lineTotal);
  List<SttStockCheck> get _checks => [for (final l in _lines) l.check];

  bool get _canCommit => _lines.isNotEmpty && _blocking == 0 && !_submitting;

  Future<void> _finish() async {
    if (!_canCommit) return;
    setState(() => _submitting = true);
    final ok = await widget.onFinish(_checks);
    if (!mounted) return;
    // A failed submit leaves the bill on screen: nothing was recorded, so nothing may be cleared.
    setState(() {
      _submitting = false;
      if (ok) _lines.clear();
    });
    if (ok && mounted) Navigator.of(context).maybePop();
  }

  void _addToCart() {
    if (!_canCommit) return;
    widget.onAddToCart(_checks);
    setState(_lines.clear);
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final preview = previewTotals(subtotal: _subtotal, tax: widget.taxRule);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.notaNumber != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(t.notaOrderFrom(widget.notaNumber!),
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
          ),
        const SizedBox(height: 8),
        _headerRow(context),
        Expanded(
          child: _lines.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(t.notaOrderEmpty,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: cs.onSurfaceVariant)),
                  ),
                )
              : ListView.builder(
                  itemCount: _lines.length,
                  itemBuilder: (context, i) => _row(context, i),
                ),
        ),

        // ---- totals and actions — the same block as voice ----------------------------------
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
                    key: const ValueKey('nota-order-total'),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              ]),
              if (_blocking > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(t.voiceFixLines(_blocking),
                      key: const ValueKey('nota-order-blocked'),
                      style: TextStyle(fontSize: 12, color: cs.error)),
                ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      key: const ValueKey('nota-order-add-to-cart'),
                      onPressed: _canCommit ? _addToCart : null,
                      child: Text(t.voiceAddToCart, textAlign: TextAlign.center),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 48,
                    child: FilledButton(
                      key: const ValueKey('nota-order-selesai'),
                      onPressed: _canCommit ? _finish : null,
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
    final style = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant);
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

  /// What is wrong with a line, in the order a cashier needs it: a line that can't be sold at all
  /// first, then stock, then the paper's price. Each is its own sentence.
  List<({String text, bool fatal})> _problems(BuildContext context, NotaOrderLine l) {
    final t = AppLocalizations.of(context)!;
    final c = l.check;
    final out = <({String text, bool fatal})>[];
    if (l.qtyUnreadable) out.add((text: t.notaQtyUnreadable, fatal: true));
    // Red for what blocks (the server would refuse it), amber for what only warns.
    switch (c.status) {
      case SttStockStatus.notFound:
        out.add((text: t.sttStockNotFound, fatal: true));
      case SttStockStatus.unavailable:
        out.add((text: t.sttStockUnavailable(c.displayName), fatal: false));
      case SttStockStatus.outOfStock:
        out.add((text: t.sttStockOut(c.displayName), fatal: true));
      case SttStockStatus.insufficient:
        out.add((text: t.sttStockShort(c.displayName, c.remaining ?? 0, c.qty), fatal: true));
      case SttStockStatus.ok:
        break;
    }
    if (l.priceDiffers) {
      out.add((text: t.notaPriceOnPaper(formatRupiah(l.writtenUnitPrice!)), fatal: false));
    }
    return out;
  }

  Widget _row(BuildContext context, int i) {
    final t = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final l = _lines[i];
    // Not in the catalogue: show the paper's own words, so the cashier sees what was read.
    final name = l.notFound ? l.rawText : l.check.displayName;
    final problems = _problems(context, l);
    return Container(
      color: i.isOdd ? cs.surfaceContainerHighest.withValues(alpha: 0.4) : null,
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
                for (final (k, p) in problems.indexed)
                  Text(p.text,
                      key: ValueKey('nota-order-problem-$i-$k'),
                      style: TextStyle(
                          fontSize: 11, color: p.fatal ? cs.error : const Color(0xFF7A5A00))),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text('${l.qty}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, fontFeatures: tabular)),
          ),
          Expanded(
            flex: 3,
            child: Text(formatRupiah(l.unitPrice),
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 13, fontFeatures: tabular)),
          ),
          Expanded(
            flex: 3,
            child: Text(formatRupiah(l.lineTotal),
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, fontFeatures: tabular)),
          ),
          SizedBox(
            width: 36,
            child: IconButton(
              key: ValueKey('nota-order-remove-$i'),
              tooltip: t.removeItem,
              visualDensity: VisualDensity.compact,
              onPressed: _submitting ? null : () => setState(() => _lines.removeAt(i)),
              icon: Icon(Icons.close, size: 18, color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
