-- ============================================================
--  VISIT GONDAR — THE ONE MIGRATION TO RUN
--  Paste into: Supabase Dashboard → SQL Editor → Run
--
--  This is the ONLY file you need to run. It supersedes:
--    supabase_update.sql (old, targets a schema that no longer exists)
--    supabase_commission_and_seed.sql (its seed data has already been
--    inserted into the live database for you — only the parts below
--    were impossible to apply automatically)
--
--  Safe to run more than once.
-- ============================================================

-- ── 1. COMMISSION FIELDS ON BOOKINGS ─────────────────────────
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS total_price       numeric(10,2) DEFAULT 0;
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS commission_rate   numeric(4,3)  DEFAULT 0.03;
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS commission_amount numeric(10,2) DEFAULT 0;

-- ── 2. AUTO-CALCULATE COMMISSION TRIGGER ─────────────────────
--  Hotel bookings  = 3%  of total price
--  Guide bookings  = 10% of the guide fee
CREATE OR REPLACE FUNCTION calculate_booking_commission()
RETURNS trigger AS $$
BEGIN
  -- Fall back to legacy "price" column if total_price not supplied
  IF NEW.total_price IS NULL OR NEW.total_price = 0 THEN
    NEW.total_price := COALESCE(NEW.price, 0);
  END IF;

  IF NEW.item_type = 'guide' THEN
    NEW.commission_rate := 0.10;
  ELSE
    NEW.commission_rate := 0.03;
  END IF;

  NEW.commission_amount := ROUND(NEW.total_price * NEW.commission_rate, 2);
  -- keep legacy column in sync for older admin views
  NEW.commission_earned := NEW.commission_amount;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_booking_commission ON bookings;
CREATE TRIGGER on_booking_commission
  BEFORE INSERT OR UPDATE OF total_price, price, item_type ON bookings
  FOR EACH ROW EXECUTE FUNCTION calculate_booking_commission();

-- Recalculate any existing bookings
UPDATE bookings SET total_price = COALESCE(NULLIF(total_price, 0), price, 0);

-- ── 3. HOTEL MAP COORDINATES ─────────────────────────────────
--  The app's map screen shows hotel pins straight from this table.
--  Hotels without lat/lng are simply not shown on the map.
ALTER TABLE hotels ADD COLUMN IF NOT EXISTS lat numeric(9,6);
ALTER TABLE hotels ADD COLUMN IF NOT EXISTS lng numeric(9,6);

UPDATE hotels SET lat = 12.6098, lng = 37.4808 WHERE name_en = 'Goha Hotel'              AND lat IS NULL;
UPDATE hotels SET lat = 12.6070, lng = 37.4750 WHERE name_en = 'Haile Resort Gondar'     AND lat IS NULL;
UPDATE hotels SET lat = 12.6015, lng = 37.4658 WHERE name_en = 'Lodge de Chateau'        AND lat IS NULL;
UPDATE hotels SET lat = 12.6028, lng = 37.4672 WHERE name_en = 'Taye Belay Hotel'        AND lat IS NULL;
UPDATE hotels SET lat = 12.6080, lng = 37.4710 WHERE name_en = 'Inn of the Four Sisters' AND lat IS NULL;
UPDATE hotels SET lat = 12.6022, lng = 37.4660 WHERE name_en = 'Fasil Hotel'             AND lat IS NULL;
UPDATE hotels SET lat = 12.6120, lng = 37.4580 WHERE name_en = 'Gondar Hills Resort'     AND lat IS NULL;
UPDATE hotels SET lat = 12.6018, lng = 37.4645 WHERE name_en = 'Quara Hotel'             AND lat IS NULL;

-- ── 4. VERIFY ────────────────────────────────────────────────
SELECT 'hotels' AS t, count(*) FROM hotels
UNION ALL SELECT 'hotels with map pin', count(*) FROM hotels WHERE lat IS NOT NULL
UNION ALL SELECT 'sites', count(*) FROM sites
UNION ALL SELECT 'guides', count(*) FROM guides
UNION ALL SELECT 'bookings', count(*) FROM bookings;
