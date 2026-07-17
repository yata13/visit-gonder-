-- ============================================================
-- 0005  Storage buckets: public read, editor/admin write only
--
-- Why: listing images must be world-readable (the app shows them without
-- auth) but no anonymous or ordinary-user writes. Admin/editor image
-- upload (Phase 3) writes here.
--
-- Buckets match lib/core/constants/app_constants.dart.
-- Idempotent.
-- ============================================================

insert into storage.buckets (id, name, public)
values
  ('site-images',  'site-images',  true),
  ('hotel-images', 'hotel-images', true),
  ('guide-images', 'guide-images', true)
on conflict (id) do update set public = excluded.public;

-- Public read for these buckets.
drop policy if exists listing_images_public_read on storage.objects;
create policy listing_images_public_read
  on storage.objects for select
  using (bucket_id in ('site-images','hotel-images','guide-images'));

-- Only editors/admins may upload/replace/delete listing images.
drop policy if exists listing_images_editor_insert on storage.objects;
create policy listing_images_editor_insert
  on storage.objects for insert
  with check (
    bucket_id in ('site-images','hotel-images','guide-images')
    and public.is_editor()
  );

drop policy if exists listing_images_editor_update on storage.objects;
create policy listing_images_editor_update
  on storage.objects for update
  using (
    bucket_id in ('site-images','hotel-images','guide-images')
    and public.is_editor()
  )
  with check (
    bucket_id in ('site-images','hotel-images','guide-images')
    and public.is_editor()
  );

drop policy if exists listing_images_editor_delete on storage.objects;
create policy listing_images_editor_delete
  on storage.objects for delete
  using (
    bucket_id in ('site-images','hotel-images','guide-images')
    and public.is_editor()
  );

-- NOTE: run supabase/audit/00_inspect_current_state.sql (and the storage
-- section of the exit-check) to confirm no OTHER bucket allows anon writes.
