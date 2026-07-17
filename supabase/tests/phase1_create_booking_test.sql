-- ============================================================
-- Phase 1 smoke + RLS tests. Run in the Supabase SQL editor AFTER
-- applying migrations 0001–0005. Wrapped in a transaction that ROLLS
-- BACK — it inserts nothing permanently and changes no data.
--
-- Prints "PASS n ..." NOTICEs; RAISES on the first failure. If you see
-- "✅ ALL PHASE 1 DB TESTS PASSED", every check held.
-- Requires: >= 2 rows in auth.users, >= 1 published hotel with a price.
-- ============================================================
begin;

do $$
declare
  v_userA uuid; v_userB uuid;
  v_hotel uuid; v_hotel_price numeric;
  v_row public.bookings;
  v_expect_total numeric; v_expect_comm numeric;
  v_count int;
begin
  -- ── fixtures (as the SQL-editor superuser) ──
  select id into v_userA from auth.users order by created_at limit 1;
  select id into v_userB from auth.users where id <> v_userA order by created_at limit 1;
  select id, price into v_hotel, v_hotel_price
    from public.hotels
   where coalesce(publish_status,'published') = 'published' and price is not null
   limit 1;

  if v_userA is null or v_userB is null then
    raise exception 'Need at least 2 auth users to run RLS tests'; end if;
  if v_hotel is null then
    raise exception 'Need a published hotel with a price'; end if;

  -- ── become user A (RLS now applies) ──
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_userA::text, 'email','userA@test.local','role','authenticated')::text, true);
  set local role authenticated;

  -- 1) price + commission are server-computed (2 nights x 2 guests, 3%)
  v_row := public.create_booking('hotel', v_hotel, current_date+1, current_date+3, 2, 'Test A', '+251911000000');
  v_expect_total := round(v_hotel_price * 2 * 2, 2);
  v_expect_comm  := round(v_expect_total * 0.03, 2);
  if v_row.total_price <> v_expect_total then
    raise exception 'FAIL 1 price: got % expected %', v_row.total_price, v_expect_total; end if;
  if v_row.commission_amount <> v_expect_comm then
    raise exception 'FAIL 1 commission: got % expected %', v_row.commission_amount, v_expect_comm; end if;
  if v_row.status <> 'pending' then raise exception 'FAIL 1 default status not pending'; end if;
  raise notice 'PASS 1 create_booking server-side price=% commission=%', v_row.total_price, v_row.commission_amount;

  -- 2) invalid date range rejected
  begin
    perform public.create_booking('hotel', v_hotel, current_date+3, current_date+1, 1, 'X','Y');
    raise exception 'FAIL 2 invalid date range accepted';
  exception when others then
    if sqlerrm like 'FAIL%' then raise; end if;
    raise notice 'PASS 2 invalid date range rejected';
  end;

  -- 3) past start date rejected
  begin
    perform public.create_booking('hotel', v_hotel, current_date-1, current_date+1, 1, 'X','Y');
    raise exception 'FAIL 3 past start date accepted';
  exception when others then
    if sqlerrm like 'FAIL%' then raise; end if;
    raise notice 'PASS 3 past start date rejected';
  end;

  -- 4) direct client INSERT into bookings denied (grant revoked)
  begin
    insert into public.bookings(item_type,item_name,customer_name,customer_contact,booking_date,status,price,total_price)
    values ('hotel','hack','h','h',current_date,'pending',1,1);
    raise exception 'FAIL 4 direct booking INSERT succeeded';
  exception when others then
    if sqlerrm like 'FAIL%' then raise; end if;
    raise notice 'PASS 4 direct booking INSERT denied';
  end;

  -- 5) direct client UPDATE denied / affects nothing
  begin
    update public.bookings set status='confirmed' where id = v_row.id;
    get diagnostics v_count = row_count;
    if v_count > 0 then raise exception 'FAIL 5 client UPDATE changed % rows', v_count; end if;
    raise notice 'PASS 5 client UPDATE affected 0 rows';
  exception when others then
    if sqlerrm like 'FAIL%' then raise; end if;
    raise notice 'PASS 5 client UPDATE denied';
  end;

  -- 6) commissions ledger has no client access
  begin
    perform 1 from public.commissions limit 1;
    raise exception 'FAIL 6 client read commissions';
  exception when others then
    if sqlerrm like 'FAIL%' then raise; end if;
    raise notice 'PASS 6 commissions read denied';
  end;

  -- 7) cannot self-grant a role
  begin
    insert into public.user_roles(user_id, role) values (v_userA, 'admin');
    raise exception 'FAIL 7 self role grant succeeded';
  exception when others then
    if sqlerrm like 'FAIL%' then raise; end if;
    raise notice 'PASS 7 self role grant denied';
  end;

  -- 8) RLS: user B cannot see user A's booking
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_userB::text, 'email','userB@test.local','role','authenticated')::text, true);
  select count(*) into v_count from public.bookings where id = v_row.id;
  if v_count <> 0 then raise exception 'FAIL 8 user B sees user A booking (% rows)', v_count; end if;
  raise notice 'PASS 8 cross-user booking read blocked by RLS';

  -- 9) RLS: user A can see own booking
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_userA::text, 'email','userA@test.local','role','authenticated')::text, true);
  select count(*) into v_count from public.bookings where id = v_row.id;
  if v_count <> 1 then raise exception 'FAIL 9 owner cannot see own booking'; end if;
  raise notice 'PASS 9 owner can read own booking';

  -- 10) owner can cancel own pending booking via RPC
  v_row := public.cancel_my_booking(v_row.id);
  if v_row.status <> 'cancelled' then raise exception 'FAIL 10 cancel did not set status'; end if;
  raise notice 'PASS 10 cancel_my_booking works for owner';

  reset role;
  raise notice '✅ ALL PHASE 1 DB TESTS PASSED';
end $$;

rollback;
