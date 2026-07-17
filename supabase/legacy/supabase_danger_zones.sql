-- Danger Zones table
CREATE TABLE IF NOT EXISTS danger_zones (
  id          uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  name        text NOT NULL,
  description text,
  severity    text DEFAULT 'medium',  -- low / medium / high / critical
  lat         double precision NOT NULL,
  lng         double precision NOT NULL,
  radius      int DEFAULT 500,        -- meters
  is_active   boolean DEFAULT true,
  created_at  timestamptz DEFAULT now()
);

ALTER TABLE danger_zones ENABLE ROW LEVEL SECURITY;
CREATE POLICY "dz_select" ON danger_zones FOR SELECT USING (true);
CREATE POLICY "dz_insert" ON danger_zones FOR INSERT WITH CHECK (true);
CREATE POLICY "dz_update" ON danger_zones FOR UPDATE USING (true);
CREATE POLICY "dz_delete" ON danger_zones FOR DELETE USING (true);

SELECT 'Danger zones table ready!' AS result;
