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
