-- ============================================================
-- 0009  Chapa deposits — payment tracking on bookings
--
-- Why: the project is moving from pure commission to Chapa-based
-- deposits. A tourist pays a deposit through Chapa to confirm a
-- booking. This adds:
--   * bookings.payment_status + bookings.deposit_amount
--   * a deposits table: one row per Chapa transaction
--
-- Writes happen ONLY server-side (a Chapa webhook Edge Function
-- using the service role, or the SQL editor). Clients can read
-- their own deposit rows; admins can read all. The admin
-- dashboard is read-only over this data in v1.
--
-- Idempotent.
-- ============================================================

-- ── bookings: payment fields ─────────────────────────────────
alter table public.bookings add column if not exists payment_status text not null default 'unpaid';
alter table public.bookings add column if not exists deposit_amount numeric(10,2);

comment on column public.bookings.payment_status is
  'unpaid | deposit_pending | deposit_paid | refunded — set by the Chapa webhook, never by clients.';
comment on column public.bookings.deposit_amount is
  'Deposit required to confirm this booking, in ETB.';

create index if not exists bookings_payment_status_idx on public.bookings(payment_status);

-- ── deposits: one row per Chapa transaction ──────────────────
create table if not exists public.deposits (
  id           uuid primary key default gen_random_uuid(),
  booking_id   uuid not null references public.bookings(id) on delete cascade,
  amount       numeric(10,2) not null check (amount >= 0),
  currency     text not null default 'ETB',
  chapa_tx_ref text unique,
  status       text not null default 'initiated'
                 check (status in ('initiated','pending','success','failed','refunded')),
  checkout_url text,
  raw          jsonb,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

comment on table public.deposits is
  'Chapa deposit transactions. Written only by the payment webhook (service role). chapa_tx_ref is the tx_ref sent to Chapa.';

create index if not exists deposits_booking_id_idx on public.deposits(booking_id);
create index if not exists deposits_status_idx     on public.deposits(status);

create or replace function public.touch_deposits()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_touch_deposits on public.deposits;
create trigger trg_touch_deposits
  before update on public.deposits
  for each row execute function public.touch_deposits();

-- ── RLS: read own (via the booking) or admin; NO client writes ──
alter table public.deposits enable row level security;

drop policy if exists deposits_select_own_or_admin on public.deposits;
create policy deposits_select_own_or_admin
  on public.deposits for select
  using (
    public.is_admin()
    or exists (
      select 1 from public.bookings b
      where b.id = deposits.booking_id
        and (b.user_id = auth.uid()
             or (b.user_email is not null and b.user_email = (auth.jwt() ->> 'email')))
    )
  );

-- No INSERT/UPDATE/DELETE policies, and grants stripped: only the
-- service role (webhook) can write.
revoke insert, update, delete on public.deposits from anon, authenticated;
