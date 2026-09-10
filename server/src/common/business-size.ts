import { BusinessSize } from '@prisma/client';
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
