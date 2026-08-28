import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/brand.dart';
import '../../core/formatters.dart';
import '../../core/money.dart';
import '../../core/settings_actions.dart';
import '../../core/theme.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../data/session.dart';
import '../../l10n/app_localizations.dart';
import '../payment/checkout_screen.dart';
import '../transactions/transactions_screen.dart';
import 'cart.dart';
import 'open_bills_screen.dart';

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
          if (catalogAsync.valueOrNull?.isOpenBill ?? false)
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const OpenBillsScreen()),
              ),
              style: TextButton.styleFrom(foregroundColor: kBrandGold),
              child: Text(t.openBillsTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
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
                  childAspectRatio: 0.78,
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
    final cart = ref.watch(cartProvider);
    final qty = cart.lines
        .where((l) => l.product.id == product.id)
        .fold<int>(0, (s, l) => s + l.qty);
    final from = product.variants.isEmpty
        ? 0
        : product.variants.map((v) => v.price).reduce((a, b) => a < b ? a : b);

    // Remaining sellable units, counted live against the cart: a sale isn't
    // committed until checkout, so items already in the cart are treated as
    // reserved. The badge ticks down and the tile greys the instant nothing is
    // left to add.
    int cartQtyOf(String variantId) =>
        cart.lines.where((l) => l.variant.id == variantId).fold<int>(0, (s, l) => s + l.qty);
    final trackedVariants =
        product.variants.where((v) => v.isAvailable && v.trackInventory).toList();
    final isTracked = trackedVariants.isNotEmpty;
    var remaining = 0;
    for (final v in trackedVariants) {
      final r = (v.stock ?? 0) - cartQtyOf(v.id);
      if (r > 0) remaining += r;
    }
    final orderableExists = product.variants.any((v) =>
        v.isAvailable && (!v.trackInventory || ((v.stock ?? 0) - cartQtyOf(v.id)) > 0));
    final available = product.isAvailable && orderableExists;

    final t = AppLocalizations.of(context)!;
    return Opacity(
      opacity: available ? 1 : 0.5,
      child: Card(
      clipBehavior: Clip.antiAlias, // keep the photo inside the card's rounded corners
      child: InkWell(
        onTap: available ? () => _pickAndAdd(context, ref, product) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: _ProductPhoto(product: product),
                ),
                // Always-visible remaining-stock badge (tracked items with stock left).
                if (isTracked && available)
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.inventory_2_outlined, size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                          Text('${_stockWord(context)} $remaining',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                if (!available)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.35),
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: cs.error,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(t.soldOut,
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                      ),
                    ),
                  ),
                if (available && qty > 0)
                  Positioned(
                    right: 8,
                    bottom: 8,
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
      ),
    );
  }

  String _dariLabel(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'id' ? 'dari' : 'from';
}

/// Product photo from the API's `imageUrl` (Wikimedia today, S3 later).
///
/// `BoxFit.cover` fills the 4:3 frame without distorting the source — the photo
/// is centre-cropped, never stretched, whatever its original proportions. Any
/// missing URL, slow load or offline device degrades to the brand initial tile,
/// so a card is never blank.
class _ProductPhoto extends StatelessWidget {
  const _ProductPhoto({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final url = product.imageUrl;
    if (url == null || url.isEmpty) return _InitialTile(name: product.name);
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => _InitialTile(name: product.name),
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : _InitialTile(name: product.name),
    );
  }
}

/// DIKA-gradient tile showing the product's initial — placeholder and fallback.
class _InitialTile extends StatelessWidget {
  const _InitialTile({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final ext = brandColors(context);
    return Container(
      decoration: BoxDecoration(gradient: ext.headerGradient),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(color: kBrandGold, fontSize: 26, fontWeight: FontWeight.w800),
      ),
    );
  }
}

