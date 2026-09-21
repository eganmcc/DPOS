import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/session.dart';
import '../payment/payment_screen.dart';
import '../stt/stt_stock_check.dart';
import 'cart.dart';
import 'order_screen.dart';

/// Catalogue lines staged somewhere other than the till's own grid — heard by voice, or read off a
/// photographed nota — handed to the till's ordinary cart and money path.
///
/// One way in, whoever staged them. Voice and the nota reader both finish through here, so neither
/// can grow a money path of its own; both end in code that already existed.

/// Staged lines go into the SAME cart as tapped ones, so one bill can be half staged and half
/// tapped. A line with no product behind it (not in the catalogue) is skipped — callers block
/// Selesai on those, so none should reach here.
void addStagedToCart(WidgetRef ref, List<SttStockCheck> checks) {
  final cart = ref.read(cartProvider.notifier);
  for (final c in checks) {
    final p = c.product;
    final v = c.variant;
    if (p == null || v == null) continue;
    cart.addItem(p, v, const [], qty: c.qty);
  }
}

/// Selesai for a staged catalogue order: into the cart, then the outlet's own way of settling —
/// the existing open-bill path, or the payment screen where the outlet pays immediately.
Future<bool> finishStagedOrder(
  BuildContext context,
  WidgetRef ref,
  List<SttStockCheck> checks,
) async {
  addStagedToCart(ref, checks);
  final session = ref.read(sessionProvider)!;
  final catalog = ref.read(catalogProvider(session.outletId)).valueOrNull;
  if (catalog?.isOpenBill ?? false) {
    return confirmOpenBill(context, ref);
  }
  final preview = ref.read(cartProvider).preview(catalog?.taxRule);
  if (!context.mounted) return false;
  await Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => PaymentScreen(grandTotalPreview: preview.grandTotal)),
  );
  return true;
}
