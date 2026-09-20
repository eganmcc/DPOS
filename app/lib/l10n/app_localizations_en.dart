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
  String get sessionExpired => 'Your session expired. Please sign in again.';

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
  String get voidOwnerOnly => 'Only an owner or manager can void a sale.';

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
  String get voidWindowExpired =>
      'Voids are only allowed on the same day — issue a refund instead.';

  @override
  String get voidHint => 'Cancels the whole sale — today only';

  @override
  String get refundHint => 'Return part or all — any day';

  @override
  String get voidReasonWrongItem => 'Wrong item';

  @override
  String get voidReasonWrongPrice => 'Wrong price';

  @override
  String get voidReasonCustomerCancel => 'Customer cancelled';

  @override
  String get voidReasonTest => 'Test transaction';

  @override
  String get actionRefund => 'Refund';

  @override
  String get refundTitle => 'Refund sale';

  @override
  String get refundFull => 'Full';

  @override
  String get refundPartial => 'By item';

  @override
  String get refundReasonLabel => 'Refund reason';

  @override
  String get refundEstimate => 'Estimated refund';

  @override
  String get refundSuccess => 'Refund processed';

  @override
  String get refundFailed => 'Refund failed — please try again';

  @override
  String get refundedSoFar => 'Refunded so far';

  @override
  String get refundNothingLeft => 'Nothing left to refund on this sale.';

  @override
  String get refundReasonDamaged => 'Damaged / defective';

  @override
  String get refundReasonReturn => 'Customer return';

  @override
  String get refundReasonQuality => 'Quality issue';

  @override
  String get managerApprovalTitle => 'Manager approval';

  @override
  String get managerPinLabel => 'Manager / owner PIN';

  @override
  String get approvalInvalid => 'Invalid manager PIN';

  @override
  String get approvalRequired => 'Manager approval is required';

  @override
  String get actionCancelBill => 'Cancel bill';

  @override
  String get cancelBillTitle => 'Cancel this bill?';

  @override
  String get cancelBillBody =>
      'Reserved stock is released and the bill is closed. No payment was taken.';

  @override
  String get cancelSuccess => 'Bill cancelled and stock released';

  @override
  String get cancelFailed => 'Cancel failed — please try again';

  @override
  String get clockInPromptTitle => 'Clock in now?';

  @override
  String get actionLater => 'Later';

  @override
  String get clockOutPromptTitle => 'Clock out?';

  @override
  String get clockOutPromptBody =>
      'You\'re still on the clock. Clock out before logging out?';

  @override
  String get actionLogoutOnly => 'Just log out';

  @override
  String get actionClockOutAndLogout => 'Clock out & log out';

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
  String get updateOrder => 'Update order';

  @override
  String get orderSaved => 'Order processed';

  @override
  String get openBillsTitle => 'Orders';

  @override
  String get emptyOpenBills => 'No open bills';

  @override
  String get onlineOrdersTitle => 'Online orders';

  @override
  String get onlineOrderNew => 'New';

  @override
  String get onlineOrderAccept => 'Accept';

  @override
  String get onlineDemoLabel => 'Online orders (demo)';

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

  @override
  String get reportsTitle => 'Reports';

  @override
  String get reportsOrders => 'Orders';

  @override
  String get reportsAvgTicket => 'Avg ticket';

  @override
  String get reportsPayments => 'PAYMENT METHODS';

  @override
  String get itemsTitle => 'Items & prices';

  @override
  String itemsCount(int used, int max) {
    return '$used / $max';
  }

  @override
  String get itemsAdd => 'Add item';

  @override
  String get itemsEmpty => 'No items yet — add your first one.';

  @override
  String get itemsLimitReached =>
      'Item limit reached. Contact DPOS to change your plan.';

  @override
  String get itemName => 'Item name';

  @override
  String get itemCategory => 'Category';

  @override
  String get itemPrice => 'Selling price';

  @override
  String get itemCost => 'Cost price';

  @override
  String get itemCostHint => 'Needed for the profit report';

  @override
  String get itemSku => 'SKU / barcode';

  @override
  String get itemAvailable => 'Available for sale';

  @override
  String get itemTrackStock => 'Track stock';

  @override
  String get itemOnHand => 'On hand';

  @override
  String get itemNoCost => 'No cost price';

  @override
  String itemMargin(String amount) {
    return 'Margin $amount';
  }

  @override
  String get itemSaved => 'Saved';

  @override
  String get itemSaveFailed => 'Could not save — please try again';

  @override
  String get itemNameRequired => 'Name and category are required';

  @override
  String get reportsProfit => 'GROSS PROFIT';

  @override
  String get plRevenue => 'Revenue';

  @override
  String get plCogs => 'Cost of goods';

  @override
  String get plGrossProfit => 'Gross profit';

  @override
  String get plMargin => 'Margin';

  @override
  String plMissingCost(int n) {
    return '$n sales lines have no cost price — profit reads higher than it is';
  }

  @override
  String get plSetCostPrices => 'Set cost prices';

  @override
  String get reportsTopItems => 'TOP ITEMS';

  @override
  String get reportsByOutlet => 'BY OUTLET';

  @override
  String get reportsByDay => 'SALES BY DAY';

  @override
  String reportsQtySold(int qty) {
    return '$qty sold';
  }

  @override
  String get reportsOpenCashier => 'Open cashier';

  @override
  String get reportsAttendance => 'ATTENDANCE';

  @override
  String get reportsNoAttendance => 'No attendance in this period';

  @override
  String get attendanceOnClock => 'On the clock';

  @override
  String get periodDaily => 'Daily';

  @override
  String get periodWeekly => 'Weekly';

  @override
  String get periodMonthly => 'Monthly';

  @override
  String get attendanceSection => 'Attendance';

  @override
  String get attendanceClockIn => 'Clock in';

  @override
  String get attendanceClockOut => 'Clock out';

  @override
  String get attendanceClockedOut => 'Not clocked in';

  @override
  String attendanceSince(String time) {
    return 'On the clock since $time';
  }

  @override
  String get methodDebit => 'Debit card';

  @override
  String get methodCredit => 'Credit card';

  @override
  String get methodBcaCard => 'BCA card';

  @override
  String get methodShopeePay => 'ShopeePay';

  @override
  String get methodGoPay => 'GoPay';

  @override
  String get methodOvo => 'OVO';

  @override
  String get tenderGroupCard => 'Card';

  @override
  String get tenderGroupEwallet => 'E-wallet';

  @override
  String get tenderGroupOther => 'Cash & QRIS';

  @override
  String get actionProcessCard => 'Process on EDC';

  @override
  String get actionWalletConfirm => 'Payment received';

  @override
  String walletScanHint(String wallet) {
    return 'Ask the customer to scan with $wallet';
  }

  @override
  String cardApprovedShort(String code) {
    return 'Approved · $code';
  }

  @override
  String get tenderNotAvailable =>
      'This payment method is not available for your plan.';

  @override
  String get edcTitle => 'EDC terminal';

  @override
  String get edcInsertCard => 'INSERT, TAP OR SWIPE CARD';

  @override
  String get edcReadingCard => 'READING CARD…';

  @override
  String get edcAuthorizing => 'AUTHORIZING…';

  @override
  String get edcApproved => 'APPROVED';

  @override
  String get edcDeclined => 'DECLINED';

  @override
  String get edcDeclinedHint =>
      'The card was declined. Try again or use another payment method.';

  @override
  String get edcEntryMode => 'Entry mode';

  @override
  String get edcChip => 'Chip';

  @override
  String get edcContactless => 'Contactless';

  @override
  String get edcSwipe => 'Swipe';

  @override
  String get edcScheme => 'Card scheme';

  @override
  String get edcCard => 'Card';

  @override
  String get edcApprovalCode => 'Approval code';

  @override
  String get edcRrn => 'RRN';

  @override
  String get edcTrace => 'Trace / batch';

  @override
  String get edcTerminal => 'Terminal';

  @override
  String get edcProcess => 'Process card';

  @override
  String get edcSimulateDecline => 'Simulate a declined card';

  @override
  String get edcContinue => 'Continue';

  @override
  String get edcRetry => 'Try again';

  @override
  String get otherMethods => 'Other methods';

  @override
  String get chooseCard => 'Choose card';

  @override
  String get chooseWallet => 'Choose e-wallet';

  @override
  String get actionProcessPayment => 'Process payment';

  @override
  String get qrisAnyAppHint => 'Scan with any payment app';

  @override
  String get edcPromptCard =>
      'Swipe, tap or insert the card on the EDC machine';

  @override
  String walletScanApp(String wallet) {
    return 'Scan with the $wallet app';
  }

  @override
  String get amountReceivedLabel => 'Amount received';

  @override
  String get tabEwallet => 'E-Wallet';

  @override
  String get notaTitle => 'Read nota';

  @override
  String get notaIntro =>
      'Take a photo of a handwritten nota and DPOS will read it for you. Nothing is saved.';

  @override
  String get notaTakePhoto => 'Take photo';

  @override
  String get notaChooseGallery => 'Choose from gallery';

  @override
  String get notaRetake => 'Retake';

  @override
  String get notaReading => 'Reading the nota…';

  @override
  String get notaReadingHint => 'This can take up to half a minute.';

  @override
  String get notaResultTitle => 'What DPOS read';

  @override
  String get notaNumber => 'Nota no.';

  @override
  String get notaDate => 'Date';

  @override
  String get notaCustomer => 'Name';

  @override
  String get notaItems => 'Items';

  @override
  String get notaColItem => 'Item';

  @override
  String get notaColQty => 'Qty';

  @override
  String get notaColPrice => 'Price';

  @override
  String get notaColTotal => 'Total';

  @override
  String get notaTotalWritten => 'Total on the nota';

  @override
  String get notaLinesSum => 'Sum of the lines';

  @override
  String get notaTotalMismatch =>
      'The lines don\'t add up to the written total — check the photo.';

  @override
  String get notaUnreadable => 'Not readable';

  @override
  String get notaNoItems => 'No item lines could be read.';

  @override
  String get notaUnclearTitle => 'Couldn\'t read clearly';

  @override
  String notaConfidence(int pct) {
    return 'Confidence $pct%';
  }

  @override
  String notaReadBy(String model, String secs) {
    return 'Read by $model in ${secs}s';
  }

  @override
  String get notaRawData => 'Raw data';

  @override
  String get notaErrorUnsupported =>
      'That file isn\'t a supported photo. Use JPEG or PNG.';

  @override
  String get notaErrorTooLarge =>
      'That photo is too large. Try again with the camera.';

  @override
  String get notaErrorUnreadable =>
      'The nota couldn\'t be read. Try a clearer, closer photo.';

  @override
  String notaErrorGeneric(String code) {
    return 'Reading failed ($code). Check the connection and try again.';
  }

  @override
  String get notaReadAnother => 'Read another nota';

  @override
  String get notaCameraDenied =>
      'Camera access is needed to photograph a nota.';

  @override
  String get notaPanHint => 'Drag · double-tap or pinch to zoom';

  @override
  String get notaFitImage => 'Fit to width';

  @override
  String get notaFullscreen => 'Full screen';

  @override
  String get notaStubBanner =>
      'Demo mode: the AI reader is not switched on for this server yet, so this is a fixed sample — it did NOT read your photo. Every photo will show the same result until it is enabled.';

  @override
  String get calcTitle => 'Input nota';

  @override
  String calcNotaNumber(int n) {
    return 'Nota #$n';
  }

  @override
  String get calcCurrentValue => 'Current value';

  @override
  String get calcItemCountLabel => 'Items';

  @override
  String calcItemCount(int n) {
    return '$n item';
  }

  @override
  String calcItemLine(int n) {
    return 'Item $n';
  }

  @override
  String get calcEmptyList => 'Key an amount, then press ↵';

  @override
  String get calcTotal => 'TOTAL';

  @override
  String get calcAmountReceived => 'Cash received';

  @override
  String get calcShort => 'Short';

  @override
  String get calcCancelTitle => 'Cancel this nota?';

  @override
  String get calcCancelBody =>
      'Every item will be deleted. The nota number stays the same.';

  @override
  String get calcCancelConfirm => 'Yes, cancel';

  @override
  String get calcCancelKeep => 'No';

  @override
  String get calcBack => 'Back';

  @override
  String get calcFinish => 'Done';

  @override
  String calcPaid(String amount) {
    return 'Paid · change $amount';
  }

  @override
  String calcTaxLine(String label, String pct) {
    return '$label $pct%';
  }

  @override
  String calcSaveFailed(String code) {
    return 'This sale was not saved ($code). Nothing was recorded — check the connection and press Done again.';
  }

  @override
  String loginVersionApp(String version, String build) {
    return 'App v$version ($build)';
  }

  @override
  String loginVersionServer(String version) {
    return 'Server v$version';
  }

  @override
  String get calcPreviousSaved =>
      'Your previous nota had already been saved — check History.';

  @override
  String get chatTitle => 'Nota';

  @override
  String get chatWelcome =>
      'Send a photo of a nota. I will read it, and you check it before the transaction is created.';

  @override
  String get chatCamera => 'Camera';

  @override
  String get chatGallery => 'Gallery';

  @override
  String get chatReading => 'Reading the nota…';

  @override
  String chatReadFailed(String code) {
    return 'The nota could not be read ($code). Try another photo.';
  }

  @override
  String chatNotaHeader(String number) {
    return 'Nota #$number';
  }

  @override
  String get chatNoNumber => 'Nota number not readable';

  @override
  String get chatNotCharged => 'not charged';

  @override
  String get chatWrittenTotal => 'Total on the nota';

  @override
  String get chatLinesTotal => 'To be charged';

  @override
  String chatTotalsDisagree(String amount) {
    return 'The total written on the nota differs from its lines. The transaction uses the lines: $amount.';
  }

  @override
  String get chatTotalOnly =>
      'No line has its own price, so the transaction is the total written on the nota.';

  @override
  String get chatNothingToCharge =>
      'No price could be read, so there is nothing to charge yet. Try a clearer photo.';

  @override
  String chatUnclear(String items) {
    return 'Unclear: $items';
  }

  @override
  String get chatAskFix => 'Does anything need fixing?';

  @override
  String get chatFixYes => 'Yes, fix it';

  @override
  String get chatFixNo => 'No, create it';

  @override
  String get chatFixNotYet =>
      'Fixing a reading is not available yet. This nota was NOT recorded — retake the photo if something was misread.';

  @override
  String get chatCreating => 'Creating the transaction…';

  @override
  String get chatCreated => 'Transaction created — waiting for payment.';

  @override
  String get chatPayNow => 'Pay now';

  @override
  String chatAlreadyRecorded(String number) {
    return 'Nota #$number is already recorded, so it was not created twice.';
  }

  @override
  String get chatViewTransaction => 'View transaction';

  @override
  String chatCreateFailed(String code) {
    return 'The transaction was not created ($code). Nothing was recorded — try again.';
  }

  @override
  String get bizTypeFnb => 'F&B';

  @override
  String get bizTypeGrocery => 'Grocery';

  @override
  String get bizTypeHhi => 'High Human Interactions';

  @override
  String get chatNoteRecorded => 'Kept as the transaction note:';

  @override
  String get detailCustomer => 'Customer';

  @override
  String get detailNote => 'Note';

  @override
  String get sttLabTitle => 'Voice test';

  @override
  String get sttSettingsRow => 'Voice test (speech-to-text)';

  @override
  String get sttSettingsHint => 'Android only — for testing and tuning';

  @override
  String get sttStatus => 'Status';

  @override
  String get sttFirstWord => 'First word';

  @override
  String get sttSaySomething => 'Tap Listen and say something…';

  @override
  String get sttListen => 'Listen';

  @override
  String get sttStop => 'Stop';

  @override
  String get sttClear => 'Clear results';

  @override
  String get sttCopyDiagnostics => 'Copy diagnostics';

  @override
  String get sttCopied => 'Copied';

  @override
  String get sttResultsLabel => 'Results';

  @override
  String get sttNoResults => 'Nothing heard yet.';

  @override
  String get sttTuning => 'Per listen';

  @override
  String get sttTuningInit => 'Per engine start';

  @override
  String get sttTuningInitHint =>
      'Changing one of these restarts the recognizer.';

  @override
  String get sttLocaleAuto => 'Automatic';

  @override
  String sttIndonesianFound(String id) {
    return 'Indonesian on this device: $id';
  }

  @override
  String get sttNoIndonesian => 'This device offers no Indonesian recognition.';

  @override
  String get sttNoRecognizer =>
      'No speech recognizer available on this device. On some Android builds, turning on androidIntentLookup below helps.';

  @override
  String get sttAndroidOnly => 'Voice input is Android only for now.';

  @override
  String get sttMicDeniedTitle => 'Microphone needed';

  @override
  String get sttMicDeniedBody =>
      'Voice input needs permission to use the microphone.';

  @override
  String get sttOpenSettings => 'Open settings';

  @override
  String get sttPauseForHint =>
      'Silence that ends the session. Counted from the moment listening starts, NOT from the first word — below 2s it can end before you speak.';

  @override
  String get sttOnDeviceHint =>
      'Forces offline recognition; listening fails outright if this device cannot.';

  @override
  String get sttNoBluetoothHint =>
      'Ignore Bluetooth audio routing. Worth testing with the thermal printer paired.';

  @override
  String get sttIntentLookupHint =>
      'Workaround for Android builds that do not declare a recognizer properly.';

  @override
  String get sttDebugLoggingHint =>
      'Writes the plugin\'s own trace to logcat (tag SpeechToText).';

  @override
  String get sttIosOnlyNote =>
      'listenMode, sampleRate, autoPunctuation and haptics are iOS-only in this plugin version, so they are not offered here.';

  @override
  String get sttLog => 'Event log';

  @override
  String get sttListenContinuous => 'Listen (keeps going)';

  @override
  String get sttContinuousHint =>
      'Keep listening until you press stop. Each pause ends one utterance and the next session starts by itself — the recognizer has no continuous mode of its own.';

  @override
  String get sttRestarting => 'Still listening — starting the next stretch…';

  @override
  String get sttModeLabel => 'What to do with what it hears';

  @override
  String get sttModePlain => 'Text only';

  @override
  String get sttModeStock => 'Check against stock';

  @override
  String get sttStockNotFound => 'Not in the catalogue';

  @override
  String sttStockUnavailable(String name) {
    return '$name is switched off';
  }

  @override
  String sttStockOut(String name) {
    return '$name — out of stock (0 left)';
  }

  @override
  String sttStockShort(String name, int left, int asked) {
    return '$name — only $left left, $asked asked for';
  }

  @override
  String sttStockOk(String name, int asked, int left) {
    return '$name ×$asked — $left left';
  }

  @override
  String sttStockOkUntracked(String name, int asked) {
    return '$name ×$asked — stock not tracked';
  }

  @override
  String get voiceOrderTitle => 'Voice order';

  @override
  String get voiceModeCatalogue => 'From catalogue';

  @override
  String get voiceModeOpenPrice => 'Spoken price';

  @override
  String get voiceEmpty => 'Press the microphone, then read the order out.';

  @override
  String get voiceColItem => 'Item';

  @override
  String get voiceColQty => 'Qty';

  @override
  String get voiceColPrice => 'Price';

  @override
  String get voiceColTotal => 'Total';

  @override
  String get voiceAddToCart => 'Add to cart';

  @override
  String get voiceNeedsPrice => 'No price said';

  @override
  String voiceFixLines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Fix $count marked lines first.',
      one: 'Fix 1 marked line first.',
    );
    return '$_temp0';
  }

  @override
  String get sttStockNoCatalog =>
      'This account has no catalogue to check against.';

  @override
  String sttStopPhraseHint(String phrase) {
    return 'Say “$phrase” to stop listening.';
  }
}
