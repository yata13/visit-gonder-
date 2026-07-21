-- ============================================================
-- 0010  Gondar Passport — check-in points, stories, trivia
--
-- The Gondar Passport is a gamified city tour: tourists scan a QR
-- code (or use GPS) at heritage checkpoints, collect points, and
-- unlock stories + trivia.
--
-- Tables:
--   passport_checkpoints         public content (no secret inside)
--   passport_checkpoint_secrets  the QR token — editors/admins only
--   passport_stories             unlocked at a checkpoint
--   passport_trivia              quiz questions per checkpoint
--   passport_checkins            one row per user per checkpoint
--
-- The QR token lives in a separate secrets table so the public
-- checkpoint list can stay a plain `select *` without leaking the
-- token (anyone holding the token could fake a visit). Tourists
-- check in ONLY through the passport_check_in() RPC below.
--
-- Known v1 limitation: trivia correct_index is client-readable, so
-- a determined user can cheat the quiz. Acceptable for now.
--
-- Idempotent.
-- ============================================================

-- ── Checkpoints (public content) ─────────────────────────────
create table if not exists public.passport_checkpoints (
  id             uuid primary key default gen_random_uuid(),
  name_en        text not null,
  name_am        text,
  description_en text,
  description_am text,
  photo          text,
  lat            numeric(9,6) not null,
  lng            numeric(9,6) not null,
  points         int  not null default 10 check (points >= 0),
  sort_order     int  not null default 0,
  is_active      boolean not null default true,
  created_at     timestamptz not null default now()
);

comment on table public.passport_checkpoints is
  'Gondar Passport check-in points. QR tokens live in passport_checkpoint_secrets, never here.';

-- ── QR secrets (editors/admins only) ─────────────────────────
create table if not exists public.passport_checkpoint_secrets (
  checkpoint_id uuid primary key references public.passport_checkpoints(id) on delete cascade,
  qr_token      text not null unique default replace(gen_random_uuid()::text, '-', ''),
  rotated_at    timestamptz not null default now()
);

comment on table public.passport_checkpoint_secrets is
  'QR token per checkpoint. Editors read it to print QR codes; tourists never see it (they scan it).';

-- Every checkpoint automatically gets a token.
create or replace function public.create_checkpoint_secret()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.passport_checkpoint_secrets (checkpoint_id)
  values (new.id)
  on conflict (checkpoint_id) do nothing;
  return new;
end;
$$;

drop trigger if exists trg_checkpoint_secret on public.passport_checkpoints;
create trigger trg_checkpoint_secret
  after insert on public.passport_checkpoints
  for each row execute function public.create_checkpoint_secret();

-- Backfill secrets for any checkpoint created before this trigger.
insert into public.passport_checkpoint_secrets (checkpoint_id)
select id from public.passport_checkpoints
on conflict (checkpoint_id) do nothing;

-- ── Stories ──────────────────────────────────────────────────
create table if not exists public.passport_stories (
  id            uuid primary key default gen_random_uuid(),
  checkpoint_id uuid not null references public.passport_checkpoints(id) on delete cascade,
  title_en      text not null,
  title_am      text,
  body_en       text,
  body_am       text,
  media_url     text,
  sort_order    int not null default 0,
  is_active     boolean not null default true,
  created_at    timestamptz not null default now()
);

create index if not exists passport_stories_checkpoint_idx
  on public.passport_stories(checkpoint_id);

-- ── Trivia ───────────────────────────────────────────────────
create table if not exists public.passport_trivia (
  id            uuid primary key default gen_random_uuid(),
  checkpoint_id uuid not null references public.passport_checkpoints(id) on delete cascade,
  question_en   text not null,
  question_am   text,
  options_en    text[] not null default '{}',
  options_am    text[] not null default '{}',
  correct_index int  not null default 0 check (correct_index >= 0),
  points        int  not null default 5 check (points >= 0),
  is_active     boolean not null default true,
  created_at    timestamptz not null default now()
);

create index if not exists passport_trivia_checkpoint_idx
  on public.passport_trivia(checkpoint_id);

-- ── Check-ins ────────────────────────────────────────────────
create table if not exists public.passport_checkins (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  checkpoint_id uuid not null references public.passport_checkpoints(id) on delete cascade,
  method        text not null default 'qr' check (method in ('qr','gps')),
  checked_in_at timestamptz not null default now(),
  unique (user_id, checkpoint_id)
);

create index if not exists passport_checkins_user_idx
  on public.passport_checkins(user_id);
create index if not exists passport_checkins_checkpoint_idx
  on public.passport_checkins(checkpoint_id);

