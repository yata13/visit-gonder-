-- ============================================================
-- 0016  Close the old "anyone can do anything" policies
--
-- Why: legacy/supabase_reset.sql (and the old hand-run scripts)
-- created permissive policies such as
--     bookings_select  USING (true)     hotels_update  USING (true)
--     em_select        USING (true)     notifs_insert  WITH CHECK (true)
-- Migrations 0003–0015 ADDED the correct policies but never dropped
-- these. PostgreSQL ORs policies together, so one leftover
-- USING (true) re-opens the table: with only the public app key,
-- anyone could read every booking and SOS request, or edit/delete
-- hotels, sites, posts, notifications and safety zones.
--
-- What this does:
--   1. drops the known legacy policies by name;
--   2. safety net: drops ANY public-schema policy that lets clients
--      write (INSERT/UPDATE/DELETE/ALL) with a bare `true`;
--   3. safety net: drops bare `true` READ policies on tables that
--      hold personal or financial data.
-- The correct policies (…_select_published, …_editor_write,
-- …_select_own…) stay, so the apps and the admin keep working.
--
-- Check before / after with supabase/CHECK_OPEN_POLICIES.sql.
-- Idempotent.
-- ============================================================

-- 1. Known legacy policies ───────────────────────────────────
do $$
declare
  t text;
  p text;
begin
  foreach t in array array['bookings','events','guides','hotels','places','posts','sites'] loop
    foreach p in array array['_select','_insert','_update','_delete'] loop
      if to_regclass('public.' || t) is not null then
        execute format('drop policy if exists %I on public.%I', t || p, t);
      end if;
    end loop;
  end loop;

  -- shortened legacy names
  foreach p in array array['dz_select','dz_insert','dz_update','dz_delete'] loop
    if to_regclass('public.danger_zones') is not null then
      execute format('drop policy if exists %I on public.danger_zones', p);
    end if;
  end loop;
  foreach p in array array['em_select','em_insert','em_update','em_delete'] loop
    if to_regclass('public.emergency_requests') is not null then
      execute format('drop policy if exists %I on public.emergency_requests', p);
    end if;
  end loop;
  foreach p in array array['notifs_select','notifs_insert','notifs_update','notifs_delete'] loop
    if to_regclass('public.notifications') is not null then
      execute format('drop policy if exists %I on public.notifications', p);
    end if;
  end loop;
  foreach p in array array['profiles_select','profiles_insert'] loop
    if to_regclass('public.profiles') is not null then
      execute format('drop policy if exists %I on public.profiles', p);
    end if;
  end loop;
end $$;

-- 2. Safety net: no client write may be allowed by a bare `true` ─
do $$
declare
  r record;
begin
  for r in
    select tablename, policyname
      from pg_policies
     where schemaname = 'public'
       and cmd in ('INSERT', 'UPDATE', 'DELETE', 'ALL')
       and (btrim(coalesce(qual, '')) = 'true'
            or btrim(coalesce(with_check, '')) = 'true')
  loop
    execute format('drop policy if exists %I on public.%I', r.policyname, r.tablename);
    raise notice 'dropped open write policy %.%', r.tablename, r.policyname;
  end loop;
end $$;

-- 3. Safety net: personal / financial tables are never world-readable ─
do $$
declare
  r record;
begin
  for r in
    select tablename, policyname
      from pg_policies
     where schemaname = 'public'
       and cmd = 'SELECT'
       and btrim(coalesce(qual, '')) = 'true'
       and tablename in ('bookings', 'emergency_requests', 'users', 'profiles',
                         'deposits', 'commissions', 'user_roles', 'user_tiers',
                         'premium_requests', 'passport_checkins',
                         'passport_checkpoint_secrets', 'ai_questions')
  loop
    execute format('drop policy if exists %I on public.%I', r.policyname, r.tablename);
    raise notice 'dropped open read policy %.%', r.tablename, r.policyname;
  end loop;
end $$;
