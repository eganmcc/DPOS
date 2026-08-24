/**
 * Demo F&B menu (US1 catalog fixture) — shared by `seed.ts` (fresh merchant) and
 * `seed-menu.ts` (top up an existing merchant, e.g. the live RDS demo).
 *
 * Images: Wikimedia Commons thumbnails, all CC/CC0 (see LICENCE note per item).
 * Commons only serves a fixed set of thumbnail widths — 250 and 500 are valid,
 * arbitrary widths (300/320/400/800) return HTTP 400 — so every URL here is 500px.
 * These are placeholders for the demo; swap `imageUrl` for S3 objects later and
 * nothing else has to change (the app just renders whatever URL the API returns).
 */
import type { PrismaClient } from '@prisma/client';

const COMMONS = 'https://upload.wikimedia.org/wikipedia/commons/thumb';
/** Build a 500px Commons thumbnail URL from its "<a>/<ab>/<File>.jpg" path. */
const img = (path: string): string => `${COMMONS}/${path}/500px-${path.split('/').pop()}`;

export interface MenuVariantSpec {
  name: string;
  price: number; // integer rupiah
  costPrice?: number;
  isDefault?: boolean;
  trackInventory?: boolean;
}

export interface MenuModifierGroupSpec {
  name: string;
  minSelect: number;
  maxSelect: number;
  required?: boolean;
  modifiers: { name: string; priceDelta: number }[];
}

export interface MenuItemSpec {
  name: string;
  category: string;
  imageUrl: string;
  variants: MenuVariantSpec[];
  modifierGroups?: MenuModifierGroupSpec[];
}

export const CATEGORIES: { name: string; sortOrder: number }[] = [
  { name: 'Minuman', sortOrder: 1 },
  { name: 'Makanan', sortOrder: 2 },
  { name: 'Snack', sortOrder: 3 },
];

const SUGAR_LEVEL: MenuModifierGroupSpec = {
  name: 'Sugar level',
  minSelect: 0,
  maxSelect: 1,
  modifiers: [
    { name: 'Less sugar', priceDelta: 0 },
    { name: 'Normal', priceDelta: 0 },
    { name: 'Extra shot', priceDelta: 5000 },
  ],
};

const SPICE_LEVEL: MenuModifierGroupSpec = {
  name: 'Level pedas',
  minSelect: 0,
  maxSelect: 1,
  modifiers: [
    { name: 'Level 1', priceDelta: 0 },
    { name: 'Level 3', priceDelta: 0 },
    { name: 'Level 5', priceDelta: 2000 },
  ],
};

