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
  String get errorConnection => 'Tidak bisa terhubung ke server — cek koneksi.';

  @override
  String errorStockShort(String name) {
    return 'Stok $name tidak cukup — pesanan tidak disimpan.';
  }

  @override
  String errorSaveFailed(int code) {
    return 'Gagal menyimpan pesanan (kode $code).';
  }

  @override
  String get sessionExpired => 'Sesi Anda berakhir. Silakan masuk lagi.';

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
  String get actionMarkPaid => 'Tandai sudah dibayar';

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
  String get voidOwnerOnly =>
      'Hanya pemilik atau manajer yang dapat membatalkan transaksi.';

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
  String get voidWindowExpired =>
      'Pembatalan hanya boleh di hari yang sama — lakukan refund.';

  @override
  String get voidHint => 'Membatalkan seluruh transaksi — hanya hari ini';

  @override
  String get refundHint => 'Kembalikan sebagian atau semua — kapan saja';

  @override
  String get voidReasonWrongItem => 'Salah item';

  @override
  String get voidReasonWrongPrice => 'Salah harga';

  @override
  String get voidReasonCustomerCancel => 'Pelanggan batal';

  @override
  String get voidReasonTest => 'Transaksi tes';

  @override
  String get actionRefund => 'Refund';

  @override
  String get refundTitle => 'Refund transaksi';

  @override
  String get refundFull => 'Penuh';

  @override
  String get refundPartial => 'Per item';

  @override
  String get refundReasonLabel => 'Alasan refund';

  @override
  String get refundEstimate => 'Perkiraan refund';

  @override
  String get refundSuccess => 'Refund diproses';

  @override
  String get refundFailed => 'Refund gagal — coba lagi';

  @override
  String get refundedSoFar => 'Sudah direfund';

  @override
  String get refundNothingLeft => 'Tidak ada yang bisa direfund lagi.';

  @override
  String get refundReasonDamaged => 'Rusak / cacat';

  @override
  String get refundReasonReturn => 'Barang dikembalikan';

  @override
  String get refundReasonQuality => 'Masalah kualitas';

  @override
  String get managerApprovalTitle => 'Persetujuan manajer';

  @override
  String get managerPinLabel => 'PIN manajer / pemilik';

  @override
  String get approvalInvalid => 'PIN manajer salah';

  @override
  String get approvalRequired => 'Perlu persetujuan manajer';

  @override
  String get actionCancelBill => 'Batalkan pesanan';

  @override
  String get cancelBillTitle => 'Batalkan pesanan ini?';

  @override
  String get cancelBillBody =>
      'Stok yang direservasi dikembalikan dan pesanan ditutup. Tidak ada pembayaran.';

  @override
  String get cancelSuccess => 'Pesanan dibatalkan, stok dikembalikan';

  @override
  String get cancelFailed => 'Pembatalan gagal — coba lagi';

  @override
  String get clockInPromptTitle => 'Absen masuk sekarang?';

  @override
  String get actionLater => 'Nanti';

  @override
  String get clockOutPromptTitle => 'Absen keluar?';

  @override
  String get clockOutPromptBody =>
      'Anda masih dalam sesi kerja. Absen keluar sebelum keluar?';

  @override
  String get actionLogoutOnly => 'Keluar saja';

  @override
  String get actionClockOutAndLogout => 'Absen keluar & keluar';

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
  String get updateOrder => 'Update Pesanan';

  @override
  String get orderSaved => 'Pesanan diproses';

  @override
  String get openBillsTitle => 'Pesanan';

  @override
  String get emptyOpenBills => 'Belum ada pesanan terbuka';

  @override
  String get onlineOrdersTitle => 'Pesanan Online';

  @override
  String get onlineOrderNew => 'Baru';

  @override
  String get onlineOrderAccept => 'Terima';

  @override
  String get onlineDemoLabel => 'Pesanan online (demo)';

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

  @override
  String get scannerTitle => 'Pindai';

  @override
  String get scannerHint => 'Arahkan kamera ke barcode';

  @override
  String get scannerSkuLabel => 'SKU';

  @override
  String get scannerAdd => 'Tambah';

  @override
  String get scannerBrowse => 'Lihat produk';

  @override
  String scannerAdded(String name) {
    return 'Ditambahkan: $name';
  }

  @override
  String scannerSkuNotFound(String sku) {
    return 'SKU tidak ditemukan: $sku';
  }

  @override
  String get scannerOutOfStock => 'Stok habis';

  @override
  String get scannerModeLabel => 'Mode pindai';

  @override
  String get scannerModeAuto => 'Otomatis';

  @override
  String get scannerModeOn => 'Aktif';

  @override
  String get scannerModeOff => 'Nonaktif';

  @override
  String get printFailed => 'Printer tidak terhubung';

  @override
  String get actionPrint => 'Cetak';

  @override
  String get printerSection => 'Printer';

  @override
  String get printerPaired => 'Terpasang';

  @override
  String get printerNone => 'Tidak ditemukan';

  @override
  String get printerTest => 'Tes cetak';

  @override
  String get printerOk => 'Tercetak';

  @override
  String get reportsTitle => 'Laporan';

  @override
  String get reportsOrders => 'Transaksi';

  @override
  String get reportsAvgTicket => 'Rata-rata';

  @override
  String get reportsPayments => 'METODE PEMBAYARAN';

  @override
  String get itemsTitle => 'Barang & harga';

  @override
  String itemsCount(int used, int max) {
    return '$used / $max';
  }

  @override
  String get itemsAdd => 'Tambah barang';

  @override
  String get itemsEmpty => 'Belum ada barang — tambahkan yang pertama.';

  @override
  String get itemsLimitReached =>
      'Batas barang tercapai. Hubungi DPOS untuk mengubah paket.';

  @override
  String get itemName => 'Nama barang';

  @override
  String get itemCategory => 'Kategori';

  @override
  String get itemPrice => 'Harga jual';

  @override
  String get itemCost => 'Harga modal';

  @override
  String get itemCostHint => 'Diperlukan untuk laporan laba';

  @override
  String get itemSku => 'SKU / barcode';

  @override
  String get itemAvailable => 'Tersedia untuk dijual';

  @override
  String get itemTrackStock => 'Lacak stok';

  @override
  String get itemOnHand => 'Stok saat ini';

  @override
  String get itemNoCost => 'Belum ada harga modal';

  @override
  String itemMargin(String amount) {
    return 'Margin $amount';
  }

  @override
  String get itemSaved => 'Tersimpan';

  @override
  String get itemSaveFailed => 'Gagal menyimpan — coba lagi';

  @override
  String get itemNameRequired => 'Nama dan kategori wajib diisi';

  @override
  String get reportsProfit => 'LABA KOTOR';

  @override
  String get plRevenue => 'Pendapatan';

  @override
  String get plCogs => 'Modal barang';

  @override
  String get plGrossProfit => 'Laba kotor';

  @override
  String get plMargin => 'Margin';

  @override
  String plMissingCost(int n) {
    return '$n baris penjualan belum ada harga modal — laba terlihat lebih besar';
  }

  @override
  String get plSetCostPrices => 'Atur harga modal';

  @override
  String get reportsTopItems => 'PRODUK TERLARIS';

  @override
  String get reportsByOutlet => 'PER OUTLET';

  @override
  String get reportsByDay => 'PENJUALAN HARIAN';

  @override
  String reportsQtySold(int qty) {
    return '$qty terjual';
  }

  @override
  String get reportsOpenCashier => 'Buka kasir';

  @override
  String get reportsAttendance => 'ABSENSI';

  @override
  String get reportsNoAttendance => 'Belum ada absensi di periode ini';

  @override
  String get attendanceOnClock => 'Sedang bekerja';

  @override
  String get periodDaily => 'Harian';

  @override
  String get periodWeekly => 'Mingguan';

  @override
  String get periodMonthly => 'Bulanan';

  @override
  String get attendanceSection => 'Absensi';

  @override
  String get attendanceClockIn => 'Absen masuk';

  @override
  String get attendanceClockOut => 'Absen keluar';

  @override
  String get attendanceClockedOut => 'Belum absen masuk';

  @override
  String attendanceSince(String time) {
    return 'Bekerja sejak $time';
  }

  @override
  String get methodDebit => 'Kartu debit';

  @override
  String get methodCredit => 'Kartu kredit';

  @override
  String get methodBcaCard => 'Kartu BCA';

  @override
  String get methodShopeePay => 'ShopeePay';

  @override
  String get methodGoPay => 'GoPay';

  @override
  String get methodOvo => 'OVO';

  @override
  String get tenderGroupCard => 'Kartu';

  @override
  String get tenderGroupEwallet => 'Dompet digital';

  @override
  String get tenderGroupOther => 'Tunai & QRIS';

  @override
  String get actionProcessCard => 'Proses di EDC';

  @override
  String get actionWalletConfirm => 'Pembayaran diterima';

  @override
  String walletScanHint(String wallet) {
    return 'Minta pelanggan memindai dengan $wallet';
  }

  @override
  String cardApprovedShort(String code) {
    return 'Disetujui · $code';
  }

  @override
  String get tenderNotAvailable =>
      'Metode pembayaran ini tidak tersedia untuk paket Anda.';

  @override
  String get edcTitle => 'Mesin EDC';

  @override
  String get edcInsertCard => 'MASUKKAN, TEMPEL ATAU GESEK KARTU';

  @override
  String get edcReadingCard => 'MEMBACA KARTU…';

  @override
  String get edcAuthorizing => 'MEMPROSES…';

  @override
  String get edcApproved => 'DISETUJUI';

  @override
  String get edcDeclined => 'DITOLAK';

  @override
  String get edcDeclinedHint =>
      'Kartu ditolak. Coba lagi atau gunakan metode pembayaran lain.';

  @override
  String get edcEntryMode => 'Cara baca';

  @override
  String get edcChip => 'Chip';

  @override
  String get edcContactless => 'Tempel';

  @override
  String get edcSwipe => 'Gesek';

  @override
  String get edcScheme => 'Jaringan kartu';

  @override
  String get edcCard => 'Kartu';

  @override
  String get edcApprovalCode => 'Kode persetujuan';

  @override
  String get edcRrn => 'RRN';

  @override
  String get edcTrace => 'Trace / batch';

  @override
  String get edcTerminal => 'Terminal';

  @override
  String get edcProcess => 'Proses kartu';

  @override
  String get edcSimulateDecline => 'Simulasikan kartu ditolak';

  @override
  String get edcContinue => 'Lanjut';

  @override
  String get edcRetry => 'Coba lagi';

  @override
  String get otherMethods => 'Metode lain';

  @override
  String get chooseCard => 'Pilih kartu';

  @override
  String get chooseWallet => 'Pilih e-wallet';

  @override
  String get actionProcessPayment => 'Proses pembayaran';

  @override
  String get qrisAnyAppHint => 'Pindai dengan aplikasi pembayaran apa pun';

  @override
  String get edcPromptCard => 'Gesek, tap, atau masukkan kartu pada mesin EDC';

  @override
  String walletScanApp(String wallet) {
    return 'Scan dengan aplikasi $wallet';
  }

  @override
  String get amountReceivedLabel => 'Jumlah diterima';

  @override
  String get tabEwallet => 'E-Wallet';

  @override
  String get notaTitle => 'Baca nota';

  @override
  String get notaIntro =>
      'Foto nota tulisan tangan dan DPOS akan membacanya. Tidak ada yang disimpan.';

  @override
  String get notaTakePhoto => 'Ambil foto';

  @override
  String get notaChooseGallery => 'Pilih dari galeri';

  @override
  String get notaRetake => 'Foto ulang';

  @override
  String get notaReading => 'Membaca nota…';

  @override
  String get notaReadingHint => 'Bisa memakan waktu hingga setengah menit.';

  @override
  String get notaResultTitle => 'Hasil bacaan DPOS';

  @override
  String get notaNumber => 'No. nota';

  @override
  String get notaDate => 'Tanggal';

  @override
  String get notaCustomer => 'Nama';

  @override
  String get notaItems => 'Item';

  @override
  String get notaColItem => 'Keterangan';

  @override
  String get notaColQty => 'Qty';

  @override
  String get notaColPrice => 'Harga';

  @override
  String get notaColTotal => 'Jumlah';

  @override
  String get notaTotalWritten => 'Total di nota';

  @override
  String get notaLinesSum => 'Jumlah per baris';

  @override
  String get notaTotalMismatch =>
      'Jumlah per baris tidak sama dengan total yang tertulis — periksa fotonya.';

  @override
  String get notaDifference => 'Selisih';

  @override
  String notaDiffLinesMore(String amount) {
    return 'Baris-barisnya $amount lebih banyak dari total yang tertulis.';
  }

  @override
  String notaDiffLinesLess(String amount) {
    return 'Baris-barisnya $amount lebih sedikit dari total yang tertulis.';
  }

  @override
  String get notaTable => 'Meja';

  @override
  String get notaFixLine => 'Perbaiki baris';

  @override
  String get notaFixHint => 'Ketuk baris untuk memperbaikinya.';

  @override
  String get notaEdited => 'diubah';

  @override
  String notaLineTotalIs(String amount) {
    return 'Jumlah: $amount';
  }

  @override
  String get actionSave => 'Simpan';

  @override
  String get notaUnreadable => 'Tidak terbaca';

  @override
  String get notaNoItems => 'Tidak ada baris item yang terbaca.';

  @override
  String get notaUnclearTitle => 'Kurang jelas terbaca';

  @override
  String notaConfidence(int pct) {
    return 'Keyakinan $pct%';
  }

  @override
  String notaReadBy(String model, String secs) {
    return 'Dibaca oleh $model dalam $secs dtk';
  }

  @override
  String get notaRawData => 'Data mentah';

  @override
  String get notaErrorUnsupported =>
      'File bukan foto yang didukung. Gunakan JPEG atau PNG.';

  @override
  String get notaErrorTooLarge =>
      'Foto terlalu besar. Coba lagi dengan kamera.';

  @override
  String get notaErrorUnreadable =>
      'Nota tidak dapat dibaca. Coba foto yang lebih jelas dan dekat.';

  @override
  String notaErrorGeneric(String code) {
    return 'Gagal membaca ($code). Periksa koneksi lalu coba lagi.';
  }

  @override
  String get notaReadAnother => 'Baca nota lain';

  @override
  String get notaMakeOrder => 'Jadikan pesanan';

  @override
  String get notaOrderTitle => 'Pesanan dari nota';

  @override
  String notaOrderFrom(String number) {
    return 'Dibaca dari nota #$number';
  }

  @override
  String get notaOrderEmpty => 'Tidak ada baris untuk dipesan.';

  @override
  String get notaQtyUnreadable => 'Jumlah di nota bukan bilangan bulat';

  @override
  String notaPriceOnPaper(String price) {
    return 'Di nota $price — yang dikenakan harga toko';
  }

  @override
  String get notaCameraDenied => 'Akses kamera diperlukan untuk memotret nota.';

  @override
  String get notaPanHint => 'Geser · ketuk 2x atau cubit untuk zoom';

  @override
  String get notaFitImage => 'Sesuaikan lebar';

  @override
  String get notaFullscreen => 'Layar penuh';

  @override
  String get notaStubBanner =>
      'Mode contoh: pembaca AI belum diaktifkan di server, jadi ini hasil contoh tetap — foto Anda TIDAK dibaca. Semua foto akan menampilkan hasil yang sama sampai fitur ini diaktifkan.';

  @override
  String get calcTitle => 'Input nota';

  @override
  String calcNotaNumber(int n) {
    return 'Nota #$n';
  }

  @override
  String get calcCurrentValue => 'Nilai saat ini';

  @override
  String get calcItemCountLabel => 'Jumlah item';

  @override
  String calcItemCount(int n) {
    return '$n item';
  }

  @override
  String calcItemLine(int n) {
    return 'Item $n';
  }

  @override
  String get calcEmptyList => 'Ketik nilai, lalu tekan ↵';

  @override
  String get calcTotal => 'TOTAL';

  @override
  String get calcAmountReceived => 'Uang diterima';

  @override
  String get calcShort => 'Kurang';

  @override
  String get calcCancelTitle => 'Batalkan nota ini?';

  @override
  String get calcCancelBody =>
      'Semua item akan dihapus. Nomor nota tidak berubah.';

  @override
  String get calcCancelConfirm => 'Ya, batalkan';

  @override
  String get calcCancelKeep => 'Tidak';

  @override
  String get calcBack => 'Kembali';

  @override
  String get calcFinish => 'Selesai';

  @override
  String calcPaid(String amount) {
    return 'Lunas · kembalian $amount';
  }

  @override
  String calcTaxLine(String label, String pct) {
    return '$label $pct%';
  }

  @override
  String calcSaveFailed(String code) {
    return 'Penjualan ini belum tersimpan ($code). Belum ada yang tercatat — periksa koneksi lalu tekan Selesai lagi.';
  }

  @override
  String loginVersionApp(String version, String build) {
    return 'Aplikasi v$version ($build)';
  }

  @override
  String loginVersionServer(String version) {
    return 'Server v$version';
  }

  @override
  String get calcPreviousSaved =>
      'Nota sebelumnya sudah tersimpan — cek Riwayat.';

  @override
  String get chatTitle => 'Nota';

  @override
  String get chatWelcome =>
      'Kirim foto nota. Saya bacakan isinya, lalu Anda periksa sebelum transaksi dibuat.';

  @override
  String get chatCamera => 'Kamera';

  @override
  String get chatGallery => 'Galeri';

  @override
  String get chatReading => 'Membaca nota…';

  @override
  String chatReadFailed(String code) {
    return 'Nota tidak bisa dibaca ($code). Coba foto lain.';
  }

  @override
  String chatNotaHeader(String number) {
    return 'Nota #$number';
  }

  @override
  String get chatNoNumber => 'Nomor nota tidak terbaca';

  @override
  String get chatNotCharged => 'tidak dihitung';

  @override
  String get chatWrittenTotal => 'Total di nota';

  @override
  String get chatLinesTotal => 'Akan ditagih';

  @override
  String chatTotalsDisagree(String amount) {
    return 'Total yang ditulis di nota berbeda dengan barisnya. Transaksi memakai jumlah baris: $amount.';
  }

  @override
  String get chatTotalOnly =>
      'Tidak ada baris yang berharga sendiri, jadi transaksi memakai total di nota.';

  @override
  String get chatNothingToCharge =>
      'Tidak ada harga yang terbaca, jadi belum ada yang bisa ditagih. Coba foto yang lebih jelas.';

  @override
  String chatUnclear(String items) {
    return 'Kurang jelas: $items';
  }

  @override
  String get chatAskFix => 'Apakah ada yang perlu diperbaiki?';

  @override
  String get chatFixYes => 'Ya, perbaiki';

  @override
  String get chatFixNo => 'Tidak, buat transaksi';

  @override
  String get chatFixNotYet =>
      'Perbaikan belum tersedia. Nota ini BELUM dicatat — foto ulang bila ada yang salah baca.';

  @override
  String get chatCreating => 'Membuat transaksi…';

  @override
  String get chatCreated => 'Transaksi dibuat — menunggu pembayaran.';

  @override
  String get chatPayNow => 'Bayar sekarang';

  @override
  String chatAlreadyRecorded(String number) {
    return 'Nota #$number sudah tercatat, jadi tidak dibuat dua kali.';
  }

  @override
  String get chatViewTransaction => 'Lihat transaksi';

  @override
  String chatCreateFailed(String code) {
    return 'Transaksi belum dibuat ($code). Belum ada yang tercatat — coba lagi.';
  }

  @override
  String get bizTypeFnb => 'F&B';

  @override
  String get bizTypeGrocery => 'Grosir';

  @override
  String get bizTypeHhi => 'High Human Interactions';

  @override
  String get chatNoteRecorded => 'Dicatat sebagai catatan transaksi:';

  @override
  String get detailCustomer => 'Pelanggan';

  @override
  String get detailNote => 'Catatan';

  @override
  String get sttLabTitle => 'Uji coba suara';

  @override
  String get sttSettingsRow => 'Uji coba suara (ucapan ke teks)';

  @override
  String get sttSettingsHint =>
      'Hanya Android — untuk pengujian dan penyetelan';

  @override
  String get sttStatus => 'Status';

  @override
  String get sttFirstWord => 'Kata pertama';

  @override
  String get sttSaySomething => 'Tekan Dengarkan lalu bicara…';

  @override
  String get sttListen => 'Dengarkan';

  @override
  String get sttStop => 'Berhenti';

  @override
  String get sttClear => 'Hapus hasil';

  @override
  String get sttCopyDiagnostics => 'Salin diagnostik';

  @override
  String get sttCopied => 'Disalin';

  @override
  String get sttResultsLabel => 'Hasil';

  @override
  String get sttNoResults => 'Belum ada yang terdengar.';

  @override
  String get sttTuning => 'Setiap sesi dengar';

  @override
  String get sttTuningInit => 'Saat mesin dimulai';

  @override
  String get sttTuningInitHint =>
      'Mengubah salah satu ini akan memulai ulang pengenal suara.';

  @override
  String get sttLocaleAuto => 'Otomatis';

  @override
  String sttIndonesianFound(String id) {
    return 'Bahasa Indonesia di perangkat ini: $id';
  }

  @override
  String get sttNoIndonesian =>
      'Perangkat ini tidak menyediakan pengenalan Bahasa Indonesia.';

  @override
  String get sttNoRecognizer =>
      'Tidak ada pengenal suara di perangkat ini. Pada sebagian Android, menyalakan androidIntentLookup di bawah bisa membantu.';

  @override
  String get sttAndroidOnly => 'Input suara baru tersedia di Android.';

  @override
  String get sttMicDeniedTitle => 'Perlu izin mikrofon';

  @override
  String get sttMicDeniedBody => 'Input suara memerlukan izin mikrofon.';

  @override
  String get sttOpenSettings => 'Buka pengaturan';

  @override
  String get sttPauseForHint =>
      'Jeda diam yang mengakhiri sesi. Dihitung sejak mulai mendengar, BUKAN sejak kata pertama — di bawah 2 dtk bisa berhenti sebelum Anda bicara.';

  @override
  String get sttOnDeviceHint =>
      'Memaksa pengenalan offline; sesi gagal bila perangkat tidak mampu.';

  @override
  String get sttNoBluetoothHint =>
      'Abaikan jalur audio Bluetooth. Layak diuji saat printer termal terhubung.';

  @override
  String get sttIntentLookupHint =>
      'Solusi untuk Android yang tidak mendeklarasikan pengenal suara dengan benar.';

  @override
  String get sttDebugLoggingHint =>
      'Menulis jejak plugin ke logcat (tag SpeechToText).';

  @override
  String get sttIosOnlyNote =>
      'listenMode, sampleRate, autoPunctuation dan haptic hanya berlaku di iOS pada versi plugin ini, jadi tidak ditampilkan.';

  @override
  String get sttLog => 'Catatan kejadian';

  @override
  String get sttListenContinuous => 'Dengarkan (terus)';

  @override
  String get sttContinuousHint =>
      'Terus mendengarkan sampai Anda menekan berhenti. Tiap jeda mengakhiri satu ucapan dan sesi berikutnya dimulai sendiri — pengenal suara tidak punya mode terus-menerus.';

  @override
  String get sttRestarting =>
      'Masih mendengarkan — menyiapkan sesi berikutnya…';

  @override
  String get sttModeLabel => 'Apa yang dilakukan dengan hasilnya';

  @override
  String get sttModePlain => 'Teks saja';

  @override
  String get sttModeStock => 'Cek ke stok';

  @override
  String get sttStockNotFound => 'Tidak ada di katalog';

  @override
  String sttStockUnavailable(String name) {
    return '$name sedang dinonaktifkan';
  }

  @override
  String sttStockOut(String name) {
    return '$name — stok habis (sisa 0)';
  }

  @override
  String sttStockShort(String name, int left, int asked) {
    return '$name — sisa $left, diminta $asked';
  }

  @override
  String sttStockOk(String name, int asked, int left) {
    return '$name ×$asked — sisa $left';
  }

  @override
  String sttStockOkUntracked(String name, int asked) {
    return '$name ×$asked — stok tidak dilacak';
  }

  @override
  String get voiceOrderTitle => 'Pesan dengan suara';

  @override
  String get voiceModeCatalogue => 'Dari katalog';

  @override
  String get voiceModeOpenPrice => 'Harga diucapkan';

  @override
  String get voiceEmpty => 'Tekan mikrofon, lalu sebutkan pesanannya.';

  @override
  String get voiceColItem => 'Item';

  @override
  String get voiceColQty => 'Jml';

  @override
  String get voiceColPrice => 'Harga';

  @override
  String get voiceColTotal => 'Jumlah';

  @override
  String get voiceAddToCart => 'Tambah ke keranjang';

  @override
  String get voiceNeedsPrice => 'Harga belum disebut';

  @override
  String get voiceRepeatIgnored =>
      'Terdengar lagi dalam hitungan detik — dianggap ulangan, tidak ditambahkan.';

  @override
  String voiceFixLines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Perbaiki $count baris bertanda dulu.',
      one: 'Perbaiki 1 baris bertanda dulu.',
    );
    return '$_temp0';
  }

  @override
  String get sttStockNoCatalog => 'Akun ini tidak punya katalog untuk dicek.';

  @override
  String sttStopPhraseHint(String phrase) {
    return 'Ucapkan “$phrase” untuk berhenti mendengarkan.';
  }
}
