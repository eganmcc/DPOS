-- Calculator-only mode (Constitution v1.8.0, specs/008-calculator-only).
--
-- A calculator-only merchant sells with no catalog: the cashier keys bare rupiah amounts and each
-- nota is still recorded as a real Order. Both columns are additive with a NOT NULL DEFAULT, which
-- is metadata-only on PostgreSQL 11+ — no table rewrite, no lock held over a scan, and every
-- existing merchant/product backfills to the old behaviour exactly.

-- Set by DPOS provisioning; published read-only on /catalog and accepted by no endpoint.
ALTER TABLE "merchants" ADD COLUMN "calculatorOnly" BOOLEAN NOT NULL DEFAULT false;

-- The single provisioned product whose variant takes the cashier's keyed amount as its unit price.
-- Declared in no admin DTO, so ValidationPipe({ whitelist: true }) strips any attempt to set it.
ALTER TABLE "products" ADD COLUMN "isOpenAmount" BOOLEAN NOT NULL DEFAULT false;

-- At most ONE open-amount product per merchant. Partial, so it constrains nothing for the rows of
-- every existing merchant. Prisma cannot express a partial index, so this exists only here — see
-- the NOTE on Product.isOpenAmount in schema.prisma.
CREATE UNIQUE INDEX "products_open_amount_uq" ON "products" ("merchantId") WHERE "isOpenAmount";
