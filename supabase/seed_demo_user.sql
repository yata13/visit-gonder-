-- ============================================================
-- Demo login for testing the tourist app
--
-- Creates (or resets) a ready-to-use, already-confirmed account:
--     email:    demo@visitgondar.com
--     password: Demo1234!
-- The app's login screen is pre-filled with exactly these values.
--
-- Run in: Supabase Dashboard → SQL Editor → paste → Run.
-- Safe to run again: it just resets the password and confirms it.
-- Demo only — do NOT run this on the real production project.
-- ============================================================

create extension if not exists pgcrypto;

do $$
declare
  v_email    text := 'demo@visitgondar.com';
  v_password text := 'Demo1234!';
  v_id       uuid;
begin
  select id into v_id from auth.users where email = v_email;

  if v_id is null then
    v_id := gen_random_uuid();
    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password,
      email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
      created_at, updated_at,
      confirmation_token, recovery_token, email_change_token_new, email_change
    ) values (
      '00000000-0000-0000-0000-000000000000', v_id, 'authenticated',
      'authenticated', v_email, crypt(v_password, gen_salt('bf')),
      now(),
      '{"provider":"email","providers":["email"]}',
      '{"full_name":"Demo Tourist","country":"Ethiopia"}',
      now(), now(),
      '', '', '', ''
    );
  else
    update auth.users
       set encrypted_password = crypt(v_password, gen_salt('bf')),
           email_confirmed_at = coalesce(email_confirmed_at, now()),
           banned_until       = null,
           updated_at         = now()
     where id = v_id;
  end if;

  -- Email/password sign-in needs a matching identity row.
  if not exists (
    select 1 from auth.identities
     where user_id = v_id and provider = 'email'
  ) then
    insert into auth.identities (
      id, user_id, provider_id, provider, identity_data,
      last_sign_in_at, created_at, updated_at
    ) values (
      gen_random_uuid(), v_id, v_id::text, 'email',
      jsonb_build_object('sub', v_id::text, 'email', v_email,
                         'email_verified', true),
      now(), now(), now()
    );
  end if;

  -- App profile row (the signup trigger from 0011 also does this).
  insert into public.users (id, full_name, language)
  values (v_id, 'Demo Tourist', 'en')
  on conflict (id) do nothing;

  raise notice 'Demo user ready: % / %', v_email, v_password;
end $$;
