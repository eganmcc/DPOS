import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/brand.dart';
import '../../core/formatters.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/tts.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../data/session.dart';
import '../../l10n/app_localizations.dart';
import '../order/cart.dart';
import '../receipt/receipt_screen.dart';
import '../scanner/rongta_printer.dart';
import 'brand_mark.dart';
import 'edc_screen.dart';
import 'payment_tenders.dart';

/// Payment type, as a tab. Matches the visual-system redesign: the cashier picks *what kind* of
/// payment this is, and the pane below shows that one flow at full width.
enum PayTab { cash, qris, card, wallet }

/// Payment screen — "Pembayaran", redesign v2 per `DPOS Checkout Redesign.dc.html`.
///
/// Structure fixed across tabs: app bar → total block → segmented tab track → content pane →
/// pinned primary button. Only the pane swaps. The old grid screen (`checkout_screen.dart`) is
/// kept in the tree, unused, until this has been through a few real shifts.
class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key, required this.grandTotalPreview, this.settleOrderId});

  final int grandTotalPreview;

  /// Non-null → settle an existing open bill (no cart, no offline queue).
  final String? settleOrderId;
  bool get isSettle => settleOrderId != null;

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  PayTab _tab = PayTab.cash;

  /// Which card / wallet is selected inside its tab.
  String _cardId = 'CARD_DEBIT';
  String _walletId = 'EWALLET_SHOPEEPAY';

  final _tender = TextEditingController();
  int? _selectedTender;
  bool _submitting = false;
  String? _error;

  /// Set once the simulated EDC approves. A card sale cannot complete without it.
  EdcResult? _edc;

  /// Reference for the selected wallet, minted when the wallet changes.
  String _walletRef = const Uuid().v4();

  @override
  void dispose() {
    _tender.dispose();
    super.dispose();
  }

  /// The `PaymentMethod` this screen will post.
  String get _method => switch (_tab) {
        PayTab.cash => 'CASH',
        PayTab.qris => 'QRIS_SIMULATED',
        PayTab.card => _cardId,
        PayTab.wallet => _walletId,
      };

  int? get _tenderValue => int.tryParse(_tender.text.replaceAll(RegExp(r'[^0-9]'), ''));
  int get _change => (_tenderValue ?? 0) - widget.grandTotalPreview;

  List<int> get _quickTenders {
    final g = widget.grandTotalPreview;
    int ceilTo(int step) => ((g + step - 1) ~/ step) * step;
    final set = <int>{g, ceilTo(5000), ceilTo(10000), ceilTo(50000), 50000, 100000}
        .where((v) => v >= g)
        .toList()
      ..sort();
    return set.take(3).toList(); // the design shows three chips
  }

  void _setTender(int v) => setState(() {
        _tender.value = ThousandsTextInputFormatter()
            .formatEditUpdate(const TextEditingValue(), TextEditingValue(text: v.toString()));
        _selectedTender = v;
      });

  /// Changing tab or tender clears anything the previous one collected, so a card approval can
  /// never ride along on a different payment method.
  void _selectTab(PayTab tab) => setState(() {
        _tab = tab;
        _error = null;
        _edc = null;
      });

  void _selectCard(String id) => setState(() {
        _cardId = id;
        _edc = null; // a new card means a new authorization
        _error = null;
      });

  void _selectWallet(String id) => setState(() {
        _walletId = id;
        _walletRef = const Uuid().v4();
        _error = null;
      });

  Future<void> _runEdc() async {
    final result = await Navigator.of(context).push<EdcResult>(
      MaterialPageRoute(
        builder: (_) => EdcScreen(amount: widget.grandTotalPreview, tenderId: _cardId),
      ),
    );
    if (!mounted || result == null) return; // cancelled or declined — stay put
    setState(() => _edc = result);
    await _submit();
  }

  Future<void> _submit() async {
    final t = AppLocalizations.of(context)!;
    final session = ref.read(sessionProvider)!;
    if (_tab == PayTab.cash && (_tenderValue ?? 0) < widget.grandTotalPreview) {
      setState(() => _error = t.errorCashShort);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final edcJson = _edc?.toJson();
      final walletJson = _tab == PayTab.wallet ? {'reference': _walletRef} : null;

      OrderResult? result;
      if (widget.isSettle) {
        final json = await ref.read(apiClientProvider).settleOrder(
              widget.settleOrderId!,
              clientSettleId: const Uuid().v4(),
              method: _method,
              tendered: _tab == PayTab.cash ? _tenderValue : null,
              edc: edcJson,
              wallet: walletJson,
            );
        result = OrderResult.fromJson(json);
        ref.invalidate(openBillsProvider(session.outletId));
        ref.invalidate(catalogProvider(session.outletId));
      } else {
        final cart = ref.read(cartProvider.notifier);
        final payload = cart.buildPayload(
          clientOrderId: const Uuid().v4(),
          outletId: session.outletId,
          deviceId: session.deviceId,
          method: _method,
          tendered: _tab == PayTab.cash ? _tenderValue : null,
          edc: edcJson,
          wallet: walletJson,
        );
        result = await ref.read(syncQueueProvider).submit(payload);
        cart.clear();
        if (result != null) ref.invalidate(catalogProvider(session.outletId));
      }
      if (!mounted) return;
      if (result != null) {
        announceReceived(result.grandTotal);
        final cat = ref.read(catalogProvider(session.outletId)).valueOrNull;
        // openDrawer: only a cash sale pops the drawer.
        printReceiptSmart(result,
            businessName: cat?.merchantName,
            outletName: cat?.outletName,
            openDrawer: _tab == PayTab.cash);
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => ReceiptScreen(order: result!)),
        );
      } else {
        Navigator.of(context).popUntil((r) => r.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.msgQueuedOffline)));
      }
    } on DioException catch (e) {
      final code = e.response?.data is Map ? (e.response!.data as Map)['code'] : null;
      setState(() => _error = code == 'UMI_TENDER_NOT_AVAILABLE'
          ? t.tenderNotAvailable
          : '${t.errorSignIn} (${e.response?.statusCode ?? 'network'})');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final session = ref.watch(sessionProvider);
    final catalog =
        session == null ? null : ref.watch(catalogProvider(session.outletId)).valueOrNull;

    // Fails CLOSED: card and e-wallet appear only when the catalog positively says this
    // merchant is not UMI. Unknown (cold start, stale cache, or an API older than
    // businessSize) means cash and QRIS only.
    final tabs = cardTendersAllowed(catalog) ? PayTab.values : [PayTab.cash, PayTab.qris];
    if (!tabs.contains(_tab)) _tab = PayTab.cash;

    return Scaffold(
      appBar: BrandAppBar(title: Text(t.paymentTitle)),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.totalDue.toUpperCase(),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.9,
                          color: cs.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Text(formatRupiah(widget.grandTotalPreview),
                      style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: cs.primary,
                          fontFeatures: const [FontFeature.tabularFigures()])),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: _TabTrack(
                tabs: tabs,
                selected: _tab,
                labelOf: (tab) => _tabLabel(t, tab),
                onSelected: _selectTab,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: switch (_tab) {
                  PayTab.cash => _cashPane(t, cs),
                  PayTab.qris => _qrisPane(t, cs),
                  PayTab.card => _cardPane(t, cs),
                  PayTab.wallet => _walletPane(t, cs),
                },
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Text(_error!, style: TextStyle(color: cs.error)),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: _primaryButton(t),
            ),
          ],
        ),
      ),
    );
  }

  String _tabLabel(AppLocalizations t, PayTab tab) => switch (tab) {
        PayTab.cash => t.methodCash,
        PayTab.qris => t.methodQris,
        PayTab.card => t.tenderGroupCard,
        PayTab.wallet => t.tabEwallet,
      };

  // ---------------------------------------------------------------- panes

  Widget _cashPane(AppLocalizations t, ColorScheme cs) {
    final ext = brandColors(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final v in _quickTenders) ...[
              if (v != _quickTenders.first) const SizedBox(width: 8),
              Expanded(
                child: _PillChip(
                  label: v == widget.grandTotalPreview ? t.tenderExact : formatRupiah(v),
                  selected: _selectedTender == v,
                  onTap: () => _setTender(v),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: cs.surface,
            border: Border.all(color: cs.outlineVariant),
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.amountReceivedLabel.toUpperCase(),
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
              TextField(
                controller: _tender,
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandsTextInputFormatter()],
                style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()]),
                decoration: const InputDecoration(
                  prefixText: 'Rp ',
                  border: InputBorder.none,
                  filled: false,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (_) => setState(() => _selectedTender = null),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (_tenderValue != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: ext.successContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(t.labelChange,
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600, color: ext.onSuccessContainer)),
                Text(formatRupiah(_change < 0 ? 0 : _change),
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: ext.onSuccessContainer,
                        fontFeatures: const [FontFeature.tabularFigures()])),
              ],
            ),
          ),
        const Spacer(),
        _otherMethodsStrip(t, cs),
      ],
    );
  }

  Widget _qrisPane(AppLocalizations t, ColorScheme cs) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: _QrFrame(
              payload: 'DPOS-QRIS-SIM|amount=${widget.grandTotalPreview}',
              size: 176,
              hint: t.qrisAnyAppHint,
            ),
          ),
        ),
        _otherMethodsStrip(t, cs),
      ],
    );
  }

  Widget _cardPane(AppLocalizations t, ColorScheme cs) {
    final cards = kAllTenders.where((x) => x.isCard).toList();
    final approved = _edc;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _paneLabel(t.chooseCard, cs),
        const SizedBox(height: 10),
        for (final c in cards) ...[
          _SelectableRow(
            selected: _cardId == c.id,
            onTap: () => _selectCard(c.id),
            leading: BrandMarkRow(assets: c.assets, height: 17),
            label: c.label(t),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 10),
        if (approved == null)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border.all(color: cs.outlineVariant),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.credit_card, size: 22, color: cs.primary),
                ),
                const SizedBox(height: 10),
                Text(t.edcPromptCard,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
              ],
            ),
          )
        else
          _ApprovedSlip(edc: approved),
      ],
    );
  }

  Widget _walletPane(AppLocalizations t, ColorScheme cs) {
    final wallets = kAllTenders.where((x) => x.isEwallet).toList();
    final selected = tenderById(_walletId);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _paneLabel(t.chooseWallet, cs),
        const SizedBox(height: 10),
        for (final w in wallets) ...[
          _SelectableRow(
            selected: _walletId == w.id,
            onTap: () => _selectWallet(w.id),
            leading: BrandMark(asset: w.assets.first, height: 18),
            label: w.label(t),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 14),
        Center(
          child: _QrFrame(
            payload: 'DPOS-$_walletId-SIM|amount=${widget.grandTotalPreview}|ref=$_walletRef',
            size: 148,
            hint: t.walletScanApp(selected.label(t)),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _paneLabel(String text, ColorScheme cs) => Text(
        text.toUpperCase(),
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7,
            color: cs.onSurfaceVariant),
      );

  /// Quick jump to any card or wallet without leaving the current tab. Hidden for UMI, which
  /// has none of them.
  Widget _otherMethodsStrip(AppLocalizations t, ColorScheme cs) {
    final session = ref.watch(sessionProvider);
    final catalog =
        session == null ? null : ref.watch(catalogProvider(session.outletId)).valueOrNull;
    if (!cardTendersAllowed(catalog)) return const SizedBox.shrink();

    final others = kAllTenders.where((x) => x.isCard || x.isEwallet).toList();
    return Container(
      padding: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _paneLabel(t.otherMethods, cs),
          const SizedBox(height: 8),
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: others.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final tender = others[i];
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    if (tender.isCard) {
                      _selectCard(tender.id);
                      _selectTab(PayTab.card);
                    } else {
                      _selectWallet(tender.id);
                      _selectTab(PayTab.wallet);
                    }
                  },
                  child: Container(
                    width: 56,
                    height: 56,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      border: Border.all(color: cs.outlineVariant),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        BrandMarkRow(assets: tender.assets, height: 12, spacing: 3),
                        // Debit and credit share the same scheme marks, so the tile needs a word.
                        if (tender.isCard) ...[
                          const SizedBox(height: 3),
                          Text(tender.label(t).split(' ').last,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 8.5, color: cs.onSurfaceVariant)),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- action

  Widget _primaryButton(AppLocalizations t) {
    final needsEdc = _tab == PayTab.card && _edc == null;
    final (label, icon) = switch (_tab) {
      PayTab.cash => (t.actionComplete, Icons.check),
      PayTab.qris => (t.actionMarkPaid, Icons.check),
      PayTab.wallet => (t.actionMarkPaid, Icons.check),
      PayTab.card => needsEdc
          ? (t.actionProcessPayment, Icons.credit_card)
          : (t.actionComplete, Icons.check),
    };

    return SizedBox(
      height: 52,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(shape: const StadiumBorder()),
        icon: _submitting
            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(icon, size: 18),
        label: Text(_submitting ? '' : label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        onPressed: _submitting ? null : (needsEdc ? _runEdc : _submit),
      ),
    );
  }
}

// ------------------------------------------------------------------ pieces

/// Segmented control: pills inside a track. Material's SegmentedButton can't be themed into this
/// shape without a fight, so it is drawn directly (per the design's Flutter notes).
class _TabTrack extends StatelessWidget {
  const _TabTrack({
    required this.tabs,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
  });

  final List<PayTab> tabs;
  final PayTab selected;
  final String Function(PayTab) labelOf;
  final ValueChanged<PayTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final tab in tabs)
            Expanded(
              child: GestureDetector(
                onTap: () => onSelected(tab),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: tab == selected ? cs.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: tab == selected
                        ? [
                            BoxShadow(
                              color: cs.primary.withValues(alpha: 0.12),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    labelOf(tab),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: tab == selected ? cs.primary : cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The one selected-state in this design: gold 2px border over a light-gold tint.
BoxDecoration _selectableDecoration(BuildContext context, bool selected) {
  final cs = Theme.of(context).colorScheme;
  final light = Theme.of(context).brightness == Brightness.light;
  return BoxDecoration(
    color: selected
        ? (light ? const Color(0xFFFBEDBB) : kBrandGold.withValues(alpha: 0.18))
        : cs.surface,
    border: Border.all(
      color: selected ? kBrandGold : cs.outlineVariant,
      width: selected ? 2 : 1,
    ),
    borderRadius: BorderRadius.circular(14),
  );
}

/// A card or wallet row: brand mark, label, radio dot.
class _SelectableRow extends StatelessWidget {
  const _SelectableRow({
    required this.selected,
    required this.onTap,
    required this.leading,
    required this.label,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget leading;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: _selectableDecoration(context, selected),
        child: Row(
          children: [
            SizedBox(width: 52, child: Align(alignment: Alignment.centerLeft, child: leading)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? kBrandGold : Colors.transparent,
                border: Border.all(color: selected ? kBrandGold : cs.outlineVariant, width: 2),
              ),
              child: selected
                  ? Icon(Icons.check, size: 13, color: cs.onSecondary)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Quick-tender chip (cash tab).
class _PillChip extends StatelessWidget {
  const _PillChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? cs.primary : cs.surface,
          border: Border.all(color: selected ? cs.primary : cs.outlineVariant),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? cs.onPrimary : cs.onSurfaceVariant)),
      ),
    );
  }
}

/// QR in a gold-bordered frame, with its helper line underneath.
class _QrFrame extends StatelessWidget {
  const _QrFrame({required this.payload, required this.size, required this.hint});

  final String payload;
  final double size;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: kBrandGold, width: 2),
            borderRadius: BorderRadius.circular(20),
            boxShadow: kShadowE2,
          ),
          child: QrImageView(data: payload, size: size),
        ),
        const SizedBox(height: 14),
        Text(hint,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
      ],
    );
  }
}

/// What the terminal approved, shown in place of the "insert card" prompt.
class _ApprovedSlip extends StatelessWidget {
  const _ApprovedSlip({required this.edc});
  final EdcResult edc;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final ext = brandColors(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ext.successContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, size: 20, color: ext.onSuccessContainer),
              const SizedBox(width: 8),
              Text(t.cardApprovedShort(edc.approvalCode),
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700, color: ext.onSuccessContainer)),
            ],
          ),
          const SizedBox(height: 8),
          Text('${edc.scheme} · ${edc.maskedPan} · ${edc.entryMode}',
              style: TextStyle(
                  fontSize: 12, fontFamily: 'monospace', color: ext.onSuccessContainer)),
          Text('RRN ${edc.rrn}',
              style: TextStyle(
                  fontSize: 12, fontFamily: 'monospace', color: ext.onSuccessContainer)),
        ],
      ),
    );
  }
}
