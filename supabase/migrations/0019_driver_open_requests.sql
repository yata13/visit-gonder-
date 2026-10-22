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
