import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/brand.dart';
import '../../core/money.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../data/session.dart';
import '../../l10n/app_localizations.dart';

/// Max items a UMI catalog holds. Mirrors UMI_PRODUCT_LIMIT on the server, which is
/// authoritative — this copy only drives the counter and disables Add early. A stale
/// copy costs a redundant round-trip, never a wrong outcome.
const int kUmiItemLimit = 30;

/// In-app item & price management for a UMI merchant, which has no portal access.
///
/// Mirrors the portal's PricesView, phone-shaped and minus the branch picker — a
/// one-person business has one outlet, and `session.outletId` already is it.
class ItemsScreen extends ConsumerWidget {
  const ItemsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final session = ref.watch(sessionProvider);
    final products = ref.watch(adminProductsProvider);
    final stock = session == null
        ? const AsyncValue<Map<String, int>>.data({})
        : ref.watch(adminStockProvider(session.outletId));

    final used = products.valueOrNull?.where((p) => p.isAvailable).length ?? 0;
    final full = used >= kUmiItemLimit;

    return Scaffold(
      appBar: BrandAppBar(
        title: Text(t.itemsTitle),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: Text(
                t.itemsCount(used, kUmiItemLimit),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: full ? cs.error : cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        // Disabled at the limit, but the server is what actually refuses — this count
        // can be stale, so ITEM_LIMIT_REACHED is surfaced in the sheet too.
        onPressed: full
            ? () => ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(t.itemsLimitReached)))
            : () => _openSheet(context, ref, null, session?.outletId),
        icon: const Icon(Icons.add),
        label: Text(t.itemsAdd),
        backgroundColor: full ? cs.surfaceContainerHighest : null,
        foregroundColor: full ? cs.onSurfaceVariant : null,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(adminProductsProvider);
          if (session != null) ref.invalidate(adminStockProvider(session.outletId));
        },
        child: products.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(t.itemSaveFailed, textAlign: TextAlign.center),
            ),
          ]),
          data: (list) => list.isEmpty
              ? ListView(children: [
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(t.itemsEmpty,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: cs.onSurfaceVariant)),
                  ),
                ])
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _ItemTile(
                    product: list[i],
                    onHand: stock.valueOrNull?[list[i].defaultVariant?.id],
                    onTap: () => _openSheet(context, ref, list[i], session?.outletId),
                  ),
                ),
        ),
      ),
    );
  }

  void _openSheet(BuildContext context, WidgetRef ref, AdminProduct? product, String? outletId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _ItemSheet(product: product, outletId: outletId),
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.product, required this.onTap, this.onHand});
  final AdminProduct product;
  final VoidCallback onTap;
  final int? onHand;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final v = product.defaultVariant;
    final margin = v?.marginPerUnit;
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            [
              product.categoryName,
              // A missing cost price is called out here because it is what makes the
              // profit report read high — and this is the screen that fixes it.
              if (margin == null) t.itemNoCost else t.itemMargin(formatRupiah(margin)),
              if (v?.trackInventory == true && onHand != null) '${t.itemOnHand}: $onHand',
            ].join(' · '),
            style: TextStyle(
              color: margin == null ? cs.tertiary : cs.onSurfaceVariant,
              fontSize: 12,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: Text(formatRupiah(v?.price ?? 0),
            style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }
}

/// Add (product == null) or edit one item. Price and cost are integer rupiah.
class _ItemSheet extends ConsumerStatefulWidget {
  const _ItemSheet({required this.product, required this.outletId});
  final AdminProduct? product;
  final String? outletId;

  @override
  ConsumerState<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends ConsumerState<_ItemSheet> {
  late final TextEditingController _name;
  late final TextEditingController _category;
  late final TextEditingController _price;
  late final TextEditingController _cost;
  late final TextEditingController _sku;
  late final TextEditingController _onHand;
  late bool _available;
  late bool _track;
  bool _saving = false;
  String? _error;

  bool get _isNew => widget.product == null;

  int _currentStock() {
    final id = widget.product?.defaultVariant?.id;
    if (id == null || widget.outletId == null) return 0;
    return ref.read(adminStockProvider(widget.outletId!)).valueOrNull?[id] ?? 0;
  }

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    final v = p?.defaultVariant;
    _name = TextEditingController(text: p?.name ?? '');
    _category = TextEditingController(text: p?.categoryName ?? '');
    _price = TextEditingController(text: v == null ? '' : '${v.price}');
    _cost = TextEditingController(text: v?.costPrice == null ? '' : '${v!.costPrice}');
    _sku = TextEditingController(text: v?.sku ?? '');
    _onHand = TextEditingController(text: '${_currentStock()}');
    _available = v?.isAvailable ?? true;
    // Off by default for a new item: a street-food vendor does not do stock counts,
    // and the server defaults trackInventory to TRUE, so this must be sent explicitly.
    _track = v?.trackInventory ?? false;
  }

