-- ============================================================
--  Partner portal — database tests (migration 0018).
--  Paste into Supabase → SQL Editor → Run. Everything rolls back.
--  Needs 3 ordinary accounts (no team role) and 1 published hotel
--  with a price. Expect: ✅ ALL PARTNER TESTS PASSED
-- ============================================================
begin;

do $$
declare
  v_tourist uuid;
  v_owner   uuid;
  v_other   uuid;
  v_admin   uuid;
  v_hotel   uuid;
  v_hotel2  uuid;
  v_booking public.bookings;
  v_h       public.hotels;
  v_n       int;
  v_email   text;
begin
  select id into v_tourist from auth.users
   where id not in (select user_id from public.user_roles)
   order by created_at, id limit 1 offset 0;
  select id, email into v_owner, v_email from auth.users
   where id not in (select user_id from public.user_roles)
   order by created_at, id limit 1 offset 1;
  select id into v_other from auth.users
   where id not in (select user_id from public.user_roles)
   order by created_at, id limit 1 offset 2;
  if v_other is null then
    raise exception 'Need at least 3 ordinary auth users';
  end if;
  v_admin := v_other;  -- temporary team role for the link step (rolled back)

  select id into v_hotel from public.hotels
   where coalesce(publish_status, 'published') = 'published' and price is not null
   order by created_at limit 1;
  if v_hotel is null then raise exception 'Need a published hotel with a price'; end if;
  insert into public.hotels (name_en, price, publish_status) values ('Not mine', 900, 'draft')
    returning id into v_hotel2;

  -- 1) a partner asks to be linked
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_owner::text, 'role', 'authenticated', 'email', v_email)::text, true);
  set local role authenticated;
  insert into public.partner_requests (email, business_type, business_name, phone)
  values (v_email, 'hotel', 'My Hotel', '+251900000000');
  begin
    insert into public.partner_requests (user_id, business_type, business_name)
    values (v_tourist, 'hotel', 'Pretend to be someone else');
    raise exception 'FAIL 1 request filed for another user';
  exception when others then
    if sqlerrm like 'FAIL%' then raise; end if;
  end;
  raise notice 'PASS 1 partner request saved (own account only)';

  -- 2) the partner cannot link themselves
  begin
    perform public.admin_link_owner('hotel', v_hotel, v_email);
    raise exception 'FAIL 2 partner linked themselves';
  exception when others then
    if sqlerrm like 'FAIL%' then raise; end if;
  end;
  raise notice 'PASS 2 only the city team can link owners';

  -- 3) the city team links the owner; request marked linked
  reset role;
  insert into public.user_roles (user_id, role) values (v_admin, 'admin')
    on conflict (user_id) do update set role = 'admin';
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_admin::text, 'role', 'authenticated')::text, true);
  set local role authenticated;
  perform public.admin_link_owner('hotel', v_hotel, v_email);
  reset role;
  delete from public.user_roles where user_id = v_admin;
  select count(*) into v_n from public.partner_requests where user_id = v_owner and status = 'linked';
  if v_n <> 1 then raise exception 'FAIL 3 request not marked linked'; end if;
  raise notice 'PASS 3 admin linked the owner';

  -- 4) a tourist books the hotel
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_tourist::text, 'role', 'authenticated', 'email', 'tourist@x.com')::text, true);
  set local role authenticated;
  v_booking := public.create_booking('hotel', v_hotel, current_date + 3, current_date + 5, 2,
                                     'Sara Tourist', '+251922000000');

  -- 5) the owner sees it; another user does not
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_owner::text, 'role', 'authenticated', 'email', v_email)::text, true);
  select count(*) into v_n from public.bookings where id = v_booking.id;
  if v_n <> 1 then raise exception 'FAIL 5 owner cannot see the booking'; end if;
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_other::text, 'role', 'authenticated')::text, true);
  select count(*) into v_n from public.bookings where id = v_booking.id;
  if v_n <> 0 then raise exception 'FAIL 5b stranger sees the booking'; end if;
  raise notice 'PASS 5 owner sees their bookings; others do not';

  -- 6) only the owner can confirm; bad transitions refused
  begin
    perform public.partner_set_booking_status(v_booking.id, 'confirmed');
    raise exception 'FAIL 6 stranger confirmed the booking';
  exception when others then
    if sqlerrm like 'FAIL%' then raise; end if;
  end;
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_owner::text, 'role', 'authenticated', 'email', v_email)::text, true);
  v_booking := public.partner_set_booking_status(v_booking.id, 'confirmed');
  if v_booking.status <> 'confirmed' then raise exception 'FAIL 6b not confirmed'; end if;
  begin
    perform public.partner_set_booking_status(v_booking.id, 'pending');
    raise exception 'FAIL 6c moved back to pending';
  exception when others then
    if sqlerrm like 'FAIL%' then raise; end if;
  end;
  raise notice 'PASS 6 owner confirms; transitions enforced';

  -- 7) owner edits price/description; cannot publish or touch others
  v_h := public.partner_update_hotel(v_hotel, 'Rooms with a castle view', '+251911223344',
                                     'Near Piassa', 1750, null);
  if v_h.price <> 1750 then raise exception 'FAIL 7 price not saved'; end if;
  begin
    update public.hotels set publish_status = 'published' where id = v_hotel2;
    get diagnostics v_n = row_count;
    if v_n > 0 then raise exception 'FAIL 7b owner published a hotel directly'; end if;
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.partner_update_hotel(v_hotel2, 'x', 'x', 'x', 10, null);
    raise exception 'FAIL 7c edited someone else''s hotel';
  exception when others then
    if sqlerrm like 'FAIL%' then raise; end if;
  end;
  raise notice 'PASS 7 owner edits own hotel only; publishing stays with the team';

  -- 8) availability: own calendar yes, others no
  insert into public.availability (business_type, business_id, day, capacity, is_closed)
  values ('hotel', v_hotel, current_date + 10, 0, true);
  begin
    insert into public.availability (business_type, business_id, day, capacity)
    values ('hotel', v_hotel2, current_date + 10, 5);
    raise exception 'FAIL 8 wrote another hotel''s calendar';
  exception when others then
    if sqlerrm like 'FAIL%' then raise; end if;
  end;
  raise notice 'PASS 8 owner manages own availability only';

  -- 9) the tourist sees the confirmation on their booking
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_tourist::text, 'role', 'authenticated', 'email', 'tourist@x.com')::text, true);
  select count(*) into v_n from public.bookings where id = v_booking.id and status = 'confirmed';
  if v_n <> 1 then raise exception 'FAIL 9 tourist does not see the confirmation'; end if;
  raise notice 'PASS 9 tourist sees the confirmed booking';

  reset role;
  raise notice '✅ ALL PARTNER TESTS PASSED';
end $$;

rollback;
