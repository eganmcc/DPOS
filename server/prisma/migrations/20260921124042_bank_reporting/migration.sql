-- AlterTable
ALTER TABLE "merchants" ADD COLUMN     "bankBranch" TEXT,
ADD COLUMN     "bankCif" TEXT,
ADD COLUMN     "bankOfficerId" TEXT,
ADD COLUMN     "dataConsentAt" TIMESTAMP(3),
ADD COLUMN     "dataConsentBy" TEXT,
ADD COLUMN     "dataConsentRevokedAt" TIMESTAMP(3),
ADD COLUMN     "dataConsentVersion" TEXT,
ADD COLUMN     "edcMid" TEXT,
ADD COLUMN     "edcTid" TEXT,
ADD COLUMN     "mcc" TEXT,
ADD COLUMN     "nib" TEXT,
ADD COLUMN     "npwp" TEXT,
ADD COLUMN     "onboardedAt" TIMESTAMP(3),
ADD COLUMN     "qrisMpan" TEXT,
ADD COLUMN     "qrisNmid" TEXT;

-- CreateTable
CREATE TABLE "settlement_records" (
    "id" TEXT NOT NULL,
    "merchantId" TEXT NOT NULL,
    "settledOn" DATE NOT NULL,
    "method" TEXT NOT NULL,
    "terminalRef" TEXT,
    "grossAmount" INTEGER NOT NULL,
    "feeAmount" INTEGER NOT NULL DEFAULT 0,
    "netAmount" INTEGER NOT NULL,
    "txnCount" INTEGER NOT NULL DEFAULT 0,
    "externalRef" TEXT,
    "ingestedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "settlement_records_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "settlement_records_merchantId_settledOn_idx" ON "settlement_records"("merchantId", "settledOn");

-- CreateIndex
CREATE UNIQUE INDEX "settlement_records_merchantId_externalRef_key" ON "settlement_records"("merchantId", "externalRef");

-- AddForeignKey
ALTER TABLE "settlement_records" ADD CONSTRAINT "settlement_records_merchantId_fkey" FOREIGN KEY ("merchantId") REFERENCES "merchants"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
