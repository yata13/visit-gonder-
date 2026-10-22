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
