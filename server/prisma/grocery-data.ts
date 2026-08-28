// Grocery catalog for the "Toko Sembako Demo" merchant. Real product photos are
// sourced at provisioning time (scripts/provision-grocery-images.ts):
//   1) Open Food Facts (search-a-licious) for branded packaged goods — actual
//      product packaging;
//   2) Wikimedia Commons image search as a fallback for generic produce /
//      household items.
// Images upload to the public S3 `menu/` prefix under `<slug>_v2.jpg`; the app
// loads them via groceryImageUrl(name). The first 6 names match seed-portal.ts.
import { MENU_IMAGE_BASE_URL, slugify } from './menu-data';

export { slugify };

/** Versioned key so the app fetches the real photo (not the earlier placeholder). */
export const groceryImageUrl = (name: string): string =>
  `${MENU_IMAGE_BASE_URL}/${slugify(name)}_v2.jpg`;

export interface GroceryItem {
  category: string;
  name: string;
  variant: string;
  price: number; // integer rupiah
  cost: number;
  sku: string;
  /** Open Food Facts search term (branded goods). null → skip OFF, use Commons. */
  off: string | null;
  /** Wikimedia Commons image-search term (English) — fallback / generic items. */
  commons: string;
}

export const GROCERY: GroceryItem[] = [
  // --- 6 existing (names match seed-portal.ts) ---
  { category: 'Sembako', name: 'Beras Premium 5kg', variant: 'Karung', price: 65000, cost: 58000, sku: 'BRS5', off: null, commons: 'sack of rice' },
  { category: 'Sembako', name: 'Minyak Goreng 2L', variant: 'Pouch', price: 38000, cost: 34000, sku: 'MYK2', off: 'bimoli minyak goreng', commons: 'cooking oil bottle' },
  { category: 'Sembako', name: 'Gula Pasir 1kg', variant: 'Pak', price: 15000, cost: 13000, sku: 'GLA1', off: 'gulaku gula', commons: 'sugar bag' },
  { category: 'Sembako', name: 'Telur Ayam 1kg', variant: 'Kg', price: 28000, cost: 25000, sku: 'TLR1', off: null, commons: 'chicken eggs carton' },
  { category: 'Minuman', name: 'Air Mineral 600ml', variant: 'Botol', price: 4000, cost: 2500, sku: 'AIR6', off: 'aqua air mineral', commons: 'bottled water' },
  { category: 'Snack', name: 'Indomie Goreng', variant: 'Pcs', price: 3500, cost: 3000, sku: 'IDM1', off: 'indomie goreng', commons: 'instant noodles package' },

  // --- 20 new ---
  { category: 'Sembako', name: 'Tepung Terigu 1kg', variant: 'Pak', price: 12000, cost: 10000, sku: 'TPG1', off: 'segitiga biru tepung terigu', commons: 'wheat flour bag' },
  { category: 'Sembako', name: 'Beras Merah 2kg', variant: 'Karung', price: 32000, cost: 28000, sku: 'BRM2', off: null, commons: 'brown rice grains' },
  { category: 'Sembako', name: 'Kacang Hijau 500g', variant: 'Pak', price: 14000, cost: 12000, sku: 'KCH5', off: null, commons: 'mung beans' },
  { category: 'Sembako', name: 'Kecap Manis 600ml', variant: 'Botol', price: 22000, cost: 19000, sku: 'KCP6', off: 'bango kecap manis', commons: 'soy sauce bottle' },
  { category: 'Sembako', name: 'Susu Kental Manis', variant: 'Kaleng', price: 11000, cost: 9500, sku: 'SKM1', off: 'frisian flag kental manis', commons: 'condensed milk can' },
  { category: 'Snack', name: 'Mie Instan Ayam', variant: 'Pcs', price: 3000, cost: 2500, sku: 'MIA1', off: 'mie sedaap ayam', commons: 'instant noodles' },
  { category: 'Bumbu', name: 'Garam Halus 500g', variant: 'Pak', price: 5000, cost: 3500, sku: 'GRM5', off: null, commons: 'table salt' },
  { category: 'Bumbu', name: 'Merica Bubuk 100g', variant: 'Sachet', price: 9000, cost: 7000, sku: 'MRC1', off: 'ladaku merica', commons: 'ground black pepper' },
  { category: 'Bumbu', name: 'Bawang Merah 1kg', variant: 'Kg', price: 35000, cost: 30000, sku: 'BWM1', off: null, commons: 'shallots' },
  { category: 'Bumbu', name: 'Bawang Putih 1kg', variant: 'Kg', price: 32000, cost: 28000, sku: 'BWP1', off: null, commons: 'garlic bulb' },
  { category: 'Bumbu', name: 'Cabai Merah 1kg', variant: 'Kg', price: 45000, cost: 38000, sku: 'CBM1', off: null, commons: 'red chili pepper' },
  { category: 'Minuman', name: 'Teh Kotak 300ml', variant: 'Kotak', price: 5000, cost: 3500, sku: 'TEH3', off: 'teh kotak', commons: 'tea carton drink' },
  { category: 'Minuman', name: 'Kopi Sachet', variant: 'Renceng', price: 12000, cost: 10000, sku: 'KOP1', off: 'kapal api kopi', commons: 'coffee sachet' },
  { category: 'Minuman', name: 'Sirup Buah 460ml', variant: 'Botol', price: 25000, cost: 21000, sku: 'SRP4', off: 'marjan sirup', commons: 'syrup bottle' },
  { category: 'Snack', name: 'Biskuit Marie 300g', variant: 'Pak', price: 13000, cost: 11000, sku: 'BSK3', off: 'roma marie biskuit', commons: 'marie biscuit' },
  { category: 'Snack', name: 'Keripik Kentang', variant: 'Pak', price: 15000, cost: 12000, sku: 'KRP1', off: 'chitato', commons: 'potato chips bag' },
  { category: 'Snack', name: 'Wafer Coklat', variant: 'Pak', price: 9000, cost: 7000, sku: 'WFR1', off: 'tango wafer', commons: 'chocolate wafer' },
  { category: 'Perawatan', name: 'Sabun Mandi', variant: 'Batang', price: 4500, cost: 3200, sku: 'SBN1', off: 'lifebuoy sabun', commons: 'bar soap' },
  { category: 'Perawatan', name: 'Pasta Gigi 190g', variant: 'Tube', price: 16000, cost: 13000, sku: 'PSG1', off: 'pepsodent pasta gigi', commons: 'toothpaste tube' },
  { category: 'Rumah Tangga', name: 'Sabun Cuci Piring', variant: 'Botol', price: 14000, cost: 11000, sku: 'SCP1', off: 'sunlight sabun cuci piring', commons: 'dishwashing liquid bottle' },
];
