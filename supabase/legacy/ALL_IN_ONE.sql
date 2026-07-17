-- ════════════════════════════════════════════════════════════
--  VISIT GONDAR — ALL-IN-ONE SETUP (run once, safe to re-run)
--  1. posts table   → News Feed (admin posts → app home feed)
--  2. places table  → Map Manager (you control every map pin)
--  3. realtime      → instant popups for notifications & posts
--  4. seed          → your 8 hotels + main heritage sites on map
-- ════════════════════════════════════════════════════════════

-- ── 1. POSTS (news feed) ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS posts (
  id         uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  title      text NOT NULL,
  title_am   text,
  body       text,
  body_am    text,
  photo      text,
  category   text DEFAULT 'news',
  created_at timestamptz DEFAULT now()
);
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  BEGIN CREATE POLICY posts_select ON posts FOR SELECT USING (true);
  EXCEPTION WHEN duplicate_object THEN NULL; END;
  BEGIN CREATE POLICY posts_insert ON posts FOR INSERT WITH CHECK (true);
  EXCEPTION WHEN duplicate_object THEN NULL; END;
  BEGIN CREATE POLICY posts_update ON posts FOR UPDATE USING (true);
  EXCEPTION WHEN duplicate_object THEN NULL; END;
  BEGIN CREATE POLICY posts_delete ON posts FOR DELETE USING (true);
  EXCEPTION WHEN duplicate_object THEN NULL; END;
END $$;

INSERT INTO posts (title, title_am, body, body_am, photo, category)
SELECT
  'Welcome to the new Visit Gondar app!',
  'እንኳን ወደ አዲሱ የጎንደር ጉብኝት መተግበሪያ በደህና መጡ!',
  'Follow this feed for city news, festival updates and travel tips — straight from the Gondar tourism office.',
  'የከተማ ዜናዎችን፣ የበዓል ዝመናዎችን እና የጉዞ ምክሮችን እዚህ ይከታተሉ።',
  'https://upload.wikimedia.org/wikipedia/commons/thumb/8/8b/Fasil_Ghebbi%2C_Gondar.jpg/800px-Fasil_Ghebbi%2C_Gondar.jpg',
  'news'
WHERE NOT EXISTS (SELECT 1 FROM posts);

-- ── 2. PLACES (map manager) ──────────────────────────────────
CREATE TABLE IF NOT EXISTS places (
  id          uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  name_en     text NOT NULL,
  name_am     text,
  category    text DEFAULT 'other',  -- hotel|castle|church|museum|store|club|restaurant|other
  photo       text,
  info        text,
  description text,
  lat         numeric(9,6),
  lng         numeric(9,6),
  created_at  timestamptz DEFAULT now()
);
ALTER TABLE places ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  BEGIN CREATE POLICY places_select ON places FOR SELECT USING (true);
  EXCEPTION WHEN duplicate_object THEN NULL; END;
  BEGIN CREATE POLICY places_insert ON places FOR INSERT WITH CHECK (true);
  EXCEPTION WHEN duplicate_object THEN NULL; END;
  BEGIN CREATE POLICY places_update ON places FOR UPDATE USING (true);
  EXCEPTION WHEN duplicate_object THEN NULL; END;
  BEGIN CREATE POLICY places_delete ON places FOR DELETE USING (true);
  EXCEPTION WHEN duplicate_object THEN NULL; END;
END $$;

-- ── 3. REALTIME (instant popups + live map edits) ────────────
DO $$ BEGIN
  BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
  EXCEPTION WHEN duplicate_object THEN NULL; END;
  BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE danger_zones;
  EXCEPTION WHEN duplicate_object THEN NULL; END;
  BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE posts;
  EXCEPTION WHEN duplicate_object THEN NULL; END;
  BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE places;
  EXCEPTION WHEN duplicate_object THEN NULL; END;
END $$;

-- ── 4. SEED THE MAP ──────────────────────────────────────────
-- Your hotels (with their coordinates) become map pins
INSERT INTO places (name_en, name_am, category, photo, info, description, lat, lng)
SELECT
  h.name_en, h.name_am, 'hotel',
  COALESCE(h.photos[1], ''),
  '$' || ROUND(h.price) || '/night · ' || REPEAT('★', h.star_ranking),
  h.description, h.lat, h.lng
FROM hotels h
WHERE h.lat IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM places p WHERE p.name_en = h.name_en);

-- Main heritage sites with REAL coordinates
INSERT INTO places (name_en, name_am, category, photo, info, lat, lng)
SELECT * FROM (VALUES
  ('Fasil Ghebbi', 'ፋሲል ግቢ', 'castle',
   'https://upload.wikimedia.org/wikipedia/commons/thumb/8/8b/Fasil_Ghebbi%2C_Gondar.jpg/800px-Fasil_Ghebbi%2C_Gondar.jpg',
   'UNESCO World Heritage · Entry 200 ETB', 12.604300, 37.470000),
  ('Debre Berhan Selassie', 'ደብረ ብርሃን ሥላሴ', 'church',
   'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a8/Debre_Berhan_Selassie_Church.jpg/800px-Debre_Berhan_Selassie_Church.jpg',
   'Famous 135-angel ceiling · Entry 100 ETB', 12.613600, 37.476200),
  ('Fasilides Bath', 'የፋሲልደስ መታጠቢያ', 'castle',
   'https://upload.wikimedia.org/wikipedia/commons/thumb/1/19/Fasilides_Bath_Gondar_Ethiopia.jpg/800px-Fasilides_Bath_Gondar_Ethiopia.jpg',
   'Timket festival site · Entry 100 ETB', 12.606200, 37.464800),
  ('Kusquam Palace', 'ቁስቋም ቤተ መንግሥት', 'church',
   '', 'Empress Mentewab''s palace · Entry 100 ETB', 12.615500, 37.459800)
) AS v(name_en, name_am, category, photo, info, lat, lng)
WHERE NOT EXISTS (SELECT 1 FROM places p WHERE p.name_en = v.name_en);

-- ── VERIFY ───────────────────────────────────────────────────
SELECT 'posts' AS t, count(*) FROM posts
UNION ALL SELECT 'places', count(*) FROM places;
