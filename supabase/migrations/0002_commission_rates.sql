-- ============================================================
-- 0002  commission_rates — single source of truth for rates
--
-- Why: rates were duplicated in two SQL files (3% vs 10% conflict) and
-- hard-coded in Dart. Canonical rates are hotels 3% / guides 10% (this
-- matches the live app and RUN_THIS_IN_SUPABASE.sql; supabase_update.sql
-- was wrong and is archived under supabase/legacy/). The create_booking
-- RPC (0004) reads the rate from here — never from the client.
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
