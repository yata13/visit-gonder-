-- ============================================================
--  ENABLE REALTIME — required for instant popup notifications.
--  Run once in the Supabase SQL Editor. Safe to re-run.
-- ============================================================
DO $$
BEGIN
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE danger_zones;
  EXCEPTION WHEN duplicate_object THEN NULL;
  EXCEPTION WHEN undefined_table THEN NULL; -- danger_zones optional
  END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE hotels;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE sites;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE guides;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE events;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;
END $$;

-- Verify: lists every table realtime now broadcasts
SELECT schemaname, tablename
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime';