-- ── RLS ──────────────────────────────────────────────────────
alter table public.passport_checkpoints        enable row level security;
alter table public.passport_checkpoint_secrets enable row level security;
alter table public.passport_stories            enable row level security;
alter table public.passport_trivia             enable row level security;
alter table public.passport_checkins           enable row level security;

-- Checkpoints: public sees active; editors see + manage all.
drop policy if exists passport_checkpoints_select on public.passport_checkpoints;
create policy passport_checkpoints_select
  on public.passport_checkpoints for select
  using (is_active or public.is_editor());

drop policy if exists passport_checkpoints_editor_write on public.passport_checkpoints;
create policy passport_checkpoints_editor_write
  on public.passport_checkpoints for all
  using (public.is_editor()) with check (public.is_editor());

-- Secrets: editors read; nobody writes from a client (trigger + RPC only).
drop policy if exists passport_secrets_editor_select on public.passport_checkpoint_secrets;
create policy passport_secrets_editor_select
  on public.passport_checkpoint_secrets for select
  using (public.is_editor());

revoke insert, update, delete on public.passport_checkpoint_secrets from anon, authenticated;

-- Stories + trivia: public sees active; editors manage.
drop policy if exists passport_stories_select on public.passport_stories;
create policy passport_stories_select
  on public.passport_stories for select
  using (is_active or public.is_editor());

drop policy if exists passport_stories_editor_write on public.passport_stories;
create policy passport_stories_editor_write
  on public.passport_stories for all
  using (public.is_editor()) with check (public.is_editor());

drop policy if exists passport_trivia_select on public.passport_trivia;
create policy passport_trivia_select
  on public.passport_trivia for select
  using (is_active or public.is_editor());

drop policy if exists passport_trivia_editor_write on public.passport_trivia;
create policy passport_trivia_editor_write
  on public.passport_trivia for all
  using (public.is_editor()) with check (public.is_editor());

-- Check-ins: read your own (admins read all). Writes ONLY via RPC.
drop policy if exists passport_checkins_select_own_or_admin on public.passport_checkins;
create policy passport_checkins_select_own_or_admin
  on public.passport_checkins for select
  using (user_id = auth.uid() or public.is_admin());

revoke insert, update, delete on public.passport_checkins from anon, authenticated;

-- ── passport_check_in : the only way a tourist checks in ─────
create or replace function public.passport_check_in(p_qr_token text)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid        uuid := auth.uid();
  v_checkpoint public.passport_checkpoints;
  v_rows       int := 0;
begin
  if v_uid is null then
    raise exception 'You must be signed in to check in.' using errcode = '28000';
  end if;

  select c.* into v_checkpoint
    from public.passport_checkpoint_secrets s
    join public.passport_checkpoints c on c.id = s.checkpoint_id
   where s.qr_token = p_qr_token
     and c.is_active;

  if not found then
    raise exception 'Invalid or inactive checkpoint code.' using errcode = 'P0002';
  end if;

  insert into public.passport_checkins (user_id, checkpoint_id, method)
  values (v_uid, v_checkpoint.id, 'qr')
  on conflict (user_id, checkpoint_id) do nothing;

  get diagnostics v_rows = row_count;

  return jsonb_build_object(
    'checkpoint_id',   v_checkpoint.id,
    'name_en',         v_checkpoint.name_en,
    'name_am',         v_checkpoint.name_am,
    'points',          case when v_rows > 0 then v_checkpoint.points else 0 end,
    'already_checked', v_rows = 0
  );
end;
$$;

comment on function public.passport_check_in(text) is
  'Tourist scans a checkpoint QR code. Validates the token server-side and records the check-in once.';

revoke all on function public.passport_check_in(text) from public, anon;
grant execute on function public.passport_check_in(text) to authenticated;

-- ── admin_rotate_checkpoint_qr : editors invalidate a leaked QR ──
create or replace function public.admin_rotate_checkpoint_qr(p_checkpoint_id uuid)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_token text;
begin
  if not public.is_editor() then
    raise exception 'Editors/admins only.' using errcode = '42501';
  end if;

  update public.passport_checkpoint_secrets
     set qr_token  = replace(gen_random_uuid()::text, '-', ''),
         rotated_at = now()
   where checkpoint_id = p_checkpoint_id
   returning qr_token into v_token;

  if not found then
    raise exception 'Checkpoint not found.' using errcode = 'P0002';
  end if;

  return v_token;
end;
$$;

comment on function public.admin_rotate_checkpoint_qr(uuid) is
  'Generates a fresh QR token for a checkpoint (use if a token leaks). Editors/admins only.';

revoke all on function public.admin_rotate_checkpoint_qr(uuid) from public, anon;
grant execute on function public.admin_rotate_checkpoint_qr(uuid) to authenticated;
