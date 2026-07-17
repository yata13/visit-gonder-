-- ============================================================
--  VISIT GONDAR — FULL DATABASE RESET
--  Drops all tables and recreates them cleanly
-- ============================================================

-- Drop existing tables
DROP TABLE IF EXISTS bookings CASCADE;
DROP TABLE IF EXISTS notifications CASCADE;
DROP TABLE IF EXISTS events CASCADE;
DROP TABLE IF EXISTS sites CASCADE;
DROP TABLE IF EXISTS guides CASCADE;
DROP TABLE IF EXISTS hotels CASCADE;
DROP TABLE IF EXISTS profiles CASCADE;

-- ── HOTELS ───────────────────────────────────────────────────
CREATE TABLE hotels (
  id             uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  name_en        text,
  name_am        text,
  description    text,
  location       text,
  contact        text,
  photos         text[],
  price          numeric DEFAULT 80,
  star_ranking   int DEFAULT 4,
  publish_status text DEFAULT 'published',
  created_at     timestamptz DEFAULT now()
);

-- ── GUIDES ───────────────────────────────────────────────────
CREATE TABLE guides (
  id             uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  name           text,
  initials       text,
  specialty      text,
  photo          text,
  languages      text[],
  price          numeric DEFAULT 30,
  license_status text DEFAULT 'licensed',
  publish_status text DEFAULT 'published',
  created_at     timestamptz DEFAULT now()
);

-- ── SITES ────────────────────────────────────────────────────
CREATE TABLE sites (
  id          uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  name_en     text,
  name_am     text,
  description text,
  info        text,
  location    text,
  photo       text,
  created_at  timestamptz DEFAULT now()
);

-- ── EVENTS ───────────────────────────────────────────────────
CREATE TABLE events (
  id              uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  name            text,
  date            text,
  description     text,
  photo           text,
  category        text DEFAULT 'Religious Festival',
  includes_timket boolean DEFAULT false,
  created_at      timestamptz DEFAULT now()
);

-- ── NOTIFICATIONS ─────────────────────────────────────────────
CREATE TABLE notifications (
  id          uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  title       text,
  type        text DEFAULT 'news',
  message     text,
  body        text,
  send_to_all boolean DEFAULT true,
  created_at  timestamptz DEFAULT now()
);

-- ── BOOKINGS ──────────────────────────────────────────────────
CREATE TABLE bookings (
  id                uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  item_type         text DEFAULT 'hotel',
  item_name         text,
  customer_name     text,
  customer_contact  text,
  booking_date      text,
  status            text DEFAULT 'pending',
  price             numeric DEFAULT 0,
  commission_earned numeric DEFAULT 0,
  created_at        timestamptz DEFAULT now()
);

-- ── PROFILES ──────────────────────────────────────────────────
CREATE TABLE profiles (
  id         uuid REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
  email      text,
  full_name  text,
  avatar_url text,
  created_at timestamptz DEFAULT now()
);

-- ── RLS POLICIES ──────────────────────────────────────────────
ALTER TABLE hotels        ENABLE ROW LEVEL SECURITY;
ALTER TABLE guides        ENABLE ROW LEVEL SECURITY;
ALTER TABLE sites         ENABLE ROW LEVEL SECURITY;
ALTER TABLE events        ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE bookings      ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles      ENABLE ROW LEVEL SECURITY;

-- Hotels
CREATE POLICY "hotels_select" ON hotels FOR SELECT USING (true);
CREATE POLICY "hotels_insert" ON hotels FOR INSERT WITH CHECK (true);
CREATE POLICY "hotels_update" ON hotels FOR UPDATE USING (true);
CREATE POLICY "hotels_delete" ON hotels FOR DELETE USING (true);

-- Guides
CREATE POLICY "guides_select" ON guides FOR SELECT USING (true);
CREATE POLICY "guides_insert" ON guides FOR INSERT WITH CHECK (true);
CREATE POLICY "guides_update" ON guides FOR UPDATE USING (true);
CREATE POLICY "guides_delete" ON guides FOR DELETE USING (true);

-- Sites
CREATE POLICY "sites_select" ON sites FOR SELECT USING (true);
CREATE POLICY "sites_insert" ON sites FOR INSERT WITH CHECK (true);
CREATE POLICY "sites_update" ON sites FOR UPDATE USING (true);
CREATE POLICY "sites_delete" ON sites FOR DELETE USING (true);

-- Events
CREATE POLICY "events_select" ON events FOR SELECT USING (true);
CREATE POLICY "events_insert" ON events FOR INSERT WITH CHECK (true);
CREATE POLICY "events_update" ON events FOR UPDATE USING (true);
CREATE POLICY "events_delete" ON events FOR DELETE USING (true);

-- Notifications
CREATE POLICY "notifs_select" ON notifications FOR SELECT USING (true);
CREATE POLICY "notifs_insert" ON notifications FOR INSERT WITH CHECK (true);
CREATE POLICY "notifs_update" ON notifications FOR UPDATE USING (true);
CREATE POLICY "notifs_delete" ON notifications FOR DELETE USING (true);

-- Bookings
CREATE POLICY "bookings_select" ON bookings FOR SELECT USING (true);
CREATE POLICY "bookings_insert" ON bookings FOR INSERT WITH CHECK (true);
CREATE POLICY "bookings_update" ON bookings FOR UPDATE USING (true);
CREATE POLICY "bookings_delete" ON bookings FOR DELETE USING (true);

-- Profiles
CREATE POLICY "profiles_select" ON profiles FOR SELECT USING (true);
CREATE POLICY "profiles_insert" ON profiles FOR INSERT WITH CHECK (true);
CREATE POLICY "profiles_update" ON profiles FOR UPDATE USING (auth.uid() = id);

SELECT 'Database reset complete!' AS result;
