-- ============================================================
-- 0013  Staff role — hired employees (call-center / operations)
--
-- The team is hiring managers who handle tourist calls, SOS
-- requests and bookings. A `staff` member may use everything in
-- the admin dashboard EXCEPT:
--   * finance (commission / sales money — admin only in the app;
--     the commissions ledger table stays fully locked to clients)
--   * Users & Roles (admin only)
--
-- How: is_editor() now means "any team member" (admin, editor or
-- staff) — every content policy and the 0012 admin actions inherit
-- that automatically. Bookings and SOS lists open up to the team
-- too, because a call-center agent must see them to work.
-- is_admin() is unchanged: money + user management stay admin-only.
--
-- Idempotent.
-- ============================================================

-- ── Allow the new role value ─────────────────────────────────
alter table public.user_roles drop constraint if exists user_roles_role_check;
alter table public.user_roles
  add constraint user_roles_role_check check (role in ('admin','editor','staff'));

comment on table public.user_roles is
  'Team roles: admin (everything), editor (content), staff (operations). Written only via admin_grant_role/admin_revoke_role.';

-- ── is_editor() = any team member ────────────────────────────
create or replace function public.is_editor()
returns boolean
language sql
security definer
set search_path = public, pg_temp
stable
as $$
  select exists (
    select 1 from public.user_roles
    where user_id = auth.uid() and role in ('admin','editor','staff')
  );
$$;

comment on function public.is_editor() is
  'True if the caller is admin, editor or staff. Gates content management and daily operations.';

-- ── Team members see all bookings (needed to manage them) ────
drop policy if exists bookings_select_own on public.bookings;
create policy bookings_select_own
  on public.bookings for select
  using (
    user_id = auth.uid()
    or (user_email is not null and user_email = (auth.jwt() ->> 'email'))
    or public.is_editor()
  );

-- ── Team members see all SOS requests ────────────────────────
drop policy if exists er_select_own_or_admin on public.emergency_requests;
create policy er_select_own_or_admin
  on public.emergency_requests for select
  using (user_id = auth.uid() or public.is_editor());

-- ── Role management accepts the new role ─────────────────────
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
  if p_role not in ('admin','editor','staff') then
    raise exception 'Role must be admin, editor or staff.' using errcode = '22023';
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
