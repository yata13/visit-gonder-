-- ════════════════════════════════════════════════════════════════
--  SOS UPGRADE — paste this whole file into the Supabase SQL editor
--  and press RUN. Safe to run more than once.
-- ════════════════════════════════════════════════════════════════

-- 1) Phone number on user profiles (older sign-ups won't have it; the
--    app asks once on first SOS and saves it here).
ALTER TABLE users ADD COLUMN IF NOT EXISTS phone text;

-- 2) New columns on emergency_requests so we can store the exact GPS
--    point, the user's email, and who sent it.
ALTER TABLE emergency_requests ADD COLUMN IF NOT EXISTS lat      double precision;
ALTER TABLE emergency_requests ADD COLUMN IF NOT EXISTS lng      double precision;
ALTER TABLE emergency_requests ADD COLUMN IF NOT EXISTS email    text;
ALTER TABLE emergency_requests ADD COLUMN IF NOT EXISTS user_id  uuid;

-- 'type' now also accepts: transport / police / ambulance / fire
--  (it's a free-text column, so nothing else to change.)

SELECT 'SOS upgrade applied!' AS result;
