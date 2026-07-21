-- ============================================================
-- 0006  publish_status on ALL content tables (Phase 2)
--
-- Why: the admin needs a draft → pending → published workflow on
-- every listing type. hotels & guides already have publish_status;
-- sites, places, events and posts do not. New columns default to
-- 'published' so every row the tourist app shows today stays visible.
-- SELECT policies are tightened the same way hotels/guides already
-- work: the public sees only published rows, editors see everything.
--
-- Allowed values (enforced by the admin app, kept as text for
-- compatibility with the existing hotels/guides columns):
--   'draft' | 'pending' | 'published'
--
-- Idempotent: safe to run more than once.
-- ============================================================

alter table public.sites  add column if not exists publish_status text default 'published';
alter table public.places add column if not exists publish_status text default 'published';
alter table public.events add column if not exists publish_status text default 'published';
alter table public.posts  add column if not exists publish_status text default 'published';

-- Normalise any NULLs so the policies below behave predictably.
update public.sites  set publish_status = 'published' where publish_status is null;
update public.places set publish_status = 'published' where publish_status is null;
update public.events set publish_status = 'published' where publish_status is null;
update public.posts  set publish_status = 'published' where publish_status is null;

comment on column public.sites.publish_status  is 'draft | pending | published — only published rows are shown to the public.';
comment on column public.places.publish_status is 'draft | pending | published — only published rows are shown to the public.';
comment on column public.events.publish_status is 'draft | pending | published — only published rows are shown to the public.';
comment on column public.posts.publish_status  is 'draft | pending | published — only published rows are shown to the public.';

-- ── Tighten public SELECT to published-only (editors see all) ──
-- sites
drop policy if exists sites_select_public    on public.sites;
drop policy if exists sites_select_published on public.sites;
create policy sites_select_published
  on public.sites for select
  using (coalesce(publish_status,'published') = 'published' or public.is_editor());

-- places
drop policy if exists places_select_public    on public.places;
drop policy if exists places_select_published on public.places;
create policy places_select_published
  on public.places for select
  using (coalesce(publish_status,'published') = 'published' or public.is_editor());

-- events
drop policy if exists events_select_public    on public.events;
drop policy if exists events_select_published on public.events;
create policy events_select_published
  on public.events for select
  using (coalesce(publish_status,'published') = 'published' or public.is_editor());

-- posts
drop policy if exists posts_select_public    on public.posts;
drop policy if exists posts_select_published on public.posts;
create policy posts_select_published
  on public.posts for select
  using (coalesce(publish_status,'published') = 'published' or public.is_editor());
