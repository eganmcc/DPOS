import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/beep.dart';
import '../../core/brand.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../data/session.dart';
import '../../l10n/app_localizations.dart';
import '../order/cart.dart';
import '../order/order_screen.dart'; // CartPanel, CatalogPanel (public)
import '../settings/settings_screen.dart';
import '../transactions/transactions_screen.dart';

/// Grocery barcode-scanner POS home: camera scan + editable SKU field + Browse,
/// with the shared cart + pay flow below. A scanned/typed SKU that has stock is
/// added to the cart (same add + stock cap as tapping a product).
class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  final _controller = MobileScannerController(detectionSpeed: DetectionSpeed.normal);
  final _skuField = TextEditingController();

  String? _lastValue;
  DateTime _lastAt = DateTime.fromMillisecondsSinceEpoch(0);
  String? _status;
  bool _statusError = false;

  @override
  void dispose() {
    _controller.dispose();
    _skuField.dispose();
    super.dispose();
  }

  Map<String, (Product, Variant)> _skuIndex(Catalog catalog) {
    final map = <String, (Product, Variant)>{};
    for (final p in catalog.products) {
      for (final v in p.variants) {
        final sku = v.sku?.trim();
        if (sku == null || sku.isEmpty) continue;
        map.putIfAbsent(sku.toUpperCase(), () => (p, v));
      }
    }
    return map;
  }

  void _onDetect(BarcodeCapture cap) {
    final raw = cap.barcodes.isNotEmpty ? cap.barcodes.first.rawValue : null;
    if (raw == null || raw.isEmpty) return;
    final now = DateTime.now();
    // Debounce: ignore the same code within 2s (camera fires continuously).
    if (raw == _lastValue && now.difference(_lastAt) < const Duration(seconds: 2)) return;
    _lastValue = raw;
    _lastAt = now;
    _skuField.text = raw;
    _submitSku(raw);
  }

  void _submitSku(String rawSku) {
    final t = AppLocalizations.of(context)!;
    final session = ref.read(sessionProvider)!;
    final catalog = ref.read(catalogProvider(session.outletId)).valueOrNull;
    final sku = rawSku.trim();
    if (catalog == null || sku.isEmpty) return;

    final hit = _skuIndex(catalog)[sku.toUpperCase()];
    if (hit == null) {
      _setStatus(t.scannerSkuNotFound(sku), error: true);
      return;
    }
    final (product, variant) = hit;
    if (!product.isAvailable || !variant.isAvailable) {
      _setStatus(t.scannerOutOfStock, error: true);
      return;
    }
    // Same stock cap as _pickAndAdd: remaining = stock - already-in-cart.
    final inCart = ref
        .read(cartProvider)
        .lines
        .where((l) => l.variant.id == variant.id)
        .fold<int>(0, (s, l) => s + l.qty);
    final remaining = variant.trackInventory ? (variant.stock ?? 0) - inCart : null;
    if (remaining != null && remaining <= 0) {
      _setStatus(t.scannerOutOfStock, error: true);
      return;
    }
    ref.read(cartProvider.notifier).addItem(product, variant, const [], qty: 1);
    beep();
    HapticFeedback.mediumImpact();
    _setStatus(t.scannerAdded(product.name), error: false);
    _skuField.clear();
  }

  void _setStatus(String msg, {required bool error}) {
    if (!mounted) return;
    setState(() {
      _status = msg;
      _statusError = error;
    });
  }

  Future<void> _browse(Catalog catalog) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.9,
        child: CatalogPanel(catalog: catalog),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final session = ref.watch(sessionProvider)!;
    final catalogAsync = ref.watch(catalogProvider(session.outletId));

    return Scaffold(
      appBar: BrandAppBar(
        title: Text(t.scannerTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const TransactionsScreen())),
            style: TextButton.styleFrom(foregroundColor: kBrandGold),
            child: Text(t.historyLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          IconButton(
            tooltip: t.settingsTitle,
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: catalogAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(t.errorCatalog(e.toString()))),
        data: (catalog) {
          final scanner = _ScannerColumn(
            controller: _controller,
            onDetect: _onDetect,
            skuField: _skuField,
            onSubmitSku: () => _submitSku(_skuField.text),
            onBrowse: () => _browse(catalog),
            status: _status,
            statusError: _statusError,
          );
          if (isWide(context)) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: SingleChildScrollView(child: scanner)),
                SizedBox(width: 340, child: CartPanel(taxRule: catalog.taxRule, floating: true)),
              ],
            );
          }
          return Column(
            children: [
              scanner,
              Expanded(child: CartPanel(taxRule: catalog.taxRule)),
            ],
          );
        },
      ),
    );
  }
}

class _ScannerColumn extends StatelessWidget {
  const _ScannerColumn({
    required this.controller,
    required this.onDetect,
    required this.skuField,
    required this.onSubmitSku,
    required this.onBrowse,
    required this.status,
    required this.statusError,
  });

  final MobileScannerController controller;
  final void Function(BarcodeCapture) onDetect;
  final TextEditingController skuField;
  final VoidCallback onSubmitSku;
  final VoidCallback onBrowse;
  final String? status;
  final bool statusError;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 210,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(
                    controller: controller,
                    onDetect: onDetect,
                    errorBuilder: (context, error, child) => Container(
                      color: cs.surfaceContainerHighest,
                      alignment: Alignment.center,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(t.scannerHint,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: cs.onSurfaceVariant)),
                      ),
                    ),
                  ),
                  IgnorePointer(
                    child: Center(
                      child: Container(
                        width: 220,
                        height: 110,
                        decoration: BoxDecoration(
                          border: Border.all(color: kBrandGold, width: 3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(t.scannerHint, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: skuField,
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.characters,
                  onSubmitted: (_) => onSubmitSku(),
                  decoration: InputDecoration(
                    labelText: t.scannerSkuLabel,
                    isDense: true,
                    prefixIcon: const Icon(Icons.qr_code_2),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: onSubmitSku, child: Text(t.scannerAdd)),
            ],
          ),
          if (status != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(status!,
                  style: TextStyle(
                      color: statusError ? cs.error : cs.primary, fontWeight: FontWeight.w600)),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onBrowse,
            icon: const Icon(Icons.grid_view_outlined),
            label: Text(t.scannerBrowse),
          ),
        ],
      ),
    );
  }
}
