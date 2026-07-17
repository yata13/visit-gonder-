-- ============================================================
--  SITE MAP PINS — adds lat/lng to sites and sets the real
--  coordinates, so the app map shows correct locations.
--  Run once in the Supabase SQL Editor. Safe to re-run.
-- ============================================================
ALTER TABLE sites ADD COLUMN IF NOT EXISTS lat numeric(9,6);
ALTER TABLE sites ADD COLUMN IF NOT EXISTS lng numeric(9,6);

UPDATE sites SET lat = 12.604300, lng = 37.470000 WHERE name_en ILIKE '%fasil ghebbi%';
UPDATE sites SET lat = 12.613600, lng = 37.476200 WHERE name_en ILIKE '%debre berhan%';
UPDATE sites SET lat = 12.606200, lng = 37.464800 WHERE name_en ILIKE '%bath%';
UPDATE sites SET lat = 12.615500, lng = 37.459800 WHERE name_en ILIKE '%kusquam%' OR name_en ILIKE '%kuskuam%';
-- Simien Mountains are ~100km away — outside the city map, no pin.

SELECT name_en, lat, lng FROM sites ORDER BY name_en;
