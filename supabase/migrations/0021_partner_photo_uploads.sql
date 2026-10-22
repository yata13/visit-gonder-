-- ============================================================
-- 0021  Partners upload photos of their own listing
--
-- The Partners website uploads hotel / guide photos to the public
-- listing buckets (0005), inside a folder named after the business:
--     hotel-images/partners/<hotel id>/<file>
--     guide-images/partners/<guide id>/<file>
-- Only the linked owner of that hotel / guide may add or remove
-- files there. The city team keeps full access (0005 policies).
-- Idempotent.
-- ============================================================

-- True when the folder name is the id of a business I own. A folder
-- that is not an id is simply "no".
create or replace function public.owns_business_folder(p_type text, p_folder text)
returns boolean
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  return public.owns_business(p_type, p_folder::uuid);
exception when invalid_text_representation then
  return false;
end;
$$;
revoke all on function public.owns_business_folder(text, text) from public;
grant execute on function public.owns_business_folder(text, text) to authenticated;

drop policy if exists listing_images_owner_insert on storage.objects;
create policy listing_images_owner_insert on storage.objects for insert
  with check (
    bucket_id in ('hotel-images', 'guide-images')
    and (storage.foldername(name))[1] = 'partners'
    and public.owns_business_folder(
          case bucket_id when 'hotel-images' then 'hotel' else 'guide' end,
          (storage.foldername(name))[2])
  );

drop policy if exists listing_images_owner_delete on storage.objects;
create policy listing_images_owner_delete on storage.objects for delete
  using (
    bucket_id in ('hotel-images', 'guide-images')
    and (storage.foldername(name))[1] = 'partners'
    and public.owns_business_folder(
          case bucket_id when 'hotel-images' then 'hotel' else 'guide' end,
          (storage.foldername(name))[2])
  );
