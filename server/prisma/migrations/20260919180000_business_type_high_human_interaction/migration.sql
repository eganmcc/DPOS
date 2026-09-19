-- High Human Interactions (specs/009-nota-reading-mode, Constitution v1.9.0).
--
-- A new business TYPE for trades whose sale is written by hand on a nota. Adding an enum value is
-- metadata-only and touches no existing row; every merchant keeps FNB or GROCERY.
--
-- DEPLOY ORDER MATTERS: apply this, then deploy the server built against it, and only THEN create a
-- merchant of this type. A server built before this value exists cannot decode such a row, and
-- endpoints that list every merchant (GET /demo/directory) would fail for everyone.
ALTER TYPE "BusinessType" ADD VALUE 'HIGH_HUMAN_INTERACTION';
