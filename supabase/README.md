# Supabase — the shared database 🗄️

Both apps (tourist app + admin dashboard) use **one Supabase project**.
This folder is the single source of truth for its schema.

## Folder guide

| Folder | What it is |
|---|---|
| `migrations/` | ✅ **The source of truth.** Numbered SQL migrations — every schema change lives here |
| `legacy/` | 🗃️ Old hand-run scripts, already applied to the live DB. History only — do **not** run |
| `audit/` | Security audit of the database (RLS report + attacker-simulation script) |
| `tests/` | SQL tests you can run in the SQL Editor (they roll back, change nothing) |
| `PHASE1_DEPLOY.md` | Step-by-step notes from the Phase-1 security deploy |

## How to apply a migration

No Supabase CLI needed: **Supabase Dashboard → SQL Editor → paste the file → Run.**
Run files in numeric order (`0001`, `0002`, …). All are safe to re-run.

With the CLI installed it's:

```bash
supabase link --project-ref <your-project-ref>
supabase db push
```

## Making a schema change (team rule)

1. Create a new numbered file in `migrations/`, e.g. `0006_add_reviews_table.sql`.
2. Make it **safe to re-run**: `CREATE TABLE IF NOT EXISTS`,
   `ADD COLUMN IF NOT EXISTS`, `DROP POLICY IF EXISTS` before `CREATE POLICY`.
3. Run it on the live DB via the SQL Editor.
4. Commit it in the **same pull request** as the app code that needs it.
5. Never edit tables by hand in the dashboard — teammates can't reproduce that.

## Setting up a brand-new Supabase project

The live DB was built incrementally, so a fresh one needs the old base scripts
first, then the migrations:

1. From `legacy/`, in order:
   `supabase_reset.sql` → `supabase_danger_zones.sql` → `supabase_emergency.sql`
   → `RUN_THIS_IN_SUPABASE.sql` → `ALL_IN_ONE.sql` → `SITES_COORDS.sql`
   → `RUN_THIS_SOS_UPGRADE.sql`
2. Then everything in `migrations/`, in numeric order.
3. Grant yourself admin — see `PHASE1_DEPLOY.md` ("Grant yourself admin").
4. Verify with `tests/phase1_create_booking_test.sql`
   (expect: `✅ ALL PHASE 1 DB TESTS PASSED`).

> ⚠️ `legacy/supabase_reset.sql` **drops every table**. Only ever run it on a
> fresh project, never on the live database.
