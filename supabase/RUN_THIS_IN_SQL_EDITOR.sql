
-- ─────────────────────────  combined_header.sql  ─────────────────────────
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--  VISIT GONDAR â€” ONE-PASTE DATABASE UPGRADE          (2026-07-21)
--
--  HOW TO RUN (one time, ~30 seconds):
--    Supabase Dashboard â†’ SQL Editor â†’ paste this WHOLE file â†’ Run
--
--  Your project was paused and resumed. Checking it live showed the
--  database only has the old hand-run scripts â€” the migrations in
--  supabase/migrations/ (0001â€“0011) were never applied. Because of
--  that, the tourist app's booking button is broken (it calls the
--  create_booking function, which does not exist yet) and the new
--  admin dashboard cannot manage roles, availability, deposits or
--  the Gondar Passport.
--
--  This file is simply, in order:
--    1. sites lat/lng            (from legacy/SITES_COORDS.sql)
--    2. migrations 0001 â†’ 0011   (copied word for word)
--    3. grant the admin role to admin@visitgondar.com / sefedstudio@gmail.com
--       (only if that login already exists)
--    4. a small report so you can see it worked
--
--  Safe to run more than once. The numbered files in
--  supabase/migrations/ stay the source of truth.
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•


-- ─────────────────────────  SITES_COORDS.sql  ─────────────────────────
-- ============================================================
--  SITE MAP PINS â€” adds lat/lng to sites and sets the real
--  coordinates, so the app map shows correct locations.
--  Run once in the Supabase SQL Editor. Safe to re-run.
-- ============================================================
ALTER TABLE sites ADD COLUMN IF NOT EXISTS lat numeric(9,6);
ALTER TABLE sites ADD COLUMN IF NOT EXISTS lng numeric(9,6);

UPDATE sites SET lat = 12.604300, lng = 37.470000 WHERE name_en ILIKE '%fasil ghebbi%';
UPDATE sites SET lat = 12.613600, lng = 37.476200 WHERE name_en ILIKE '%debre berhan%';
UPDATE sites SET lat = 12.606200, lng = 37.464800 WHERE name_en ILIKE '%bath%';
UPDATE sites SET lat = 12.615500, lng = 37.459800 WHERE name_en ILIKE '%kusquam%' OR name_en ILIKE '%kuskuam%';
-- Simien Mountains are ~100km away â€” outside the city map, no pin.

SELECT name_en, lat, lng FROM sites ORDER BY name_en;


-- ─────────────────────────  0001_security_helpers_and_roles.sql  ─────────────────────────
-- ============================================================
-- 0001  Admin role plumbing (never trust a client-writable column)
--
-- Why: the live `users` table has no role column, and even if it did,
-- clients can UPDATE their own row â€” so a self-set role would be a
-- privilege-escalation hole. Roles live in a separate table that has
-- NO client write policy, and are read only through SECURITY DEFINER
-- helpers used by every admin RLS policy.
--
-- Idempotent: safe to run more than once.
-- ============================================================

-- â”€â”€ Role assignments â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
create table if not exists public.user_roles (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  role       text not null check (role in ('admin','editor')),
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id)
);

comment on table public.user_roles is
  'Admin/editor grants. Written by service role only (Supabase dashboard / SECURITY DEFINER RPC). Never client-writable.';

alter table public.user_roles enable row level security;

-- A signed-in user may see their OWN role (so the admin app can gate
-- its UI). Nobody can INSERT/UPDATE/DELETE from a client â€” no such
-- policy exists, so RLS denies all writes for anon/authenticated.
drop policy if exists user_roles_select_own on public.user_roles;
create policy user_roles_select_own
  on public.user_roles for select
  using (user_id = auth.uid());

-- Defense in depth: strip write grants so no stray policy can ever let a
-- client grant itself a role. Assignments are done by the service role.
revoke insert, update, delete on public.user_roles from anon, authenticated;

-- â”€â”€ Helpers (SECURITY DEFINER so RLS on user_roles can't hide the row
--    from the very check that needs it). Fixed search_path for safety.
create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public, pg_temp
stable
as $$
  select exists (
    select 1 from public.user_roles
    where user_id = auth.uid() and role = 'admin'
  );
$$;

create or replace function public.is_editor()
returns boolean
language sql
security definer
set search_path = public, pg_temp
stable
as $$
  select exists (
    select 1 from public.user_roles
    where user_id = auth.uid() and role in ('admin','editor')
  );
$$;

comment on function public.is_admin()  is 'True if the caller has the admin role. Use in admin-only RLS policies.';
comment on function public.is_editor() is 'True if the caller has admin OR editor role. Use in content RLS policies.';

-- Callable by logged-in users (return false for anon). Never let anyone
-- run them as a way to enumerate â€” they only ever look at auth.uid().
revoke all on function public.is_admin()  from public;
revoke all on function public.is_editor() from public;
grant execute on function public.is_admin()  to authenticated, anon;
grant execute on function public.is_editor() to authenticated, anon;


-- ─────────────────────────  0002_commission_rates.sql  ─────────────────────────
-- ============================================================
-- 0002  commission_rates â€” single source of truth for rates
--
-- Why: rates were duplicated in two SQL files (3% vs 10% conflict) and
-- hard-coded in Dart. Canonical rates are hotels 3% / guides 10% (this
-- matches the live app and RUN_THIS_IN_SUPABASE.sql; supabase_update.sql
-- was wrong and is archived under supabase/legacy/). The create_booking
-- RPC (0004) reads the rate from here â€” never from the client.
--
-- Idempotent.
-- ============================================================

create table if not exists public.commission_rates (
  target_type text primary key check (target_type in ('hotel','guide')),
  rate        numeric(4,3) not null check (rate >= 0 and rate <= 1),
  updated_at  timestamptz  not null default now()
);

comment on table public.commission_rates is
  'Commission rate per bookable type. Canonical: hotel=0.03, guide=0.10. Read server-side by create_booking.';

-- Seed canonical rates without clobbering any later admin edits.
insert into public.commission_rates (target_type, rate) values
  ('hotel', 0.030),
  ('guide', 0.100)
on conflict (target_type) do nothing;

-- Keep updated_at honest on any future rate change.
create or replace function public.touch_commission_rates()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_touch_commission_rates on public.commission_rates;
create trigger trg_touch_commission_rates
  before update on public.commission_rates
  for each row execute function public.touch_commission_rates();

-- RLS: rates are not secret (the app shows the platform fee), so public
-- SELECT is fine. Only admins may change them.
alter table public.commission_rates enable row level security;

drop policy if exists commission_rates_select_all on public.commission_rates;
create policy commission_rates_select_all
  on public.commission_rates for select
  using (true);

drop policy if exists commission_rates_admin_write on public.commission_rates;
create policy commission_rates_admin_write
  on public.commission_rates for all
  using (public.is_admin())
  with check (public.is_admin());


-- ─────────────────────────  0003_rls_core_tables.sql  ─────────────────────────
-- ============================================================
-- 0003  Enable RLS + policies on all tables except bookings
--       (bookings + its RPC are handled in 0004).
--
-- Why: today RLS is effectively OFF DB-wide â€” with the public anon key
-- anyone can read all PII and UPDATE/DELETE every table. Enabling RLS
-- flips the default to deny; the policies below re-open exactly what the
-- app legitimately needs and nothing more.
--
-- Column names match the LIVE schema (verified 2026-07-07), which differs
-- from supabase_update.sql.
--
-- Idempotent.
-- ============================================================

-- Helper note: PERMISSIVE policies combine with OR. A public SELECT
-- policy + an "editor manages" FOR ALL policy => SELECT stays public,
-- while INSERT/UPDATE/DELETE require editor/admin.

-- â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
-- users â€” PII. Own row only; admins may read all (Phase 3).
-- Role is NOT stored here, so it can never be self-escalated.
-- â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
alter table public.users enable row level security;

drop policy if exists users_select_own_or_admin on public.users;
create policy users_select_own_or_admin
  on public.users for select
  using (id = auth.uid() or public.is_admin());

drop policy if exists users_insert_own on public.users;
create policy users_insert_own
  on public.users for insert
  with check (id = auth.uid());

drop policy if exists users_update_own on public.users;
create policy users_update_own
  on public.users for update
  using (id = auth.uid())
  with check (id = auth.uid());
-- No DELETE policy: clients cannot delete user rows.

-- â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
-- emergency_requests â€” PII incl. live GPS. Own insert + own read;
-- admins read (read-only audited view in Phase 3). No client edits.
-- â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
alter table public.emergency_requests enable row level security;

drop policy if exists er_insert_own on public.emergency_requests;
create policy er_insert_own
  on public.emergency_requests for insert
  with check (user_id = auth.uid());

drop policy if exists er_select_own_or_admin on public.emergency_requests;
create policy er_select_own_or_admin
  on public.emergency_requests for select
  using (user_id = auth.uid() or public.is_admin());
-- No UPDATE/DELETE policy: emergency logs are immutable to clients.

-- â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
-- Content tables â€” public read; editor/admin write.
-- sites & places have no publish_status yet (added in Phase 2, which
-- will tighten these SELECTs to published-only). hotels & guides do,
-- so drafts are hidden from clients right now.
-- â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

-- sites
alter table public.sites enable row level security;
drop policy if exists sites_select_public on public.sites;
create policy sites_select_public on public.sites for select using (true);
drop policy if exists sites_editor_write on public.sites;
create policy sites_editor_write on public.sites for all
  using (public.is_editor()) with check (public.is_editor());

-- places
alter table public.places enable row level security;
drop policy if exists places_select_public on public.places;
create policy places_select_public on public.places for select using (true);
drop policy if exists places_editor_write on public.places;
create policy places_editor_write on public.places for all
  using (public.is_editor()) with check (public.is_editor());

-- hotels (publish_status exists â†’ hide drafts from clients)
alter table public.hotels enable row level security;
drop policy if exists hotels_select_published on public.hotels;
create policy hotels_select_published on public.hotels for select
  using (coalesce(publish_status,'published') = 'published' or public.is_editor());
drop policy if exists hotels_editor_write on public.hotels;
create policy hotels_editor_write on public.hotels for all
  using (public.is_editor()) with check (public.is_editor());

-- guides (publish_status exists â†’ hide drafts from clients)
alter table public.guides enable row level security;
drop policy if exists guides_select_published on public.guides;
create policy guides_select_published on public.guides for select
  using (coalesce(publish_status,'published') = 'published' or public.is_editor());
drop policy if exists guides_editor_write on public.guides;
create policy guides_editor_write on public.guides for all
  using (public.is_editor()) with check (public.is_editor());

-- events
alter table public.events enable row level security;
drop policy if exists events_select_public on public.events;
create policy events_select_public on public.events for select using (true);
drop policy if exists events_editor_write on public.events;
create policy events_editor_write on public.events for all
  using (public.is_editor()) with check (public.is_editor());

-- posts
alter table public.posts enable row level security;
drop policy if exists posts_select_public on public.posts;
create policy posts_select_public on public.posts for select using (true);
drop policy if exists posts_editor_write on public.posts;
create policy posts_editor_write on public.posts for all
  using (public.is_editor()) with check (public.is_editor());

-- notifications (broadcast to all; only editors compose)
alter table public.notifications enable row level security;
drop policy if exists notifications_select_public on public.notifications;
create policy notifications_select_public on public.notifications for select using (true);
drop policy if exists notifications_editor_write on public.notifications;
create policy notifications_editor_write on public.notifications for all
  using (public.is_editor()) with check (public.is_editor());

-- danger_zones (safety alerts; only editors manage)
alter table public.danger_zones enable row level security;
drop policy if exists danger_zones_select_public on public.danger_zones;
create policy danger_zones_select_public on public.danger_zones for select using (true);
drop policy if exists danger_zones_editor_write on public.danger_zones;
create policy danger_zones_editor_write on public.danger_zones for all
  using (public.is_editor()) with check (public.is_editor());