Future<void> _pickAndAdd(BuildContext context, WidgetRef ref, Product p) async {
  final t = AppLocalizations.of(context)!;
  final cs = Theme.of(context).colorScheme;
  Variant selectedVariant = p.variants.firstWhere(
    (v) => v.isAvailable && v.inStock,
    orElse: () => p.variants.firstWhere((v) => v.isAvailable, orElse: () => p.variants.first),
  );
  final Set<String> selectedMods = {};
  int qty = 1; // add several at once without reopening the sheet

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
                      final orderable = v.isAvailable && v.inStock;
                      return ChoiceChip(
                        label: Text(orderable
                            ? '${v.name} · ${formatRupiah(v.price)}'
                            : '${v.name} · ${t.soldOut}'),
                        selected: sel,
                        showCheckmark: false,
                        selectedColor: cs.primary,
                        labelStyle: TextStyle(color: sel ? cs.onPrimary : cs.onSurfaceVariant),
                        onSelected: orderable ? (_) => setSheet(() => selectedVariant = v) : null,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                ],
                for (final g in p.modifierGroups) ...[
                  Row(
                    children: [
                      Text(g.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      Text(_groupHint(context, g),
                          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (_isSingleSelect(g))
                    // One choice out of the set: chips, like the variant row above.
                    // Checkboxes here are what let "Less sugar" and "Normal" both
                    // be ticked on the same drink.
                    Wrap(
                      spacing: 8,
                      children: g.modifiers.map((m) {
                        final sel = selectedMods.contains(m.id);
                        return ChoiceChip(
                          label: Text(_modLabel(m)),
                          selected: sel,
                          showCheckmark: false,
                          selectedColor: cs.primary,
                          labelStyle:
                              TextStyle(color: sel ? cs.onPrimary : cs.onSurfaceVariant),
                          onSelected: (_) => setSheet(() {
                            final wasSelected = sel;
                            selectedMods.removeWhere(
                                (id) => g.modifiers.any((x) => x.id == id));
                            // Re-tapping clears an optional choice; a required
                            // group always keeps exactly one selected.
                            if (!wasSelected || _minFor(g) > 0) selectedMods.add(m.id);
                          }),
                        );
                      }).toList(),
                    )
                  else
                    ...g.modifiers.map((m) {
                      final on = selectedMods.contains(m.id);
                      final atCap = _selectedIn(g, selectedMods) >= g.maxSelect;
                      return CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(_modLabel(m)),
                        value: on,
                        // Greyed out once the group's cap is reached.
                        onChanged: (!on && atCap)
                            ? null
                            : (checked) => setSheet(() {
                                  if (checked == true) {
                                    selectedMods.add(m.id);
                                  } else {
                                    selectedMods.remove(m.id);
                                  }
                                }),
                      );
                    }),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 8),
                Builder(builder: (context) {
                  final unmet = _unmetGroups(p, selectedMods);
                  // How many of this variant are already in the cart — the picker
                  // can't add past the remaining stock.
                  final inCart = ref
                      .read(cartProvider)
                      .lines
                      .where((l) => l.variant.id == selectedVariant.id)
                      .fold<int>(0, (s, l) => s + l.qty);
                  final remaining = selectedVariant.trackInventory
                      ? (selectedVariant.stock ?? 0) - inCart
                      : null;
                  final soldOut = remaining != null && remaining <= 0;
                  // Keep qty within what's left to add.
                  if (remaining != null && qty > remaining && remaining > 0) qty = remaining;
                  if (qty < 1) qty = 1;
                  final atQtyCap = remaining != null && qty >= remaining;
                  final blocked = unmet.isNotEmpty || soldOut;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Remaining count, live against the chosen quantity: pick 3
                      // of 6 and it reads "tinggal 3".
                      if (remaining != null) ...[
                        Text(_stockLabel(context, (remaining - qty).clamp(0, remaining)),
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: soldOut ? cs.error : cs.onSurfaceVariant)),
                        const SizedBox(height: 8),
                      ],
                      if (unmet.isNotEmpty) ...[
                        Text(
                          _requiredWarning(context, unmet),
                          style: TextStyle(fontSize: 13, color: cs.error),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (!soldOut) ...[
                        Row(
                          children: [
                            Text(t.labelQty, style: const TextStyle(fontWeight: FontWeight.w600)),
                            const Spacer(),
                            _QtyStepper(
                              qty: qty,
                              onMinus: qty > 1 ? () => setSheet(() => qty--) : () {},
                              onPlus: atQtyCap ? null : () => setSheet(() => qty++),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          icon: const Icon(Icons.add),
                          label: Text(
                              t.addQtyToOrder(qty, formatRupiah(selectedVariant.price * qty))),
                          onPressed: blocked
                              ? null
                              : () {
                                  final mods = p.modifierGroups
                                      .expand((g) => g.modifiers)
                                      .where((m) => selectedMods.contains(m.id))
                                      .toList();
                                  ref
                                      .read(cartProvider.notifier)
                                      .addItem(p, selectedVariant, mods, qty: qty);
                                  Navigator.of(context).pop();
                                },
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          );
        },
      );
    },
  );
}

// --- Modifier group rules -------------------------------------------------
// The API defines each group's minSelect/maxSelect/required; these mirror them
// in the UI. The server enforces the same rules on checkout, so a stale build
// cannot submit an impossible combination.

/// Radio-style: exactly one of several options (e.g. sugar level, spice level).
/// A one-option group stays a checkbox so it can be toggled off.
bool _isSingleSelect(ModifierGroup g) => g.maxSelect == 1 && g.modifiers.length > 1;

int _selectedIn(ModifierGroup g, Set<String> selected) =>
    g.modifiers.where((m) => selected.contains(m.id)).length;

/// Effective minimum: `required` implies at least one even if minSelect is 0.
int _minFor(ModifierGroup g) => g.required ? (g.minSelect < 1 ? 1 : g.minSelect) : g.minSelect;

List<ModifierGroup> _unmetGroups(Product p, Set<String> selected) =>
    p.modifierGroups.where((g) => _selectedIn(g, selected) < _minFor(g)).toList();

String _modLabel(Modifier m) =>
    '${m.name}${m.priceDelta != 0 ? ' (+${formatRupiah(m.priceDelta)})' : ''}';

String _groupHint(BuildContext context, ModifierGroup g) {
  final id = Localizations.localeOf(context).languageCode == 'id';
  if (_isSingleSelect(g)) {
    if (_minFor(g) > 0) return id ? '· pilih 1' : '· choose 1';
    return id ? '· pilih 1, opsional' : '· choose 1, optional';
  }
  if (g.maxSelect > 1) return id ? '· maks ${g.maxSelect}' : '· max ${g.maxSelect}';
  return id ? '· opsional' : '· optional';
}

String _requiredWarning(BuildContext context, List<ModifierGroup> unmet) {
  final id = Localizations.localeOf(context).languageCode == 'id';
  final names = unmet.map((g) => g.name).join(', ');
  return id ? 'Pilih dulu: $names' : 'Choose first: $names';
}

String _stockLabel(BuildContext context, int remaining) {
  final id = Localizations.localeOf(context).languageCode == 'id';
  if (remaining <= 0) return id ? 'Stok habis' : 'Out of stock';
  return id ? 'Stok tinggal $remaining' : '$remaining in stock';
}

String _stockWord(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'id' ? 'Stok' : 'Stock';

class _CartPanel extends ConsumerStatefulWidget {
  const _CartPanel({required this.taxRule, this.floating = false});
  final TaxRule? taxRule;
  final bool floating;

  @override
  ConsumerState<_CartPanel> createState() => _CartPanelState();
}

class _CartPanelState extends ConsumerState<_CartPanel> {
  final _table = TextEditingController();

  @override
  void dispose() {
    _table.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final cart = ref.watch(cartProvider);
    final ctrl = ref.read(cartProvider.notifier);
    final taxRule = widget.taxRule;
    final floating = widget.floating;
    final preview = cart.preview(taxRule);

    // After a confirm clears the cart, drop any stale table text so the next
    // dine-in order starts blank.
    if ((cart.tableLabel ?? '').isEmpty && _table.text.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && (ref.read(cartProvider).tableLabel ?? '').isEmpty) _table.clear();
      });
    }

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
              controller: _table,
              inputFormatters: [UpperCaseTextInputFormatter()],
              textCapitalization: TextCapitalization.characters,
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
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  itemCount: cart.lines.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _CartLine(index: i),
                ),
        ),
        _TotalsBar(
            preview: preview, taxRule: taxRule, cartEmpty: cart.isEmpty, floating: floating),
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
    final cart = ref.watch(cartProvider);
    final l = cart.lines[index];
    final ctrl = ref.read(cartProvider.notifier);
    final t = AppLocalizations.of(context)!;
    final mods = l.modifiers.map((m) => m.name).join(', ');
    // Cap the stepper at the variant's remaining stock (summed across cart lines).
    final variantQty =
        cart.lines.where((x) => x.variant.id == l.variant.id).fold<int>(0, (s, x) => s + x.qty);
    final atCap = l.variant.trackInventory && (l.variant.stock ?? 0) <= variantQty;

    // Swipe left to remove the whole line; the − stepper at qty 1 is the second
    // path (changeQty removes at 0). Keyed by mergeKey so Dismissible stays
    // stable as lines merge/reorder.
    return Dismissible(
      key: ValueKey(l.mergeKey),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => ctrl.removeAt(index),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: cs.error,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(Icons.delete_outline, color: cs.onError, semanticLabel: t.removeItem),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outline),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${l.product.name} · ${l.variant.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text('${formatRupiah(l.unitPrice)} ${t.eachSuffix}',
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                  if (mods.isNotEmpty)
                    Text(mods,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                _QtyStepper(
                  qty: l.qty,
                  onMinus: () => ctrl.changeQty(index, -1),
                  onPlus: atCap ? null : () => ctrl.changeQty(index, 1),
                ),
                const SizedBox(height: 6),
                Text(formatRupiah(l.lineTotal),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact grouped quantity control: a single [ − qty + ] capsule, in place of
/// two loose outlined circles. The + disables at the stock cap.
class _QtyStepper extends StatelessWidget {
  const _QtyStepper({required this.qty, required this.onMinus, this.onPlus});
  final int qty;
  final VoidCallback onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepBtn(icon: Icons.remove, onTap: onMinus, color: cs.primary),
          Container(
            constraints: const BoxConstraints(minWidth: 28),
            alignment: Alignment.center,
            child: Text('$qty', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
          _StepBtn(
            icon: Icons.add,
            onTap: onPlus,
            color: onPlus == null ? cs.onSurfaceVariant : cs.primary,
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.onTap, required this.color});
  final IconData icon;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 20,
      child: SizedBox(
        width: 36,
        height: 36,
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

/// Open-bill confirm: save the order server-side (no payment) so stock is
/// reserved now and the bill is settled later. Bypasses the offline queue.
/// Returns true on a successful submit (the caller then closes the cart).
Future<bool> _confirmOpenBill(BuildContext context, WidgetRef ref) async {
  final t = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  final session = ref.read(sessionProvider)!;
  final cart = ref.read(cartProvider.notifier);
  final state = ref.read(cartProvider);

  // Dine-in open bills are keyed by table.
  if (state.type == 'DINE_IN' && (state.tableLabel ?? '').trim().isEmpty) {
    messenger.showSnackBar(SnackBar(content: Text(t.tableRequired)));
    return false;
  }
  // Friendly pre-check; the server enforces uniqueness too (409).
  final norm = state.tableLabel?.trim().toUpperCase();
  if (norm != null && norm.isNotEmpty) {
    final open = await ref.read(openBillsProvider(session.outletId).future);
    if (open.any((o) => (o.tableLabel ?? '').toUpperCase() == norm)) {
      messenger.showSnackBar(SnackBar(content: Text(t.tableExists)));
      return false;
    }
  }

  final payload = cart.buildPayload(
    clientOrderId: const Uuid().v4(),
    outletId: session.outletId,
    deviceId: session.deviceId,
    method: null, // open bill — no payment yet
  );
  try {
    await ref.read(apiClientProvider).submitOrder(payload);
    cart.clear();
    ref.invalidate(catalogProvider(session.outletId)); // stock reserved
    ref.invalidate(openBillsProvider(session.outletId));
    messenger.showSnackBar(SnackBar(content: Text(t.orderSaved)));
    return true;
  } on DioException catch (e) {
    messenger.showSnackBar(SnackBar(
      content: Text(e.response?.statusCode == 409 ? t.tableExists : t.errorSignIn),
    ));
    return false;
  }
}

class _TotalsBar extends ConsumerWidget {
  const _TotalsBar(
      {required this.preview,
      required this.taxRule,
      required this.cartEmpty,
      this.floating = false});
  final CartPreview preview;
  final TaxRule? taxRule;
  final bool cartEmpty;

  /// True on the tablet side panel (persistent); false on the mobile cart sheet,
  /// which is closed after processing an open bill.
  final bool floating;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final session = ref.watch(sessionProvider)!;
    final openBill = ref.watch(catalogProvider(session.outletId)).valueOrNull?.isOpenBill ?? false;
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
                  : () async {
                      if (openBill) {
                        final nav = Navigator.of(context);
                        final ok = await _confirmOpenBill(context, ref);
                        // On mobile the cart is a bottom sheet — close it so the
                        // cashier lands back on the menu for the next order.
                        if (ok && !floating) nav.pop();
                      } else {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => CheckoutScreen(grandTotalPreview: preview.grandTotal),
                        ));
                      }
                    },
              child: Text(openBill
                  ? t.saveOrder
                  : t.payWithTotal(formatRupiah(preview.grandTotal))),
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
