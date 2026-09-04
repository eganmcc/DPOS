const rupiah = new Intl.NumberFormat('id-ID', {
  style: 'currency',
  currency: 'IDR',
  maximumFractionDigits: 0,
});

/** Integer rupiah → "Rp 41.400". */
export function formatRupiah(amount: number): string {
  return rupiah.format(amount).replace('Rp', 'Rp ').replace('  ', ' ');
}

export function formatNumber(n: number): string {
  return new Intl.NumberFormat('id-ID').format(n);
}