-- â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
-- reviews â€” exists but unused by the client today. Lock it: public
-- read, editor/admin write (revisit if a user-review flow is built).
-- â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
alter table public.reviews enable row level security;
drop policy if exists reviews_select_public on public.reviews;
create policy reviews_select_public on public.reviews for select using (true);
drop policy if exists reviews_editor_write on public.reviews;
create policy reviews_editor_write on public.reviews for all
  using (public.is_editor()) with check (public.is_editor());

-- â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
-- commissions â€” financial ledger. RLS ON, ZERO policies => no client
-- (anon/authenticated) access whatsoever. Written only by the
-- SECURITY DEFINER create_booking RPC; read only by service role / admin
-- tooling that bypasses RLS.
-- â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
create table if not exists public.commissions (
  id                uuid primary key default gen_random_uuid(),
  booking_id        uuid not null references public.bookings(id) on delete cascade,
  target_type       text not null check (target_type in ('hotel','guide')),
  target_id         uuid,
  total_amount      numeric(10,2) not null,
  commission_rate   numeric(4,3)  not null,
  commission_amount numeric(10,2) not null,
  status            text not null default 'pending'
                      check (status in ('pending','paid','refunded')),
  created_at        timestamptz not null default now()
);

comment on table public.commissions is
  'Immutable-to-clients commission ledger. RLS enabled with no policies => service role / SECURITY DEFINER only.';

alter table public.commissions enable row level security;
-- Intentionally NO policies. Also strip grants so clients get a hard
-- "permission denied" rather than a silent empty result.
revoke all on public.commissions from anon, authenticated;


-- ─────────────────────────  0004_bookings_server_side.sql  ─────────────────────────
-- ============================================================
-- 0004  Server-side bookings: create_booking RPC + lock the table
--
-- Why: today the client computes price & commission and INSERTs them
-- directly, and anon can UPDATE/DELETE any booking. This makes price and
-- commission server-authoritative (read from hotels/guides + commission_rates),
-- enforces validation, and removes all direct client writes â€” bookings are
-- created only via create_booking() and cancelled only via cancel_my_booking().
--
-- Column names match the LIVE schema. Idempotent.
-- ============================================================

-- â”€â”€ Columns needed for server-side pricing / ownership â”€â”€â”€â”€â”€â”€
-- (booking_date already exists and is kept in sync with check_in for the
--  existing "My Bookings" UI.)
alter table public.bookings add column if not exists user_id   uuid references auth.users(id);
alter table public.bookings add column if not exists item_id   uuid;
alter table public.bookings add column if not exists check_in  date;
alter table public.bookings add column if not exists check_out date;
alter table public.bookings add column if not exists guests    int default 1;

create index if not exists bookings_user_id_idx    on public.bookings(user_id);
create index if not exists bookings_user_email_idx on public.bookings(user_email);

-- â”€â”€ RLS: read your own; no client writes at all â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
alter table public.bookings enable row level security;

drop policy if exists bookings_select_own on public.bookings;
create policy bookings_select_own
  on public.bookings for select
  using (
    user_id = auth.uid()
    or (user_email is not null and user_email = (auth.jwt() ->> 'email'))
    or public.is_admin()
  );
-- No INSERT/UPDATE/DELETE policies: all mutations go through the
-- SECURITY DEFINER functions below (which run as the table owner and
-- therefore bypass RLS). Belt-and-suspenders: also strip DML grants so a
-- future stray policy can't accidentally re-open direct writes.
revoke insert, update, delete on public.bookings from anon, authenticated;

-- â”€â”€ create_booking : the only way a client makes a booking â”€â”€
create or replace function public.create_booking(
  p_item_type        text,          -- 'hotel' | 'guide'
  p_item_id          uuid,          -- which hotel/guide
  p_check_in         date,
  p_check_out        date,
  p_guests           int,
  p_customer_name    text,
  p_customer_contact text
)
returns public.bookings
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid   uuid := auth.uid();
  v_email text := auth.jwt() ->> 'email';
  v_price numeric(10,2);
  v_name  text;
  v_pub   text;
  v_units int;
  v_rate  numeric(4,3);
  v_total numeric(10,2);
  v_comm  numeric(10,2);
  v_row   public.bookings;
begin
  if v_uid is null then
    raise exception 'You must be signed in to book.' using errcode = '28000';
  end if;

  -- â”€â”€ validation â”€â”€
  if p_item_type not in ('hotel','guide') then
    raise exception 'Invalid booking type.' using errcode = '22023';
  end if;
  if p_check_in is null or p_check_out is null then
    raise exception 'Both dates are required.' using errcode = '22023';
  end if;
  if p_check_in < current_date then
    raise exception 'Start date cannot be in the past.' using errcode = '22023';
  end if;
  if p_check_out <= p_check_in then
    raise exception 'End date must be after the start date.' using errcode = '22023';
  end if;
  if coalesce(p_guests,1) < 1 or coalesce(p_guests,1) > 20 then
    raise exception 'Guests must be between 1 and 20.' using errcode = '22023';
  end if;
  if coalesce(btrim(p_customer_name),'') = ''
     or coalesce(btrim(p_customer_contact),'') = '' then
    raise exception 'Name and contact are required.' using errcode = '22023';
  end if;

  -- â”€â”€ server-side price + published check (never trust the client) â”€â”€
  if p_item_type = 'hotel' then
    select price, name_en, coalesce(publish_status,'published')
      into v_price, v_name, v_pub
      from public.hotels where id = p_item_id;
  else
    select price, name, coalesce(publish_status,'published')
      into v_price, v_name, v_pub
      from public.guides where id = p_item_id;
  end if;

  if not found or v_price is null then
    raise exception 'That % is no longer available.', p_item_type using errcode = 'P0002';
  end if;
  if v_pub <> 'published' then
    raise exception 'That % is not open for booking.', p_item_type using errcode = 'P0002';
  end if;

  v_units := greatest((p_check_out - p_check_in), 1);   -- nights (hotel) / days (guide)
  v_total := round(v_price * v_units * coalesce(p_guests,1), 2);

  select rate into v_rate from public.commission_rates where target_type = p_item_type;
  v_rate := coalesce(v_rate, case when p_item_type = 'guide' then 0.100 else 0.030 end);
  v_comm := round(v_total * v_rate, 2);

  insert into public.bookings (
    item_type, item_id, item_name,
    customer_name, customer_contact,
    check_in, check_out, booking_date, guests,
    status, price, total_price,
    commission_rate, commission_amount, commission_earned,
    user_id, user_email
  ) values (
    p_item_type, p_item_id, v_name,
    btrim(p_customer_name), btrim(p_customer_contact),
    p_check_in, p_check_out, p_check_in, coalesce(p_guests,1),
    'pending', v_total, v_total,
    v_rate, v_comm, v_comm,
    v_uid, v_email
  )
  returning * into v_row;

  -- financial ledger (clients can never read or write this table)
  insert into public.commissions (
    booking_id, target_type, target_id,
    total_amount, commission_rate, commission_amount
  ) values (
    v_row.id, p_item_type, p_item_id, v_total, v_rate, v_comm
  );

  return v_row;
end;
$$;

comment on function public.create_booking(text,uuid,date,date,int,text,text) is
  'The only client path to create a booking. Prices from hotels/guides, rate from commission_rates, all server-side.';

revoke all on function public.create_booking(text,uuid,date,date,int,text,text) from public, anon;
grant execute on function public.create_booking(text,uuid,date,date,int,text,text) to authenticated;

-- â”€â”€ cancel_my_booking : a user cancels their OWN pending booking â”€â”€
create or replace function public.cancel_my_booking(p_booking_id uuid)
returns public.bookings
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid   uuid := auth.uid();
  v_email text := auth.jwt() ->> 'email';
  v_row   public.bookings;
begin
  if v_uid is null then
    raise exception 'You must be signed in.' using errcode = '28000';
  end if;

  select * into v_row from public.bookings
   where id = p_booking_id
     and (user_id = v_uid
          or (user_email is not null and user_email = v_email));
  if not found then
    raise exception 'Booking not found.' using errcode = 'P0002';
  end if;
  if v_row.status <> 'pending' then
    raise exception 'Only a pending booking can be cancelled.' using errcode = '22023';
  end if;

  update public.bookings set status = 'cancelled'
   where id = p_booking_id
   returning * into v_row;
  return v_row;
end;
$$;

comment on function public.cancel_my_booking(uuid) is
  'Lets a signed-in user cancel their own pending booking (replaces the old direct UPDATE).';

revoke all on function public.cancel_my_booking(uuid) from public, anon;
grant execute on function public.cancel_my_booking(uuid) to authenticated;


-- ─────────────────────────  0005_storage_buckets.sql  ─────────────────────────
-- ============================================================
-- 0005  Storage buckets: public read, editor/admin write only
--
-- Why: listing images must be world-readable (the app shows them without
-- auth) but no anonymous or ordinary-user writes. Admin/editor image
-- upload (Phase 3) writes here.
--
-- Buckets match lib/core/constants/app_constants.dart.
-- Idempotent.
-- ============================================================

insert into storage.buckets (id, name, public)
values
  ('site-images',  'site-images',  true),
  ('hotel-images', 'hotel-images', true),
  ('guide-images', 'guide-images', true)
on conflict (id) do update set public = excluded.public;

-- Public read for these buckets.
drop policy if exists listing_images_public_read on storage.objects;
create policy listing_images_public_read
  on storage.objects for select
  using (bucket_id in ('site-images','hotel-images','guide-images'));

-- Only editors/admins may upload/replace/delete listing images.
drop policy if exists listing_images_editor_insert on storage.objects;
create policy listing_images_editor_insert
  on storage.objects for insert
  with check (
    bucket_id in ('site-images','hotel-images','guide-images')
    and public.is_editor()
  );

drop policy if exists listing_images_editor_update on storage.objects;
create policy listing_images_editor_update
  on storage.objects for update
  using (
    bucket_id in ('site-images','hotel-images','guide-images')
    and public.is_editor()
  )
  with check (
    bucket_id in ('site-images','hotel-images','guide-images')
    and public.is_editor()
  );

drop policy if exists listing_images_editor_delete on storage.objects;
create policy listing_images_editor_delete
  on storage.objects for delete
  using (
    bucket_id in ('site-images','hotel-images','guide-images')
    and public.is_editor()
  );

-- NOTE: run supabase/audit/00_inspect_current_state.sql (and the storage
-- section of the exit-check) to confirm no OTHER bucket allows anon writes.


-- ─────────────────────────  0006_publish_status_all_content.sql  ─────────────────────────
-- ============================================================
-- 0006  publish_status on ALL content tables (Phase 2)
--
-- Why: the admin needs a draft â†’ pending â†’ published workflow on
-- every listing type. hotels & guides already have publish_status;
-- sites, places, events and posts do not. New columns default to
-- 'published' so every row the tourist app shows today stays visible.
-- SELECT policies are tightened the same way hotels/guides already
-- work: the public sees only published rows, editors see everything.
--
-- Allowed values (enforced by the admin app, kept as text for
-- compatibility with the existing hotels/guides columns):
--   'draft' | 'pending' | 'published'
--
-- Idempotent: safe to run more than once.
-- ============================================================

alter table public.sites  add column if not exists publish_status text default 'published';
alter table public.places add column if not exists publish_status text default 'published';
alter table public.events add column if not exists publish_status text default 'published';
alter table public.posts  add column if not exists publish_status text default 'published';

-- Normalise any NULLs so the policies below behave predictably.
update public.sites  set publish_status = 'published' where publish_status is null;
update public.places set publish_status = 'published' where publish_status is null;
update public.events set publish_status = 'published' where publish_status is null;
update public.posts  set publish_status = 'published' where publish_status is null;

comment on column public.sites.publish_status  is 'draft | pending | published â€” only published rows are shown to the public.';
comment on column public.places.publish_status is 'draft | pending | published â€” only published rows are shown to the public.';
comment on column public.events.publish_status is 'draft | pending | published â€” only published rows are shown to the public.';
comment on column public.posts.publish_status  is 'draft | pending | published â€” only published rows are shown to the public.';

