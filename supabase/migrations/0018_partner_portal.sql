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
