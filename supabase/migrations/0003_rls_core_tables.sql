-- ============================================================
-- 0003  Enable RLS + policies on all tables except bookings
--       (bookings + its RPC are handled in 0004).
--
-- Why: today RLS is effectively OFF DB-wide — with the public anon key
-- anyone can read all PII and UPDATE/DELETE every table. Enabling RLS
-- flips the default to deny; the policies below re-open exactly what the
-- app legitimately needs and nothing more.
--
-- Column names match the LIVE schema (verified 2026-07-07), which differs
-- from supabase_update.sql.
--
-- Idempotent.
-- ============================================================

-- Helper note: PERMISSIVE policies combine with OR. A public SELECT
-- policy + an "editor manages" FOR ALL policy => SELECT stays public,
-- while INSERT/UPDATE/DELETE require editor/admin.

-- ─────────────────────────────────────────────────────────────
-- users — PII. Own row only; admins may read all (Phase 3).
-- Role is NOT stored here, so it can never be self-escalated.
-- ─────────────────────────────────────────────────────────────
alter table public.users enable row level security;

drop policy if exists users_select_own_or_admin on public.users;
create policy users_select_own_or_admin
  on public.users for select
  using (id = auth.uid() or public.is_admin());

drop policy if exists users_insert_own on public.users;
create policy users_insert_own
  on public.users for insert
  with check (id = auth.uid());

drop policy if exists users_update_own on public.users;
create policy users_update_own
  on public.users for update
  using (id = auth.uid())
  with check (id = auth.uid());
-- No DELETE policy: clients cannot delete user rows.

-- ─────────────────────────────────────────────────────────────
-- emergency_requests — PII incl. live GPS. Own insert + own read;
-- admins read (read-only audited view in Phase 3). No client edits.
-- ─────────────────────────────────────────────────────────────
alter table public.emergency_requests enable row level security;

drop policy if exists er_insert_own on public.emergency_requests;
create policy er_insert_own
  on public.emergency_requests for insert
  with check (user_id = auth.uid());

drop policy if exists er_select_own_or_admin on public.emergency_requests;
create policy er_select_own_or_admin
  on public.emergency_requests for select
  using (user_id = auth.uid() or public.is_admin());
-- No UPDATE/DELETE policy: emergency logs are immutable to clients.

-- ─────────────────────────────────────────────────────────────
-- Content tables — public read; editor/admin write.
-- sites & places have no publish_status yet (added in Phase 2, which
-- will tighten these SELECTs to published-only). hotels & guides do,
-- so drafts are hidden from clients right now.
-- ─────────────────────────────────────────────────────────────

-- sites
alter table public.sites enable row level security;
drop policy if exists sites_select_public on public.sites;
create policy sites_select_public on public.sites for select using (true);
drop policy if exists sites_editor_write on public.sites;
create policy sites_editor_write on public.sites for all
  using (public.is_editor()) with check (public.is_editor());

-- places
alter table public.places enable row level security;
drop policy if exists places_select_public on public.places;
create policy places_select_public on public.places for select using (true);
drop policy if exists places_editor_write on public.places;
create policy places_editor_write on public.places for all
  using (public.is_editor()) with check (public.is_editor());

-- hotels (publish_status exists → hide drafts from clients)
alter table public.hotels enable row level security;
drop policy if exists hotels_select_published on public.hotels;
create policy hotels_select_published on public.hotels for select
  using (coalesce(publish_status,'published') = 'published' or public.is_editor());
drop policy if exists hotels_editor_write on public.hotels;
create policy hotels_editor_write on public.hotels for all
  using (public.is_editor()) with check (public.is_editor());

-- guides (publish_status exists → hide drafts from clients)
alter table public.guides enable row level security;
drop policy if exists guides_select_published on public.guides;
create policy guides_select_published on public.guides for select
  using (coalesce(publish_status,'published') = 'published' or public.is_editor());
drop policy if exists guides_editor_write on public.guides;
create policy guides_editor_write on public.guides for all
  using (public.is_editor()) with check (public.is_editor());

-- events
alter table public.events enable row level security;
drop policy if exists events_select_public on public.events;
create policy events_select_public on public.events for select using (true);
drop policy if exists events_editor_write on public.events;
create policy events_editor_write on public.events for all
  using (public.is_editor()) with check (public.is_editor());

-- posts
alter table public.posts enable row level security;
drop policy if exists posts_select_public on public.posts;
create policy posts_select_public on public.posts for select using (true);
drop policy if exists posts_editor_write on public.posts;
create policy posts_editor_write on public.posts for all
  using (public.is_editor()) with check (public.is_editor());

-- notifications (broadcast to all; only editors compose)
alter table public.notifications enable row level security;
drop policy if exists notifications_select_public on public.notifications;
create policy notifications_select_public on public.notifications for select using (true);
drop policy if exists notifications_editor_write on public.notifications;
create policy notifications_editor_write on public.notifications for all
  using (public.is_editor()) with check (public.is_editor());

-- danger_zones (safety alerts; only editors manage)
alter table public.danger_zones enable row level security;
drop policy if exists danger_zones_select_public on public.danger_zones;
create policy danger_zones_select_public on public.danger_zones for select using (true);
drop policy if exists danger_zones_editor_write on public.danger_zones;
create policy danger_zones_editor_write on public.danger_zones for all
  using (public.is_editor()) with check (public.is_editor());

-- ─────────────────────────────────────────────────────────────
-- reviews — exists but unused by the client today. Lock it: public
-- read, editor/admin write (revisit if a user-review flow is built).
-- ─────────────────────────────────────────────────────────────
alter table public.reviews enable row level security;
drop policy if exists reviews_select_public on public.reviews;
create policy reviews_select_public on public.reviews for select using (true);
drop policy if exists reviews_editor_write on public.reviews;
create policy reviews_editor_write on public.reviews for all
  using (public.is_editor()) with check (public.is_editor());

-- ─────────────────────────────────────────────────────────────
-- commissions — financial ledger. RLS ON, ZERO policies => no client
-- (anon/authenticated) access whatsoever. Written only by the
-- SECURITY DEFINER create_booking RPC; read only by service role / admin
-- tooling that bypasses RLS.
-- ─────────────────────────────────────────────────────────────
create table if not exists public.commissions (
  id                uuid primary key default gen_random_uuid(),
  booking_id        uuid not null references public.bookings(id) on delete cascade,
  target_type       text not null check (target_type in ('hotel','guide')),
  target_id         uuid,
  total_amount      numeric(10,2) not null,
  commission_rate   numeric(4,3)  not null,
  commission_amount numeric(10,2) not null,
  status            text not null default 'pending'
                      check (status in ('pending','paid','refunded')),
  created_at        timestamptz not null default now()
);

comment on table public.commissions is
  'Immutable-to-clients commission ledger. RLS enabled with no policies => service role / SECURITY DEFINER only.';

alter table public.commissions enable row level security;
-- Intentionally NO policies. Also strip grants so clients get a hard
-- "permission denied" rather than a silent empty result.
revoke all on public.commissions from anon, authenticated;