-- â”€â”€ Tighten public SELECT to published-only (editors see all) â”€â”€
-- sites
drop policy if exists sites_select_public    on public.sites;
drop policy if exists sites_select_published on public.sites;
create policy sites_select_published
  on public.sites for select
  using (coalesce(publish_status,'published') = 'published' or public.is_editor());

-- places
drop policy if exists places_select_public    on public.places;
drop policy if exists places_select_published on public.places;
create policy places_select_published
  on public.places for select
  using (coalesce(publish_status,'published') = 'published' or public.is_editor());

-- events
drop policy if exists events_select_public    on public.events;
drop policy if exists events_select_published on public.events;
create policy events_select_published
  on public.events for select
  using (coalesce(publish_status,'published') = 'published' or public.is_editor());

-- posts
drop policy if exists posts_select_public    on public.posts;
drop policy if exists posts_select_published on public.posts;
create policy posts_select_published
  on public.posts for select
  using (coalesce(publish_status,'published') = 'published' or public.is_editor());


-- ─────────────────────────  0007_business_owner_links.sql  ─────────────────────────
-- ============================================================
-- 0007  Vendor/owner links on bookable businesses
--
-- Why: hotels and guides are the platform's businesses/vendors.
-- The admin needs to see who owns each listing and how to reach
-- them. hotels already have a contact column; guides do not.
-- owner_id links a listing to the auth account of the business
-- owner (nullable â€” many listings are city-managed).
--
-- Note: an owner self-service portal (owners editing their own
-- listing) is a later phase; no owner RLS policies are added here.
--
-- Idempotent.
-- ============================================================

alter table public.hotels add column if not exists owner_id uuid references auth.users(id) on delete set null;
alter table public.guides add column if not exists owner_id uuid references auth.users(id) on delete set null;
alter table public.guides add column if not exists contact  text;

comment on column public.hotels.owner_id is 'Auth user who owns/manages this hotel. NULL = city-managed.';
comment on column public.guides.owner_id is 'Auth user who owns this guide profile. NULL = city-managed.';
comment on column public.guides.contact  is 'Phone / WhatsApp / email shown to the admin (and later to tourists).';

create index if not exists hotels_owner_id_idx on public.hotels(owner_id);
create index if not exists guides_owner_id_idx on public.guides(owner_id);


-- ─────────────────────────  0008_availability.sql  ─────────────────────────
-- ============================================================
-- 0008  availability â€” per-day capacity for hotels & guides
--
-- Why: the platform has no availability model. This is the simple
-- v1: one row per business per day. capacity = how many bookings
-- can be taken that day (rooms for a hotel, tours for a guide),
-- booked = how many are taken, is_closed = hard off switch.
-- Days with no row mean "use the business default" (app decides).
--
-- Public read (the tourist app must show availability before
-- booking); only editors/admins write. booked will later be kept
-- in sync by the booking RPC (Phase: Chapa deposits go live).
--
-- Idempotent.
-- ============================================================

create table if not exists public.availability (
  id            uuid primary key default gen_random_uuid(),
  business_type text not null check (business_type in ('hotel','guide')),
  business_id   uuid not null,
  day           date not null,
  capacity      int  not null default 1 check (capacity >= 0),
  booked        int  not null default 0 check (booked >= 0),
  is_closed     boolean not null default false,
  note          text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (business_type, business_id, day)
);

comment on table public.availability is
  'Per-day slots for a hotel or guide. No row for a day = business default. Managed by the admin dashboard.';

create index if not exists availability_business_idx
  on public.availability(business_type, business_id, day);

-- Keep updated_at honest.
create or replace function public.touch_availability()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_touch_availability on public.availability;
create trigger trg_touch_availability
  before update on public.availability
  for each row execute function public.touch_availability();

-- â”€â”€ RLS: public read, editor/admin write â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
alter table public.availability enable row level security;

drop policy if exists availability_select_public on public.availability;
create policy availability_select_public
  on public.availability for select
  using (true);

drop policy if exists availability_editor_write on public.availability;
create policy availability_editor_write
  on public.availability for all
  using (public.is_editor())
  with check (public.is_editor());


-- ─────────────────────────  0009_chapa_deposits.sql  ─────────────────────────
-- ============================================================
-- 0009  Chapa deposits â€” payment tracking on bookings
--
-- Why: the project is moving from pure commission to Chapa-based
-- deposits. A tourist pays a deposit through Chapa to confirm a
-- booking. This adds:
--   * bookings.payment_status + bookings.deposit_amount
--   * a deposits table: one row per Chapa transaction
--
-- Writes happen ONLY server-side (a Chapa webhook Edge Function
-- using the service role, or the SQL editor). Clients can read
-- their own deposit rows; admins can read all. The admin
-- dashboard is read-only over this data in v1.
--
-- Idempotent.
-- ============================================================

-- â”€â”€ bookings: payment fields â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
alter table public.bookings add column if not exists payment_status text not null default 'unpaid';
alter table public.bookings add column if not exists deposit_amount numeric(10,2);

comment on column public.bookings.payment_status is
  'unpaid | deposit_pending | deposit_paid | refunded â€” set by the Chapa webhook, never by clients.';
comment on column public.bookings.deposit_amount is
  'Deposit required to confirm this booking, in ETB.';

create index if not exists bookings_payment_status_idx on public.bookings(payment_status);

-- â”€â”€ deposits: one row per Chapa transaction â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
create table if not exists public.deposits (
  id           uuid primary key default gen_random_uuid(),
  booking_id   uuid not null references public.bookings(id) on delete cascade,
  amount       numeric(10,2) not null check (amount >= 0),
  currency     text not null default 'ETB',
  chapa_tx_ref text unique,
  status       text not null default 'initiated'
                 check (status in ('initiated','pending','success','failed','refunded')),
  checkout_url text,
  raw          jsonb,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

comment on table public.deposits is
  'Chapa deposit transactions. Written only by the payment webhook (service role). chapa_tx_ref is the tx_ref sent to Chapa.';

create index if not exists deposits_booking_id_idx on public.deposits(booking_id);
create index if not exists deposits_status_idx     on public.deposits(status);

create or replace function public.touch_deposits()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_touch_deposits on public.deposits;
create trigger trg_touch_deposits
  before update on public.deposits
  for each row execute function public.touch_deposits();

-- â”€â”€ RLS: read own (via the booking) or admin; NO client writes â”€â”€
alter table public.deposits enable row level security;

drop policy if exists deposits_select_own_or_admin on public.deposits;
create policy deposits_select_own_or_admin
  on public.deposits for select
  using (
    public.is_admin()
    or exists (
      select 1 from public.bookings b
      where b.id = deposits.booking_id
        and (b.user_id = auth.uid()
             or (b.user_email is not null and b.user_email = (auth.jwt() ->> 'email')))
    )
  );

-- No INSERT/UPDATE/DELETE policies, and grants stripped: only the
-- service role (webhook) can write.
revoke insert, update, delete on public.deposits from anon, authenticated;


-- ─────────────────────────  0010_gondar_passport.sql  ─────────────────────────
-- ============================================================
-- 0010  Gondar Passport â€” check-in points, stories, trivia
--
-- The Gondar Passport is a gamified city tour: tourists scan a QR
-- code (or use GPS) at heritage checkpoints, collect points, and
-- unlock stories + trivia.
--
-- Tables:
--   passport_checkpoints         public content (no secret inside)
--   passport_checkpoint_secrets  the QR token â€” editors/admins only
--   passport_stories             unlocked at a checkpoint
--   passport_trivia              quiz questions per checkpoint
--   passport_checkins            one row per user per checkpoint
--
-- The QR token lives in a separate secrets table so the public
-- checkpoint list can stay a plain `select *` without leaking the
-- token (anyone holding the token could fake a visit). Tourists
-- check in ONLY through the passport_check_in() RPC below.
--
-- Known v1 limitation: trivia correct_index is client-readable, so
-- a determined user can cheat the quiz. Acceptable for now.
--
-- Idempotent.
-- ============================================================

-- â”€â”€ Checkpoints (public content) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
create table if not exists public.passport_checkpoints (
  id             uuid primary key default gen_random_uuid(),
  name_en        text not null,
  name_am        text,
  description_en text,
  description_am text,
  photo          text,
  lat            numeric(9,6) not null,
  lng            numeric(9,6) not null,
  points         int  not null default 10 check (points >= 0),
  sort_order     int  not null default 0,
  is_active      boolean not null default true,
  created_at     timestamptz not null default now()
);

comment on table public.passport_checkpoints is
  'Gondar Passport check-in points. QR tokens live in passport_checkpoint_secrets, never here.';

-- â”€â”€ QR secrets (editors/admins only) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
create table if not exists public.passport_checkpoint_secrets (
  checkpoint_id uuid primary key references public.passport_checkpoints(id) on delete cascade,
  qr_token      text not null unique default replace(gen_random_uuid()::text, '-', ''),
  rotated_at    timestamptz not null default now()
);

comment on table public.passport_checkpoint_secrets is
  'QR token per checkpoint. Editors read it to print QR codes; tourists never see it (they scan it).';

-- Every checkpoint automatically gets a token.
create or replace function public.create_checkpoint_secret()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.passport_checkpoint_secrets (checkpoint_id)
  values (new.id)
  on conflict (checkpoint_id) do nothing;
  return new;
end;
$$;

drop trigger if exists trg_checkpoint_secret on public.passport_checkpoints;
create trigger trg_checkpoint_secret
  after insert on public.passport_checkpoints
  for each row execute function public.create_checkpoint_secret();

-- Backfill secrets for any checkpoint created before this trigger.
insert into public.passport_checkpoint_secrets (checkpoint_id)
select id from public.passport_checkpoints
on conflict (checkpoint_id) do nothing;

-- â”€â”€ Stories â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
create table if not exists public.passport_stories (
  id            uuid primary key default gen_random_uuid(),
  checkpoint_id uuid not null references public.passport_checkpoints(id) on delete cascade,
  title_en      text not null,
  title_am      text,
  body_en       text,
  body_am       text,
  media_url     text,
  sort_order    int not null default 0,
  is_active     boolean not null default true,
  created_at    timestamptz not null default now()
);

create index if not exists passport_stories_checkpoint_idx
  on public.passport_stories(checkpoint_id);

-- â”€â”€ Trivia â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
create table if not exists public.passport_trivia (
  id            uuid primary key default gen_random_uuid(),
  checkpoint_id uuid not null references public.passport_checkpoints(id) on delete cascade,
  question_en   text not null,
  question_am   text,
  options_en    text[] not null default '{}',
  options_am    text[] not null default '{}',
  correct_index int  not null default 0 check (correct_index >= 0),
  points        int  not null default 5 check (points >= 0),
  is_active     boolean not null default true,
  created_at    timestamptz not null default now()
);

create index if not exists passport_trivia_checkpoint_idx
  on public.passport_trivia(checkpoint_id);

-- â”€â”€ Check-ins â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
create table if not exists public.passport_checkins (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  checkpoint_id uuid not null references public.passport_checkpoints(id) on delete cascade,
  method        text not null default 'qr' check (method in ('qr','gps')),
  checked_in_at timestamptz not null default now(),
  unique (user_id, checkpoint_id)
);

create index if not exists passport_checkins_user_idx
  on public.passport_checkins(user_id);
create index if not exists passport_checkins_checkpoint_idx
  on public.passport_checkins(checkpoint_id);

-- â”€â”€ RLS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
alter table public.passport_checkpoints        enable row level security;
alter table public.passport_checkpoint_secrets enable row level security;
alter table public.passport_stories            enable row level security;
alter table public.passport_trivia             enable row level security;
alter table public.passport_checkins           enable row level security;

-- Checkpoints: public sees active; editors see + manage all.
drop policy if exists passport_checkpoints_select on public.passport_checkpoints;
create policy passport_checkpoints_select
  on public.passport_checkpoints for select
  using (is_active or public.is_editor());

drop policy if exists passport_checkpoints_editor_write on public.passport_checkpoints;
create policy passport_checkpoints_editor_write
  on public.passport_checkpoints for all
  using (public.is_editor()) with check (public.is_editor());

-- Secrets: editors read; nobody writes from a client (trigger + RPC only).
drop policy if exists passport_secrets_editor_select on public.passport_checkpoint_secrets;
create policy passport_secrets_editor_select
  on public.passport_checkpoint_secrets for select
  using (public.is_editor());

revoke insert, update, delete on public.passport_checkpoint_secrets from anon, authenticated;

-- Stories + trivia: public sees active; editors manage.
drop policy if exists passport_stories_select on public.passport_stories;
create policy passport_stories_select
  on public.passport_stories for select
  using (is_active or public.is_editor());

drop policy if exists passport_stories_editor_write on public.passport_stories;
create policy passport_stories_editor_write
  on public.passport_stories for all
  using (public.is_editor()) with check (public.is_editor());

drop policy if exists passport_trivia_select on public.passport_trivia;
create policy passport_trivia_select
  on public.passport_trivia for select
  using (is_active or public.is_editor());

drop policy if exists passport_trivia_editor_write on public.passport_trivia;
create policy passport_trivia_editor_write
  on public.passport_trivia for all
  using (public.is_editor()) with check (public.is_editor());

-- Check-ins: read your own (admins read all). Writes ONLY via RPC.
drop policy if exists passport_checkins_select_own_or_admin on public.passport_checkins;
create policy passport_checkins_select_own_or_admin
  on public.passport_checkins for select
  using (user_id = auth.uid() or public.is_admin());

revoke insert, update, delete on public.passport_checkins from anon, authenticated;

-- â”€â”€ passport_check_in : the only way a tourist checks in â”€â”€â”€â”€â”€
create or replace function public.passport_check_in(p_qr_token text)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid        uuid := auth.uid();
  v_checkpoint public.passport_checkpoints;
  v_rows       int := 0;
begin
  if v_uid is null then
    raise exception 'You must be signed in to check in.' using errcode = '28000';
  end if;

  select c.* into v_checkpoint
    from public.passport_checkpoint_secrets s
    join public.passport_checkpoints c on c.id = s.checkpoint_id
   where s.qr_token = p_qr_token
     and c.is_active;

  if not found then
    raise exception 'Invalid or inactive checkpoint code.' using errcode = 'P0002';
  end if;

  insert into public.passport_checkins (user_id, checkpoint_id, method)
  values (v_uid, v_checkpoint.id, 'qr')
  on conflict (user_id, checkpoint_id) do nothing;

  get diagnostics v_rows = row_count;

  return jsonb_build_object(
    'checkpoint_id',   v_checkpoint.id,
    'name_en',         v_checkpoint.name_en,
    'name_am',         v_checkpoint.name_am,
    'points',          case when v_rows > 0 then v_checkpoint.points else 0 end,
    'already_checked', v_rows = 0
  );
end;
$$;

comment on function public.passport_check_in(text) is
  'Tourist scans a checkpoint QR code. Validates the token server-side and records the check-in once.';

revoke all on function public.passport_check_in(text) from public, anon;
grant execute on function public.passport_check_in(text) to authenticated;

-- â”€â”€ admin_rotate_checkpoint_qr : editors invalidate a leaked QR â”€â”€
create or replace function public.admin_rotate_checkpoint_qr(p_checkpoint_id uuid)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_token text;
begin
  if not public.is_editor() then
    raise exception 'Editors/admins only.' using errcode = '42501';
  end if;

  update public.passport_checkpoint_secrets
     set qr_token  = replace(gen_random_uuid()::text, '-', ''),
         rotated_at = now()
   where checkpoint_id = p_checkpoint_id
   returning qr_token into v_token;

  if not found then
    raise exception 'Checkpoint not found.' using errcode = 'P0002';
  end if;

  return v_token;
end;
$$;

comment on function public.admin_rotate_checkpoint_qr(uuid) is
  'Generates a fresh QR token for a checkpoint (use if a token leaks). Editors/admins only.';

revoke all on function public.admin_rotate_checkpoint_qr(uuid) from public, anon;
grant execute on function public.admin_rotate_checkpoint_qr(uuid) to authenticated;


-- ─────────────────────────  0011_admin_role_management.sql  ─────────────────────────
-- ============================================================
-- 0011  Users & roles for the admin dashboard
--
-- Why: the admin needs to (a) list all users with their email,
-- (b) see everyone's role, (c) grant/revoke roles â€” all with the
-- anon key, which today is impossible: user_roles only shows your
-- own row and is never client-writable (by design, see 0001).
--
-- This keeps that design: roles still live in user_roles, writes
-- still never come from a plain client â€” they go through
-- SECURITY DEFINER RPCs that check is_admin() themselves.
--
-- Also: public.users gets an email column, auto-filled on signup
-- by a trigger on auth.users (the app's client-side upsert stays
-- as a fallback but is no longer the only path).
--
-- Idempotent.
-- ============================================================

-- â”€â”€ users.email + signup trigger â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
alter table public.users add column if not exists email      text;
alter table public.users add column if not exists created_at timestamptz default now();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.users (id, email, full_name)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data ->> 'full_name', '')
  )
  on conflict (id) do update
    set email = excluded.email;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Backfill: profile rows for existing auth users + missing emails.
