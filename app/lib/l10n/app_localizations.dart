import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_id.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('id')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'DPOS'**
  String get appTitle;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Cashier login'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to start selling'**
  String get loginSubtitle;

  /// No description provided for @fieldMerchantId.
  ///
  /// In en, this message translates to:
  /// **'Merchant ID'**
  String get fieldMerchantId;

  /// No description provided for @fieldOutletId.
  ///
  /// In en, this message translates to:
  /// **'Outlet ID'**
  String get fieldOutletId;

  /// No description provided for @fieldPin.
  ///
  /// In en, this message translates to:
  /// **'PIN'**
  String get fieldPin;

  /// No description provided for @advancedSettings.
  ///
  /// In en, this message translates to:
  /// **'Advanced settings'**
  String get advancedSettings;

  /// No description provided for @actionSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get actionSignIn;

  /// No description provided for @errorSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed (check connection)'**
  String get errorSignIn;

  /// No description provided for @sessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your session expired. Please sign in again.'**
  String get sessionExpired;

  /// No description provided for @posTitle.
  ///
  /// In en, this message translates to:
  /// **'Cashier'**
  String get posTitle;

  /// No description provided for @actionLogout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get actionLogout;

  /// No description provided for @errorCatalog.
  ///
  /// In en, this message translates to:
  /// **'Failed to load catalog: {error}'**
  String errorCatalog(String error);

  /// No description provided for @emptyItems.
  ///
  /// In en, this message translates to:
  /// **'No items yet'**
  String get emptyItems;

  /// No description provided for @emptyCatalog.
  ///
  /// In en, this message translates to:
  /// **'No products available'**
  String get emptyCatalog;

  /// No description provided for @typeTakeaway.
  ///
  /// In en, this message translates to:
  /// **'Takeaway'**
  String get typeTakeaway;

  /// No description provided for @typeDineIn.
  ///
  /// In en, this message translates to:
  /// **'Dine-in'**
  String get typeDineIn;

  /// No description provided for @fieldTableNo.
  ///
  /// In en, this message translates to:
  /// **'Table no.'**
  String get fieldTableNo;

  /// No description provided for @actionAddToOrder.
  ///
  /// In en, this message translates to:
  /// **'Add to order'**
  String get actionAddToOrder;

  /// No description provided for @labelVariant.
  ///
  /// In en, this message translates to:
  /// **'Variant'**
  String get labelVariant;

  /// No description provided for @labelSubtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get labelSubtotal;

  /// No description provided for @labelDiscount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get labelDiscount;

  /// No description provided for @labelTax.
  ///
  /// In en, this message translates to:
  /// **'Tax'**
  String get labelTax;

  /// No description provided for @labelService.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get labelService;

  /// No description provided for @labelTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get labelTotal;

  /// No description provided for @payWithTotal.
  ///
  /// In en, this message translates to:
  /// **'Pay · {amount}'**
  String payWithTotal(String amount);

  /// No description provided for @orderSummary.
  ///
  /// In en, this message translates to:
  /// **'Order ({count})'**
  String orderSummary(int count);

  /// No description provided for @paymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get paymentTitle;

  /// No description provided for @methodCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get methodCash;

  /// No description provided for @methodQris.
  ///
  /// In en, this message translates to:
  /// **'QRIS'**
  String get methodQris;

  /// No description provided for @fieldCashReceived.
  ///
  /// In en, this message translates to:
  /// **'Cash received'**
  String get fieldCashReceived;

  /// No description provided for @labelChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get labelChange;

  /// No description provided for @actionComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get actionComplete;

  /// No description provided for @actionMarkPaid.
  ///
  /// In en, this message translates to:
  /// **'Mark as paid'**
  String get actionMarkPaid;

  /// No description provided for @qrisHint.
  ///
  /// In en, this message translates to:
  /// **'Scan to pay (simulation)'**
  String get qrisHint;

  /// No description provided for @errorCashShort.
  ///
  /// In en, this message translates to:
  /// **'Cash is less than the total'**
  String get errorCashShort;

  /// No description provided for @msgQueuedOffline.
  ///
  /// In en, this message translates to:
  /// **'Saved offline — will sync when online'**
  String get msgQueuedOffline;

  /// No description provided for @receiptTitle.
  ///
  /// In en, this message translates to:
  /// **'Receipt'**
  String get receiptTitle;

  /// No description provided for @actionNewOrder.
  ///
  /// In en, this message translates to:
  /// **'New order'**
  String get actionNewOrder;

  /// No description provided for @actionShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get actionShare;

  /// No description provided for @shareSoon.
  ///
  /// In en, this message translates to:
  /// **'Share receipt (coming soon)'**
  String get shareSoon;

  /// No description provided for @tenderExact.
  ///
  /// In en, this message translates to:
  /// **'Exact'**
  String get tenderExact;

  /// No description provided for @themeToggle.
  ///
  /// In en, this message translates to:
  /// **'Toggle theme'**
  String get themeToggle;

  /// No description provided for @langToggle.
  ///
  /// In en, this message translates to:
  /// **'Bahasa / English'**
  String get langToggle;

  /// No description provided for @loginFooter.
  ///
  /// In en, this message translates to:
  /// **'Forgot PIN? Contact your outlet admin.'**
  String get loginFooter;

  /// No description provided for @cartHeader.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get cartHeader;

  /// No description provided for @viewOrder.
  ///
  /// In en, this message translates to:
  /// **'View order'**
  String get viewOrder;

  /// No description provided for @itemsLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} item'**
  String itemsLabel(int count);

  /// No description provided for @historyLabel.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historyLabel;

  /// No description provided for @totalDue.
  ///
  /// In en, this message translates to:
  /// **'Total due'**
  String get totalDue;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @tableLabelShort.
  ///
  /// In en, this message translates to:
  /// **'Table {n}'**
  String tableLabelShort(String n);

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get historyTitle;

  /// No description provided for @historyNetSales.
  ///
  /// In en, this message translates to:
  /// **'NET SALES'**
  String get historyNetSales;

  /// No description provided for @historyCount.
  ///
  /// In en, this message translates to:
  /// **'{count} sale'**
  String historyCount(int count);

  /// No description provided for @historyVoidedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} voided'**
  String historyVoidedCount(int count);

  /// No description provided for @emptyHistory.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet'**
  String get emptyHistory;

  /// No description provided for @errorHistory.
  ///
  /// In en, this message translates to:
  /// **'Failed to load transactions'**
  String get errorHistory;

  /// No description provided for @actionRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get actionRetry;

  /// No description provided for @transactionTitle.
  ///
  /// In en, this message translates to:
  /// **'Transaction'**
  String get transactionTitle;

  /// No description provided for @statusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get statusCompleted;

  /// No description provided for @statusVoided.
  ///
  /// In en, this message translates to:
  /// **'Voided'**
  String get statusVoided;

  /// No description provided for @statusRefunded.
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get statusRefunded;

  /// No description provided for @paymentReversal.
  ///
  /// In en, this message translates to:
  /// **'Reversal'**
  String get paymentReversal;

  /// No description provided for @voidedHeader.
  ///
  /// In en, this message translates to:
  /// **'Sale voided'**
  String get voidedHeader;

  /// No description provided for @voidReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get voidReasonLabel;

  /// No description provided for @voidImmutableNote.
  ///
  /// In en, this message translates to:
  /// **'The sale is kept as a record — the void is a separate entry and stock has been restored.'**
  String get voidImmutableNote;

  /// No description provided for @actionVoidSale.
  ///
  /// In en, this message translates to:
  /// **'Void sale'**
  String get actionVoidSale;

  /// No description provided for @voidOwnerOnly.
  ///
  /// In en, this message translates to:
  /// **'Only an owner or manager can void a sale.'**
  String get voidOwnerOnly;

  /// No description provided for @voidConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Void this sale?'**
  String get voidConfirmTitle;

  /// No description provided for @voidConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'The sale stays in the records as voided, stock is restored, and the action is logged.'**
  String get voidConfirmBody;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionVoidConfirm.
  ///
  /// In en, this message translates to:
  /// **'Void'**
  String get actionVoidConfirm;

  /// No description provided for @voidSuccess.
  ///
  /// In en, this message translates to:
  /// **'Sale voided and stock restored'**
  String get voidSuccess;

  /// No description provided for @voidFailed.
  ///
  /// In en, this message translates to:
  /// **'Void failed — please try again'**
  String get voidFailed;

  /// No description provided for @voidForbidden.
  ///
  /// In en, this message translates to:
  /// **'You are not allowed to void a sale'**
  String get voidForbidden;

  /// No description provided for @voidWindowExpired.
  ///
  /// In en, this message translates to:
  /// **'Voids are only allowed on the same day — issue a refund instead.'**
  String get voidWindowExpired;

  /// No description provided for @voidReasonWrongItem.
  ///
  /// In en, this message translates to:
  /// **'Wrong item'**
  String get voidReasonWrongItem;

  /// No description provided for @voidReasonWrongPrice.
  ///
  /// In en, this message translates to:
  /// **'Wrong price'**
  String get voidReasonWrongPrice;

  /// No description provided for @voidReasonCustomerCancel.
  ///
  /// In en, this message translates to:
  /// **'Customer cancelled'**
  String get voidReasonCustomerCancel;

  /// No description provided for @voidReasonTest.
  ///
  /// In en, this message translates to:
  /// **'Test transaction'**
  String get voidReasonTest;

  /// No description provided for @actionRefund.
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get actionRefund;

  /// No description provided for @refundTitle.
  ///
  /// In en, this message translates to:
  /// **'Refund sale'**
  String get refundTitle;

  /// No description provided for @refundFull.
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get refundFull;

  /// No description provided for @refundPartial.
  ///
  /// In en, this message translates to:
  /// **'By item'**
  String get refundPartial;

  /// No description provided for @refundReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Refund reason'**
  String get refundReasonLabel;

  /// No description provided for @refundEstimate.
  ///
  /// In en, this message translates to:
  /// **'Estimated refund'**
  String get refundEstimate;

  /// No description provided for @refundSuccess.
  ///
  /// In en, this message translates to:
  /// **'Refund processed'**
  String get refundSuccess;

  /// No description provided for @refundFailed.
  ///
  /// In en, this message translates to:
  /// **'Refund failed — please try again'**
  String get refundFailed;

  /// No description provided for @refundedSoFar.
  ///
  /// In en, this message translates to:
  /// **'Refunded so far'**
  String get refundedSoFar;

  /// No description provided for @refundNothingLeft.
  ///
  /// In en, this message translates to:
  /// **'Nothing left to refund on this sale.'**
  String get refundNothingLeft;

  /// No description provided for @refundReasonDamaged.
  ///
  /// In en, this message translates to:
  /// **'Damaged / defective'**
  String get refundReasonDamaged;

  /// No description provided for @refundReasonReturn.
  ///
  /// In en, this message translates to:
  /// **'Customer return'**
  String get refundReasonReturn;

  /// No description provided for @refundReasonQuality.
  ///
  /// In en, this message translates to:
  /// **'Quality issue'**
  String get refundReasonQuality;

  /// No description provided for @managerApprovalTitle.
  ///
  /// In en, this message translates to:
  /// **'Manager approval'**
  String get managerApprovalTitle;

  /// No description provided for @managerPinLabel.
  ///
  /// In en, this message translates to:
  /// **'Manager / owner PIN'**
  String get managerPinLabel;

  /// No description provided for @approvalInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid manager PIN'**
  String get approvalInvalid;

  /// No description provided for @approvalRequired.
  ///
  /// In en, this message translates to:
  /// **'Manager approval is required'**
  String get approvalRequired;

  /// No description provided for @actionCancelBill.
  ///
  /// In en, this message translates to:
  /// **'Cancel bill'**
  String get actionCancelBill;

  /// No description provided for @cancelBillTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel this bill?'**
  String get cancelBillTitle;

  /// No description provided for @cancelBillBody.
  ///
  /// In en, this message translates to:
  /// **'Reserved stock is released and the bill is closed. No payment was taken.'**
  String get cancelBillBody;

  /// No description provided for @cancelSuccess.
  ///
  /// In en, this message translates to:
  /// **'Bill cancelled and stock released'**
  String get cancelSuccess;

  /// No description provided for @cancelFailed.
  ///
  /// In en, this message translates to:
  /// **'Cancel failed — please try again'**
  String get cancelFailed;

  /// No description provided for @clockInPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Clock in now?'**
  String get clockInPromptTitle;

  /// No description provided for @actionLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get actionLater;

  /// No description provided for @clockOutPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Clock out?'**
  String get clockOutPromptTitle;

  /// No description provided for @clockOutPromptBody.
  ///
  /// In en, this message translates to:
  /// **'You\'re still on the clock. Clock out before logging out?'**
  String get clockOutPromptBody;

  /// No description provided for @actionLogoutOnly.
  ///
  /// In en, this message translates to:
  /// **'Just log out'**
  String get actionLogoutOnly;

  /// No description provided for @actionClockOutAndLogout.
  ///
  /// In en, this message translates to:
  /// **'Clock out & log out'**
  String get actionClockOutAndLogout;

  /// No description provided for @soldOut.
  ///
  /// In en, this message translates to:
  /// **'Sold out'**
  String get soldOut;

  /// No description provided for @eachSuffix.
  ///
  /// In en, this message translates to:
  /// **'each'**
  String get eachSuffix;

  /// No description provided for @removeItem.
  ///
  /// In en, this message translates to:
  /// **'Remove item'**
  String get removeItem;

  /// No description provided for @labelQty.
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get labelQty;

  /// No description provided for @addQtyToOrder.
  ///
  /// In en, this message translates to:
  /// **'Add {qty} · {amount}'**
  String addQtyToOrder(int qty, String amount);

  /// No description provided for @saveOrder.
  ///
  /// In en, this message translates to:
  /// **'Process order'**
  String get saveOrder;

  /// No description provided for @updateOrder.
  ///
  /// In en, this message translates to:
  /// **'Update order'**
  String get updateOrder;

  /// No description provided for @orderSaved.
  ///
  /// In en, this message translates to:
  /// **'Order processed'**
  String get orderSaved;

  /// No description provided for @openBillsTitle.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get openBillsTitle;

  /// No description provided for @emptyOpenBills.
  ///
  /// In en, this message translates to:
  /// **'No open bills'**
  String get emptyOpenBills;

  /// No description provided for @onlineOrdersTitle.
  ///
  /// In en, this message translates to:
  /// **'Online orders'**
  String get onlineOrdersTitle;

  /// No description provided for @onlineOrderNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get onlineOrderNew;

  /// No description provided for @onlineOrderAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get onlineOrderAccept;

  /// No description provided for @onlineDemoLabel.
  ///
  /// In en, this message translates to:
  /// **'Online orders (demo)'**
  String get onlineDemoLabel;

  /// No description provided for @searchTable.
  ///
  /// In en, this message translates to:
  /// **'Search table'**
  String get searchTable;

  /// No description provided for @tableRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a table number'**
  String get tableRequired;

  /// No description provided for @tableExists.
  ///
  /// In en, this message translates to:
  /// **'That table already has an open bill'**
  String get tableExists;

  /// No description provided for @actionOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get actionOk;

  /// No description provided for @dialogTitleInfo.
  ///
  /// In en, this message translates to:
  /// **'Information'**
  String get dialogTitleInfo;

  /// No description provided for @dialogTitleSuccess.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get dialogTitleSuccess;

  /// No description provided for @dialogTitleWarning.
  ///
  /// In en, this message translates to:
  /// **'Heads up'**
  String get dialogTitleWarning;

  /// No description provided for @dialogTitleError.
  ///
  /// In en, this message translates to:
  /// **'Can\'t do that'**
  String get dialogTitleError;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @aboutSection.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutSection;

  /// No description provided for @appVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'App version'**
  String get appVersionLabel;

  /// No description provided for @serverVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Server version'**
  String get serverVersionLabel;

  /// No description provided for @preferencesSection.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferencesSection;

  /// No description provided for @languageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageLabel;

  /// No description provided for @themeLabel.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeLabel;

  /// No description provided for @scannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get scannerTitle;

  /// No description provided for @scannerHint.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at a barcode'**
  String get scannerHint;

  /// No description provided for @scannerSkuLabel.
  ///
  /// In en, this message translates to:
  /// **'SKU'**
  String get scannerSkuLabel;

  /// No description provided for @scannerAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get scannerAdd;

  /// No description provided for @scannerBrowse.
  ///
  /// In en, this message translates to:
  /// **'Browse products'**
  String get scannerBrowse;

  /// No description provided for @scannerAdded.
  ///
  /// In en, this message translates to:
  /// **'Added: {name}'**
  String scannerAdded(String name);

  /// No description provided for @scannerSkuNotFound.
  ///
  /// In en, this message translates to:
  /// **'SKU not found: {sku}'**
  String scannerSkuNotFound(String sku);

  /// No description provided for @scannerOutOfStock.
  ///
  /// In en, this message translates to:
  /// **'Out of stock'**
  String get scannerOutOfStock;

  /// No description provided for @scannerModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Scanner mode'**
  String get scannerModeLabel;

  /// No description provided for @scannerModeAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get scannerModeAuto;

  /// No description provided for @scannerModeOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get scannerModeOn;

  /// No description provided for @scannerModeOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get scannerModeOff;

  /// No description provided for @printFailed.
  ///
  /// In en, this message translates to:
  /// **'Printer not reachable'**
  String get printFailed;

  /// No description provided for @actionPrint.
  ///
  /// In en, this message translates to:
  /// **'Print'**
  String get actionPrint;

  /// No description provided for @printerSection.
  ///
  /// In en, this message translates to:
  /// **'Printer'**
  String get printerSection;

  /// No description provided for @printerPaired.
  ///
  /// In en, this message translates to:
  /// **'Paired'**
  String get printerPaired;

  /// No description provided for @printerNone.
  ///
  /// In en, this message translates to:
  /// **'None found'**
  String get printerNone;

  /// No description provided for @printerTest.
  ///
  /// In en, this message translates to:
  /// **'Test print'**
  String get printerTest;

  /// No description provided for @printerOk.
  ///
  /// In en, this message translates to:
  /// **'Printed'**
  String get printerOk;

  /// No description provided for @reportsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reportsTitle;

  /// No description provided for @reportsOrders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get reportsOrders;

  /// No description provided for @reportsAvgTicket.
  ///
  /// In en, this message translates to:
  /// **'Avg ticket'**
  String get reportsAvgTicket;

  /// No description provided for @reportsPayments.
  ///
  /// In en, this message translates to:
  /// **'PAYMENT METHODS'**
  String get reportsPayments;

  /// No description provided for @reportsTopItems.
  ///
  /// In en, this message translates to:
  /// **'TOP ITEMS'**
  String get reportsTopItems;

  /// No description provided for @reportsByOutlet.
  ///
  /// In en, this message translates to:
  /// **'BY OUTLET'**
  String get reportsByOutlet;

  /// No description provided for @reportsByDay.
  ///
  /// In en, this message translates to:
  /// **'SALES BY DAY'**
  String get reportsByDay;

  /// No description provided for @reportsQtySold.
  ///
  /// In en, this message translates to:
  /// **'{qty} sold'**
  String reportsQtySold(int qty);

  /// No description provided for @reportsOpenCashier.
  ///
  /// In en, this message translates to:
  /// **'Open cashier'**
  String get reportsOpenCashier;

  /// No description provided for @reportsAttendance.
  ///
  /// In en, this message translates to:
  /// **'ATTENDANCE'**
  String get reportsAttendance;

  /// No description provided for @reportsNoAttendance.
  ///
  /// In en, this message translates to:
  /// **'No attendance in this period'**
  String get reportsNoAttendance;

  /// No description provided for @attendanceOnClock.
  ///
  /// In en, this message translates to:
  /// **'On the clock'**
  String get attendanceOnClock;

  /// No description provided for @periodDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get periodDaily;

  /// No description provided for @periodWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get periodWeekly;

  /// No description provided for @periodMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get periodMonthly;

  /// No description provided for @attendanceSection.
  ///
  /// In en, this message translates to:
  /// **'Attendance'**
  String get attendanceSection;

  /// No description provided for @attendanceClockIn.
  ///
  /// In en, this message translates to:
  /// **'Clock in'**
  String get attendanceClockIn;

  /// No description provided for @attendanceClockOut.
  ///
  /// In en, this message translates to:
  /// **'Clock out'**
  String get attendanceClockOut;

  /// No description provided for @attendanceClockedOut.
  ///
  /// In en, this message translates to:
  /// **'Not clocked in'**
  String get attendanceClockedOut;

  /// No description provided for @attendanceSince.
  ///
  /// In en, this message translates to:
  /// **'On the clock since {time}'**
  String attendanceSince(String time);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'id'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'id':
      return AppLocalizationsId();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
