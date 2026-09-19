/// The calculator-only keypad (specs/008-calculator-only), as pure Dart.
///
/// No Flutter imports on purpose: every rule a cashier's thumb can hit lives here, so it is tested
/// directly rather than through taps, and the screen is only layout over it.
library;

/// Ceiling on one keyed amount, in rupiah.
///
/// MUST equal `MAX_OPEN_AMOUNT` in `server/src/common/business-size.ts`. If the two drift, the app
/// accepts a nota the server then refuses — after the customer has handed over the cash.
const int kMaxNotaAmount = 100000000;

/// Keys that append zeros. They are shortcuts for "…ribu" and "…juta", so they only make sense
/// after a real digit: on an empty entry they are no-ops, and the entry never starts with zero.
const Set<String> kZeroKeys = {'0', '00', '000'};

/// One nota in progress: the amounts already committed with ↵, plus the digits being typed.
class NotaCalculatorState {
  /// Committed amounts, in entry order. Each becomes one qty-1 line on the order.
  final List<int> amounts;

  /// Raw digits of the amount being typed; empty when nothing is being typed.
  final String entry;

  const NotaCalculatorState({this.amounts = const [], this.entry = ''});

  int get currentValue => entry.isEmpty ? 0 : int.parse(entry);

  /// Sum of the committed amounts.
  int get subtotal => amounts.fold(0, (s, a) => s + a);

  int get count => amounts.length;

  bool get canCommit => currentValue > 0;

  /// What Selesai charges: the committed amounts PLUS a typed amount the cashier forgot to ↵.
  /// Dropping that last number would under-charge the customer with no visible sign of it.
  List<int> get pendingAmounts => canCommit ? [...amounts, currentValue] : amounts;

  bool get canFinish => pendingAmounts.isNotEmpty;

  bool get isEmpty => amounts.isEmpty && entry.isEmpty;

  /// A digit or a zero shortcut (`00`, `000`).
  ///
  /// A keystroke that would take the entry past [kMaxNotaAmount] is refused WHOLE rather than
  /// truncated: a truncated `000` silently becomes a different number, a refused one is obvious.
  NotaCalculatorState key(String k) {
    if (kZeroKeys.contains(k) && entry.isEmpty) return this;
    final next = entry + k;
    if (int.parse(next) > kMaxNotaAmount) return this;
    return NotaCalculatorState(amounts: amounts, entry: next);
  }

  /// Removes one CHARACTER, not one keypress: `00` then ⌫ leaves one `0`. Pinned in a test so a
  /// later "fix" to per-keypress undo is a decision, not an accident.
  NotaCalculatorState backspace() => entry.isEmpty
      ? this
      : NotaCalculatorState(amounts: amounts, entry: entry.substring(0, entry.length - 1));

  /// Clears the amount being typed ONLY. The committed list survives, because the only way to
  /// throw a whole nota away is Batal behind a confirmation — one stray tap must never wipe it.
  NotaCalculatorState clear() => NotaCalculatorState(amounts: amounts);

  /// ↵ — commits the typed amount as a new line.
  NotaCalculatorState commit() =>
      canCommit ? NotaCalculatorState(amounts: [...amounts, currentValue]) : this;

  NotaCalculatorState reset() => const NotaCalculatorState();

  Map<String, dynamic> toJson() => {'amounts': amounts, 'entry': entry};

  /// Tolerant on purpose: a draft is a convenience, so anything unreadable restores as empty rather
  /// than throwing on the screen a cashier needs to sell from.
  factory NotaCalculatorState.fromJson(Map<String, dynamic> j) {
    final raw = j['amounts'];
    final amounts = raw is List ? raw.whereType<int>().where((a) => a > 0).toList() : <int>[];
    final entry = j['entry'];
    final digits = entry is String && RegExp(r'^[1-9][0-9]*$').hasMatch(entry) ? entry : '';
    return NotaCalculatorState(amounts: amounts, entry: digits);
  }
}

/// An unfinished nota as saved on the device, so closing the app doesn't lose it.
class NotaDraft {
  final NotaCalculatorState state;

  /// Set only while Selesai is sending: the `clientOrderId` of that sale. If the app dies in that
  /// window, this is how reopening tells "already recorded" from "never sent" — see
  /// `AppDatabase.isOrderCaptured`. Without it a restored list could be charged twice.
  final String? pendingClientOrderId;

  const NotaDraft(this.state, {this.pendingClientOrderId});

  Map<String, dynamic> toJson() => {
        ...state.toJson(),
        if (pendingClientOrderId != null) 'pendingClientOrderId': pendingClientOrderId,
      };

  factory NotaDraft.fromJson(Map<String, dynamic> j) => NotaDraft(
        NotaCalculatorState.fromJson(j),
        pendingClientOrderId: j['pendingClientOrderId'] as String?,
      );
}

/// The `POST /orders` body for a finished nota.
///
/// Every amount is a separate qty-1 line against the merchant's provisioned open-amount variant —
/// the server prices each from its `amount` (Constitution III, open-amount lines) and recomputes
/// every total itself. Deliberately NOT built through `CartController`: a nota has no catalog
/// lines, and faking a cart around it would hand the payload fields that mean nothing here.
Map<String, dynamic> buildNotaPayload({
  required String clientOrderId,
  required String outletId,
  required String openAmountVariantId,
  required List<int> amounts,
  required int tendered,
  String? deviceId,
}) =>
    {
      'clientOrderId': clientOrderId,
      'outletId': outletId,
      if (deviceId != null) 'deviceId': deviceId,
      // A counter sale: no table, no dine-in. `type` is stored but never branched on in the
      // money path, so this is descriptive, not behavioural.
      'type': 'RETAIL',
      'lines': [
        for (final a in amounts) {'variantId': openAmountVariantId, 'qty': 1, 'amount': a},
      ],
      'payment': {'method': 'CASH', 'tendered': tendered},
    };

// Indonesian day/month abbreviations for the "Sab, 19 Sep" header.
//
// Hand-rolled rather than `DateFormat('EEE, d MMM', 'id')`: this app never calls
// `initializeDateFormatting`, and every existing DateFormat is deliberately locale-free, so a named
// Indonesian pattern would throw LocaleDataException at runtime. Nineteen constants avoid touching
// app startup for one label.
const List<String> _kHari = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
const List<String> _kBulan = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

/// "Sab, 19 Sep".
String notaDateLabel(DateTime d) => '${_kHari[d.weekday - 1]}, ${d.day} ${_kBulan[d.month - 1]}';

/// "09:05".
String notaTimeLabel(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
