-- ── RLS POLICIES FOR ALL TABLES ─────────────────────────────

-- HOTELS
ALTER TABLE hotels ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Hotels public read" ON hotels;
DROP POLICY IF EXISTS "Hotels admin write" ON hotels;
CREATE POLICY "Hotels public read" ON hotels FOR SELECT USING (true);
CREATE POLICY "Hotels admin insert" ON hotels FOR INSERT WITH CHECK (true);
CREATE POLICY "Hotels admin update" ON hotels FOR UPDATE USING (true);
CREATE POLICY "Hotels admin delete" ON hotels FOR DELETE USING (true);

-- GUIDES
ALTER TABLE guides ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Guides public read" ON guides;
CREATE POLICY "Guides public read" ON guides FOR SELECT USING (true);
CREATE POLICY "Guides admin insert" ON guides FOR INSERT WITH CHECK (true);
CREATE POLICY "Guides admin update" ON guides FOR UPDATE USING (true);
CREATE POLICY "Guides admin delete" ON guides FOR DELETE USING (true);

-- SITES
ALTER TABLE sites ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Sites public read" ON sites;
CREATE POLICY "Sites public read" ON sites FOR SELECT USING (true);
CREATE POLICY "Sites admin insert" ON sites FOR INSERT WITH CHECK (true);
CREATE POLICY "Sites admin update" ON sites FOR UPDATE USING (true);
CREATE POLICY "Sites admin delete" ON sites FOR DELETE USING (true);

-- EVENTS
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Events public read" ON events;
CREATE POLICY "Events public read" ON events FOR SELECT USING (true);
CREATE POLICY "Events admin insert" ON events FOR INSERT WITH CHECK (true);
CREATE POLICY "Events admin update" ON events FOR UPDATE USING (true);
CREATE POLICY "Events admin delete" ON events FOR DELETE USING (true);

-- NOTIFICATIONS
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public read notifications" ON notifications;
DROP POLICY IF EXISTS "Anyone can insert notifications" ON notifications;
DROP POLICY IF EXISTS "Anyone can delete notifications" ON notifications;
CREATE POLICY "Notif public read" ON notifications FOR SELECT USING (true);
CREATE POLICY "Notif admin insert" ON notifications FOR INSERT WITH CHECK (true);
CREATE POLICY "Notif admin delete" ON notifications FOR DELETE USING (true);

-- BOOKINGS
ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admin can read all bookings" ON bookings;
CREATE POLICY "Bookings public read" ON bookings FOR SELECT USING (true);
CREATE POLICY "Bookings insert" ON bookings FOR INSERT WITH CHECK (true);
CREATE POLICY "Bookings update" ON bookings FOR UPDATE USING (true);

-- ── ADD MISSING COLUMNS ──────────────────────────────────────
ALTER TABLE hotels ADD COLUMN IF NOT EXISTS name_en text;
ALTER TABLE hotels ADD COLUMN IF NOT EXISTS name_am text;
ALTER TABLE hotels ADD COLUMN IF NOT EXISTS photos text[];
ALTER TABLE hotels ADD COLUMN IF NOT EXISTS price numeric DEFAULT 80;
ALTER TABLE hotels ADD COLUMN IF NOT EXISTS contact text;
ALTER TABLE hotels ADD COLUMN IF NOT EXISTS star_ranking int DEFAULT 4;
ALTER TABLE hotels ADD COLUMN IF NOT EXISTS publish_status text DEFAULT 'published';

ALTER TABLE guides ADD COLUMN IF NOT EXISTS specialty text;
ALTER TABLE guides ADD COLUMN IF NOT EXISTS photo text;
ALTER TABLE guides ADD COLUMN IF NOT EXISTS license_status text DEFAULT 'licensed';
ALTER TABLE guides ADD COLUMN IF NOT EXISTS publish_status text DEFAULT 'published';
ALTER TABLE guides ADD COLUMN IF NOT EXISTS price numeric DEFAULT 30;

ALTER TABLE sites ADD COLUMN IF NOT EXISTS name_en text;
ALTER TABLE sites ADD COLUMN IF NOT EXISTS name_am text;
ALTER TABLE sites ADD COLUMN IF NOT EXISTS info text;
ALTER TABLE sites ADD COLUMN IF NOT EXISTS photo text;

ALTER TABLE events ADD COLUMN IF NOT EXISTS includes_timket boolean DEFAULT false;
ALTER TABLE events ADD COLUMN IF NOT EXISTS category text DEFAULT 'Religious Festival';
ALTER TABLE events ADD COLUMN IF NOT EXISTS photo text;
ALTER TABLE events ADD COLUMN IF NOT EXISTS date text;

ALTER TABLE notifications ADD COLUMN IF NOT EXISTS message text;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS type text DEFAULT 'news';
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS send_to_all boolean DEFAULT true;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS body text;
ALTER TABLE notifications ALTER COLUMN body DROP NOT NULL;

ALTER TABLE bookings ADD COLUMN IF NOT EXISTS item_type text DEFAULT 'hotel';
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS item_name text;
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS customer_name text;
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS customer_contact text;
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS booking_date text;
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS price numeric DEFAULT 0;
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS commission_earned numeric DEFAULT 0;