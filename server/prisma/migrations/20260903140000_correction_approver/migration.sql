-- AlterTable
ALTER TABLE "order_voids" ADD COLUMN "approvedById" TEXT;

-- AlterTable
ALTER TABLE "refunds" ADD COLUMN "approvedById" TEXT;
