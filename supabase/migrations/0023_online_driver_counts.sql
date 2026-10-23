-- ============================================================
-- 0023  How many drivers are online right now (public, no names)
--
-- The drivers table itself stays private (a tourist can only read
-- their own row — 0017), so the app cannot "see or call" a driver
-- directly: that goes through request_ride() instead. This gives
-- the app just a live count per vehicle type, to show "X bajaj
-- online now" before someone requests a ride. No names, phones,
-- plates or positions are exposed.
-- Idempotent.
-- ============================================================

create or replace function public.online_driver_counts()
returns table (vehicle_type text, online_count int)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select f.vehicle_type, count(d.user_id)::int as online_count
    from public.ride_fares f
    left join public.drivers d
      on d.vehicle_type = f.vehicle_type
     and d.status = 'approved'
     and d.is_online
     and d.location_at > now() - interval '10 minutes'
   group by f.vehicle_type;
$$;

revoke all on function public.online_driver_counts() from public;
grant execute on function public.online_driver_counts() to anon, authenticated;
