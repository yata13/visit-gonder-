-- ============================================================
-- 0001  Admin role plumbing (never trust a client-writable column)
--
-- Why: the live `users` table has no role column, and even if it did,
-- clients can UPDATE their own row — so a self-set role would be a
-- privilege-escalation hole. Roles live in a separate table that has
-- NO client write policy, and are read only through SECURITY DEFINER
-- helpers used by every admin RLS policy.
--
-- Idempotent: safe to run more than once.
-- ============================================================

-- ── Role assignments ────────────────────────────────────────
create table if not exists public.user_roles (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  role       text not null check (role in ('admin','editor')),
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id)
);

comment on table public.user_roles is
  'Admin/editor grants. Written by service role only (Supabase dashboard / SECURITY DEFINER RPC). Never client-writable.';

alter table public.user_roles enable row level security;

-- A signed-in user may see their OWN role (so the admin app can gate
-- its UI). Nobody can INSERT/UPDATE/DELETE from a client — no such
-- policy exists, so RLS denies all writes for anon/authenticated.
drop policy if exists user_roles_select_own on public.user_roles;
create policy user_roles_select_own
  on public.user_roles for select
  using (user_id = auth.uid());

-- Defense in depth: strip write grants so no stray policy can ever let a
-- client grant itself a role. Assignments are done by the service role.
revoke insert, update, delete on public.user_roles from anon, authenticated;

-- ── Helpers (SECURITY DEFINER so RLS on user_roles can't hide the row
--    from the very check that needs it). Fixed search_path for safety.
create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public, pg_temp
stable
as $$
  select exists (
    select 1 from public.user_roles
    where user_id = auth.uid() and role = 'admin'
  );
$$;

create or replace function public.is_editor()
returns boolean
language sql
security definer
set search_path = public, pg_temp
stable
as $$
  select exists (
    select 1 from public.user_roles
    where user_id = auth.uid() and role in ('admin','editor')
  );
$$;

comment on function public.is_admin()  is 'True if the caller has the admin role. Use in admin-only RLS policies.';
comment on function public.is_editor() is 'True if the caller has admin OR editor role. Use in content RLS policies.';

-- Callable by logged-in users (return false for anon). Never let anyone
-- run them as a way to enumerate — they only ever look at auth.uid().
revoke all on function public.is_admin()  from public;
revoke all on function public.is_editor() from public;
grant execute on function public.is_admin()  to authenticated, anon;
grant execute on function public.is_editor() to authenticated, anon;