export const MENU: MenuItemSpec[] = [
  // ---- Minuman -------------------------------------------------------------
  {
    name: 'Kopi Susu',
    category: 'Minuman',
    imageUrl: img('5/54/Es_kopi_susu_kekinian_di_Yogyakarta%2C_Indonesia.jpg'), // CC BY-SA 4.0
    variants: [
      { name: 'Regular', price: 18000, costPrice: 7000, isDefault: true, trackInventory: true },
      { name: 'Large', price: 23000, costPrice: 9000, trackInventory: true },
    ],
    modifierGroups: [SUGAR_LEVEL],
  },
  {
    name: 'Es Teh Manis',
    category: 'Minuman',
    imageUrl: img('6/64/Es_teh_manis.jpg'), // CC BY 4.0
    variants: [
      { name: 'Regular', price: 8000, costPrice: 2500, isDefault: true, trackInventory: true },
      { name: 'Jumbo', price: 12000, costPrice: 3500, trackInventory: true },
    ],
  },
  {
    name: 'Es Jeruk',
    category: 'Minuman',
    imageUrl: img('6/67/Orange_juice_1_edit1.jpg'), // public domain
    variants: [
      { name: 'Regular', price: 12000, costPrice: 4000, isDefault: true, trackInventory: true },
      { name: 'Jumbo', price: 16000, costPrice: 5500, trackInventory: true },
    ],
  },
  {
    name: 'Cappuccino',
    category: 'Minuman',
    imageUrl: img('0/0c/Cappuccino_latte_art_20260712_-_02.jpg'), // CC BY-SA 4.0
    variants: [
      { name: 'Hot', price: 25000, costPrice: 9000, isDefault: true, trackInventory: true },
      { name: 'Iced', price: 28000, costPrice: 10000, trackInventory: true },
    ],
    modifierGroups: [SUGAR_LEVEL],
  },
  {
    name: 'Teh Tarik',
    category: 'Minuman',
    imageUrl: img('2/26/Teh_Tarik.jpg'), // CC BY-SA 2.0
    variants: [{ name: 'Regular', price: 15000, costPrice: 5000, isDefault: true, trackInventory: true }],
  },
  {
    name: 'Air Mineral',
    category: 'Minuman',
    imageUrl: img('3/37/Botol_air_mineral.jpg'), // CC BY-SA 4.0
    variants: [{ name: '600 ml', price: 6000, costPrice: 2500, isDefault: true, trackInventory: true }],
  },
  {
    name: 'Jus Alpukat',
    category: 'Minuman',
    imageUrl: img('2/2c/Jus_alpukat_Bandung.JPG'), // CC BY 3.0
    variants: [{ name: 'Regular', price: 20000, costPrice: 8000, isDefault: true, trackInventory: true }],
  },

  // ---- Makanan -------------------------------------------------------------
  {
    name: 'Nasi Goreng',
    category: 'Makanan',
    imageUrl: img('3/3e/Nasi_goreng_indonesia.jpg'), // CC BY-SA 4.0
    variants: [{ name: 'Regular', price: 27000, costPrice: 12000, isDefault: true, trackInventory: true }],
  },
  {
    name: 'Mie Goreng',
    category: 'Makanan',
    imageUrl: img('f/f9/Mie_goreng.jpg'), // CC BY-SA 4.0
    variants: [{ name: 'Regular', price: 25000, costPrice: 11000, isDefault: true, trackInventory: true }],
  },
  {
    name: 'Ayam Geprek',
    category: 'Makanan',
    imageUrl: img('c/ce/Ayam_geprek.jpg'), // CC BY-SA 4.0
    variants: [
      { name: 'Original', price: 28000, costPrice: 13000, isDefault: true, trackInventory: true },
      { name: 'Keju', price: 33000, costPrice: 16000, trackInventory: true },
    ],
    modifierGroups: [SPICE_LEVEL],
  },
  {
    name: 'Sate Ayam',
    category: 'Makanan',
    imageUrl: img('4/44/Sate_Ayam_Panggang.jpg'), // CC BY-SA 4.0
    variants: [{ name: '10 tusuk', price: 30000, costPrice: 14000, isDefault: true, trackInventory: true }],
  },
  {
    name: 'Soto Ayam',
    category: 'Makanan',
    imageUrl: img('8/8e/Soto_Ayam_Kudus.jpg'), // CC BY-SA 4.0
    variants: [{ name: 'Regular', price: 26000, costPrice: 11000, isDefault: true, trackInventory: true }],
  },
  {
    name: 'Bakso',
    category: 'Makanan',
    imageUrl: img('6/6e/Bakso_Indonesian_Meatball_Soup_from_Solo.jpg'), // CC0
    variants: [
      { name: 'Biasa', price: 24000, costPrice: 10000, isDefault: true, trackInventory: true },
      { name: 'Spesial', price: 30000, costPrice: 13000, trackInventory: true },
    ],
  },
  {
    name: 'Gado-Gado',
    category: 'Makanan',
    imageUrl: img('3/30/Gado-gado_in_Jakarta.JPG'), // CC BY 3.0
    variants: [{ name: 'Regular', price: 22000, costPrice: 9000, isDefault: true, trackInventory: true }],
  },
  {
    name: 'Ayam Bakar',
    category: 'Makanan',
    imageUrl: img('7/78/Ayam_bakar.jpg'), // CC BY-SA 4.0
    variants: [{ name: 'Paket nasi', price: 32000, costPrice: 15000, isDefault: true, trackInventory: true }],
    modifierGroups: [SPICE_LEVEL],
  },

  // ---- Snack ---------------------------------------------------------------
  {
    name: 'Pisang Goreng',
    category: 'Snack',
    imageUrl: img('0/0f/Pisang_Goreng.jpg'), // CC BY-SA 4.0
    variants: [{ name: 'Porsi', price: 15000, costPrice: 6000, isDefault: true, trackInventory: true }],
  },
  {
    name: 'Tahu Isi',
    category: 'Snack',
    imageUrl: img('2/28/Tahu_isi_goreng_plus_cabe_rawit.jpg'), // CC BY-SA 3.0
    variants: [{ name: '5 pcs', price: 12000, costPrice: 4500, isDefault: true, trackInventory: true }],
  },
  {
    name: 'Roti Bakar',
    category: 'Snack',
    imageUrl: img('1/1a/Roti_bakar_kekinian.jpg'), // CC BY-SA 4.0
    variants: [
      { name: 'Coklat', price: 18000, costPrice: 7000, isDefault: true, trackInventory: true },
      { name: 'Coklat Keju', price: 22000, costPrice: 9000, trackInventory: true },
    ],
  },
  {
    name: 'Martabak Manis',
    category: 'Snack',
    imageUrl: img('9/93/Martabak_manis_coklat_keju_khas_indonesia.jpg'), // CC BY-SA 4.0
    variants: [
      { name: 'Coklat Kacang', price: 30000, costPrice: 14000, isDefault: true, trackInventory: true },
      { name: 'Keju', price: 35000, costPrice: 17000, trackInventory: true },
    ],
  },
  {
    name: 'Es Campur',
    category: 'Snack',
    imageUrl: img('e/e0/Es_Campur%2C_2019.jpg'), // CC BY-SA 4.0
    variants: [{ name: 'Regular', price: 20000, costPrice: 8000, isDefault: true, trackInventory: true }],
  },
];

