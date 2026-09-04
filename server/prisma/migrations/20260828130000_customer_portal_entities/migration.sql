-- Staff roles: add MANAGER and SERVER (append to the enum).
ALTER TYPE "StaffRole" ADD VALUE IF NOT EXISTS 'MANAGER';
ALTER TYPE "StaffRole" ADD VALUE IF NOT EXISTS 'SERVER';

-- Merchant business type.
CREATE TYPE "BusinessType" AS ENUM ('FNB', 'GROCERY');

-- Merchant: business type + logo (company name is Merchant.name).
ALTER TABLE "merchants" ADD COLUMN "businessType" "BusinessType" NOT NULL DEFAULT 'FNB';
ALTER TABLE "merchants" ADD COLUMN "logoUrl" TEXT;

-- Outlet (branch): code + manager. Code is unique per merchant (NULLs are
-- distinct, so branches without a code don't clash).
ALTER TABLE "outlets" ADD COLUMN "code" TEXT;
ALTER TABLE "outlets" ADD COLUMN "managerId" TEXT;
CREATE UNIQUE INDEX "outlets_merchantId_code_key" ON "outlets" ("merchantId", "code");

-- Staff: employee id, phone, outlet assignment.
ALTER TABLE "staff" ADD COLUMN "employeeId" TEXT;
ALTER TABLE "staff" ADD COLUMN "phone" TEXT;
ALTER TABLE "staff" ADD COLUMN "outletId" TEXT;
CREATE UNIQUE INDEX "staff_merchantId_employeeId_key" ON "staff" ("merchantId", "employeeId");