  @override
  void dispose() {
    for (final c in [_name, _category, _price, _cost, _sku, _onHand]) {
      c.dispose();
    }
    super.dispose();
  }

  int? _int(TextEditingController c) {
    final raw = c.text.trim();
    return raw.isEmpty ? null : int.tryParse(raw);
  }

  Future<void> _save() async {
    final t = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    if (_isNew && (_name.text.trim().isEmpty || _category.text.trim().isEmpty)) {
      setState(() => _error = t.itemNameRequired);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      if (_isNew) {
        await api.createAdminProduct({
          'name': _name.text.trim(),
          'categoryName': _category.text.trim(),
          'price': _int(_price) ?? 0,
          if (_int(_cost) != null) 'costPrice': _int(_cost),
          if (_sku.text.trim().isNotEmpty) 'sku': _sku.text.trim(),
          'trackInventory': _track,
          if (_track && (_int(_onHand) ?? 0) > 0) ...{
            'initialStock': _int(_onHand),
            'outletId': widget.outletId,
          },
        });
      } else {
        final v = widget.product!.defaultVariant!;
        await api.updateVariant(
          v.id,
          price: _int(_price),
          costPrice: _int(_cost),
          isAvailable: _available,
          sku: _sku.text.trim(), // '' clears it server-side
        );
        final desired = _int(_onHand) ?? 0;
        if (v.trackInventory && widget.outletId != null && desired != _currentStock()) {
          await api.adjustStock(
            outletId: widget.outletId!,
            variantId: v.id,
            quantityOnHand: desired,
          );
        }
      }
      ref.invalidate(adminProductsProvider);
      if (widget.outletId != null) {
        ref.invalidate(adminStockProvider(widget.outletId!));
        ref.invalidate(catalogProvider(widget.outletId!)); // the POS reads /catalog
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text(t.itemSaved)));
    } on DioException catch (e) {
      if (!mounted) return;
      final code = e.response?.data is Map ? e.response?.data['code'] : null;
      final server = e.response?.data is Map ? e.response?.data['message'] : null;
      setState(() {
        _error = code == 'ITEM_LIMIT_REACHED'
            ? t.itemsLimitReached
            : (server is String ? server : t.itemSaveFailed);
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final digits = <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly];
    final tracked = _track || (widget.product?.defaultVariant?.trackInventory ?? false);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_isNew ? t.itemsAdd : widget.product!.name,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            if (_isNew) ...[
              TextField(
                controller: _name,
                decoration: InputDecoration(labelText: t.itemName, isDense: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _category,
                decoration: InputDecoration(labelText: t.itemCategory, isDense: true),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _price,
              keyboardType: TextInputType.number,
              inputFormatters: digits,
              decoration: InputDecoration(labelText: t.itemPrice, prefixText: 'Rp ', isDense: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cost,
              keyboardType: TextInputType.number,
              inputFormatters: digits,
              decoration: InputDecoration(
                labelText: t.itemCost,
                helperText: t.itemCostHint,
                prefixText: 'Rp ',
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _sku,
              decoration: InputDecoration(labelText: t.itemSku, isDense: true),
            ),
            const SizedBox(height: 4),
            if (!_isNew)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(t.itemAvailable),
                value: _available,
                onChanged: (v) => setState(() => _available = v),
              ),
            if (_isNew)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(t.itemTrackStock),
                value: _track,
                onChanged: (v) => setState(() => _track = v),
              ),
            if (tracked)
              TextField(
                controller: _onHand,
                keyboardType: TextInputType.number,
                inputFormatters: digits,
                decoration: InputDecoration(labelText: t.itemOnHand, isDense: true),
              ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: cs.error, fontSize: 13)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_isNew ? t.itemsAdd : t.actionOk),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
