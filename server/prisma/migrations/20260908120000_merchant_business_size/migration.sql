-- Merchant business size (operating scale), orthogonal to businessType.
-- UMI = "Ultra Mikro": a single-person operation.
-- A NEW enum, not a value appended to "BusinessType": CREATE TYPE is transaction-safe,
-- ALTER TYPE ... ADD VALUE is not, and the two axes are independent.
CREATE TYPE "BusinessSize" AS ENUM ('GENERAL', 'UMKM', 'UMI');

-- NOT NULL DEFAULT is metadata-only on PG 11+ (no rewrite of a live table);
-- existing merchants backfill to GENERAL.
ALTER TABLE "merchants" ADD COLUMN "businessSize" "BusinessSize" NOT NULL DEFAULT 'GENERAL';
