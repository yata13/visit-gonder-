# Legacy SQL — do NOT run on the live database

These files are kept for history only. They were hand-run in the Supabase SQL
Editor while the project was being built, and the live database already contains
all of them. The `supabase/migrations/` directory is now the **single source of
truth** — any new schema change goes in a new numbered migration there.

The only time these files are used again is when creating a **brand-new**
Supabase project — see the order in [`../README.md`](../README.md).

## What each file did (oldest → newest)

| File | What it did |
|---|---|
| `supabase_reset.sql` | ⚠️ Full reset — dropped and recreated the core tables (hotels, guides, sites, events, bookings, users, notifications) |
| `supabase_fix_all.sql` | Early pass adding RLS (row-level security) policies to every table |
| `supabase_fix_notnull.sql` | Dropped a NOT NULL constraint on `guides.initials` |
| `supabase_danger_zones.sql` | Created `danger_zones` — safety areas drawn in the admin |
| `supabase_emergency.sql` | Created `emergency_requests` — SOS messages from tourists |
| `supabase_commission_and_seed.sql` | First commission tracking + real hotel seed data |
| `RUN_THIS_IN_SUPABASE.sql` | Commission columns + auto-calculation trigger (3% hotels / 10% guides) |
| `ENABLE_REALTIME.sql` | Enabled realtime for instant popup notifications |
| `POSTS_TABLE.sql` | Created `posts` — the news feed |
| `SITES_COORDS.sql` | Added real GPS coordinates to the historical sites |
| `ALL_IN_ONE.sql` | Combined posts + places (map pins) + realtime into one script |
| `RUN_THIS_SOS_UPGRADE.sql` | SOS improvements (extra columns + policies) |
| `supabase_update.sql` | ❌ ARCHIVED as stale/incorrect — targets a schema that never existed and sets hotel commission to 10% (correct rates: hotels 3% / guides 10%, defined in `migrations/0002_commission_rates.sql`) |
