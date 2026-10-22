-- ============================================================
--  Visit Gondar — SECURITY FIX + RIDES + PARTNERS (one file)
--  Paste this whole file into Supabase → SQL Editor → Run.
--  Safe to run more than once. Contains, in order:
--    0016  close the old "anyone can do anything" policies
--    0017  rides + drivers (Visit Gondar Driver app)
--    0018  partner portal (hotels / guides website)
--    0019  drivers' request list on server time
--    0020  bookings respect the partner's calendar
--    0021  partners upload photos of their own listing
--    0022  the office registers a driver directly
--  Then check: CHECK_OPEN_POLICIES.sql should show only ✅ rows.
-- ============================================================

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
