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

  @override
  String get historyTitle => 'Transactions';

  @override
  String get historyNetSales => 'NET SALES';

  @override
  String historyCount(int count) {
    return '$count sale';
  }

  @override
  String historyVoidedCount(int count) {
    return '$count voided';
  }

  @override
  String get emptyHistory => 'No transactions yet';

  @override
  String get errorHistory => 'Failed to load transactions';

  @override
  String get actionRetry => 'Retry';

  @override
  String get transactionTitle => 'Transaction';

  @override
  String get statusCompleted => 'Paid';

  @override
  String get statusVoided => 'Voided';

  @override
  String get statusRefunded => 'Refunded';

  @override
  String get paymentReversal => 'Reversal';

  @override
  String get voidedHeader => 'Sale voided';

  @override
  String get voidReasonLabel => 'Reason';

  @override
  String get voidImmutableNote =>
      'The sale is kept as a record — the void is a separate entry and stock has been restored.';

  @override
  String get actionVoidSale => 'Void sale';

  @override
  String get voidOwnerOnly => 'Only an owner can void a sale.';

  @override
  String get voidConfirmTitle => 'Void this sale?';

  @override
  String get voidConfirmBody =>
      'The sale stays in the records as voided, stock is restored, and the action is logged.';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionVoidConfirm => 'Void';

  @override
  String get voidSuccess => 'Sale voided and stock restored';

  @override
  String get voidFailed => 'Void failed — please try again';

  @override
  String get voidForbidden => 'You are not allowed to void a sale';

  @override
  String get soldOut => 'Sold out';

  @override
  String get eachSuffix => 'each';

  @override
  String get removeItem => 'Remove item';

  @override
  String get labelQty => 'Qty';

  @override
  String addQtyToOrder(int qty, String amount) {
    return 'Add $qty · $amount';
  }

  @override
  String get saveOrder => 'Process order';

  @override
  String get orderSaved => 'Order processed';

  @override
  String get openBillsTitle => 'Orders';

  @override
  String get emptyOpenBills => 'No open bills';

  @override
  String get searchTable => 'Search table';

  @override
  String get tableRequired => 'Enter a table number';

  @override
  String get tableExists => 'That table already has an open bill';

  @override
  String get actionOk => 'OK';

  @override
  String get dialogTitleInfo => 'Information';

  @override
  String get dialogTitleSuccess => 'Done';

  @override
  String get dialogTitleWarning => 'Heads up';

  @override
  String get dialogTitleError => 'Can\'t do that';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get aboutSection => 'About';

  @override
  String get appVersionLabel => 'App version';

  @override
  String get serverVersionLabel => 'Server version';

  @override
  String get preferencesSection => 'Preferences';

  @override
  String get languageLabel => 'Language';

  @override
  String get themeLabel => 'Theme';

  @override
  String get scannerTitle => 'Scan';

  @override
  String get scannerHint => 'Point the camera at a barcode';

  @override
  String get scannerSkuLabel => 'SKU';

  @override
  String get scannerAdd => 'Add';

  @override
  String get scannerBrowse => 'Browse products';

  @override
  String scannerAdded(String name) {
    return 'Added: $name';
  }

  @override
  String scannerSkuNotFound(String sku) {
    return 'SKU not found: $sku';
  }

  @override
  String get scannerOutOfStock => 'Out of stock';

  @override
  String get scannerModeLabel => 'Scanner mode';

  @override
  String get scannerModeAuto => 'Auto';

  @override
  String get scannerModeOn => 'On';

  @override
  String get scannerModeOff => 'Off';

  @override
  String get printFailed => 'Printer not reachable';

  @override
  String get actionPrint => 'Print';

  @override
  String get printerSection => 'Printer';

  @override
  String get printerPaired => 'Paired';

  @override
  String get printerNone => 'None found';

  @override
  String get printerTest => 'Test print';

  @override
  String get printerOk => 'Printed';
}
