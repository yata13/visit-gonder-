-- ============================================================
--  GONDAR NEWS FEED — posts table (Facebook-style feed on the
--  app home, written from the admin "News Feed" tab).
--  Run once in the Supabase SQL Editor. Safe to re-run.
-- ============================================================
CREATE TABLE IF NOT EXISTS posts (
  id         uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  title      text NOT NULL,
  title_am   text,
  body       text,
  body_am    text,
  photo      text,
  category   text DEFAULT 'news',   -- news | event | culture
  created_at timestamptz DEFAULT now()
);

ALTER TABLE posts ENABLE ROW LEVEL SECURITY;
DO $$
BEGIN
  BEGIN CREATE POLICY posts_select ON posts FOR SELECT USING (true);
  EXCEPTION WHEN duplicate_object THEN NULL; END;
  BEGIN CREATE POLICY posts_insert ON posts FOR INSERT WITH CHECK (true);
  EXCEPTION WHEN duplicate_object THEN NULL; END;
  BEGIN CREATE POLICY posts_update ON posts FOR UPDATE USING (true);
  EXCEPTION WHEN duplicate_object THEN NULL; END;
  BEGIN CREATE POLICY posts_delete ON posts FOR DELETE USING (true);
  EXCEPTION WHEN duplicate_object THEN NULL; END;
  -- realtime so new posts appear in the app instantly
  BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE posts;
  EXCEPTION WHEN duplicate_object THEN NULL; END;
END $$;

-- Welcome post so the feed isn't empty
INSERT INTO posts (title, title_am, body, body_am, photo, category)
SELECT
  'Welcome to the new Visit Gondar app!',
  'እንኳን ወደ አዲሱ የጎንደር ጉብኝት መተግበሪያ በደህና መጡ!',
  'Follow this feed for city news, festival updates and travel tips — straight from the Gondar tourism office.',
  'የከተማ ዜናዎችን፣ የበዓል ዝመናዎችን እና የጉዞ ምክሮችን እዚህ ይከታተሉ — በቀጥታ ከጎንደር ቱሪዝም ቢሮ።',
  'https://upload.wikimedia.org/wikipedia/commons/thumb/8/8b/Fasil_Ghebbi%2C_Gondar.jpg/800px-Fasil_Ghebbi%2C_Gondar.jpg',
  'news'
WHERE NOT EXISTS (SELECT 1 FROM posts);

SELECT 'posts table ready' AS result, count(*) AS post_count FROM posts;
