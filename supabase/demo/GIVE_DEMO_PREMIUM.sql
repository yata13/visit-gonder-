-- ============================================================
--  Demo account → Premium (for testing and the proposal demo)
--
--  1. In the app, sign up (or sign in once) with the demo email.
--  2. Paste this whole file into Supabase → SQL Editor → Run.
--  3. In the app: close and reopen it (or pull down on Home).
--     Ask AI and the Fasil Ghebbi virtual tour are now open.
--
--  Needs migration 0014 (user_tiers). Safe to run again.
--  To give another account Premium, change the email below.
-- ============================================================

insert into public.user_tiers (user_id, tier, premium_until, updated_at)
select id, 'premium', null, now()          -- null = no end date
from auth.users
where lower(email) = lower('yata@gmail.com')
on conflict (user_id) do update
  set tier          = 'premium',
      premium_until = null,
      updated_at    = now();

-- Close any open "Request Premium" for this account.
update public.premium_requests
   set status = 'approved', handled_at = now()
 where user_id in (select id from auth.users
                   where lower(email) = lower('yata@gmail.com'))
   and status = 'pending';

-- Check: should show one row with tier = premium.
-- No row? The account does not exist yet — sign up in the app first.
select u.email, t.tier, t.premium_until
from auth.users u
join public.user_tiers t on t.user_id = u.id
where lower(u.email) = lower('yata@gmail.com');
