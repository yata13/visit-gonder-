-- ============================================================
-- 0004  Server-side bookings: create_booking RPC + lock the table
--
-- Why: today the client computes price & commission and INSERTs them
-- directly, and anon can UPDATE/DELETE any booking. This makes price and
-- commission server-authoritative (read from hotels/guides + commission_rates),
-- enforces validation, and removes all direct client writes — bookings are
-- created only via create_booking() and cancelled only via cancel_my_booking().
--
-- Column names match the LIVE schema. Idempotent.
-- ============================================================

-- ── Columns needed for server-side pricing / ownership ──────
-- (booking_date already exists and is kept in sync with check_in for the
--  existing "My Bookings" UI.)
alter table public.bookings add column if not exists user_id   uuid references auth.users(id);
alter table public.bookings add column if not exists item_id   uuid;
alter table public.bookings add column if not exists check_in  date;
alter table public.bookings add column if not exists check_out date;
alter table public.bookings add column if not exists guests    int default 1;

create index if not exists bookings_user_id_idx    on public.bookings(user_id);
create index if not exists bookings_user_email_idx on public.bookings(user_email);

-- ── RLS: read your own; no client writes at all ─────────────
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

-- ── create_booking : the only way a client makes a booking ──
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

  -- ── validation ──
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

  -- ── server-side price + published check (never trust the client) ──
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

-- ── cancel_my_booking : a user cancels their OWN pending booking ──
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