insert into public.users (id, email, full_name)
select au.id, au.email, coalesce(au.raw_user_meta_data ->> 'full_name', '')
from auth.users au
on conflict (id) do nothing;

update public.users u
   set email = au.email
  from auth.users au
 where au.id = u.id
   and u.email is null;

-- â”€â”€ Admins can list every role â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
drop policy if exists user_roles_select_admin on public.user_roles;
create policy user_roles_select_admin
  on public.user_roles for select
  using (public.is_admin());

-- â”€â”€ admin_grant_role / admin_revoke_role â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
create or replace function public.admin_grant_role(p_user_id uuid, p_role text)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_admin() then
    raise exception 'Admins only.' using errcode = '42501';
  end if;
  if p_role not in ('admin','editor') then
    raise exception 'Role must be admin or editor.' using errcode = '22023';
  end if;
  if not exists (select 1 from auth.users where id = p_user_id) then
    raise exception 'User not found.' using errcode = 'P0002';
  end if;

  insert into public.user_roles (user_id, role, created_by)
  values (p_user_id, p_role, auth.uid())
  on conflict (user_id) do update
    set role = excluded.role,
        created_by = excluded.created_by;
end;
$$;

create or replace function public.admin_revoke_role(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_admin() then
    raise exception 'Admins only.' using errcode = '42501';
  end if;
  if p_user_id = auth.uid() then
    raise exception 'You cannot remove your own admin role.' using errcode = '22023';
  end if;

  delete from public.user_roles where user_id = p_user_id;
end;
$$;

comment on function public.admin_grant_role(uuid, text) is
  'Admin grants/changes a user''s role (admin or editor). The only client path for role writes.';
comment on function public.admin_revoke_role(uuid) is
  'Admin removes a user''s role. Cannot remove your own admin role (no locking yourself out).';

revoke all on function public.admin_grant_role(uuid, text) from public, anon;
revoke all on function public.admin_revoke_role(uuid)      from public, anon;
grant execute on function public.admin_grant_role(uuid, text) to authenticated;
grant execute on function public.admin_revoke_role(uuid)      to authenticated;


-- ─────────────────────────  0012_admin_status_rpcs.sql  ─────────────────────────
-- ============================================================
-- 0012  Admin actions the old Flutter admin did with open RLS
--
-- Why: 0003/0004 made bookings and emergency_requests immutable to
-- clients (all writes revoked). The admin dashboard still needs the
-- old admin's actions: approve/reject a booking, move an SOS request
-- through pending â†’ responding â†’ resolved, and clean up old requests.
-- These SECURITY DEFINER functions are the controlled path â€” they
-- check is_editor() themselves, so RLS stays locked for everyone else.
--
-- Idempotent.
-- ============================================================

-- â”€â”€ Booking status (old admin: APPROVE / REJECT buttons) â”€â”€â”€â”€â”€
create or replace function public.admin_set_booking_status(
  p_booking_id uuid,
  p_status     text
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_editor() then
    raise exception 'Editors/admins only.' using errcode = '42501';
  end if;
  if p_status not in ('pending','approved','rejected','confirmed','cancelled') then
    raise exception 'Invalid booking status.' using errcode = '22023';
  end if;

  update public.bookings set status = p_status where id = p_booking_id;
  if not found then
    raise exception 'Booking not found.' using errcode = 'P0002';
  end if;
end;
$$;

comment on function public.admin_set_booking_status(uuid, text) is
  'Admin/editor approves, rejects, confirms or cancels a booking. The only admin write path to bookings.';

-- â”€â”€ Emergency status (pending â†’ responding â†’ resolved) â”€â”€â”€â”€â”€â”€â”€
create or replace function public.admin_set_emergency_status(
  p_id     uuid,
  p_status text
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_editor() then
    raise exception 'Editors/admins only.' using errcode = '42501';
  end if;
  if p_status not in ('pending','responding','resolved') then
    raise exception 'Invalid emergency status.' using errcode = '22023';
  end if;

  update public.emergency_requests set status = p_status where id = p_id;
  if not found then
    raise exception 'Request not found.' using errcode = 'P0002';
  end if;
end;
$$;

comment on function public.admin_set_emergency_status(uuid, text) is
  'Admin/editor updates an SOS request status. Tourists still cannot touch these rows.';

-- â”€â”€ Emergency delete (old admin could remove handled requests) â”€â”€
create or replace function public.admin_delete_emergency(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_editor() then
    raise exception 'Editors/admins only.' using errcode = '42501';
  end if;
  delete from public.emergency_requests where id = p_id;
  if not found then
    raise exception 'Request not found.' using errcode = 'P0002';
  end if;
end;
$$;

comment on function public.admin_delete_emergency(uuid) is
  'Admin/editor removes an emergency request from the log.';

-- â”€â”€ Grants â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
revoke all on function public.admin_set_booking_status(uuid, text) from public, anon;
revoke all on function public.admin_set_emergency_status(uuid, text) from public, anon;
revoke all on function public.admin_delete_emergency(uuid) from public, anon;
grant execute on function public.admin_set_booking_status(uuid, text) to authenticated;
grant execute on function public.admin_set_emergency_status(uuid, text) to authenticated;
grant execute on function public.admin_delete_emergency(uuid) to authenticated;


-- ─────────────────────────  0013_staff_role.sql  ─────────────────────────
-- ============================================================
-- 0013  Staff role â€” hired employees (call-center / operations)
--
-- The team is hiring managers who handle tourist calls, SOS
-- requests and bookings. A `staff` member may use everything in
-- the admin dashboard EXCEPT:
--   * finance (commission / sales money â€” admin only in the app;
--     the commissions ledger table stays fully locked to clients)
--   * Users & Roles (admin only)
--
-- How: is_editor() now means "any team member" (admin, editor or
-- staff) â€” every content policy and the 0012 admin actions inherit
-- that automatically. Bookings and SOS lists open up to the team
-- too, because a call-center agent must see them to work.
-- is_admin() is unchanged: money + user management stay admin-only.
--
-- Idempotent.
-- ============================================================

-- â”€â”€ Allow the new role value â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
alter table public.user_roles drop constraint if exists user_roles_role_check;
alter table public.user_roles
  add constraint user_roles_role_check check (role in ('admin','editor','staff'));

comment on table public.user_roles is
  'Team roles: admin (everything), editor (content), staff (operations). Written only via admin_grant_role/admin_revoke_role.';

-- â”€â”€ is_editor() = any team member â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
create or replace function public.is_editor()
returns boolean
language sql
security definer
set search_path = public, pg_temp
stable
as $$
  select exists (
    select 1 from public.user_roles
    where user_id = auth.uid() and role in ('admin','editor','staff')
  );
$$;

comment on function public.is_editor() is
  'True if the caller is admin, editor or staff. Gates content management and daily operations.';

-- â”€â”€ Team members see all bookings (needed to manage them) â”€â”€â”€â”€
drop policy if exists bookings_select_own on public.bookings;
create policy bookings_select_own
  on public.bookings for select
  using (
    user_id = auth.uid()
    or (user_email is not null and user_email = (auth.jwt() ->> 'email'))
    or public.is_editor()
  );

-- â”€â”€ Team members see all SOS requests â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
drop policy if exists er_select_own_or_admin on public.emergency_requests;
create policy er_select_own_or_admin
  on public.emergency_requests for select
  using (user_id = auth.uid() or public.is_editor());

-- â”€â”€ Role management accepts the new role â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
create or replace function public.admin_grant_role(p_user_id uuid, p_role text)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_admin() then
    raise exception 'Admins only.' using errcode = '42501';
  end if;
  if p_role not in ('admin','editor','staff') then
    raise exception 'Role must be admin, editor or staff.' using errcode = '22023';
  end if;
  if not exists (select 1 from auth.users where id = p_user_id) then
    raise exception 'User not found.' using errcode = 'P0002';
  end if;

  insert into public.user_roles (user_id, role, created_by)
  values (p_user_id, p_role, auth.uid())
  on conflict (user_id) do update
    set role = excluded.role,
        created_by = excluded.created_by;
end;
$$;


-- ─────────────────────────  0014_premium_tier_and_ai.sql  ─────────────────────────
-- ============================================================
-- 0014  Two kinds of visitor (Free / Premium) + "Ask Gondar" AI
--
-- From the proposal (v15, pages 7 and 9):
--   * Free (every visitor): sites, maps, verified listings,
--     ratings, SOS + safety notices. Safety is always free.
--   * Premium (optional upgrade): Ask Gondar AI chat, and later
--     the other premium extras.
--   * The AI only answers from information the City approves.
--
-- Same security design as user_roles (0001): the tier lives in its
-- own table that NO client can write. A visitor can read their own
-- tier; only admins change it, through admin_set_user_tier().
-- Visitors ask for Premium through premium_requests; the admin
-- approves in the dashboard (payment is decided with the City later).
--
-- ai_knowledge = the City-approved facts the AI is allowed to use.
-- ai_questions = a log of what was asked (for the City's evidence
-- and to rate-limit). Both are read by the ask-gondar edge function.
--
-- Idempotent. Also safe on a database where 0001–0013 were never
-- run: the role helpers below are only created if they are missing.
-- ============================================================

-- ── Role helpers (from 0001/0013) — created only if missing ──
create table if not exists public.user_roles (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  role       text not null check (role in ('admin','editor','staff')),
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id)
);
alter table public.user_roles enable row level security;
drop policy if exists user_roles_select_own on public.user_roles;
create policy user_roles_select_own
  on public.user_roles for select
  using (user_id = auth.uid());
revoke insert, update, delete on public.user_roles from anon, authenticated;

do $helpers$
begin
  if to_regprocedure('public.is_admin()') is null then
    execute $f$
      create function public.is_admin()
      returns boolean language sql security definer
      set search_path = public, pg_temp stable
      as $b$
        select exists (select 1 from public.user_roles
                       where user_id = auth.uid() and role = 'admin');
      $b$;
      revoke all on function public.is_admin() from public;
      grant execute on function public.is_admin() to authenticated, anon;
    $f$;
  end if;
  if to_regprocedure('public.is_editor()') is null then
    execute $f$
      create function public.is_editor()
      returns boolean language sql security definer
      set search_path = public, pg_temp stable
      as $b$
        select exists (select 1 from public.user_roles
                       where user_id = auth.uid() and role in ('admin','editor','staff'));
      $b$;
      revoke all on function public.is_editor() from public;
      grant execute on function public.is_editor() to authenticated, anon;
    $f$;
  end if;
end
$helpers$;

-- ── Tiers ────────────────────────────────────────────────────
create table if not exists public.user_tiers (
  user_id       uuid primary key references auth.users(id) on delete cascade,
  tier          text not null default 'free' check (tier in ('free','premium')),
  premium_until timestamptz,                 -- null = no end date
  updated_at    timestamptz not null default now(),
  updated_by    uuid references auth.users(id)
);

comment on table public.user_tiers is
  'Visitor plan: free or premium. Written only via admin_set_user_tier(). No row = free.';

alter table public.user_tiers enable row level security;

drop policy if exists user_tiers_select_own on public.user_tiers;
create policy user_tiers_select_own
  on public.user_tiers for select
  using (user_id = auth.uid() or public.is_admin());

revoke insert, update, delete on public.user_tiers from anon, authenticated;

-- True if the caller has an active Premium plan. Team members
-- (admin/editor/staff) count as premium so they can test the app.
create or replace function public.is_premium()
returns boolean
language sql
security definer
set search_path = public, pg_temp
stable
as $$
  select public.is_editor() or exists (
    select 1 from public.user_tiers
    where user_id = auth.uid()
      and tier = 'premium'
      and (premium_until is null or premium_until > now())
  );
$$;

comment on function public.is_premium() is
  'True if the caller has an active Premium plan (team members always do).';

revoke all on function public.is_premium() from public;
grant execute on function public.is_premium() to authenticated, anon;

create or replace function public.admin_set_user_tier(
  p_user_id uuid,
  p_tier    text,
  p_until   timestamptz default null
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_admin() then
    raise exception 'Admins only.' using errcode = '42501';
  end if;
  if p_tier not in ('free','premium') then
    raise exception 'Tier must be free or premium.' using errcode = '22023';
  end if;
  if not exists (select 1 from auth.users where id = p_user_id) then
    raise exception 'User not found.' using errcode = 'P0002';
  end if;

  insert into public.user_tiers (user_id, tier, premium_until, updated_at, updated_by)
  values (p_user_id, p_tier,
          case when p_tier = 'premium' then p_until end,
          now(), auth.uid())
  on conflict (user_id) do update
    set tier          = excluded.tier,
        premium_until = excluded.premium_until,
        updated_at    = excluded.updated_at,
        updated_by    = excluded.updated_by;

  -- Approving someone closes their open request.
  if p_tier = 'premium' then
    update public.premium_requests
       set status = 'approved', handled_at = now(), handled_by = auth.uid()
     where user_id = p_user_id and status = 'pending';
  end if;
end;
$$;

-- ── Premium requests (visitor asks, admin approves) ──────────
create table if not exists public.premium_requests (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  email      text,
  note       text,
  status     text not null default 'pending'
             check (status in ('pending','approved','rejected')),
  created_at timestamptz not null default now(),
  handled_at timestamptz,
  handled_by uuid references auth.users(id)
);

-- One open request per visitor.
create unique index if not exists premium_requests_one_pending
  on public.premium_requests (user_id) where status = 'pending';

alter table public.premium_requests enable row level security;

drop policy if exists premium_requests_select on public.premium_requests;
create policy premium_requests_select
  on public.premium_requests for select
  using (user_id = auth.uid() or public.is_admin());

drop policy if exists premium_requests_insert_own on public.premium_requests;
create policy premium_requests_insert_own
  on public.premium_requests for insert
  with check (user_id = auth.uid() and status = 'pending');

drop policy if exists premium_requests_update_admin on public.premium_requests;
create policy premium_requests_update_admin
  on public.premium_requests for update
  using (public.is_admin())
  with check (public.is_admin());

-- Function defined after premium_requests exists (it references it).
revoke all on function public.admin_set_user_tier(uuid, text, timestamptz) from public, anon;
grant execute on function public.admin_set_user_tier(uuid, text, timestamptz) to authenticated;

-- ── City-approved knowledge for the AI ───────────────────────
create table if not exists public.ai_knowledge (
  id             uuid primary key default gen_random_uuid(),
  title          text not null,
  title_am       text,
  body           text,
  body_am        text,
  category       text default 'general',
  publish_status text default 'draft',
  created_at     timestamptz not null default now()
);

comment on table public.ai_knowledge is
  'Facts the Ask Gondar AI may use. Only published rows reach the AI.';

alter table public.ai_knowledge enable row level security;

drop policy if exists ai_knowledge_select on public.ai_knowledge;
create policy ai_knowledge_select
  on public.ai_knowledge for select
  using (publish_status = 'published' or public.is_editor());

drop policy if exists ai_knowledge_write_editor on public.ai_knowledge;
create policy ai_knowledge_write_editor
  on public.ai_knowledge for all
  using (public.is_editor())
  with check (public.is_editor());

-- ── Question log (written by the edge function's service role) ─
create table if not exists public.ai_questions (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid references auth.users(id) on delete set null,
  mode       text not null default 'visitor' check (mode in ('visitor','city')),
  lang       text,
  question   text not null,
  answer     text,
  created_at timestamptz not null default now()
);

create index if not exists ai_questions_user_day
  on public.ai_questions (user_id, created_at desc);

alter table public.ai_questions enable row level security;

drop policy if exists ai_questions_select on public.ai_questions;
create policy ai_questions_select
  on public.ai_questions for select
  using (user_id = auth.uid() or public.is_editor());

revoke insert, update, delete on public.ai_questions from anon, authenticated;


-- ─────────────────────────  combined_tail.sql  ─────────────────────────

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--  FINAL STEP 1: give the admin account its role.
--  (Edit the emails below if you use a different login.)
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
insert into public.user_roles (user_id, role)
select id, 'admin'
from auth.users
where email in ('admin@visitgondar.com', 'sefedstudio@gmail.com')
on conflict (user_id) do update set role = 'admin';

-- ─────────────────────────  0015_realtime_live_updates.sql  ─────────────────────────
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

-- ─────────────────────────  0016_close_legacy_open_policies.sql  ─────────────────────────
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

-- ─────────────────────────  0017_rides_and_drivers.sql  ─────────────────────────
-- ============================================================
-- 0017  Rides: tourists request a bajaj / taxi, partner drivers
--       (Visit Gondar Driver app) accept and drive.
--
--   ride_fares     price per vehicle type (admin-editable)
--   drivers        partner drivers; approved by the city team
--   rides          one row per trip, requested → accepted → arrived
--                  → in_progress → completed (or cancelled/expired)
--   ride_contacts  rider phone, hidden until a driver accepts
--
-- All changes go through SECURITY DEFINER functions (no direct client
-- writes): fares and distances are computed here, the first driver
-- to accept wins atomically, and a rider's phone is only revealed to
-- the driver who accepted. Live updates via supabase_realtime.
-- Idempotent.
-- ============================================================

-- ── Fares (ETB) ──────────────────────────────────────────────
create table if not exists public.ride_fares (
  vehicle_type text primary key check (vehicle_type in ('bajaj', 'taxi')),
  base_fare    numeric(8,2) not null check (base_fare >= 0),
  per_km       numeric(8,2) not null check (per_km >= 0),
  minimum      numeric(8,2) not null check (minimum >= 0),
  updated_at   timestamptz not null default now()
);
insert into public.ride_fares (vehicle_type, base_fare, per_km, minimum) values
  ('bajaj', 25, 15, 40),
  ('taxi',  60, 30, 100)
on conflict (vehicle_type) do nothing;

alter table public.ride_fares enable row level security;
drop policy if exists ride_fares_select_all on public.ride_fares;
create policy ride_fares_select_all on public.ride_fares for select using (true);
drop policy if exists ride_fares_editor_write on public.ride_fares;
create policy ride_fares_editor_write on public.ride_fares for all
  using (public.is_editor()) with check (public.is_editor());

-- ── Drivers ──────────────────────────────────────────────────
create table if not exists public.drivers (
  user_id         uuid primary key references auth.users(id) on delete cascade,
  full_name       text not null,
  phone           text not null,
  vehicle_type    text not null check (vehicle_type in ('bajaj', 'taxi')),
  plate           text not null,
  vehicle_desc    text,
  photo           text,
  status          text not null default 'pending'
                  check (status in ('pending', 'approved', 'suspended')),
  is_online       boolean not null default false,
  lat             numeric(9,6),
  lng             numeric(9,6),
  location_at     timestamptz,
  rating_sum      int not null default 0,
  rating_count    int not null default 0,
  rides_completed int not null default 0,
  created_at      timestamptz not null default now(),
  approved_at     timestamptz
);
comment on table public.drivers is
  'Partner bajaj/taxi drivers. Apply in the Driver app (driver_apply); the city team approves.';

alter table public.drivers enable row level security;
drop policy if exists drivers_select_own_or_editor on public.drivers;
create policy drivers_select_own_or_editor on public.drivers for select
  using (user_id = auth.uid() or public.is_editor());
revoke insert, update, delete on public.drivers from anon, authenticated;

-- ── Rides ────────────────────────────────────────────────────
create table if not exists public.rides (
  id                 uuid primary key default gen_random_uuid(),
  rider_id           uuid not null references auth.users(id) on delete cascade,
  rider_name         text,
  rider_phone        text,             -- copied in only when a driver accepts
  vehicle_type       text not null check (vehicle_type in ('bajaj', 'taxi')),
  pickup_lat         numeric(9,6) not null,
  pickup_lng         numeric(9,6) not null,
  pickup_label       text,
  dropoff_lat        numeric(9,6) not null,
  dropoff_lng        numeric(9,6) not null,
  dropoff_label      text,
  distance_km        numeric(6,2) not null,
  fare_estimate      numeric(10,2) not null,
  status             text not null default 'requested'
                     check (status in ('requested', 'accepted', 'arrived', 'in_progress',
                                       'completed', 'cancelled', 'expired')),
  driver_id          uuid references auth.users(id) on delete set null,
  driver_name        text,
  driver_phone       text,
  vehicle_plate      text,
  vehicle_desc       text,
  driver_lat         numeric(9,6),
  driver_lng         numeric(9,6),
  driver_location_at timestamptz,
  rider_rating       int check (rider_rating between 1 and 5),
  cancelled_by       text check (cancelled_by in ('rider', 'driver', 'admin', 'system')),
  cancel_reason      text,
  created_at         timestamptz not null default now(),
  accepted_at        timestamptz,
  arrived_at         timestamptz,
  started_at         timestamptz,
  completed_at       timestamptz,
  cancelled_at       timestamptz
);
comment on table public.rides is
  'Ride requests and trips. Only changed through the ride RPCs.';

create index if not exists rides_open_idx   on public.rides (status, vehicle_type, created_at desc);
create index if not exists rides_rider_idx  on public.rides (rider_id, created_at desc);
create index if not exists rides_driver_idx on public.rides (driver_id, created_at desc);
-- One live ride per rider and per driver, enforced by the database.
create unique index if not exists rides_one_active_per_rider on public.rides (rider_id)
  where status in ('requested', 'accepted', 'arrived', 'in_progress');
create unique index if not exists rides_one_active_per_driver on public.rides (driver_id)
  where status in ('accepted', 'arrived', 'in_progress');

-- Rider phone numbers wait here (no client can read this table)
-- until a driver accepts the ride.
create table if not exists public.ride_contacts (
  ride_id     uuid primary key references public.rides(id) on delete cascade,
  rider_phone text not null
);
alter table public.ride_contacts enable row level security;
revoke all on public.ride_contacts from anon, authenticated;

alter table public.rides enable row level security;
drop policy if exists rides_select on public.rides;
create policy rides_select on public.rides for select using (
  rider_id = auth.uid()
  or driver_id = auth.uid()
  or public.is_editor()
  -- open requests are visible to approved drivers of the same vehicle type
  or (status = 'requested' and driver_id is null
      and exists (select 1 from public.drivers d
                   where d.user_id = auth.uid()
                     and d.status = 'approved'
                     and d.vehicle_type = rides.vehicle_type))
);
revoke insert, update, delete on public.rides from anon, authenticated;

-- ── Helpers ──────────────────────────────────────────────────
-- Straight-line distance in km (haversine).
create or replace function public.geo_km(
  lat1 numeric, lng1 numeric, lat2 numeric, lng2 numeric)
returns numeric
language sql
immutable
as $$
  select (6371 * 2 * asin(sqrt(
            power(sin(radians((lat2 - lat1)::float8) / 2), 2)
          + cos(radians(lat1::float8)) * cos(radians(lat2::float8))
          * power(sin(radians((lng2 - lng1)::float8) / 2), 2))))::numeric;
$$;

-- Price + road distance for a trip. Roads are ~30% longer than the
-- straight line; fares round to the nearest 5 birr.
create or replace function public.ride_quote(
  p_vehicle_type text,
  p_pickup_lat numeric, p_pickup_lng numeric,
  p_dropoff_lat numeric, p_dropoff_lng numeric)
returns table (distance_km numeric, fare numeric)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_fare public.ride_fares;
  v_km   numeric;
begin
  select * into v_fare from public.ride_fares where vehicle_type = p_vehicle_type;
  if not found then
    raise exception 'Unknown vehicle type.' using errcode = '22023';
  end if;
  if p_pickup_lat is null or p_pickup_lng is null
     or p_dropoff_lat is null or p_dropoff_lng is null then
    raise exception 'Pickup and destination are required.' using errcode = '22023';
  end if;
  -- Service area: within 60 km of Gondar.
  if public.geo_km(p_pickup_lat, p_pickup_lng, 12.6075, 37.4592) > 60
     or public.geo_km(p_dropoff_lat, p_dropoff_lng, 12.6075, 37.4592) > 60 then
    raise exception 'Rides are available in and around Gondar only.' using errcode = '22023';
  end if;
  v_km := round(public.geo_km(p_pickup_lat, p_pickup_lng, p_dropoff_lat, p_dropoff_lng) * 1.3, 2);
  distance_km := v_km;
  fare := greatest(v_fare.minimum, round((v_fare.base_fare + v_fare.per_km * v_km) / 5) * 5);
  return next;
end;
$$;

-- ── Tourist: request a ride ──────────────────────────────────
create or replace function public.request_ride(
  p_vehicle_type  text,
  p_pickup_lat    numeric, p_pickup_lng  numeric, p_pickup_label  text,
  p_dropoff_lat   numeric, p_dropoff_lng numeric, p_dropoff_label text,
  p_rider_name    text,
  p_rider_phone   text)
returns public.rides
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_q   record;
  v_row public.rides;
begin
  if v_uid is null then
    raise exception 'Please sign in to request a ride.' using errcode = '28000';
  end if;
  if coalesce(btrim(p_rider_phone), '') = '' then
    raise exception 'A phone number is needed so the driver can call you.' using errcode = '22023';
  end if;

  -- An old request nobody took is expired, so the rider can try again.
  update public.rides
     set status = 'expired', cancelled_by = 'system', cancelled_at = now()
   where rider_id = v_uid and status = 'requested'
     and created_at < now() - interval '15 minutes';

  if exists (select 1 from public.rides
              where rider_id = v_uid
                and status in ('requested', 'accepted', 'arrived', 'in_progress')) then
    raise exception 'You already have a ride in progress.' using errcode = 'P0001';
  end if;

  select * into v_q from public.ride_quote(
    p_vehicle_type, p_pickup_lat, p_pickup_lng, p_dropoff_lat, p_dropoff_lng);

  insert into public.rides (
    rider_id, rider_name, vehicle_type,
    pickup_lat, pickup_lng, pickup_label,
    dropoff_lat, dropoff_lng, dropoff_label,
    distance_km, fare_estimate)
  values (
    v_uid, nullif(btrim(p_rider_name), ''), p_vehicle_type,
    p_pickup_lat, p_pickup_lng, nullif(btrim(p_pickup_label), ''),
    p_dropoff_lat, p_dropoff_lng, nullif(btrim(p_dropoff_label), ''),
    v_q.distance_km, v_q.fare)
  returning * into v_row;

  insert into public.ride_contacts (ride_id, rider_phone)
  values (v_row.id, btrim(p_rider_phone));

  return v_row;
end;
$$;

-- ── Rider or driver: cancel ──────────────────────────────────
-- Rider: cancels the ride. Driver: hands it back to other drivers.
create or replace function public.cancel_ride(p_ride_id uuid, p_reason text default null)
returns public.rides
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.rides;
begin
  select * into v_row from public.rides where id = p_ride_id for update;
  if not found then
    raise exception 'Ride not found.' using errcode = 'P0002';
  end if;

  if v_row.rider_id = v_uid then
    if v_row.status not in ('requested', 'accepted', 'arrived') then
      raise exception 'This ride can no longer be cancelled.' using errcode = 'P0001';
    end if;
    update public.rides
       set status = 'cancelled', cancelled_by = 'rider', cancelled_at = now(),
           cancel_reason = nullif(btrim(p_reason), '')
     where id = p_ride_id
    returning * into v_row;
  elsif v_row.driver_id = v_uid then
    if v_row.status not in ('accepted', 'arrived') then
      raise exception 'This ride can no longer be handed back.' using errcode = 'P0001';
    end if;
    update public.rides
       set status = 'requested', driver_id = null, driver_name = null,
           driver_phone = null, vehicle_plate = null, vehicle_desc = null,
           driver_lat = null, driver_lng = null, driver_location_at = null,
           rider_phone = null, accepted_at = null, arrived_at = null,
           created_at = now()  -- back to the top of the drivers' list
     where id = p_ride_id
    returning * into v_row;
  else
    raise exception 'Not your ride.' using errcode = '42501';
  end if;
  return v_row;
end;
$$;

-- ── Rider: rate the driver after the trip ────────────────────
create or replace function public.rate_ride(p_ride_id uuid, p_stars int)
returns public.rides
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_row public.rides;
begin
  if p_stars is null or p_stars < 1 or p_stars > 5 then
    raise exception 'Rating must be 1 to 5 stars.' using errcode = '22023';
  end if;
  update public.rides set rider_rating = p_stars
   where id = p_ride_id and rider_id = auth.uid()
     and status = 'completed' and rider_rating is null
  returning * into v_row;
  if not found then
    raise exception 'This ride cannot be rated.' using errcode = 'P0001';
  end if;
  update public.drivers
     set rating_sum = rating_sum + p_stars, rating_count = rating_count + 1
   where user_id = v_row.driver_id;
  return v_row;
end;
$$;

-- ── Driver: apply / update profile ───────────────────────────
create or replace function public.driver_apply(
  p_full_name    text,
  p_phone        text,
  p_vehicle_type text,
  p_plate        text,
  p_vehicle_desc text default null)
returns public.drivers
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_old public.drivers;
  v_row public.drivers;
begin
  if v_uid is null then
    raise exception 'Please sign in first.' using errcode = '28000';
  end if;
  if coalesce(btrim(p_full_name), '') = '' or coalesce(btrim(p_phone), '') = ''
     or coalesce(btrim(p_plate), '') = '' then
    raise exception 'Name, phone and plate number are required.' using errcode = '22023';
  end if;
  if p_vehicle_type not in ('bajaj', 'taxi') then
    raise exception 'Vehicle must be bajaj or taxi.' using errcode = '22023';
  end if;

  select * into v_old from public.drivers where user_id = v_uid;
  if not found then
    insert into public.drivers (user_id, full_name, phone, vehicle_type, plate, vehicle_desc)
    values (v_uid, btrim(p_full_name), btrim(p_phone), p_vehicle_type,
            upper(btrim(p_plate)), nullif(btrim(p_vehicle_desc), ''))
    returning * into v_row;
  else
    update public.drivers
       set full_name    = btrim(p_full_name),
           phone        = btrim(p_phone),
           vehicle_type = p_vehicle_type,
           plate        = upper(btrim(p_plate)),
           vehicle_desc = nullif(btrim(p_vehicle_desc), ''),
           -- a new vehicle or plate has to be checked again
           status = case
                      when v_old.status = 'approved'
                       and (v_old.vehicle_type <> p_vehicle_type
                            or v_old.plate <> upper(btrim(p_plate)))
                      then 'pending' else v_old.status end,
           is_online = case
                         when v_old.vehicle_type <> p_vehicle_type
                           or v_old.plate <> upper(btrim(p_plate))
                         then false else v_old.is_online end
     where user_id = v_uid
    returning * into v_row;
  end if;
  return v_row;
end;
$$;

-- ── Driver: online / offline ─────────────────────────────────
create or replace function public.driver_set_online(
  p_online boolean, p_lat numeric default null, p_lng numeric default null)
returns public.drivers
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_row public.drivers;
begin
  select * into v_row from public.drivers where user_id = auth.uid();
  if not found then
    raise exception 'Apply as a driver first.' using errcode = 'P0002';
  end if;
  if p_online and v_row.status <> 'approved' then
    raise exception 'Your driver account is not approved yet.' using errcode = '42501';
  end if;
  update public.drivers
     set is_online   = p_online,
         lat         = coalesce(p_lat, lat),
         lng         = coalesce(p_lng, lng),
         location_at = case when p_lat is not null then now() else location_at end
   where user_id = auth.uid()
  returning * into v_row;
  return v_row;
end;
$$;

-- ── Driver: location (also shown live to their rider) ────────
create or replace function public.driver_update_location(p_lat numeric, p_lng numeric)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if p_lat is null or p_lng is null then return; end if;
  update public.drivers
     set lat = p_lat, lng = p_lng, location_at = now()
   where user_id = auth.uid();
  update public.rides
     set driver_lat = p_lat, driver_lng = p_lng, driver_location_at = now()
   where driver_id = auth.uid()
     and status in ('accepted', 'arrived', 'in_progress');
end;
$$;

-- ── Driver: accept a request (first one wins) ────────────────
create or replace function public.driver_accept_ride(p_ride_id uuid)
returns public.rides
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_drv public.drivers;
  v_row public.rides;
begin
  select * into v_drv from public.drivers where user_id = auth.uid();
  if not found or v_drv.status <> 'approved' then
    raise exception 'Your driver account is not approved yet.' using errcode = '42501';
  end if;
  if exists (select 1 from public.rides
              where driver_id = v_drv.user_id
                and status in ('accepted', 'arrived', 'in_progress')) then
    raise exception 'Finish your current ride first.' using errcode = 'P0001';
  end if;

  update public.rides r
     set status        = 'accepted',
         driver_id     = v_drv.user_id,
         driver_name   = v_drv.full_name,
         driver_phone  = v_drv.phone,
         vehicle_plate = v_drv.plate,
         vehicle_desc  = v_drv.vehicle_desc,
         driver_lat    = v_drv.lat,
         driver_lng    = v_drv.lng,
         driver_location_at = v_drv.location_at,
         rider_phone   = (select c.rider_phone from public.ride_contacts c where c.ride_id = r.id),
         accepted_at   = now()
   where r.id = p_ride_id
     and r.status = 'requested'
     and r.driver_id is null
     and r.vehicle_type = v_drv.vehicle_type
     and r.created_at > now() - interval '15 minutes'
  returning * into v_row;
  if not found then
    raise exception 'Sorry — this ride was already taken or cancelled.' using errcode = 'P0002';
  end if;

  update public.drivers set is_online = true where user_id = v_drv.user_id;
  return v_row;
end;
$$;

-- ── Driver: arrived → trip started → completed ───────────────
create or replace function public.driver_advance_ride(p_ride_id uuid, p_status text)
returns public.rides
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_row public.rides;
begin
  select * into v_row from public.rides
   where id = p_ride_id and driver_id = auth.uid() for update;
  if not found then
    raise exception 'Not your ride.' using errcode = '42501';
  end if;
  if not ((v_row.status = 'accepted'    and p_status = 'arrived')
       or (v_row.status = 'arrived'     and p_status = 'in_progress')
       or (v_row.status = 'accepted'    and p_status = 'in_progress')
       or (v_row.status = 'in_progress' and p_status = 'completed')) then
    raise exception 'Cannot go from % to %.', v_row.status, p_status using errcode = '22023';
  end if;
  update public.rides
     set status       = p_status,
         arrived_at   = case when p_status = 'arrived' then now() else arrived_at end,
         started_at   = case when p_status = 'in_progress' then now() else started_at end,
         completed_at = case when p_status = 'completed' then now() else completed_at end
   where id = p_ride_id
  returning * into v_row;
  if p_status = 'completed' then
    update public.drivers set rides_completed = rides_completed + 1
     where user_id = v_row.driver_id;
  end if;
  return v_row;
end;
$$;

-- ── City team ────────────────────────────────────────────────
create or replace function public.admin_set_driver_status(p_user_id uuid, p_status text)
returns public.drivers
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_row public.drivers;
begin
  if not public.is_editor() then
    raise exception 'Editors/admins only.' using errcode = '42501';
  end if;
  if p_status not in ('pending', 'approved', 'suspended') then
    raise exception 'Invalid driver status.' using errcode = '22023';
  end if;
  update public.drivers
     set status      = p_status,
         approved_at = case when p_status = 'approved' then now() else approved_at end,
         is_online   = case when p_status = 'approved' then is_online else false end
   where user_id = p_user_id
  returning * into v_row;
  if not found then
    raise exception 'Driver not found.' using errcode = 'P0002';
  end if;
  return v_row;
end;
$$;

create or replace function public.admin_cancel_ride(p_ride_id uuid, p_reason text default null)
returns public.rides
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_row public.rides;
begin
  if not public.is_editor() then
    raise exception 'Editors/admins only.' using errcode = '42501';
  end if;
  update public.rides
     set status = 'cancelled', cancelled_by = 'admin', cancelled_at = now(),
         cancel_reason = nullif(btrim(p_reason), '')
   where id = p_ride_id
     and status in ('requested', 'accepted', 'arrived', 'in_progress')
  returning * into v_row;
  if not found then
    raise exception 'No active ride with that id.' using errcode = 'P0002';
  end if;
  return v_row;
end;
$$;

-- ── Grants ───────────────────────────────────────────────────
revoke all on function public.ride_quote(text, numeric, numeric, numeric, numeric) from public;
grant execute on function public.ride_quote(text, numeric, numeric, numeric, numeric) to anon, authenticated;

do $$
declare
  f text;
begin
  foreach f in array array[
    'public.request_ride(text, numeric, numeric, text, numeric, numeric, text, text, text)',
    'public.cancel_ride(uuid, text)',
    'public.rate_ride(uuid, int)',
    'public.driver_apply(text, text, text, text, text)',
    'public.driver_set_online(boolean, numeric, numeric)',
    'public.driver_update_location(numeric, numeric)',
    'public.driver_accept_ride(uuid)',
    'public.driver_advance_ride(uuid, text)',
    'public.admin_set_driver_status(uuid, text)',
    'public.admin_cancel_ride(uuid, text)'
  ] loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end $$;

-- ── Live updates ─────────────────────────────────────────────
do $$
declare
  t text;
begin
  foreach t in array array['rides', 'drivers'] loop
    if not exists (select 1 from pg_publication_tables
                    where pubname = 'supabase_realtime'
                      and schemaname = 'public' and tablename = t) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;

-- ─────────────────────────  0018_partner_portal.sql  ─────────────────────────
-- ============================================================
-- 0018  Partner portal: hotels and guides manage their own
--       business on the Visit Gondar Partners website.
--
-- Uses hotels.owner_id / guides.owner_id (migration 0007).
--   · owners read their own listing (even before it is published)
--   · owners read the bookings for their own listings, and confirm
--     or decline them (partner_set_booking_status)
--   · owners manage the availability calendar of their listings
--   · owners edit description / contact / price / photos
--     (partner_update_hotel / partner_update_guide); publishing and
--     the business name stay with the city team
--   · partner_requests: someone asks to be linked to a business;
--     the city team links them (admin_link_owner)
-- Idempotent.
-- ============================================================

-- ── Ownership check ──────────────────────────────────────────
create or replace function public.owns_business(p_type text, p_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select case p_type
    when 'hotel' then exists (select 1 from public.hotels
                               where id = p_id and owner_id = auth.uid())
    when 'guide' then exists (select 1 from public.guides
                               where id = p_id and owner_id = auth.uid())
    else false
  end;
$$;
revoke all on function public.owns_business(text, uuid) from public;
grant execute on function public.owns_business(text, uuid) to anon, authenticated;

-- ── Owners read their own listings ───────────────────────────
drop policy if exists hotels_select_owner on public.hotels;
create policy hotels_select_owner on public.hotels for select
  using (owner_id = auth.uid());
drop policy if exists guides_select_owner on public.guides;
create policy guides_select_owner on public.guides for select
  using (owner_id = auth.uid());

-- ── Owners read the bookings for their listings ──────────────
drop policy if exists bookings_select_partner on public.bookings;
create policy bookings_select_partner on public.bookings for select
  using (item_id is not null and public.owns_business(item_type, item_id));

-- ── Owners manage their availability calendar ────────────────
drop policy if exists availability_owner_write on public.availability;
create policy availability_owner_write on public.availability for all
  using (public.owns_business(business_type, business_id))
  with check (public.owns_business(business_type, business_id));

-- ── Requests to be linked to a business ──────────────────────
create table if not exists public.partner_requests (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null default auth.uid() references auth.users(id) on delete cascade,
  email         text,
  business_type text not null check (business_type in ('hotel', 'guide')),
  business_name text not null,
  phone         text,
  message       text,
  status        text not null default 'pending'
                check (status in ('pending', 'linked', 'rejected')),
  created_at    timestamptz not null default now(),
  handled_at    timestamptz,
  handled_by    uuid references auth.users(id)
);
alter table public.partner_requests enable row level security;
drop policy if exists partner_requests_insert_own on public.partner_requests;
create policy partner_requests_insert_own on public.partner_requests for insert
  with check (user_id = auth.uid() and status = 'pending');
drop policy if exists partner_requests_select on public.partner_requests;
create policy partner_requests_select on public.partner_requests for select
  using (user_id = auth.uid() or public.is_editor());
drop policy if exists partner_requests_editor_update on public.partner_requests;
create policy partner_requests_editor_update on public.partner_requests for update
  using (public.is_editor()) with check (public.is_editor());
revoke delete on public.partner_requests from anon, authenticated;

-- ── Partner: confirm / decline / cancel a booking ────────────
create or replace function public.partner_set_booking_status(
  p_booking_id uuid, p_status text)
returns public.bookings
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_row public.bookings;
begin
  select * into v_row from public.bookings where id = p_booking_id for update;
  if not found or v_row.item_id is null
     or not public.owns_business(v_row.item_type, v_row.item_id) then
    raise exception 'Not a booking for your business.' using errcode = '42501';
  end if;
  if not ((v_row.status = 'pending'   and p_status in ('confirmed', 'rejected'))
       or (v_row.status = 'confirmed' and p_status = 'cancelled')
       or (v_row.status = 'approved'  and p_status in ('confirmed', 'cancelled'))) then
    raise exception 'Cannot change a % booking to %.', v_row.status, p_status
      using errcode = '22023';
  end if;
  update public.bookings set status = p_status where id = p_booking_id
  returning * into v_row;
  return v_row;
end;
$$;

-- ── Partner: edit their hotel ────────────────────────────────
create or replace function public.partner_update_hotel(
  p_hotel_id    uuid,
  p_description text,
  p_contact     text,
  p_location    text,
  p_price       numeric,
  p_photos      text[])
returns public.hotels
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_row public.hotels;
begin
  if not public.owns_business('hotel', p_hotel_id) then
    raise exception 'Not your hotel.' using errcode = '42501';
  end if;
  if p_price is null or p_price <= 0 or p_price > 1000000 then
    raise exception 'Enter a nightly price above 0.' using errcode = '22023';
  end if;
  update public.hotels
     set description = nullif(btrim(p_description), ''),
         contact     = nullif(btrim(p_contact), ''),
         location    = nullif(btrim(p_location), ''),
         price       = p_price,
         photos      = coalesce(p_photos, photos)
   where id = p_hotel_id
  returning * into v_row;
  return v_row;
end;
$$;

-- ── Partner: edit their guide profile ────────────────────────
create or replace function public.partner_update_guide(
  p_guide_id  uuid,
  p_specialty text,
  p_contact   text,
  p_price     numeric,
  p_languages text[],
  p_photo     text)
returns public.guides
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_row public.guides;
begin
  if not public.owns_business('guide', p_guide_id) then
    raise exception 'Not your guide profile.' using errcode = '42501';
  end if;
  if p_price is null or p_price <= 0 or p_price > 1000000 then
    raise exception 'Enter a daily price above 0.' using errcode = '22023';
  end if;
  update public.guides
     set specialty = nullif(btrim(p_specialty), ''),
         contact   = nullif(btrim(p_contact), ''),
         price     = p_price,
         languages = coalesce(p_languages, languages),
         photo     = coalesce(nullif(btrim(p_photo), ''), photo)
   where id = p_guide_id
  returning * into v_row;
  return v_row;
end;
$$;

-- ── City team: link / unlink an owner account ────────────────
create or replace function public.admin_link_owner(
  p_type text, p_business_id uuid, p_email text)
returns text
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_user uuid;
begin
  if not public.is_editor() then
    raise exception 'Editors/admins only.' using errcode = '42501';
  end if;
  select id into v_user from auth.users where lower(email) = lower(btrim(p_email));
  if v_user is null then
    raise exception 'No account with that email. Ask the partner to sign up on the Partners website first.'
      using errcode = 'P0002';
  end if;
  if p_type = 'hotel' then
    update public.hotels set owner_id = v_user where id = p_business_id;
  elsif p_type = 'guide' then
    update public.guides set owner_id = v_user where id = p_business_id;
  else
    raise exception 'Type must be hotel or guide.' using errcode = '22023';
  end if;
  if not found then
    raise exception 'Business not found.' using errcode = 'P0002';
  end if;
  update public.partner_requests
     set status = 'linked', handled_at = now(), handled_by = auth.uid()
   where user_id = v_user and business_type = p_type and status = 'pending';
  return 'linked';
end;
$$;

create or replace function public.admin_unlink_owner(p_type text, p_business_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_editor() then
    raise exception 'Editors/admins only.' using errcode = '42501';
  end if;
  if p_type = 'hotel' then
    update public.hotels set owner_id = null where id = p_business_id;
  elsif p_type = 'guide' then
    update public.guides set owner_id = null where id = p_business_id;
  else
    raise exception 'Type must be hotel or guide.' using errcode = '22023';
  end if;
end;
$$;

-- ── Grants ───────────────────────────────────────────────────
do $$
declare
  f text;
begin
  foreach f in array array[
    'public.partner_set_booking_status(uuid, text)',
    'public.partner_update_hotel(uuid, text, text, text, numeric, text[])',
    'public.partner_update_guide(uuid, text, text, numeric, text[], text)',
    'public.admin_link_owner(text, uuid, text)',
    'public.admin_unlink_owner(text, uuid)'
  ] loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end $$;

-- ── Live updates ─────────────────────────────────────────────
do $$
declare
  t text;
begin
  foreach t in array array['partner_requests', 'bookings', 'availability'] loop
    if to_regclass('public.' || t) is not null
       and not exists (select 1 from pg_publication_tables
                        where pubname = 'supabase_realtime'
                          and schemaname = 'public' and tablename = t) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;

-- ─────────────────────────  0019_driver_open_requests.sql  ─────────────────────────
-- ============================================================
-- 0019  Driver app: the list of open ride requests
--
--   driver_open_requests()  requests an approved driver can take:
--                           same vehicle type, nobody assigned,
--                           under 15 minutes old, newest first.
--
-- It runs on the server clock, so a driver whose phone clock is
-- wrong still sees the right requests. Requests nobody took in
-- 15 minutes are marked 'expired' here; the tourist app shows the
-- rider "no driver free — try again" live.
-- Idempotent.
-- ============================================================

create or replace function public.driver_open_requests()
returns setof public.rides
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_drv public.drivers;
begin
  select * into v_drv from public.drivers where user_id = auth.uid();
  if not found or v_drv.status <> 'approved' then
    return;
  end if;

  update public.rides
     set status = 'expired', cancelled_by = 'system', cancelled_at = now()
   where status = 'requested'
     and created_at < now() - interval '15 minutes';

  return query
    select r.* from public.rides r
     where r.status = 'requested'
       and r.driver_id is null
       and r.vehicle_type = v_drv.vehicle_type
     order by r.created_at desc
     limit 30;
end;
$$;

revoke all on function public.driver_open_requests() from public, anon;
grant execute on function public.driver_open_requests() to authenticated;

-- ─────────────────────────  0020_bookings_respect_calendar.sql  ─────────────────────────
-- ============================================================
-- 0020  Bookings respect the partner's calendar
--
-- Hotels and guides set their days on the Partners website
-- (availability table, 0008 / 0018). Until now nothing read it, so a
-- closed or full day could still be booked. Now every new booking
-- is checked, night by night (hotel) or day by day (guide):
--   · a day marked closed            → refused
--   · capacity reached on a day      → refused ("fully booked")
--     used = booked (rooms the partner sold elsewhere)
--          + active online bookings (pending / confirmed / approved)
--   · a day with no row              → open, as before
-- The tourist app shows the message on the booking screen.
-- The city team (editors/admins) can still add bookings on any day.
-- Idempotent.
-- ============================================================

create or replace function public.check_booking_availability()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_day  date;
  v_av   public.availability;
  v_used int;
begin
  if new.item_id is null or new.check_in is null or new.check_out is null
     or new.item_type not in ('hotel', 'guide')
     or coalesce(new.status, 'pending') not in ('pending', 'confirmed', 'approved')
     or public.is_editor() then
    return new;
  end if;

  -- One booking at a time per business, so two people cannot take
  -- the last room together.
  perform pg_advisory_xact_lock(hashtextextended(new.item_type || ':' || new.item_id::text, 0));

  for v_day in
    select d::date
      from generate_series(new.check_in, greatest(new.check_out - 1, new.check_in),
                           interval '1 day') as d
  loop
    select * into v_av from public.availability
     where business_type = new.item_type and business_id = new.item_id and day = v_day;
    continue when not found;

    if v_av.is_closed then
      raise exception 'Not available on % — please choose other dates.',
        to_char(v_day, 'DD Mon YYYY') using errcode = 'P0001';
    end if;

    select count(*) into v_used from public.bookings b
     where b.item_type = new.item_type and b.item_id = new.item_id
       and b.status in ('pending', 'confirmed', 'approved')
       and b.check_in <= v_day and b.check_out > v_day;
    if v_av.booked + v_used >= v_av.capacity then
      raise exception 'Fully booked on % — please choose other dates.',
        to_char(v_day, 'DD Mon YYYY') using errcode = 'P0001';
    end if;
  end loop;
  return new;
end;
$$;

revoke all on function public.check_booking_availability() from public, anon, authenticated;

drop trigger if exists trg_check_booking_availability on public.bookings;
create trigger trg_check_booking_availability
  before insert on public.bookings
  for each row execute function public.check_booking_availability();

-- ─────────────────────────  0021_partner_photo_uploads.sql  ─────────────────────────
-- ============================================================
-- 0021  Partners upload photos of their own listing
--
-- The Partners website uploads hotel / guide photos to the public
-- listing buckets (0005), inside a folder named after the business:
--     hotel-images/partners/<hotel id>/<file>
--     guide-images/partners/<guide id>/<file>
-- Only the linked owner of that hotel / guide may add or remove
-- files there. The city team keeps full access (0005 policies).
-- Idempotent.
-- ============================================================

-- True when the folder name is the id of a business I own. A folder
-- that is not an id is simply "no".
create or replace function public.owns_business_folder(p_type text, p_folder text)
returns boolean
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  return public.owns_business(p_type, p_folder::uuid);
exception when invalid_text_representation then
  return false;
end;
$$;
revoke all on function public.owns_business_folder(text, text) from public;
grant execute on function public.owns_business_folder(text, text) to authenticated;

drop policy if exists listing_images_owner_insert on storage.objects;
create policy listing_images_owner_insert on storage.objects for insert
  with check (
    bucket_id in ('hotel-images', 'guide-images')
    and (storage.foldername(name))[1] = 'partners'
    and public.owns_business_folder(
          case bucket_id when 'hotel-images' then 'hotel' else 'guide' end,
          (storage.foldername(name))[2])
  );

drop policy if exists listing_images_owner_delete on storage.objects;
create policy listing_images_owner_delete on storage.objects for delete
  using (
    bucket_id in ('hotel-images', 'guide-images')
    and (storage.foldername(name))[1] = 'partners'
    and public.owns_business_folder(
          case bucket_id when 'hotel-images' then 'hotel' else 'guide' end,
          (storage.foldername(name))[2])
  );

-- ─────────────────────────  0022_admin_create_driver.sql  ─────────────────────────
-- ============================================================
-- 0022  City team: register a driver directly
--
-- Driver accounts are no longer self-signed-up in the app — a driver
-- comes to the Visit Gondar office, the team checks their ID and
-- vehicle documents, and:
--   1. creates their sign-in in Supabase Dashboard → Authentication
--      → Users → Add user (email + a password the office gives them)
--   2. runs admin_create_driver() here (or uses the admin website's
--      "Add driver" button) to save their details, already approved
--      since the office just checked them in person.
-- The driver then only ever signs in with that email + password.
-- Idempotent.
-- ============================================================

create or replace function public.admin_create_driver(
  p_email        text,
  p_full_name    text,
  p_phone        text,
  p_vehicle_type text,
  p_plate        text,
  p_vehicle_desc text default null)
returns public.drivers
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_user uuid;
  v_row  public.drivers;
begin
  if not public.is_editor() then
    raise exception 'Editors/admins only.' using errcode = '42501';
  end if;
  if coalesce(btrim(p_full_name), '') = '' or coalesce(btrim(p_phone), '') = ''
     or coalesce(btrim(p_plate), '') = '' then
    raise exception 'Name, phone and plate number are required.' using errcode = '22023';
  end if;
  if p_vehicle_type not in ('bajaj', 'taxi') then
    raise exception 'Vehicle must be bajaj or taxi.' using errcode = '22023';
  end if;

  select id into v_user from auth.users where lower(email) = lower(btrim(p_email));
  if v_user is null then
    raise exception 'No account with that email yet. Create their sign-in first: Supabase Dashboard → Authentication → Users → Add user.'
      using errcode = 'P0002';
  end if;

  insert into public.drivers (
    user_id, full_name, phone, vehicle_type, plate, vehicle_desc,
    status, approved_at)
  values (
    v_user, btrim(p_full_name), btrim(p_phone), p_vehicle_type,
    upper(btrim(p_plate)), nullif(btrim(p_vehicle_desc), ''),
    'approved', now())
  on conflict (user_id) do update
     set full_name    = excluded.full_name,
         phone        = excluded.phone,
         vehicle_type = excluded.vehicle_type,
         plate        = excluded.plate,
         vehicle_desc = excluded.vehicle_desc,
         status       = 'approved',
         approved_at  = now()
  returning * into v_row;
  return v_row;
end;
$$;

revoke all on function public.admin_create_driver(text, text, text, text, text, text) from public, anon;
grant execute on function public.admin_create_driver(text, text, text, text, text, text) to authenticated;


-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--  FINAL STEP 2: the report. Read the rows this returns:
--   * "admins" must NOT say NONE â€” if it does, create the user first:
--     Dashboard â†’ Authentication â†’ Users â†’ Add user â†’ email + password,
--     then run this whole file again (it is safe to re-run).
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
select 'signed-up users' as what, count(*)::text as result from auth.users
union all
select 'admins',
       coalesce(
         (select string_agg(u.email || ' = ' || r.role, ', ')
            from public.user_roles r
            join auth.users u on u.id = r.user_id),
         'NONE â€” create the admin user, then run this file again')
union all
select 'booking function ready',
       case when exists (select 1 from pg_proc where proname = 'create_booking')
            then 'YES' else 'NO' end
union all
select 'new tables ready',
       case when to_regclass('public.availability') is not null
             and to_regclass('public.deposits') is not null
             and to_regclass('public.passport_checkpoints') is not null
            then 'YES' else 'NO' end
union all
select 'premium + AI tables ready',
       case when to_regclass('public.user_tiers') is not null
             and to_regclass('public.ai_knowledge') is not null
            then 'YES' else 'NO' end
union all
select 'sites map pins', (select count(*)::text from public.sites where lat is not null);

