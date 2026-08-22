// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'DPOS';

  @override
  String get loginTitle => 'Cashier login';

  @override
  String get loginSubtitle => 'Sign in to start selling';

  @override
  String get fieldMerchantId => 'Merchant ID';

  @override
  String get fieldOutletId => 'Outlet ID';

  @override
  String get fieldPin => 'PIN';

  @override
  String get advancedSettings => 'Advanced settings';

  @override
  String get actionSignIn => 'Sign in';

  @override
  String get errorSignIn => 'Sign-in failed (check connection)';

  @override
  String get posTitle => 'Cashier';

  @override
  String get actionLogout => 'Log out';

  @override
  String errorCatalog(String error) {
    return 'Failed to load catalog: $error';
  }

  @override
  String get emptyItems => 'No items yet';

  @override
  String get emptyCatalog => 'No products available';

  @override
  String get typeTakeaway => 'Takeaway';

  @override
  String get typeDineIn => 'Dine-in';

  @override
  String get fieldTableNo => 'Table no.';

  @override
  String get actionAddToOrder => 'Add to order';

  @override
  String get labelVariant => 'Variant';

  @override
  String get labelSubtotal => 'Subtotal';

  @override
  String get labelDiscount => 'Discount';

  @override
  String get labelTax => 'Tax';

  @override
  String get labelService => 'Service';

  @override
  String get labelTotal => 'Total';

  @override
  String payWithTotal(String amount) {
    return 'Pay · $amount';
  }

  @override
  String orderSummary(int count) {
    return 'Order ($count)';
  }

  @override
  String get paymentTitle => 'Payment';

  @override
  String get methodCash => 'Cash';

  @override
  String get methodQris => 'QRIS';

  @override
  String get fieldCashReceived => 'Cash received';

  @override
  String get labelChange => 'Change';

  @override
  String get actionComplete => 'Complete';

  @override
  String get actionMarkPaid => 'Mark as paid';

  @override
  String get qrisHint => 'Scan to pay (simulation)';

  @override
  String get errorCashShort => 'Cash is less than the total';

  @override
  String get msgQueuedOffline => 'Saved offline — will sync when online';

  @override
  String get receiptTitle => 'Receipt';

  @override
  String get actionNewOrder => 'New order';

  @override
  String get actionShare => 'Share';

  @override
  String get shareSoon => 'Share receipt (coming soon)';

  @override
  String get tenderExact => 'Exact';

  @override
  String get themeToggle => 'Toggle theme';

  @override
  String get langToggle => 'Bahasa / English';

  @override
  String get loginFooter => 'Forgot PIN? Contact your outlet admin.';

  @override
  String get cartHeader => 'Order';

  @override
  String get viewOrder => 'View order';

  @override
  String itemsLabel(int count) {
    return '$count item';
  }

  @override
  String get historyLabel => 'History';

  @override
  String get totalDue => 'Total due';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String tableLabelShort(String n) {
    return 'Table $n';
  }
}
