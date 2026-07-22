-- ============================================================
-- 0007  Vendor/owner links on bookable businesses
--
-- Why: hotels and guides are the platform's businesses/vendors.
-- The admin needs to see who owns each listing and how to reach
-- them. hotels already have a contact column; guides do not.
-- owner_id links a listing to the auth account of the business
-- owner (nullable — many listings are city-managed).
--
-- Note: an owner self-service portal (owners editing their own
-- listing) is a later phase; no owner RLS policies are added here.
--
-- Idempotent.
-- ============================================================

alter table public.hotels add column if not exists owner_id uuid references auth.users(id) on delete set null;
alter table public.guides add column if not exists owner_id uuid references auth.users(id) on delete set null;
alter table public.guides add column if not exists contact  text;

comment on column public.hotels.owner_id is 'Auth user who owns/manages this hotel. NULL = city-managed.';
comment on column public.guides.owner_id is 'Auth user who owns this guide profile. NULL = city-managed.';
comment on column public.guides.contact  is 'Phone / WhatsApp / email shown to the admin (and later to tourists).';

create index if not exists hotels_owner_id_idx on public.hotels(owner_id);
create index if not exists guides_owner_id_idx on public.guides(owner_id);
