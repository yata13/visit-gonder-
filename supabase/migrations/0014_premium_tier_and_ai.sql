-- ============================================================
-- 0014  Two kinds of visitor (Free / Premium) + "Ask Gondar" AI
--
-- From the proposal (v15, pages 7 and 9):
--   * Free (every visitor): sites, maps, verified listings,
--     ratings, SOS + safety notices. Safety is always free.
--   * Premium (optional upgrade): Ask Gondar AI chat, and later
--     the other premium extras.
--   * The AI only answers from information the City approves.
--
-- Same security design as user_roles (0001): the tier lives in its
-- own table that NO client can write. A visitor can read their own
-- tier; only admins change it, through admin_set_user_tier().
-- Visitors ask for Premium through premium_requests; the admin
-- approves in the dashboard (payment is decided with the City later).
--
-- ai_knowledge = the City-approved facts the AI is allowed to use.
-- ai_questions = a log of what was asked (for the City's evidence
-- and to rate-limit). Both are read by the ask-gondar edge function.
--
-- Idempotent.
-- ============================================================

-- ── Tiers ────────────────────────────────────────────────────
create table if not exists public.user_tiers (
  user_id       uuid primary key references auth.users(id) on delete cascade,
  tier          text not null default 'free' check (tier in ('free','premium')),
  premium_until timestamptz,                 -- null = no end date
  updated_at    timestamptz not null default now(),
  updated_by    uuid references auth.users(id)
);

comment on table public.user_tiers is
  'Visitor plan: free or premium. Written only via admin_set_user_tier(). No row = free.';

alter table public.user_tiers enable row level security;

drop policy if exists user_tiers_select_own on public.user_tiers;
create policy user_tiers_select_own
  on public.user_tiers for select
  using (user_id = auth.uid() or public.is_admin());

revoke insert, update, delete on public.user_tiers from anon, authenticated;

-- True if the caller has an active Premium plan. Team members
-- (admin/editor/staff) count as premium so they can test the app.
create or replace function public.is_premium()
returns boolean
language sql
security definer
set search_path = public, pg_temp
stable
as $$
  select public.is_editor() or exists (
    select 1 from public.user_tiers
    where user_id = auth.uid()
      and tier = 'premium'
      and (premium_until is null or premium_until > now())
  );
$$;

comment on function public.is_premium() is
  'True if the caller has an active Premium plan (team members always do).';

revoke all on function public.is_premium() from public;
grant execute on function public.is_premium() to authenticated, anon;

create or replace function public.admin_set_user_tier(
  p_user_id uuid,
  p_tier    text,
  p_until   timestamptz default null
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_admin() then
    raise exception 'Admins only.' using errcode = '42501';
  end if;
  if p_tier not in ('free','premium') then
    raise exception 'Tier must be free or premium.' using errcode = '22023';
  end if;
  if not exists (select 1 from auth.users where id = p_user_id) then
    raise exception 'User not found.' using errcode = 'P0002';
  end if;

  insert into public.user_tiers (user_id, tier, premium_until, updated_at, updated_by)
  values (p_user_id, p_tier,
          case when p_tier = 'premium' then p_until end,
          now(), auth.uid())
  on conflict (user_id) do update
    set tier          = excluded.tier,
        premium_until = excluded.premium_until,
        updated_at    = excluded.updated_at,
        updated_by    = excluded.updated_by;

  -- Approving someone closes their open request.
  if p_tier = 'premium' then
    update public.premium_requests
       set status = 'approved', handled_at = now(), handled_by = auth.uid()
     where user_id = p_user_id and status = 'pending';
  end if;
end;
$$;

-- ── Premium requests (visitor asks, admin approves) ──────────
create table if not exists public.premium_requests (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  email      text,
  note       text,
  status     text not null default 'pending'
             check (status in ('pending','approved','rejected')),
  created_at timestamptz not null default now(),
  handled_at timestamptz,
  handled_by uuid references auth.users(id)
);

-- One open request per visitor.
create unique index if not exists premium_requests_one_pending
  on public.premium_requests (user_id) where status = 'pending';

alter table public.premium_requests enable row level security;

drop policy if exists premium_requests_select on public.premium_requests;
create policy premium_requests_select
  on public.premium_requests for select
  using (user_id = auth.uid() or public.is_admin());

drop policy if exists premium_requests_insert_own on public.premium_requests;
create policy premium_requests_insert_own
  on public.premium_requests for insert
  with check (user_id = auth.uid() and status = 'pending');

drop policy if exists premium_requests_update_admin on public.premium_requests;
create policy premium_requests_update_admin
  on public.premium_requests for update
  using (public.is_admin())
  with check (public.is_admin());

-- Function defined after premium_requests exists (it references it).
revoke all on function public.admin_set_user_tier(uuid, text, timestamptz) from public, anon;
grant execute on function public.admin_set_user_tier(uuid, text, timestamptz) to authenticated;

-- ── City-approved knowledge for the AI ───────────────────────
create table if not exists public.ai_knowledge (
  id             uuid primary key default gen_random_uuid(),
  title          text not null,
  title_am       text,
  body           text,
  body_am        text,
  category       text default 'general',
  publish_status text default 'draft',
  created_at     timestamptz not null default now()
);

comment on table public.ai_knowledge is
  'Facts the Ask Gondar AI may use. Only published rows reach the AI.';

alter table public.ai_knowledge enable row level security;

drop policy if exists ai_knowledge_select on public.ai_knowledge;
create policy ai_knowledge_select
  on public.ai_knowledge for select
  using (publish_status = 'published' or public.is_editor());

drop policy if exists ai_knowledge_write_editor on public.ai_knowledge;
create policy ai_knowledge_write_editor
  on public.ai_knowledge for all
  using (public.is_editor())
  with check (public.is_editor());

-- ── Question log (written by the edge function's service role) ─
create table if not exists public.ai_questions (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid references auth.users(id) on delete set null,
  mode       text not null default 'visitor' check (mode in ('visitor','city')),
  lang       text,
  question   text not null,
  answer     text,
  created_at timestamptz not null default now()
);

create index if not exists ai_questions_user_day
  on public.ai_questions (user_id, created_at desc);

alter table public.ai_questions enable row level security;

drop policy if exists ai_questions_select on public.ai_questions;
create policy ai_questions_select
  on public.ai_questions for select
  using (user_id = auth.uid() or public.is_editor());

revoke insert, update, delete on public.ai_questions from anon, authenticated;
