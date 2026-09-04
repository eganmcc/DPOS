-- CreateTable
CREATE TABLE "attendance" (
    "id" TEXT NOT NULL,
    "merchantId" TEXT NOT NULL,
    "staffId" TEXT NOT NULL,
    "outletId" TEXT,
    "clockInAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "clockOutAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "attendance_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "attendance_merchantId_clockInAt_idx" ON "attendance"("merchantId", "clockInAt");

-- CreateIndex
CREATE INDEX "attendance_staffId_clockInAt_idx" ON "attendance"("staffId", "clockInAt");

-- AddForeignKey
ALTER TABLE "attendance" ADD CONSTRAINT "attendance_merchantId_fkey" FOREIGN KEY ("merchantId") REFERENCES "merchants"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "attendance" ADD CONSTRAINT "attendance_staffId_fkey" FOREIGN KEY ("staffId") REFERENCES "staff"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
