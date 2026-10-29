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
