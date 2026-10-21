-- ============================================================
--  Rides — database tests (migration 0017).
--  Paste into Supabase → SQL Editor → Run. Everything rolls back.
--  Needs 4 ordinary accounts (no admin/editor role) in auth.users.
--  Expect: ✅ ALL RIDE TESTS PASSED
-- ============================================================
begin;

do $$
declare
  v_tourist  uuid;
  v_driver   uuid;   -- bajaj
  v_driver2  uuid;   -- bajaj, loses the race
  v_taxi     uuid;   -- taxi, must not see bajaj requests
  v_admin    uuid;
  v_ride     public.rides;
  v_drv      public.drivers;
  v_n        int;
  v_txt      text;

begin
  select id into v_tourist from auth.users
   where id not in (select user_id from public.user_roles)
   order by created_at, id limit 1 offset 0;
  select id into v_driver  from auth.users
   where id not in (select user_id from public.user_roles)
   order by created_at, id limit 1 offset 1;
  select id into v_driver2 from auth.users
   where id not in (select user_id from public.user_roles)
   order by created_at, id limit 1 offset 2;
  select id into v_taxi    from auth.users
   where id not in (select user_id from public.user_roles)
   order by created_at, id limit 1 offset 3;
  if v_taxi is null then
    raise exception 'Need at least 4 ordinary (non-team) auth users to run the ride tests';
  end if;
  -- an admin for the approval steps (temporary — rolled back)
  v_admin := v_taxi;

  -- helper: act as a signed-in user
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_driver::text, 'role', 'authenticated')::text, true);
  set local role authenticated;

  -- 1) driver applies; cannot go online before approval
  v_drv := public.driver_apply('Abebe Kebede', '+251911000001', 'bajaj', 'aa-123', 'Blue bajaj');
  if v_drv.status <> 'pending' or v_drv.plate <> 'AA-123' then
    raise exception 'FAIL 1 apply did not create a pending driver';
  end if;
  begin
    perform public.driver_set_online(true, 12.6075, 37.4592);
    raise exception 'FAIL 1b unapproved driver went online';
  exception when others then
    if sqlerrm like 'FAIL%' then raise; end if;
  end;
  raise notice 'PASS 1 driver applies as pending, cannot go online';

  -- other drivers apply
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_driver2::text, 'role', 'authenticated')::text, true);
  perform public.driver_apply('Second Driver', '+251911000002', 'bajaj', 'AA-999');
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_taxi::text, 'role', 'authenticated')::text, true);
  perform public.driver_apply('Taxi Driver', '+251911000003', 'taxi', 'TX-1');

  -- 2) a driver cannot approve themselves
  begin
    perform public.admin_set_driver_status(v_taxi, 'approved');
    raise exception 'FAIL 2 self-approval worked';
  exception when others then
    if sqlerrm like 'FAIL%' then raise; end if;
  end;
  raise notice 'PASS 2 drivers cannot approve themselves';

  -- 3) the city team approves (temporary admin role)
  reset role;
  insert into public.user_roles (user_id, role) values (v_admin, 'admin')
    on conflict (user_id) do update set role = 'admin';
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_admin::text, 'role', 'authenticated')::text, true);
  set local role authenticated;
  perform public.admin_set_driver_status(v_driver, 'approved');
  perform public.admin_set_driver_status(v_driver2, 'approved');
  perform public.admin_set_driver_status(v_taxi, 'approved');
  reset role;
  delete from public.user_roles where user_id = v_admin;
  raise notice 'PASS 3 admin approves drivers';

  -- 4) tourist gets a quote and requests a bajaj
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_tourist::text, 'role', 'authenticated')::text, true);
  set local role authenticated;
  select fare into v_n from public.ride_quote('bajaj', 12.6075, 37.4592, 12.6081, 37.4795);
  if v_n < 40 then raise exception 'FAIL 4 quote below the minimum (%)', v_n; end if;
  v_ride := public.request_ride('bajaj', 12.6075, 37.4592, 'Piassa',
                                12.6081, 37.4795, 'Debre Berhan Selassie',
                                'Sara', '+251922000000');
  if v_ride.status <> 'requested' or v_ride.rider_phone is not null then
    raise exception 'FAIL 4 request wrong (status %, phone %)', v_ride.status, v_ride.rider_phone;
  end if;
  raise notice 'PASS 4 ride requested, fare % ETB, % km, phone hidden', v_ride.fare_estimate, v_ride.distance_km;

  -- 5) one live ride at a time; outside Gondar refused
  begin
    perform public.request_ride('bajaj', 12.6075, 37.4592, 'A', 12.61, 37.46, 'B', 'Sara', '1');
    raise exception 'FAIL 5 second ride allowed';
  exception when others then
    if sqlerrm like 'FAIL%' then raise; end if;
  end;
  begin
    perform public.ride_quote('bajaj', 9.03, 38.74, 9.04, 38.75);  -- Addis Ababa
    raise exception 'FAIL 5b ride outside Gondar quoted';
  exception when others then
    if sqlerrm like 'FAIL%' then raise; end if;
  end;
  raise notice 'PASS 5 one live ride per tourist; service area enforced';

  -- 6) tourists cannot write rides directly or read phone numbers
  begin
    update public.rides set fare_estimate = 1 where id = v_ride.id;
    get diagnostics v_n = row_count;
    if v_n > 0 then raise exception 'FAIL 6 tourist changed the fare'; end if;
  exception when insufficient_privilege then null;
  end;
  begin
    select rider_phone into v_txt from public.ride_contacts where ride_id = v_ride.id;
    raise exception 'FAIL 6b ride_contacts readable';
  exception when insufficient_privilege then null;
  end;
  raise notice 'PASS 6 no direct writes; hidden phone table locked';

  -- 7) who can see the request
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_taxi::text, 'role', 'authenticated')::text, true);
  select count(*) into v_n from public.rides where id = v_ride.id;
  if v_n <> 0 then raise exception 'FAIL 7 taxi driver sees a bajaj request'; end if;
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_driver::text, 'role', 'authenticated')::text, true);
  select count(*) into v_n from public.rides where id = v_ride.id;
  if v_n <> 1 then raise exception 'FAIL 7b bajaj driver cannot see the request'; end if;
  raise notice 'PASS 7 only approved drivers of that vehicle type see it';

  -- 8) driver goes online, accepts; phone revealed to them
  perform public.driver_set_online(true, 12.6100, 37.4600);
  v_ride := public.driver_accept_ride(v_ride.id);
  if v_ride.status <> 'accepted' or v_ride.driver_id <> v_driver
     or v_ride.rider_phone <> '+251922000000' or v_ride.vehicle_plate <> 'AA-123' then
    raise exception 'FAIL 8 accept wrong';
  end if;
  raise notice 'PASS 8 driver accepted; rider phone shared with them only';

  -- 9) the second driver loses the race
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_driver2::text, 'role', 'authenticated')::text, true);
  begin
    perform public.driver_accept_ride(v_ride.id);
    raise exception 'FAIL 9 two drivers accepted one ride';
  exception when others then
    if sqlerrm like 'FAIL%' then raise; end if;
  end;
  select count(*) into v_n from public.rides where id = v_ride.id;
  if v_n <> 0 then raise exception 'FAIL 9b other driver still sees the taken ride'; end if;
  raise notice 'PASS 9 first driver wins; others lose access';

  -- 10) live location reaches the ride; invalid step refused
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_driver::text, 'role', 'authenticated')::text, true);
  perform public.driver_update_location(12.6090, 37.4595);
  select * into v_ride from public.rides where id = v_ride.id;
  if v_ride.driver_lat <> 12.6090 then raise exception 'FAIL 10 location not on the ride'; end if;
  begin
    perform public.driver_advance_ride(v_ride.id, 'completed');
    raise exception 'FAIL 10b skipped straight to completed';
  exception when others then
    if sqlerrm like 'FAIL%' then raise; end if;
  end;
  raise notice 'PASS 10 driver location live on the ride; steps enforced';

  -- 11) driver hands the ride back → requested again, phone hidden
  v_ride := public.cancel_ride(v_ride.id, 'flat tyre');
  if v_ride.status <> 'requested' or v_ride.driver_id is not null or v_ride.rider_phone is not null then
    raise exception 'FAIL 11 hand-back wrong';
  end if;
  v_ride := public.driver_accept_ride(v_ride.id);
  raise notice 'PASS 11 driver hand-back reopens the ride and hides the phone';

  -- 12) arrived → trip → completed
  v_ride := public.driver_advance_ride(v_ride.id, 'arrived');
  v_ride := public.driver_advance_ride(v_ride.id, 'in_progress');
  v_ride := public.driver_advance_ride(v_ride.id, 'completed');
  if v_ride.status <> 'completed' or v_ride.completed_at is null then
    raise exception 'FAIL 12 trip did not complete';
  end if;
  raise notice 'PASS 12 arrived → on trip → completed';

  -- 13) tourist rates once; driver rating updated
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_tourist::text, 'role', 'authenticated')::text, true);
  v_ride := public.rate_ride(v_ride.id, 5);
  begin
    perform public.rate_ride(v_ride.id, 1);
    raise exception 'FAIL 13 rated twice';
  exception when others then
    if sqlerrm like 'FAIL%' then raise; end if;
  end;
  reset role;
  select * into v_drv from public.drivers where user_id = v_driver;
  if v_drv.rating_count <> 1 or v_drv.rating_sum <> 5 or v_drv.rides_completed <> 1 then
    raise exception 'FAIL 13b driver stats wrong';
  end if;
  raise notice 'PASS 13 rating saved once; driver stats updated';

  -- 14) strangers see nothing
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_taxi::text, 'role', 'authenticated')::text, true);
  set local role authenticated;
  select count(*) into v_n from public.rides where id = v_ride.id;
  if v_n <> 0 then raise exception 'FAIL 14 another user sees the finished ride'; end if;
  select count(*) into v_n from public.drivers where user_id = v_driver;
  if v_n <> 0 then raise exception 'FAIL 14b another user sees a driver profile'; end if;
  reset role;
  set local role anon;
  select count(*) into v_n from public.rides;
  if v_n <> 0 then raise exception 'FAIL 14c anonymous visitors see rides'; end if;
  raise notice 'PASS 14 rides and driver profiles are private';

  -- 15) the drivers' request list (0019): same type only, old ones expire
  reset role;
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_tourist::text, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v_ride := public.request_ride('bajaj', 12.6075, 37.4592, 'Piassa',
                                12.6081, 37.4795, 'Debre Berhan Selassie',
                                'Sara', '+251922000000');
  select count(*) into v_n from public.driver_open_requests();
  if v_n <> 0 then raise exception 'FAIL 15 a tourist gets the drivers'' list'; end if;
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_driver2::text, 'role', 'authenticated')::text, true);
  select count(*) into v_n from public.driver_open_requests() where id = v_ride.id;
  if v_n <> 1 then raise exception 'FAIL 15b bajaj driver misses the request'; end if;
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_taxi::text, 'role', 'authenticated')::text, true);
  select count(*) into v_n from public.driver_open_requests() where id = v_ride.id;
  if v_n <> 0 then raise exception 'FAIL 15c taxi driver gets a bajaj request'; end if;
  reset role;
  update public.rides set created_at = now() - interval '20 minutes' where id = v_ride.id;
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_driver2::text, 'role', 'authenticated')::text, true);
  set local role authenticated;
  select count(*) into v_n from public.driver_open_requests() where id = v_ride.id;
  if v_n <> 0 then raise exception 'FAIL 15d a 20-minute-old request is still listed'; end if;
  reset role;
  select * into v_ride from public.rides where id = v_ride.id;
  if v_ride.status <> 'expired' or v_ride.cancelled_by <> 'system' then
    raise exception 'FAIL 15e old request not expired (status %)', v_ride.status;
  end if;
  raise notice 'PASS 15 drivers'' list: own vehicle type only; old requests expire';

  reset role;
  raise notice '✅ ALL RIDE TESTS PASSED';
end $$;

rollback;
