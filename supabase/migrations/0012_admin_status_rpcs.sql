-- ============================================================
-- 0012  Admin actions the old Flutter admin did with open RLS
--
-- Why: 0003/0004 made bookings and emergency_requests immutable to
-- clients (all writes revoked). The admin dashboard still needs the
-- old admin's actions: approve/reject a booking, move an SOS request
-- through pending → responding → resolved, and clean up old requests.
-- These SECURITY DEFINER functions are the controlled path — they
-- check is_editor() themselves, so RLS stays locked for everyone else.
--
-- Idempotent.
-- ============================================================

-- ── Booking status (old admin: APPROVE / REJECT buttons) ─────
create or replace function public.admin_set_booking_status(
  p_booking_id uuid,
  p_status     text
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_editor() then
    raise exception 'Editors/admins only.' using errcode = '42501';
  end if;
  if p_status not in ('pending','approved','rejected','confirmed','cancelled') then
    raise exception 'Invalid booking status.' using errcode = '22023';
  end if;

  update public.bookings set status = p_status where id = p_booking_id;
  if not found then
    raise exception 'Booking not found.' using errcode = 'P0002';
  end if;
end;
$$;

comment on function public.admin_set_booking_status(uuid, text) is
  'Admin/editor approves, rejects, confirms or cancels a booking. The only admin write path to bookings.';

-- ── Emergency status (pending → responding → resolved) ───────
create or replace function public.admin_set_emergency_status(
  p_id     uuid,
  p_status text
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_editor() then
    raise exception 'Editors/admins only.' using errcode = '42501';
  end if;
  if p_status not in ('pending','responding','resolved') then
    raise exception 'Invalid emergency status.' using errcode = '22023';
  end if;

  update public.emergency_requests set status = p_status where id = p_id;
  if not found then
    raise exception 'Request not found.' using errcode = 'P0002';
  end if;
end;
$$;

comment on function public.admin_set_emergency_status(uuid, text) is
  'Admin/editor updates an SOS request status. Tourists still cannot touch these rows.';

-- ── Emergency delete (old admin could remove handled requests) ──
create or replace function public.admin_delete_emergency(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_editor() then
    raise exception 'Editors/admins only.' using errcode = '42501';
  end if;
  delete from public.emergency_requests where id = p_id;
  if not found then
    raise exception 'Request not found.' using errcode = 'P0002';
  end if;
end;
$$;

comment on function public.admin_delete_emergency(uuid) is
  'Admin/editor removes an emergency request from the log.';

-- ── Grants ───────────────────────────────────────────────────
revoke all on function public.admin_set_booking_status(uuid, text) from public, anon;
revoke all on function public.admin_set_emergency_status(uuid, text) from public, anon;
revoke all on function public.admin_delete_emergency(uuid) from public, anon;
grant execute on function public.admin_set_booking_status(uuid, text) to authenticated;
grant execute on function public.admin_set_emergency_status(uuid, text) to authenticated;
grant execute on function public.admin_delete_emergency(uuid) to authenticated;
