import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/brand.dart';
import '../../core/money.dart';
import '../../core/settings_actions.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../data/session.dart';
import '../../l10n/app_localizations.dart';
import '../payment/checkout_screen.dart';
import '../transactions/transactions_screen.dart';
import 'cart.dart';

class OrderScreen extends ConsumerWidget {
  const OrderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final session = ref.watch(sessionProvider)!;
    final catalogAsync = ref.watch(catalogProvider(session.outletId));

    return Scaffold(
      appBar: BrandAppBar(
        title: Text(catalogAsync.valueOrNull?.outletName ?? t.posTitle),
        actions: [
          Consumer(builder: (context, ref, _) {
            final cart = ref.watch(cartProvider);
            if (cart.type != 'DINE_IN' || (cart.tableLabel ?? '').isEmpty) {
              return const SizedBox.shrink();
            }
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 14),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(t.tableLabelShort(cart.tableLabel!),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
            );
          }),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TransactionsScreen()),
            ),
            style: TextButton.styleFrom(foregroundColor: kBrandGold),
            child: Text(t.historyLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          const SettingsActions(),
          IconButton(
            tooltip: t.actionLogout,
            onPressed: () => ref.read(sessionProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: catalogAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(t.errorCatalog(e.toString()))),
        data: (catalog) {
          final catalogPanel = _CatalogPanel(catalog: catalog);
          if (isWide(context)) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: catalogPanel),
                SizedBox(width: 340, child: _CartPanel(taxRule: catalog.taxRule, floating: true)),
              ],
            );
          }
          return catalogPanel;
        },
      ),
      bottomNavigationBar: isWide(context)
          ? null
          : catalogAsync.maybeWhen(
              data: (catalog) => _MobileCartBar(taxRule: catalog.taxRule),
              orElse: () => null,
            ),
    );
  }
}

class _CatalogPanel extends ConsumerStatefulWidget {
  const _CatalogPanel({required this.catalog});
  final Catalog catalog;

  @override
  ConsumerState<_CatalogPanel> createState() => _CatalogPanelState();
}

class _CatalogPanelState extends ConsumerState<_CatalogPanel> {
  String? _category;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final products = widget.catalog.products.where((p) => p.isAvailable).toList();
    final categories = <String>{for (final p in products) p.categoryName}.toList()..sort();
    final filtered =
        _category == null ? products : products.where((p) => p.categoryName == _category).toList();

