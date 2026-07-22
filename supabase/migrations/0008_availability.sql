-- ============================================================
-- 0008  availability — per-day capacity for hotels & guides
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

-- ── RLS: public read, editor/admin write ─────────────────────
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
