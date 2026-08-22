// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get appTitle => 'DPOS';

  @override
  String get loginTitle => 'Masuk kasir';

  @override
  String get loginSubtitle => 'Masuk untuk mulai berjualan';

  @override
  String get fieldMerchantId => 'ID Merchant';

  @override
  String get fieldOutletId => 'ID Outlet';

  @override
  String get fieldPin => 'PIN';

  @override
  String get advancedSettings => 'Pengaturan lanjutan';

  @override
  String get actionSignIn => 'Masuk';

  @override
  String get errorSignIn => 'Gagal masuk (cek koneksi)';

  @override
  String get posTitle => 'Kasir';

  @override
  String get actionLogout => 'Keluar';

  @override
  String errorCatalog(String error) {
    return 'Gagal memuat katalog: $error';
  }

  @override
  String get emptyItems => 'Belum ada item';

  @override
  String get emptyCatalog => 'Belum ada produk';

  @override
  String get typeTakeaway => 'Bawa pulang';

  @override
  String get typeDineIn => 'Makan di tempat';

  @override
  String get fieldTableNo => 'No. meja';

  @override
  String get actionAddToOrder => 'Tambah ke pesanan';

  @override
  String get labelVariant => 'Varian';

  @override
  String get labelSubtotal => 'Subtotal';

  @override
  String get labelDiscount => 'Diskon';

  @override
  String get labelTax => 'Pajak';

  @override
  String get labelService => 'Layanan';

  @override
  String get labelTotal => 'Total';

  @override
  String payWithTotal(String amount) {
    return 'Bayar · $amount';
  }

  @override
  String orderSummary(int count) {
    return 'Pesanan ($count)';
  }

  @override
  String get paymentTitle => 'Pembayaran';

  @override
  String get methodCash => 'Tunai';

  @override
  String get methodQris => 'QRIS';

  @override
  String get fieldCashReceived => 'Uang diterima';

  @override
  String get labelChange => 'Kembalian';

  @override
  String get actionComplete => 'Selesaikan';

  @override
  String get actionMarkPaid => 'Tandai Lunas';

  @override
  String get qrisHint => 'Pindai untuk membayar (simulasi)';

  @override
  String get errorCashShort => 'Uang tunai kurang dari total';

  @override
  String get msgQueuedOffline =>
      'Tersimpan offline — akan tersinkron saat online';

  @override
  String get receiptTitle => 'Struk';

  @override
  String get actionNewOrder => 'Pesanan baru';

  @override
  String get actionShare => 'Bagikan';

  @override
  String get shareSoon => 'Bagikan struk (segera hadir)';

  @override
  String get tenderExact => 'Uang pas';

  @override
  String get themeToggle => 'Ganti tema';

  @override
  String get langToggle => 'Bahasa / English';

  @override
  String get loginFooter => 'Lupa PIN? Hubungi admin outlet.';

  @override
  String get cartHeader => 'Pesanan';

  @override
  String get viewOrder => 'Lihat pesanan';

  @override
  String itemsLabel(int count) {
    return '$count item';
  }

  @override
  String get historyLabel => 'Riwayat';

  @override
  String get totalDue => 'Total tagihan';

  @override
  String get themeLight => 'Terang';

  @override
  String get themeDark => 'Gelap';

  @override
  String tableLabelShort(String n) {
    return 'Meja $n';
  }
}