    if (products.isEmpty) return Center(child: Text(t.emptyCatalog));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 60,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            children: [
              _catChip('Semua', _category == null, () => setState(() => _category = null)),
              for (final c in categories)
                _catChip(c, _category == c, () => setState(() => _category = c)),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              final cols = (box.maxWidth / 175).floor().clamp(2, 6);
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.86,
                ),
                itemCount: filtered.length,
                itemBuilder: (context, i) => _ProductCard(product: filtered[i]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _catChip(String label, bool selected, VoidCallback onTap) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        selectedColor: cs.primary,
        labelStyle: TextStyle(
          color: selected ? cs.onPrimary : cs.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
        side: selected ? BorderSide.none : BorderSide(color: cs.outline),
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _ProductCard extends ConsumerWidget {
  const _ProductCard({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final ext = brandColors(context);
    final qty = ref.watch(cartProvider).lines
        .where((l) => l.product.id == product.id)
        .fold<int>(0, (s, l) => s + l.qty);
    final from = product.variants.isEmpty
        ? 0
        : product.variants.map((v) => v.price).reduce((a, b) => a < b ? a : b);

    return Card(
      child: InkWell(
        onTap: () => _pickAndAdd(context, ref, product),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 64,
                  decoration: BoxDecoration(gradient: ext.headerGradient),
                  alignment: Alignment.center,
                  child: Text(
                    product.name.isNotEmpty ? product.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                        color: kBrandGold, fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                ),
                if (qty > 0)
                  Positioned(
                    right: 8,
                    top: 48,
                    child: Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(color: kBrandGold, shape: BoxShape.circle),
                      child: Text('$qty',
                          style: TextStyle(
                              color: cs.onSecondary, fontSize: 12, fontWeight: FontWeight.w800)),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    Text('${_dariLabel(context)} ${formatRupiah(from)}',
                        style: TextStyle(
                            color: cs.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _dariLabel(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'id' ? 'dari' : 'from';
}

Future<void> _pickAndAdd(BuildContext context, WidgetRef ref, Product p) async {
  final t = AppLocalizations.of(context)!;
  final cs = Theme.of(context).colorScheme;
  Variant selectedVariant = p.variants.firstWhere((v) => v.isAvailable, orElse: () => p.variants.first);
  final Set<String> selectedMods = {};

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheet) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 4,
              bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                if (p.variants.length > 1) ...[
                  Text(t.labelVariant, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: p.variants.map((v) {
                      final sel = selectedVariant.id == v.id;
                      return ChoiceChip(
                        label: Text('${v.name} · ${formatRupiah(v.price)}'),
                        selected: sel,
                        showCheckmark: false,
                        selectedColor: cs.primary,
                        labelStyle: TextStyle(color: sel ? cs.onPrimary : cs.onSurfaceVariant),
                        onSelected: v.isAvailable ? (_) => setSheet(() => selectedVariant = v) : null,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                ],
                for (final g in p.modifierGroups) ...[
                  Text(g.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ...g.modifiers.map((m) => CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                            '${m.name}${m.priceDelta != 0 ? ' (+${formatRupiah(m.priceDelta)})' : ''}'),
                        value: selectedMods.contains(m.id),
                        onChanged: (on) => setSheet(() {
                          if (on == true) {
                            selectedMods.add(m.id);
                          } else {
                            selectedMods.remove(m.id);
                          }
                        }),
                      )),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: Text(t.actionAddToOrder),
                    onPressed: () {
                      final mods = p.modifierGroups
                          .expand((g) => g.modifiers)
                          .where((m) => selectedMods.contains(m.id))
                          .toList();
                      ref.read(cartProvider.notifier).addItem(p, selectedVariant, mods);
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

class _CartPanel extends ConsumerWidget {
  const _CartPanel({required this.taxRule, this.floating = false});
  final TaxRule? taxRule;
  final bool floating;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final cart = ref.watch(cartProvider);
    final ctrl = ref.read(cartProvider.notifier);
    final preview = cart.preview(taxRule);

    final panel = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(t.cartHeader, style: Theme.of(context).textTheme.titleMedium),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: 'DINE_IN', label: Text(t.typeDineIn)),
              ButtonSegment(value: 'TAKEAWAY', label: Text(t.typeTakeaway)),
            ],
            selected: {cart.type},
            onSelectionChanged: (s) => ctrl.setType(s.first),
          ),
        ),
        if (cart.type == 'DINE_IN')
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: TextField(
              decoration: InputDecoration(labelText: t.fieldTableNo, isDense: true),
              onChanged: ctrl.setTableLabel,
            ),
          ),
        Expanded(
          child: cart.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shopping_cart_outlined, size: 44, color: cs.onSurfaceVariant),
                      const SizedBox(height: 8),
                      Text(t.emptyItems, style: TextStyle(color: cs.onSurfaceVariant)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  itemCount: cart.lines.length,
                  itemBuilder: (context, i) => _CartLine(index: i),
                ),
        ),
        _TotalsBar(preview: preview, taxRule: taxRule, cartEmpty: cart.isEmpty),
      ],
    );

    if (!floating) return Material(color: cs.surface, child: panel);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: kShadowE3,
        ),
        clipBehavior: Clip.antiAlias,
        child: panel,
      ),
    );
  }
}

class _CartLine extends ConsumerWidget {
  const _CartLine({required this.index});
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final l = ref.watch(cartProvider).lines[index];
    final ctrl = ref.read(cartProvider.notifier);
    final mods = l.modifiers.map((m) => m.name).join(', ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${l.product.name} · ${l.variant.name}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                if (mods.isNotEmpty)
                  Text(mods, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
              ],
            ),
          ),
          IconButton.outlined(
            visualDensity: VisualDensity.compact,
            iconSize: 16,
            onPressed: () => ctrl.changeQty(index, -1),
            icon: const Icon(Icons.remove),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('${l.qty}', style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          IconButton.outlined(
            visualDensity: VisualDensity.compact,
            iconSize: 16,
            onPressed: () => ctrl.changeQty(index, 1),
            icon: const Icon(Icons.add),
          ),
          SizedBox(width: 72, child: Text(formatRupiah(l.lineTotal), textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

class _TotalsBar extends StatelessWidget {
  const _TotalsBar({required this.preview, required this.taxRule, required this.cartEmpty});
  final CartPreview preview;
  final TaxRule? taxRule;
  final bool cartEmpty;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _row(context, t.labelSubtotal, preview.subtotal),
                if (preview.discountTotal > 0) _row(context, t.labelDiscount, -preview.discountTotal),
                _row(context, taxRule?.label ?? t.labelTax, preview.taxTotal),
                if (preview.serviceChargeTotal > 0) _row(context, t.labelService, preview.serviceChargeTotal),
                Divider(color: cs.outline, height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(t.labelTotal,
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: cs.primary)),
                    Text(formatRupiah(preview.grandTotal),
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: cs.primary)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: cartEmpty
                  ? null
                  : () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => CheckoutScreen(grandTotalPreview: preview.grandTotal),
                      )),
              child: Text(t.payWithTotal(formatRupiah(preview.grandTotal))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, int amount) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: cs.onSurfaceVariant)),
          Text(formatRupiah(amount)),
        ],
      ),
    );
  }
}

class _MobileCartBar extends ConsumerWidget {
  const _MobileCartBar({required this.taxRule});
  final TaxRule? taxRule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final ext = brandColors(context);
    final cart = ref.watch(cartProvider);
    final preview = cart.preview(taxRule);
    final count = cart.lines.fold<int>(0, (s, l) => s + l.qty);

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
        decoration: brandGradient(context, radius: 16, shadow: kShadowE2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.itemsLabel(count),
                      style: TextStyle(color: ext.onGradient.withValues(alpha: 0.8), fontSize: 12)),
                  Text(formatRupiah(preview.grandTotal),
                      style: TextStyle(
                          color: ext.onGradient, fontWeight: FontWeight.w800, fontSize: 18)),
                ],
              ),
            ),
            FilledButton(
              onPressed: cart.isEmpty
                  ? null
                  : () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
                        builder: (_) => SizedBox(
                          height: MediaQuery.of(context).size.height * 0.85,
                          child: _CartPanel(taxRule: taxRule),
                        ),
                      ),
              child: Text(t.viewOrder),
            ),
          ],
        ),
      ),
    );
  }
}
