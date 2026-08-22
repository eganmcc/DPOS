import 'package:intl/intl.dart';

/// Money is integer rupiah everywhere (matches the backend). Format only at the edge.
final _rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

String formatRupiah(int amount) => _rupiah.format(amount);
