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

  /// No description provided for @openBillOffline.
  ///
  /// In en, this message translates to:
  /// **'No connection. Open bills live on the server, so one cannot be started offline — reconnect first.'**
  String get openBillOffline;

  /// No description provided for @voiceFinishFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not finish — check History before trying again.'**
  String get voiceFinishFailed;

  /// No description provided for @syncPending.
  ///
  /// In en, this message translates to:
  /// **'{count} sales not yet sent — tap to retry'**
  String syncPending(int count);

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

  /// No description provided for @errorConnection.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach the server — check the connection.'**
  String get errorConnection;

  /// No description provided for @errorStockShort.
  ///
  /// In en, this message translates to:
  /// **'Not enough {name} in stock — the order was not saved.'**
  String errorStockShort(String name);

  /// No description provided for @errorSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the order (code {code}).'**
  String errorSaveFailed(int code);

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

  /// No description provided for @voidHint.
  ///
  /// In en, this message translates to:
  /// **'Cancels the whole sale — today only'**
  String get voidHint;

  /// No description provided for @refundHint.
  ///
  /// In en, this message translates to:
  /// **'Return part or all — any day'**
  String get refundHint;

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

  /// No description provided for @itemsTitle.
  ///
  /// In en, this message translates to:
  /// **'Items & prices'**
  String get itemsTitle;

  /// No description provided for @itemsCount.
  ///
  /// In en, this message translates to:
  /// **'{used} / {max}'**
  String itemsCount(int used, int max);

  /// No description provided for @itemsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add item'**
  String get itemsAdd;

  /// No description provided for @itemsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No items yet — add your first one.'**
  String get itemsEmpty;

  /// No description provided for @itemsLimitReached.
  ///
  /// In en, this message translates to:
  /// **'Item limit reached. Contact DPOS to change your plan.'**
  String get itemsLimitReached;

  /// No description provided for @itemName.
  ///
  /// In en, this message translates to:
  /// **'Item name'**
  String get itemName;

  /// No description provided for @itemCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get itemCategory;

  /// No description provided for @itemPrice.
  ///
  /// In en, this message translates to:
  /// **'Selling price'**
  String get itemPrice;

  /// No description provided for @itemCost.
  ///
  /// In en, this message translates to:
  /// **'Cost price'**
  String get itemCost;

  /// No description provided for @itemCostHint.
  ///
  /// In en, this message translates to:
  /// **'Needed for the profit report'**
  String get itemCostHint;

  /// No description provided for @itemSku.
  ///
  /// In en, this message translates to:
  /// **'SKU / barcode'**
  String get itemSku;

  /// No description provided for @itemAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available for sale'**
  String get itemAvailable;

  /// No description provided for @itemTrackStock.
  ///
  /// In en, this message translates to:
  /// **'Track stock'**
  String get itemTrackStock;

  /// No description provided for @itemOnHand.
  ///
  /// In en, this message translates to:
  /// **'On hand'**
  String get itemOnHand;

  /// No description provided for @itemNoCost.
  ///
  /// In en, this message translates to:
  /// **'No cost price'**
  String get itemNoCost;

  /// No description provided for @itemMargin.
  ///
  /// In en, this message translates to:
  /// **'Margin {amount}'**
  String itemMargin(String amount);

  /// No description provided for @itemSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get itemSaved;

  /// No description provided for @itemSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save — please try again'**
  String get itemSaveFailed;

  /// No description provided for @itemNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name and category are required'**
  String get itemNameRequired;

  /// No description provided for @reportsProfit.
  ///
  /// In en, this message translates to:
  /// **'GROSS PROFIT'**
  String get reportsProfit;

  /// No description provided for @plRevenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get plRevenue;

  /// No description provided for @plCogs.
  ///
  /// In en, this message translates to:
  /// **'Cost of goods'**
  String get plCogs;

  /// No description provided for @plGrossProfit.
  ///
  /// In en, this message translates to:
  /// **'Gross profit'**
  String get plGrossProfit;

  /// No description provided for @plMargin.
  ///
  /// In en, this message translates to:
  /// **'Margin'**
  String get plMargin;

  /// No description provided for @plMissingCost.
  ///
  /// In en, this message translates to:
  /// **'{n} sales lines have no cost price — profit reads higher than it is'**
  String plMissingCost(int n);

  /// No description provided for @plSetCostPrices.
  ///
  /// In en, this message translates to:
  /// **'Set cost prices'**
  String get plSetCostPrices;

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

  /// No description provided for @methodDebit.
  ///
  /// In en, this message translates to:
  /// **'Debit card'**
  String get methodDebit;

  /// No description provided for @methodCredit.
  ///
  /// In en, this message translates to:
  /// **'Credit card'**
  String get methodCredit;

  /// No description provided for @methodBcaCard.
  ///
  /// In en, this message translates to:
  /// **'BCA card'**
  String get methodBcaCard;

  /// No description provided for @methodShopeePay.
  ///
  /// In en, this message translates to:
  /// **'ShopeePay'**
  String get methodShopeePay;

  /// No description provided for @methodGoPay.
  ///
  /// In en, this message translates to:
  /// **'GoPay'**
  String get methodGoPay;

  /// No description provided for @methodOvo.
  ///
  /// In en, this message translates to:
  /// **'OVO'**
  String get methodOvo;

  /// No description provided for @tenderGroupCard.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get tenderGroupCard;

  /// No description provided for @tenderGroupEwallet.
  ///
  /// In en, this message translates to:
  /// **'E-wallet'**
  String get tenderGroupEwallet;

  /// No description provided for @tenderGroupOther.
  ///
  /// In en, this message translates to:
  /// **'Cash & QRIS'**
  String get tenderGroupOther;

  /// No description provided for @actionProcessCard.
  ///
  /// In en, this message translates to:
  /// **'Process on EDC'**
  String get actionProcessCard;

  /// No description provided for @actionWalletConfirm.
  ///
  /// In en, this message translates to:
  /// **'Payment received'**
  String get actionWalletConfirm;

  /// No description provided for @walletScanHint.
  ///
  /// In en, this message translates to:
  /// **'Ask the customer to scan with {wallet}'**
  String walletScanHint(String wallet);

  /// No description provided for @cardApprovedShort.
  ///
  /// In en, this message translates to:
  /// **'Approved · {code}'**
  String cardApprovedShort(String code);

  /// No description provided for @tenderNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'This payment method is not available for your plan.'**
  String get tenderNotAvailable;

  /// No description provided for @edcTitle.
  ///
  /// In en, this message translates to:
  /// **'EDC terminal'**
  String get edcTitle;

  /// No description provided for @edcInsertCard.
  ///
  /// In en, this message translates to:
  /// **'INSERT, TAP OR SWIPE CARD'**
  String get edcInsertCard;

  /// No description provided for @edcReadingCard.
  ///
  /// In en, this message translates to:
  /// **'READING CARD…'**
  String get edcReadingCard;

  /// No description provided for @edcAuthorizing.
  ///
  /// In en, this message translates to:
  /// **'AUTHORIZING…'**
  String get edcAuthorizing;

  /// No description provided for @edcApproved.
  ///
  /// In en, this message translates to:
  /// **'APPROVED'**
  String get edcApproved;

  /// No description provided for @edcDeclined.
  ///
  /// In en, this message translates to:
  /// **'DECLINED'**
  String get edcDeclined;

  /// No description provided for @edcDeclinedHint.
  ///
  /// In en, this message translates to:
  /// **'The card was declined. Try again or use another payment method.'**
  String get edcDeclinedHint;

  /// No description provided for @edcEntryMode.
  ///
  /// In en, this message translates to:
  /// **'Entry mode'**
  String get edcEntryMode;

  /// No description provided for @edcChip.
  ///
  /// In en, this message translates to:
  /// **'Chip'**
  String get edcChip;

  /// No description provided for @edcContactless.
  ///
  /// In en, this message translates to:
  /// **'Contactless'**
  String get edcContactless;

  /// No description provided for @edcSwipe.
  ///
  /// In en, this message translates to:
  /// **'Swipe'**
  String get edcSwipe;

  /// No description provided for @edcScheme.
  ///
  /// In en, this message translates to:
  /// **'Card scheme'**
  String get edcScheme;

  /// No description provided for @edcCard.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get edcCard;

  /// No description provided for @edcApprovalCode.
  ///
  /// In en, this message translates to:
  /// **'Approval code'**
  String get edcApprovalCode;

  /// No description provided for @edcRrn.
  ///
  /// In en, this message translates to:
  /// **'RRN'**
  String get edcRrn;

  /// No description provided for @edcTrace.
  ///
  /// In en, this message translates to:
  /// **'Trace / batch'**
  String get edcTrace;

  /// No description provided for @edcTerminal.
  ///
  /// In en, this message translates to:
  /// **'Terminal'**
  String get edcTerminal;

  /// No description provided for @edcProcess.
  ///
  /// In en, this message translates to:
  /// **'Process card'**
  String get edcProcess;

  /// No description provided for @edcSimulateDecline.
  ///
  /// In en, this message translates to:
  /// **'Simulate a declined card'**
  String get edcSimulateDecline;

  /// No description provided for @edcContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get edcContinue;

  /// No description provided for @edcRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get edcRetry;

  /// No description provided for @otherMethods.
  ///
  /// In en, this message translates to:
  /// **'Other methods'**
  String get otherMethods;

  /// No description provided for @chooseCard.
  ///
  /// In en, this message translates to:
  /// **'Choose card'**
  String get chooseCard;

  /// No description provided for @chooseWallet.
  ///
  /// In en, this message translates to:
  /// **'Choose e-wallet'**
  String get chooseWallet;

  /// No description provided for @actionProcessPayment.
  ///
  /// In en, this message translates to:
  /// **'Process payment'**
  String get actionProcessPayment;

  /// No description provided for @qrisAnyAppHint.
  ///
  /// In en, this message translates to:
  /// **'Scan with any payment app'**
  String get qrisAnyAppHint;

  /// No description provided for @edcPromptCard.
  ///
  /// In en, this message translates to:
  /// **'Swipe, tap or insert the card on the EDC machine'**
  String get edcPromptCard;

  /// No description provided for @walletScanApp.
  ///
  /// In en, this message translates to:
  /// **'Scan with the {wallet} app'**
  String walletScanApp(String wallet);

  /// No description provided for @amountReceivedLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount received'**
  String get amountReceivedLabel;

  /// No description provided for @tabEwallet.
  ///
  /// In en, this message translates to:
  /// **'E-Wallet'**
  String get tabEwallet;

  /// No description provided for @notaTitle.
  ///
  /// In en, this message translates to:
  /// **'Read nota'**
  String get notaTitle;

  /// No description provided for @notaIntro.
  ///
  /// In en, this message translates to:
  /// **'Take a photo of a handwritten nota and DPOS will read it for you. Nothing is saved.'**
  String get notaIntro;

  /// No description provided for @notaTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get notaTakePhoto;

  /// No description provided for @notaChooseGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get notaChooseGallery;

  /// No description provided for @notaRetake.
  ///
  /// In en, this message translates to:
  /// **'Retake'**
  String get notaRetake;

  /// No description provided for @notaReading.
  ///
  /// In en, this message translates to:
  /// **'Reading the nota…'**
  String get notaReading;

  /// No description provided for @notaReadingHint.
  ///
  /// In en, this message translates to:
  /// **'This can take up to half a minute.'**
  String get notaReadingHint;

  /// No description provided for @notaResultTitle.
  ///
  /// In en, this message translates to:
  /// **'What DPOS read'**
  String get notaResultTitle;

  /// No description provided for @notaNumber.
  ///
  /// In en, this message translates to:
  /// **'Nota no.'**
  String get notaNumber;

  /// No description provided for @notaDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get notaDate;

  /// No description provided for @notaCustomer.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get notaCustomer;

  /// No description provided for @notaItems.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get notaItems;

  /// No description provided for @notaColItem.
  ///
  /// In en, this message translates to:
  /// **'Item'**
  String get notaColItem;

  /// No description provided for @notaColQty.
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get notaColQty;

  /// No description provided for @notaColPrice.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get notaColPrice;

  /// No description provided for @notaColTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get notaColTotal;

  /// No description provided for @notaTotalWritten.
  ///
  /// In en, this message translates to:
  /// **'Total on the nota'**
  String get notaTotalWritten;

  /// No description provided for @notaLinesSum.
  ///
  /// In en, this message translates to:
  /// **'Sum of the lines'**
  String get notaLinesSum;

  /// No description provided for @notaTotalMismatch.
  ///
  /// In en, this message translates to:
  /// **'The lines don\'t add up to the written total — check the photo.'**
  String get notaTotalMismatch;

  /// No description provided for @notaDifference.
  ///
  /// In en, this message translates to:
  /// **'Difference'**
  String get notaDifference;

  /// No description provided for @notaDiffLinesMore.
  ///
  /// In en, this message translates to:
  /// **'The lines come to {amount} more than the written total.'**
  String notaDiffLinesMore(String amount);

  /// No description provided for @notaDiffLinesLess.
  ///
  /// In en, this message translates to:
  /// **'The lines come to {amount} less than the written total.'**
  String notaDiffLinesLess(String amount);

  /// No description provided for @notaTable.
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get notaTable;

  /// No description provided for @notaFixLine.
  ///
  /// In en, this message translates to:
  /// **'Correct line'**
  String get notaFixLine;

  /// No description provided for @notaFixHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a line to correct it.'**
  String get notaFixHint;

  /// No description provided for @notaEdited.
  ///
  /// In en, this message translates to:
  /// **'edited'**
  String get notaEdited;

  /// No description provided for @notaLineTotalIs.
  ///
  /// In en, this message translates to:
  /// **'Total: {amount}'**
  String notaLineTotalIs(String amount);

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @notaUnreadable.
  ///
  /// In en, this message translates to:
  /// **'Not readable'**
  String get notaUnreadable;

  /// No description provided for @notaNoItems.
  ///
  /// In en, this message translates to:
  /// **'No item lines could be read.'**
  String get notaNoItems;

  /// No description provided for @notaUnclearTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read clearly'**
  String get notaUnclearTitle;

  /// No description provided for @notaConfidence.
  ///
  /// In en, this message translates to:
  /// **'Confidence {pct}%'**
  String notaConfidence(int pct);

  /// No description provided for @notaReadBy.
  ///
  /// In en, this message translates to:
  /// **'Read by {model} in {secs}s'**
  String notaReadBy(String model, String secs);

  /// No description provided for @notaRawData.
  ///
  /// In en, this message translates to:
  /// **'Raw data'**
  String get notaRawData;

  /// No description provided for @notaErrorUnsupported.
  ///
  /// In en, this message translates to:
  /// **'That file isn\'t a supported photo. Use JPEG or PNG.'**
  String get notaErrorUnsupported;

  /// No description provided for @notaErrorTooLarge.
  ///
  /// In en, this message translates to:
  /// **'That photo is too large. Try again with the camera.'**
  String get notaErrorTooLarge;

  /// No description provided for @notaErrorUnreadable.
  ///
  /// In en, this message translates to:
  /// **'The nota couldn\'t be read. Try a clearer, closer photo.'**
  String get notaErrorUnreadable;

  /// No description provided for @notaErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Reading failed ({code}). Check the connection and try again.'**
  String notaErrorGeneric(String code);

  /// No description provided for @notaReadAnother.
  ///
  /// In en, this message translates to:
  /// **'Read another nota'**
  String get notaReadAnother;

  /// No description provided for @notaMakeOrder.
  ///
  /// In en, this message translates to:
  /// **'Make it an order'**
  String get notaMakeOrder;

  /// No description provided for @notaOrderTitle.
  ///
  /// In en, this message translates to:
  /// **'Order from nota'**
  String get notaOrderTitle;

  /// No description provided for @notaOrderFrom.
  ///
  /// In en, this message translates to:
  /// **'Read from nota #{number}'**
  String notaOrderFrom(String number);

  /// No description provided for @notaOrderEmpty.
  ///
  /// In en, this message translates to:
  /// **'No lines left to order.'**
  String get notaOrderEmpty;

  /// No description provided for @notaQtyUnreadable.
  ///
  /// In en, this message translates to:
  /// **'The quantity on the nota isn\'t a whole number'**
  String get notaQtyUnreadable;

  /// No description provided for @notaPriceOnPaper.
  ///
  /// In en, this message translates to:
  /// **'Nota says {price} — the shop\'s price is charged'**
  String notaPriceOnPaper(String price);

  /// No description provided for @notaCameraDenied.
  ///
  /// In en, this message translates to:
  /// **'Camera access is needed to photograph a nota.'**
  String get notaCameraDenied;

  /// No description provided for @notaPanHint.
  ///
  /// In en, this message translates to:
  /// **'Drag · double-tap or pinch to zoom'**
  String get notaPanHint;

  /// No description provided for @notaFitImage.
  ///
  /// In en, this message translates to:
  /// **'Fit to width'**
  String get notaFitImage;

  /// No description provided for @notaFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Full screen'**
  String get notaFullscreen;

  /// No description provided for @notaStubBanner.
  ///
  /// In en, this message translates to:
  /// **'Demo mode: the AI reader is not switched on for this server yet, so this is a fixed sample — it did NOT read your photo. Every photo will show the same result until it is enabled.'**
  String get notaStubBanner;

  /// No description provided for @calcTitle.
  ///
  /// In en, this message translates to:
  /// **'Input nota'**
  String get calcTitle;

  /// No description provided for @calcNotaNumber.
  ///
  /// In en, this message translates to:
  /// **'Nota #{n}'**
  String calcNotaNumber(int n);

  /// No description provided for @calcCurrentValue.
  ///
  /// In en, this message translates to:
  /// **'Current value'**
  String get calcCurrentValue;

  /// No description provided for @calcItemCountLabel.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get calcItemCountLabel;

  /// No description provided for @calcItemCount.
  ///
  /// In en, this message translates to:
  /// **'{n} item'**
  String calcItemCount(int n);

  /// No description provided for @calcItemLine.
  ///
  /// In en, this message translates to:
  /// **'Item {n}'**
  String calcItemLine(int n);

  /// No description provided for @calcEmptyList.
  ///
  /// In en, this message translates to:
  /// **'Key an amount, then press ↵'**
  String get calcEmptyList;

  /// No description provided for @calcTotal.
  ///
  /// In en, this message translates to:
  /// **'TOTAL'**
  String get calcTotal;

  /// No description provided for @calcAmountReceived.
  ///
  /// In en, this message translates to:
  /// **'Cash received'**
  String get calcAmountReceived;

  /// No description provided for @calcShort.
  ///
  /// In en, this message translates to:
  /// **'Short'**
  String get calcShort;

  /// No description provided for @calcCancelTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel this nota?'**
  String get calcCancelTitle;

  /// No description provided for @calcCancelBody.
  ///
  /// In en, this message translates to:
  /// **'Every item will be deleted. The nota number stays the same.'**
  String get calcCancelBody;

  /// No description provided for @calcCancelConfirm.
  ///
  /// In en, this message translates to:
  /// **'Yes, cancel'**
  String get calcCancelConfirm;

  /// No description provided for @calcCancelKeep.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get calcCancelKeep;

  /// No description provided for @calcBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get calcBack;

  /// No description provided for @calcFinish.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get calcFinish;

  /// No description provided for @calcPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid · change {amount}'**
  String calcPaid(String amount);

  /// No description provided for @calcTaxLine.
  ///
  /// In en, this message translates to:
  /// **'{label} {pct}%'**
  String calcTaxLine(String label, String pct);

  /// No description provided for @calcSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'This sale was not saved ({code}). Nothing was recorded — check the connection and press Done again.'**
  String calcSaveFailed(String code);

  /// No description provided for @loginVersionApp.
  ///
  /// In en, this message translates to:
  /// **'App v{version} ({build})'**
  String loginVersionApp(String version, String build);

  /// No description provided for @loginVersionServer.
  ///
  /// In en, this message translates to:
  /// **'Server v{version}'**
  String loginVersionServer(String version);

  /// No description provided for @calcPreviousSaved.
  ///
  /// In en, this message translates to:
  /// **'Your previous nota had already been saved — check History.'**
  String get calcPreviousSaved;

  /// No description provided for @chatTitle.
  ///
  /// In en, this message translates to:
  /// **'Nota'**
  String get chatTitle;

  /// No description provided for @chatWelcome.
  ///
  /// In en, this message translates to:
  /// **'Send a photo of a nota. I will read it, and you check it before the transaction is created.'**
  String get chatWelcome;

  /// No description provided for @chatCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get chatCamera;

  /// No description provided for @chatGallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get chatGallery;

  /// No description provided for @chatReading.
  ///
  /// In en, this message translates to:
  /// **'Reading the nota…'**
  String get chatReading;

  /// No description provided for @chatReadFailed.
  ///
  /// In en, this message translates to:
  /// **'The nota could not be read ({code}). Try another photo.'**
  String chatReadFailed(String code);

  /// No description provided for @chatNotaHeader.
  ///
  /// In en, this message translates to:
  /// **'Nota #{number}'**
  String chatNotaHeader(String number);

  /// No description provided for @chatNoNumber.
  ///
  /// In en, this message translates to:
  /// **'Nota number not readable'**
  String get chatNoNumber;

  /// No description provided for @chatNotCharged.
  ///
  /// In en, this message translates to:
  /// **'not charged'**
  String get chatNotCharged;

  /// No description provided for @chatWrittenTotal.
  ///
  /// In en, this message translates to:
  /// **'Total on the nota'**
  String get chatWrittenTotal;

  /// No description provided for @chatLinesTotal.
  ///
  /// In en, this message translates to:
  /// **'To be charged'**
  String get chatLinesTotal;

  /// No description provided for @chatTotalsDisagree.
  ///
  /// In en, this message translates to:
  /// **'The total written on the nota differs from its lines. The transaction uses the lines: {amount}.'**
  String chatTotalsDisagree(String amount);

  /// No description provided for @chatTotalOnly.
  ///
  /// In en, this message translates to:
  /// **'No line has its own price, so the transaction is the total written on the nota.'**
  String get chatTotalOnly;

  /// No description provided for @chatNothingToCharge.
  ///
  /// In en, this message translates to:
  /// **'No price could be read, so there is nothing to charge yet. Try a clearer photo.'**
  String get chatNothingToCharge;

  /// No description provided for @chatUnclear.
  ///
  /// In en, this message translates to:
  /// **'Unclear: {items}'**
  String chatUnclear(String items);

  /// No description provided for @chatAskFix.
  ///
  /// In en, this message translates to:
  /// **'Does anything need fixing?'**
  String get chatAskFix;

  /// No description provided for @chatFixYes.
  ///
  /// In en, this message translates to:
  /// **'Yes, fix it'**
  String get chatFixYes;

  /// No description provided for @chatFixNo.
  ///
  /// In en, this message translates to:
  /// **'No, create it'**
  String get chatFixNo;

  /// No description provided for @chatFixNotYet.
  ///
  /// In en, this message translates to:
  /// **'Fixing a reading is not available yet. This nota was NOT recorded — retake the photo if something was misread.'**
  String get chatFixNotYet;

  /// No description provided for @chatCreating.
  ///
  /// In en, this message translates to:
  /// **'Creating the transaction…'**
  String get chatCreating;

  /// No description provided for @chatCreated.
  ///
  /// In en, this message translates to:
  /// **'Transaction created — waiting for payment.'**
  String get chatCreated;

  /// No description provided for @chatPayNow.
  ///
  /// In en, this message translates to:
  /// **'Pay now'**
  String get chatPayNow;

  /// No description provided for @chatAlreadyRecorded.
  ///
  /// In en, this message translates to:
  /// **'Nota #{number} is already recorded, so it was not created twice.'**
  String chatAlreadyRecorded(String number);

  /// No description provided for @chatViewTransaction.
  ///
  /// In en, this message translates to:
  /// **'View transaction'**
  String get chatViewTransaction;

  /// No description provided for @chatCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'The transaction was not created ({code}). Nothing was recorded — try again.'**
  String chatCreateFailed(String code);

  /// No description provided for @bizTypeFnb.
  ///
  /// In en, this message translates to:
  /// **'F&B'**
  String get bizTypeFnb;

  /// No description provided for @bizTypeGrocery.
  ///
  /// In en, this message translates to:
  /// **'Grocery'**
  String get bizTypeGrocery;

  /// No description provided for @bizTypeHhi.
  ///
  /// In en, this message translates to:
  /// **'High Human Interactions'**
  String get bizTypeHhi;

  /// No description provided for @chatNoteRecorded.
  ///
  /// In en, this message translates to:
  /// **'Kept as the transaction note:'**
  String get chatNoteRecorded;

  /// No description provided for @detailCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get detailCustomer;

  /// No description provided for @detailNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get detailNote;

  /// No description provided for @sttLabTitle.
  ///
  /// In en, this message translates to:
  /// **'Voice test'**
  String get sttLabTitle;

  /// No description provided for @sttSettingsRow.
  ///
  /// In en, this message translates to:
  /// **'Voice test (speech-to-text)'**
  String get sttSettingsRow;

  /// No description provided for @sttSettingsHint.
  ///
  /// In en, this message translates to:
  /// **'Android only — for testing and tuning'**
  String get sttSettingsHint;

  /// No description provided for @sttStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get sttStatus;

  /// No description provided for @sttFirstWord.
  ///
  /// In en, this message translates to:
  /// **'First word'**
  String get sttFirstWord;

  /// No description provided for @sttSaySomething.
  ///
  /// In en, this message translates to:
  /// **'Tap Listen and say something…'**
  String get sttSaySomething;

  /// No description provided for @sttListen.
  ///
  /// In en, this message translates to:
  /// **'Listen'**
  String get sttListen;

  /// No description provided for @sttStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get sttStop;

  /// No description provided for @sttClear.
  ///
  /// In en, this message translates to:
  /// **'Clear results'**
  String get sttClear;

  /// No description provided for @sttCopyDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Copy diagnostics'**
  String get sttCopyDiagnostics;

  /// No description provided for @sttCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get sttCopied;

  /// No description provided for @sttResultsLabel.
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get sttResultsLabel;

  /// No description provided for @sttNoResults.
  ///
  /// In en, this message translates to:
  /// **'Nothing heard yet.'**
  String get sttNoResults;

  /// No description provided for @sttTuning.
  ///
  /// In en, this message translates to:
  /// **'Per listen'**
  String get sttTuning;

  /// No description provided for @sttTuningInit.
  ///
  /// In en, this message translates to:
  /// **'Per engine start'**
  String get sttTuningInit;

  /// No description provided for @sttTuningInitHint.
  ///
  /// In en, this message translates to:
  /// **'Changing one of these restarts the recognizer.'**
  String get sttTuningInitHint;

  /// No description provided for @sttLocaleAuto.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get sttLocaleAuto;

  /// No description provided for @sttIndonesianFound.
  ///
  /// In en, this message translates to:
  /// **'Indonesian on this device: {id}'**
  String sttIndonesianFound(String id);

  /// No description provided for @sttNoIndonesian.
  ///
  /// In en, this message translates to:
  /// **'This device offers no Indonesian recognition.'**
  String get sttNoIndonesian;

  /// No description provided for @sttNoRecognizer.
  ///
  /// In en, this message translates to:
  /// **'No speech recognizer available on this device. On some Android builds, turning on androidIntentLookup below helps.'**
  String get sttNoRecognizer;

  /// No description provided for @sttAndroidOnly.
  ///
  /// In en, this message translates to:
  /// **'Voice input is Android only for now.'**
  String get sttAndroidOnly;

  /// No description provided for @sttMicDeniedTitle.
  ///
  /// In en, this message translates to:
  /// **'Microphone needed'**
  String get sttMicDeniedTitle;

  /// No description provided for @sttMicDeniedBody.
  ///
  /// In en, this message translates to:
  /// **'Voice input needs permission to use the microphone.'**
  String get sttMicDeniedBody;

  /// No description provided for @sttOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get sttOpenSettings;

  /// No description provided for @sttPauseForHint.
  ///
  /// In en, this message translates to:
  /// **'Silence that ends the session. Counted from the moment listening starts, NOT from the first word — below 2s it can end before you speak.'**
  String get sttPauseForHint;

  /// No description provided for @sttOnDeviceHint.
  ///
  /// In en, this message translates to:
  /// **'Forces offline recognition; listening fails outright if this device cannot.'**
  String get sttOnDeviceHint;

  /// No description provided for @sttNoBluetoothHint.
  ///
  /// In en, this message translates to:
  /// **'Ignore Bluetooth audio routing. Worth testing with the thermal printer paired.'**
  String get sttNoBluetoothHint;

  /// No description provided for @sttIntentLookupHint.
  ///
  /// In en, this message translates to:
  /// **'Workaround for Android builds that do not declare a recognizer properly.'**
  String get sttIntentLookupHint;

  /// No description provided for @sttDebugLoggingHint.
  ///
  /// In en, this message translates to:
  /// **'Writes the plugin\'s own trace to logcat (tag SpeechToText).'**
  String get sttDebugLoggingHint;

  /// No description provided for @sttIosOnlyNote.
  ///
  /// In en, this message translates to:
  /// **'listenMode, sampleRate, autoPunctuation and haptics are iOS-only in this plugin version, so they are not offered here.'**
  String get sttIosOnlyNote;

  /// No description provided for @sttLog.
  ///
  /// In en, this message translates to:
  /// **'Event log'**
  String get sttLog;

  /// No description provided for @sttListenContinuous.
  ///
  /// In en, this message translates to:
  /// **'Listen (keeps going)'**
  String get sttListenContinuous;

  /// No description provided for @sttContinuousHint.
  ///
  /// In en, this message translates to:
  /// **'Keep listening until you press stop. Each pause ends one utterance and the next session starts by itself — the recognizer has no continuous mode of its own.'**
  String get sttContinuousHint;

  /// No description provided for @sttRestarting.
  ///
  /// In en, this message translates to:
  /// **'Still listening — starting the next stretch…'**
  String get sttRestarting;

  /// No description provided for @sttModeLabel.
  ///
  /// In en, this message translates to:
  /// **'What to do with what it hears'**
  String get sttModeLabel;

  /// No description provided for @sttModePlain.
  ///
  /// In en, this message translates to:
  /// **'Text only'**
  String get sttModePlain;

  /// No description provided for @sttModeStock.
  ///
  /// In en, this message translates to:
  /// **'Check against stock'**
  String get sttModeStock;

  /// No description provided for @sttStockNotFound.
  ///
  /// In en, this message translates to:
  /// **'Not in the catalogue'**
  String get sttStockNotFound;

  /// No description provided for @sttStockUnavailable.
  ///
  /// In en, this message translates to:
  /// **'{name} is switched off'**
  String sttStockUnavailable(String name);

  /// No description provided for @sttStockOut.
  ///
  /// In en, this message translates to:
  /// **'{name} — out of stock (0 left)'**
  String sttStockOut(String name);

  /// No description provided for @sttStockShort.
  ///
  /// In en, this message translates to:
  /// **'{name} — only {left} left, {asked} asked for'**
  String sttStockShort(String name, int left, int asked);

  /// No description provided for @sttStockOk.
  ///
  /// In en, this message translates to:
  /// **'{name} ×{asked} — {left} left'**
  String sttStockOk(String name, int asked, int left);

  /// No description provided for @sttStockOkUntracked.
  ///
  /// In en, this message translates to:
  /// **'{name} ×{asked} — stock not tracked'**
  String sttStockOkUntracked(String name, int asked);

  /// No description provided for @voiceOrderTitle.
  ///
  /// In en, this message translates to:
  /// **'Voice order'**
  String get voiceOrderTitle;

  /// No description provided for @voiceModeCatalogue.
  ///
  /// In en, this message translates to:
  /// **'From catalogue'**
  String get voiceModeCatalogue;

  /// No description provided for @voiceModeOpenPrice.
  ///
  /// In en, this message translates to:
  /// **'Spoken price'**
  String get voiceModeOpenPrice;

  /// No description provided for @voiceEmpty.
  ///
  /// In en, this message translates to:
  /// **'Press the microphone, then read the order out.'**
  String get voiceEmpty;

  /// No description provided for @voiceColItem.
  ///
  /// In en, this message translates to:
  /// **'Item'**
  String get voiceColItem;

  /// No description provided for @voiceColQty.
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get voiceColQty;

  /// No description provided for @voiceColPrice.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get voiceColPrice;

  /// No description provided for @voiceColTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get voiceColTotal;

  /// No description provided for @voiceAddToCart.
  ///
  /// In en, this message translates to:
  /// **'Add to cart'**
  String get voiceAddToCart;

  /// No description provided for @voiceNeedsPrice.
  ///
  /// In en, this message translates to:
  /// **'No price said'**
  String get voiceNeedsPrice;

  /// No description provided for @voiceRepeatIgnored.
  ///
  /// In en, this message translates to:
  /// **'Heard again within seconds — treated as a repeat, not added.'**
  String get voiceRepeatIgnored;

  /// No description provided for @voiceFixLines.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Fix 1 marked line first.} other{Fix {count} marked lines first.}}'**
  String voiceFixLines(int count);

  /// No description provided for @sttStockNoCatalog.
  ///
  /// In en, this message translates to:
  /// **'This account has no catalogue to check against.'**
  String get sttStockNoCatalog;

  /// No description provided for @sttStopPhraseHint.
  ///
  /// In en, this message translates to:
  /// **'Say “{phrase}” to stop listening.'**
  String sttStopPhraseHint(String phrase);
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
