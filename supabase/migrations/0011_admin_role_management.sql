-- ============================================================
-- 0011  Users & roles for the admin dashboard
--
-- Why: the admin needs to (a) list all users with their email,
-- (b) see everyone's role, (c) grant/revoke roles — all with the
-- anon key, which today is impossible: user_roles only shows your
-- own row and is never client-writable (by design, see 0001).
--
-- This keeps that design: roles still live in user_roles, writes
-- still never come from a plain client — they go through
-- SECURITY DEFINER RPCs that check is_admin() themselves.
--
-- Also: public.users gets an email column, auto-filled on signup
-- by a trigger on auth.users (the app's client-side upsert stays
-- as a fallback but is no longer the only path).
--
-- Idempotent.
-- ============================================================

-- ── users.email + signup trigger ─────────────────────────────
alter table public.users add column if not exists email      text;
alter table public.users add column if not exists created_at timestamptz default now();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.users (id, email, full_name)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data ->> 'full_name', '')
  )
  on conflict (id) do update
    set email = excluded.email;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Backfill: profile rows for existing auth users + missing emails.
insert into public.users (id, email, full_name)
select au.id, au.email, coalesce(au.raw_user_meta_data ->> 'full_name', '')
from auth.users au
on conflict (id) do nothing;

update public.users u
   set email = au.email
  from auth.users au
 where au.id = u.id
   and u.email is null;

-- ── Admins can list every role ───────────────────────────────
drop policy if exists user_roles_select_admin on public.user_roles;
create policy user_roles_select_admin
  on public.user_roles for select
  using (public.is_admin());

-- ── admin_grant_role / admin_revoke_role ─────────────────────
create or replace function public.admin_grant_role(p_user_id uuid, p_role text)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_admin() then
    raise exception 'Admins only.' using errcode = '42501';
  end if;
  if p_role not in ('admin','editor') then
    raise exception 'Role must be admin or editor.' using errcode = '22023';
  end if;
  if not exists (select 1 from auth.users where id = p_user_id) then
    raise exception 'User not found.' using errcode = 'P0002';
  end if;

  insert into public.user_roles (user_id, role, created_by)
  values (p_user_id, p_role, auth.uid())
  on conflict (user_id) do update
    set role = excluded.role,
        created_by = excluded.created_by;
end;
$$;

create or replace function public.admin_revoke_role(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_admin() then
    raise exception 'Admins only.' using errcode = '42501';
  end if;
  if p_user_id = auth.uid() then
    raise exception 'You cannot remove your own admin role.' using errcode = '22023';
  end if;

  delete from public.user_roles where user_id = p_user_id;
end;
$$;

comment on function public.admin_grant_role(uuid, text) is
  'Admin grants/changes a user''s role (admin or editor). The only client path for role writes.';
comment on function public.admin_revoke_role(uuid) is
  'Admin removes a user''s role. Cannot remove your own admin role (no locking yourself out).';

revoke all on function public.admin_grant_role(uuid, text) from public, anon;
revoke all on function public.admin_revoke_role(uuid)      from public, anon;
grant execute on function public.admin_grant_role(uuid, text) to authenticated;
grant execute on function public.admin_revoke_role(uuid)      to authenticated;
