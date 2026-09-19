import { BusinessSize, BusinessType } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

/**
 * Max products a UMI ("Ultra Mikro") catalog may hold. The cap exists so a larger
 * business cannot operate on UMI terms — it is a commercial boundary, not a
 * technical one.
 *
 * It is a HARD stop: nothing in the API writes `Product.isAvailable` (only the
 * variant's), so a merchant at the limit has no self-service way to free a slot.
 * Any message about it must say "contact DPOS", never "switch one off".
 */
export const UMI_PRODUCT_LIMIT = 30;

/**
 * True when this merchant is a single-person Ultra Mikro operation.
 *
 * Business SIZE is orthogonal to business TYPE — a UMI merchant is still F&B or
 * grocery. Read from the database rather than the JWT on purpose: tokens last 12h
 * (auth.module.ts), so a token minted before provisioning would carry a stale tier
 * for half a day, and every rule this gates is server-authoritative.
 */
export async function isUmiMerchant(prisma: PrismaService, merchantId: string): Promise<boolean> {
  const m = await prisma.merchant.findUnique({
    where: { id: merchantId },
    select: { businessSize: true },
  });
  return m?.businessSize === BusinessSize.UMI;
}

/**
 * Ceiling on a single keyed amount, in rupiah.
 *
 * A bound is required by Constitution III so the one client-originated monetary value cannot be
 * unbounded. Rp 100.000.000 is far above any warung line and far below anything that would
 * overflow an Int column, so it catches a stuck key or a misplaced `000` rather than constraining
 * a real sale.
 *
 * MUST stay equal to `kMaxNotaAmount` in `app/lib/features/calculator/nota_calculator.dart`. If
 * they diverge, the app accepts a nota the server refuses — after the cash is already counted.
 */
export const MAX_OPEN_AMOUNT = 100_000_000;

/** Longest label an open-amount line may carry — a line as written on a nota, not an essay. */
export const MAX_OPEN_AMOUNT_LABEL = 120;

/**
 * True when this merchant sells without a catalog, so a line's price may come from the client
 * (Constitution III, open-amount lines, v1.9.0). Two kinds qualify:
 *   - `calculatorOnly` — the cashier keys amounts on a keypad (specs/008);
 *   - business type `HIGH_HUMAN_INTERACTION` — the price is read off the merchant's own nota
 *     (specs/009).
 *
 * Read from the database for the same reason as `isUmiMerchant` above: this decides whether a
 * client may originate a price at all, so it must never come from a token or a request field.
 */
export async function acceptsOpenAmountLines(
  prisma: PrismaService,
  merchantId: string,
): Promise<boolean> {
  const m = await prisma.merchant.findUnique({
    where: { id: merchantId },
    select: { calculatorOnly: true, businessType: true },
  });
  return m?.calculatorOnly === true || m?.businessType === BusinessType.HIGH_HUMAN_INTERACTION;
}