export interface ApplyMenuResult {
  categoriesCreated: number;
  productsCreated: number;
  productsUpdated: number;
  stockRowsCreated: number;
}

/**
 * Idempotent: creates any missing category/product, refreshes `imageUrl` on
 * products that already exist, and opens stock for tracked variants that have
 * none at `stockOutletId`. Existing variants are never rewritten — order lines
 * and the inventory ledger reference them.
 */
export async function applyMenu(
  prisma: PrismaClient,
  opts: { merchantId: string; stockOutletId: string; openingStock?: number; createdById?: string },
): Promise<ApplyMenuResult> {
  const { merchantId, stockOutletId, openingStock = 100, createdById = 'seed' } = opts;
  const result: ApplyMenuResult = {
    categoriesCreated: 0,
    productsCreated: 0,
    productsUpdated: 0,
    stockRowsCreated: 0,
  };

  const categoryIdByName = new Map<string, string>();
  for (const spec of CATEGORIES) {
    const existing = await prisma.category.findFirst({ where: { merchantId, name: spec.name } });
    if (existing) {
      categoryIdByName.set(spec.name, existing.id);
      continue;
    }
    const created = await prisma.category.create({
      data: { merchantId, name: spec.name, sortOrder: spec.sortOrder },
    });
    categoryIdByName.set(spec.name, created.id);
    result.categoriesCreated += 1;
  }

  const trackedVariantIds: string[] = [];

  for (const item of MENU) {
    const categoryId = categoryIdByName.get(item.category);
    if (!categoryId) throw new Error(`Unknown category "${item.category}" for ${item.name}`);

    const existing = await prisma.product.findFirst({
      where: { merchantId, name: item.name },
      include: { variants: true },
    });

    if (existing) {
      await prisma.product.update({
        where: { id: existing.id },
        data: { imageUrl: item.imageUrl, categoryId },
      });
      result.productsUpdated += 1;
      trackedVariantIds.push(...existing.variants.filter((v) => v.trackInventory).map((v) => v.id));
      continue;
    }

    const created = await prisma.product.create({
      data: {
        merchantId,
        categoryId,
        name: item.name,
        imageUrl: item.imageUrl,
        variants: {
          create: item.variants.map((v) => ({
            name: v.name,
            price: v.price,
            costPrice: v.costPrice,
            isDefault: v.isDefault ?? false,
            trackInventory: v.trackInventory ?? false,
          })),
        },
        ...(item.modifierGroups && item.modifierGroups.length > 0
          ? {
              modifierGroups: {
                create: item.modifierGroups.map((g) => ({
                  name: g.name,
                  minSelect: g.minSelect,
                  maxSelect: g.maxSelect,
                  required: g.required ?? false,
                  modifiers: { create: g.modifiers.map((m) => ({ name: m.name, priceDelta: m.priceDelta })) },
                })),
              },
            }
          : {}),
      },
      include: { variants: true },
    });
    result.productsCreated += 1;
    trackedVariantIds.push(...created.variants.filter((v) => v.trackInventory).map((v) => v.id));
  }

  for (const variantId of trackedVariantIds) {
    const stock = await prisma.inventoryStock.findFirst({
      where: { merchantId, outletId: stockOutletId, variantId },
    });
    if (stock) continue;
    await prisma.inventoryStock.create({
      data: { merchantId, outletId: stockOutletId, variantId, quantityOnHand: openingStock },
    });
    await prisma.inventoryMovement.create({
      data: {
        merchantId,
        outletId: stockOutletId,
        variantId,
        qtyDelta: openingStock,
        reason: 'RECEIVE',
        refType: 'SEED',
        createdById,
      },
    });
    result.stockRowsCreated += 1;
  }

  return result;
}
