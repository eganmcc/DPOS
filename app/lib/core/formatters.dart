import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Uppercases text as it is typed. Table labels are the open-bill key, so "a1"
/// and "A1" must be the same bill.
class UpperCaseTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue _, TextEditingValue next) =>
      next.copyWith(text: next.text.toUpperCase());
}

/// Groups an integer field with id_ID thousands separators as it is typed:
/// "1352400" -> "1.352.400". Non-digits are stripped; the caret stays at the end
/// (fine for a numeric tender pad).
class ThousandsTextInputFormatter extends TextInputFormatter {
  static final NumberFormat _fmt = NumberFormat.decimalPattern('id'); // '.' grouping

  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue next) {
    final digits = next.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue(text: '');
    final grouped = _fmt.format(int.parse(digits));
    return TextEditingValue(
      text: grouped,
      selection: TextSelection.collapsed(offset: grouped.length),
    );
  }
}
