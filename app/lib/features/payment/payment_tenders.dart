import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

/// How a tender behaves at the till. Drives which panel the checkout screen shows.
enum TenderKind { cash, qris, card, ewallet, online }

/// One payment button on the till. `id` matches the server's `PaymentMethod` enum exactly —
/// it is what gets posted, printed and reported, so the two must never drift.
class Tender {
  const Tender({
    required this.id,
    required this.kind,
    required this.label,
    this.assets = const [],
    this.icon,
    this.brandColor,
  });

  final String id;
  final TenderKind kind;
  final String Function(AppLocalizations) label;

  /// Brand marks, drawn left to right. A card tender carries the schemes it accepts.
  final List<String> assets;

  /// Fallback when a tender has no brand mark of its own (cash, QRIS).
  final IconData? icon;

  /// Tint for the selected state; falls back to the theme's secondary.
  final Color? brandColor;

  bool get isCard => kind == TenderKind.card;
  bool get isEwallet => kind == TenderKind.ewallet;
}

const _p = 'assets/images/payments';

/// Every tender the till can offer, in display order.
final List<Tender> kAllTenders = [
  Tender(
    id: 'CASH',
    kind: TenderKind.cash,
    label: (t) => t.methodCash,
    icon: Icons.payments,
  ),
  Tender(
    id: 'QRIS_SIMULATED',
    kind: TenderKind.qris,
    label: (t) => t.methodQris,
    icon: Icons.qr_code_2,
  ),
  Tender(
    id: 'CARD_DEBIT',
    kind: TenderKind.card,
    label: (t) => t.methodDebit,
    assets: ['$_p/visa.svg', '$_p/mastercard.svg'],
    brandColor: const Color(0xFF1A1F71), // Visa navy
  ),
  Tender(
    id: 'CARD_CREDIT',
    kind: TenderKind.card,
    label: (t) => t.methodCredit,
    assets: ['$_p/visa.svg', '$_p/mastercard.svg'],
    brandColor: const Color(0xFFEB001B), // Mastercard red
  ),
  Tender(
    id: 'CARD_BCA',
    kind: TenderKind.card,
    label: (t) => t.methodBcaCard,
    assets: ['$_p/bca.svg'],
    brandColor: const Color(0xFF0060AF), // BCA blue
  ),
  Tender(
    id: 'EWALLET_SHOPEEPAY',
    kind: TenderKind.ewallet,
    label: (t) => t.methodShopeePay,
    assets: ['$_p/shopeepay.svg'],
    brandColor: const Color(0xFFEE4D2D),
  ),
  Tender(
    id: 'EWALLET_GOPAY',
    kind: TenderKind.ewallet,
    label: (t) => t.methodGoPay,
    assets: ['$_p/gopay.svg'],
    brandColor: const Color(0xFF00AED6),
  ),
  Tender(
    id: 'EWALLET_OVO',
    kind: TenderKind.ewallet,
    label: (t) => t.methodOvo,
    assets: ['$_p/ovo.svg'],
    brandColor: const Color(0xFF4C3494),
  ),
];

/// Tenders a merchant may use. Card and e-wallet acceptance needs an acquirer relationship a
/// one-person Ultra Mikro business does not have, so a UMI till shows cash and QRIS only —
/// the server refuses the rest regardless (`UMI_TENDER_NOT_AVAILABLE`).
List<Tender> tendersFor({required bool isUmi}) =>
    isUmi ? kAllTenders.where((x) => x.kind == TenderKind.cash || x.kind == TenderKind.qris).toList() : kAllTenders;

Tender tenderById(String id) =>
    kAllTenders.firstWhere((x) => x.id == id, orElse: () => kAllTenders.first);

/// Null for a method with no till button of its own (ONLINE, or anything added server-side
/// before the app knows about it) — callers fall back to the raw code rather than mislabel it.
Tender? tenderOrNull(String id) {
  for (final x in kAllTenders) {
    if (x.id == id) return x;
  }
  return null;
}

/// Indonesian labels for surfaces with no `BuildContext` — the thermal printer prints in
/// Indonesian regardless of the app's locale. Keep in step with the server's `PaymentMethod`.
const Map<String, String> kMethodLabelsId = {
  'CASH': 'Tunai',
  'QRIS_SIMULATED': 'QRIS',
  'ONLINE': 'Online',
  'CARD_DEBIT': 'Kartu Debit',
  'CARD_CREDIT': 'Kartu Kredit',
  'CARD_BCA': 'Kartu BCA',
  'EWALLET_SHOPEEPAY': 'ShopeePay',
  'EWALLET_GOPAY': 'GoPay',
  'EWALLET_OVO': 'OVO',
};

/// Label for a stored payment method. Localized when a tender owns the method, otherwise the
/// Indonesian fallback, otherwise the raw code — never a blank cell in a report.
String paymentMethodLabel(String id, [AppLocalizations? t]) {
  final tender = tenderOrNull(id);
  if (tender != null && t != null) return tender.label(t);
  return kMethodLabelsId[id] ?? id;
}

/// Brand marks for the online-ordering platforms, shown on an ONLINE order's receipt/tile.
const Map<String, String> kOnlinePlatformAssets = {
  'GOFOOD': '$_p/gofood.svg',
  'GRABFOOD': '$_p/grabfood.svg',
  'SHOPEEFOOD': '$_p/shopeefood.svg',
};
