-- Online-delivery orders: sales channel + fulfillment status on orders.
-- Additive only — existing rows default to channel = 'POS', onlineStatus NULL.

-- CreateEnum
CREATE TYPE "OrderChannel" AS ENUM ('POS', 'GOFOOD', 'GRABFOOD', 'SHOPEEFOOD');

-- CreateEnum
CREATE TYPE "OnlineOrderStatus" AS ENUM ('NEW', 'ACCEPTED', 'PREPARING', 'READY', 'COMPLETED', 'CANCELLED');

-- AlterEnum
ALTER TYPE "PaymentMethod" ADD VALUE 'ONLINE';

-- AlterTable
ALTER TABLE "orders" ADD COLUMN "channel" "OrderChannel" NOT NULL DEFAULT 'POS';
ALTER TABLE "orders" ADD COLUMN "onlineStatus" "OnlineOrderStatus";
ALTER TABLE "orders" ADD COLUMN "externalOrderRef" TEXT;
ALTER TABLE "orders" ADD COLUMN "customerName" TEXT;

-- CreateIndex
CREATE INDEX "orders_outletId_onlineStatus_idx" ON "orders"("outletId", "onlineStatus");
