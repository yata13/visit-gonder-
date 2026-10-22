-- ============================================================
--  CHECK: which tables can anyone (no login) read or change?
--  Read-only — changes nothing. Paste into Supabase → SQL Editor → Run.
--
--  Every row is a policy that lets ANYONE through with a bare `true`.
--  ✅ Fine:  …_select_public / …_select_all READ policies on public
--           content (notifications, danger zones, availability,
--           commission rates, reviews).
--  ❌ Fix:   any INSERT / UPDATE / DELETE / ALL row, and any SELECT
--           row on bookings, emergency_requests, users, profiles,
--           deposits … → run migrations/0016_close_legacy_open_policies.sql
-- ============================================================
select tablename,
       policyname,
       cmd as allows,
       case
         when cmd <> 'SELECT' then '❌ anyone can change data'
         when tablename in ('bookings', 'emergency_requests', 'users', 'profiles',
                            'deposits', 'commissions', 'user_roles', 'user_tiers',
                            'premium_requests', 'passport_checkins',
                            'passport_checkpoint_secrets', 'ai_questions')
           then '❌ anyone can read private data'
         else '✅ public content (ok)'
       end as verdict
  from pg_policies
 where schemaname = 'public'
   and (btrim(coalesce(qual, '')) = 'true' or btrim(coalesce(with_check, '')) = 'true')
 order by verdict, tablename, policyname;
