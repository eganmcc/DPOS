// Grocery catalog for the "Toko Sembako Demo" merchant. Shares the image
// pipeline with the F&B menu: source photos (loremflickr, pinned via ?lock) are
// uploaded to S3 by scripts/provision-grocery-images.ts, and the app loads them
// from `menuImageUrl(name)` (the public `menu/` prefix; slugs don't collide with
// the F&B menu). The first 6 names match what prisma/seed-portal.ts created, so
// re-seeding just adds their image + the 20 new products.
import { menuImageUrl, slugify } from './menu-data';

export { menuImageUrl, slugify };

const lf = (keyword: string, lock: number): string =>
  `https://loremflickr.com/512/512/${keyword}?lock=${lock}`;

export interface GroceryItem {
  category: string;
  name: string;
  variant: string;
  price: number; // integer rupiah
  cost: number;
  sku: string;
  sourceImageUrl: string;
}

export const GROCERY: GroceryItem[] = [
  // --- 6 existing (from seed-portal.ts) — names must match ---
  { category: 'Sembako', name: 'Beras Premium 5kg', variant: 'Karung', price: 65000, cost: 58000, sku: 'BRS5', sourceImageUrl: lf('rice', 1) },
  { category: 'Sembako', name: 'Minyak Goreng 2L', variant: 'Pouch', price: 38000, cost: 34000, sku: 'MYK2', sourceImageUrl: lf('oil', 2) },
  { category: 'Sembako', name: 'Gula Pasir 1kg', variant: 'Pak', price: 15000, cost: 13000, sku: 'GLA1', sourceImageUrl: lf('sugar', 3) },
  { category: 'Sembako', name: 'Telur Ayam 1kg', variant: 'Kg', price: 28000, cost: 25000, sku: 'TLR1', sourceImageUrl: lf('eggs', 4) },
  { category: 'Minuman', name: 'Air Mineral 600ml', variant: 'Botol', price: 4000, cost: 2500, sku: 'AIR6', sourceImageUrl: lf('water', 5) },
  { category: 'Snack', name: 'Indomie Goreng', variant: 'Pcs', price: 3500, cost: 3000, sku: 'IDM1', sourceImageUrl: lf('noodles', 6) },

  // --- 20 new ---
  { category: 'Sembako', name: 'Tepung Terigu 1kg', variant: 'Pak', price: 12000, cost: 10000, sku: 'TPG1', sourceImageUrl: lf('flour', 7) },
  { category: 'Sembako', name: 'Beras Merah 2kg', variant: 'Karung', price: 32000, cost: 28000, sku: 'BRM2', sourceImageUrl: lf('brownrice', 8) },
  { category: 'Sembako', name: 'Kacang Hijau 500g', variant: 'Pak', price: 14000, cost: 12000, sku: 'KCH5', sourceImageUrl: lf('beans', 9) },
  { category: 'Sembako', name: 'Kecap Manis 600ml', variant: 'Botol', price: 22000, cost: 19000, sku: 'KCP6', sourceImageUrl: lf('soysauce', 10) },
  { category: 'Sembako', name: 'Susu Kental Manis', variant: 'Kaleng', price: 11000, cost: 9500, sku: 'SKM1', sourceImageUrl: lf('milk', 11) },
  { category: 'Snack', name: 'Mie Instan Ayam', variant: 'Pcs', price: 3000, cost: 2500, sku: 'MIA1', sourceImageUrl: lf('ramen', 12) },
  { category: 'Bumbu', name: 'Garam Halus 500g', variant: 'Pak', price: 5000, cost: 3500, sku: 'GRM5', sourceImageUrl: lf('salt', 13) },
  { category: 'Bumbu', name: 'Merica Bubuk 100g', variant: 'Sachet', price: 9000, cost: 7000, sku: 'MRC1', sourceImageUrl: lf('pepper', 14) },
  { category: 'Bumbu', name: 'Bawang Merah 1kg', variant: 'Kg', price: 35000, cost: 30000, sku: 'BWM1', sourceImageUrl: lf('onion', 15) },
  { category: 'Bumbu', name: 'Bawang Putih 1kg', variant: 'Kg', price: 32000, cost: 28000, sku: 'BWP1', sourceImageUrl: lf('garlic', 16) },
  { category: 'Bumbu', name: 'Cabai Merah 1kg', variant: 'Kg', price: 45000, cost: 38000, sku: 'CBM1', sourceImageUrl: lf('chili', 17) },
  { category: 'Minuman', name: 'Teh Kotak 300ml', variant: 'Kotak', price: 5000, cost: 3500, sku: 'TEH3', sourceImageUrl: lf('tea', 18) },
  { category: 'Minuman', name: 'Kopi Sachet', variant: 'Renceng', price: 12000, cost: 10000, sku: 'KOP1', sourceImageUrl: lf('coffee', 19) },
  { category: 'Minuman', name: 'Sirup Buah 460ml', variant: 'Botol', price: 25000, cost: 21000, sku: 'SRP4', sourceImageUrl: lf('syrup', 20) },
  { category: 'Snack', name: 'Biskuit Marie 300g', variant: 'Pak', price: 13000, cost: 11000, sku: 'BSK3', sourceImageUrl: lf('biscuit', 21) },
  { category: 'Snack', name: 'Keripik Kentang', variant: 'Pak', price: 15000, cost: 12000, sku: 'KRP1', sourceImageUrl: lf('chips', 22) },
  { category: 'Snack', name: 'Wafer Coklat', variant: 'Pak', price: 9000, cost: 7000, sku: 'WFR1', sourceImageUrl: lf('wafer', 23) },
  { category: 'Perawatan', name: 'Sabun Mandi', variant: 'Batang', price: 4500, cost: 3200, sku: 'SBN1', sourceImageUrl: lf('soap', 24) },
  { category: 'Perawatan', name: 'Pasta Gigi 190g', variant: 'Tube', price: 16000, cost: 13000, sku: 'PSG1', sourceImageUrl: lf('toothpaste', 25) },
  { category: 'Rumah Tangga', name: 'Sabun Cuci Piring', variant: 'Botol', price: 14000, cost: 11000, sku: 'SCP1', sourceImageUrl: lf('dishsoap', 26) },
];
