-- ============================================================
-- 0015  Live updates (Supabase Realtime)
--   The app's pop-up notifications and the admin dashboard's live
--   wall only receive events for tables in the `supabase_realtime`
--   publication. Adds every table they watch; skips tables that do
--   not exist and ones already added. Safe to re-run.
--   Row Level Security still applies: each viewer only receives
--   rows they are allowed to read.
-- ============================================================
do $$
declare
  t text;
begin
  foreach t in array array[
    'notifications', 'posts', 'danger_zones', 'bookings',
    'emergency_requests', 'hotels', 'sites', 'guides', 'events',
    'places', 'passport_checkins', 'premium_requests', 'deposits',
    'availability', 'ai_questions', 'users', 'passport_checkpoints'
  ] loop
    if to_regclass('public.' || t) is not null
       and not exists (
         select 1 from pg_publication_tables
         where pubname = 'supabase_realtime'
           and schemaname = 'public' and tablename = t
       ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;

-- Verify: the tables that now send live updates
select tablename as live_table
from pg_publication_tables
where pubname = 'supabase_realtime' and schemaname = 'public'
order by tablename;
