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

  @override
  String get historyTitle => 'Transaksi';

  @override
  String get historyNetSales => 'PENJUALAN BERSIH';

  @override
  String historyCount(int count) {
    return '$count transaksi';
  }

  @override
  String historyVoidedCount(int count) {
    return '$count dibatalkan';
  }

  @override
  String get emptyHistory => 'Belum ada transaksi';

  @override
  String get errorHistory => 'Gagal memuat transaksi';

  @override
  String get actionRetry => 'Coba lagi';

  @override
  String get transactionTitle => 'Transaksi';

  @override
  String get statusCompleted => 'Lunas';

  @override
  String get statusVoided => 'Dibatalkan';

  @override
  String get statusRefunded => 'Dikembalikan';

  @override
  String get paymentReversal => 'Pembalikan';

  @override
  String get voidedHeader => 'Transaksi dibatalkan';

  @override
  String get voidReasonLabel => 'Alasan';

  @override
  String get voidImmutableNote =>
      'Transaksi tetap tersimpan sebagai catatan — pembatalan dicatat terpisah dan stok telah dikembalikan.';

  @override
  String get actionVoidSale => 'Batalkan transaksi';

  @override
  String get voidOwnerOnly => 'Hanya pemilik yang dapat membatalkan transaksi.';

  @override
  String get voidConfirmTitle => 'Batalkan transaksi ini?';

  @override
  String get voidConfirmBody =>
      'Transaksi tetap tercatat sebagai dibatalkan, stok dikembalikan, dan tindakan ini dicatat.';

  @override
  String get actionCancel => 'Batal';

  @override
  String get actionVoidConfirm => 'Batalkan';

  @override
  String get voidSuccess => 'Transaksi dibatalkan, stok dikembalikan';

  @override
  String get voidFailed => 'Pembatalan gagal — coba lagi';

  @override
  String get voidForbidden => 'Anda tidak berhak membatalkan transaksi';

  @override
  String get soldOut => 'Habis';

  @override
  String get eachSuffix => '/pcs';

  @override
  String get removeItem => 'Hapus item';

  @override
  String get labelQty => 'Jumlah';

  @override
  String addQtyToOrder(int qty, String amount) {
    return 'Tambah $qty · $amount';
  }

  @override
  String get saveOrder => 'Proses Pesanan';

  @override
  String get orderSaved => 'Pesanan diproses';

  @override
  String get openBillsTitle => 'Pesanan';

  @override
  String get emptyOpenBills => 'Belum ada pesanan terbuka';

  @override
  String get searchTable => 'Cari meja';

  @override
  String get tableRequired => 'Isi nomor meja dulu';

  @override
  String get tableExists => 'Meja itu sudah punya pesanan terbuka';

  @override
  String get actionOk => 'Oke';

  @override
  String get dialogTitleInfo => 'Informasi';

  @override
  String get dialogTitleSuccess => 'Berhasil';

  @override
  String get dialogTitleWarning => 'Perhatian';

  @override
  String get dialogTitleError => 'Tidak bisa';

  @override
  String get settingsTitle => 'Pengaturan';

  @override
  String get aboutSection => 'Tentang';

  @override
  String get appVersionLabel => 'Versi aplikasi';

  @override
  String get serverVersionLabel => 'Versi server';

  @override
  String get preferencesSection => 'Preferensi';

  @override
  String get languageLabel => 'Bahasa';

  @override
  String get themeLabel => 'Tema';
}
