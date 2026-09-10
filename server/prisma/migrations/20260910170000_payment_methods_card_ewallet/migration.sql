-- AlterEnum: card-present tenders captured by an EDC terminal, and e-wallet tenders.
-- Values only; nothing writes them until the providers ship (PG allows ADD VALUE here,
-- same as 20260903160000_order_cancelled).
ALTER TYPE "PaymentMethod" ADD VALUE 'CARD_CREDIT';
ALTER TYPE "PaymentMethod" ADD VALUE 'CARD_DEBIT';
ALTER TYPE "PaymentMethod" ADD VALUE 'CARD_BCA';
ALTER TYPE "PaymentMethod" ADD VALUE 'EWALLET_SHOPEEPAY';
ALTER TYPE "PaymentMethod" ADD VALUE 'EWALLET_GOPAY';
ALTER TYPE "PaymentMethod" ADD VALUE 'EWALLET_OVO';

-- AlterTable: tender-specific evidence for the receipt and end-of-day reconciliation
-- (EDC approval code / RRN / masked PAN / scheme, or the wallet reference).
-- Nullable, so every existing payment row stays valid and no backfill is needed.
ALTER TABLE "payments" ADD COLUMN "providerMeta" JSONB;
