-- A free-text note on an order (specs/009-nota-reading-mode).
--
-- A nota sale records what the paper said that was NOT charged — lines with no price ("A/J FREE",
-- "31 pc", "S/B guling = 4") and anything the reader could not make out — so nothing written on the
-- slip is silently lost. Text only: it never enters any amount. Nullable and additive, so every
-- existing order is untouched and a server built before this column keeps working.
ALTER TABLE "orders" ADD COLUMN "note" TEXT;
