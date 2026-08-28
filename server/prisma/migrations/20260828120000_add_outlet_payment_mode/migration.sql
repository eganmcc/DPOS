-- CreateEnum
CREATE TYPE "OutletPaymentMode" AS ENUM ('IMMEDIATE', 'OPEN_BILL');

-- AlterTable
ALTER TABLE "outlets" ADD COLUMN "paymentMode" "OutletPaymentMode" NOT NULL DEFAULT 'IMMEDIATE';

-- Table uniqueness among open bills: an outlet can hold only one AWAITING_PAYMENT
-- order per table label. NULLs are distinct, so takeaway open bills with no table
-- never collide. This is the hard backstop behind the app + service pre-checks.
CREATE UNIQUE INDEX "open_bill_table_uq" ON "orders" ("outletId", "tableLabel")
  WHERE "status" = 'AWAITING_PAYMENT';
