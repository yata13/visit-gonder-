# Phase 1 — Deploy & Verify

## ⚠️ Why this is urgent
Right now, with the public anon key (shipped in every APK), anyone can **read all
customer PII + live emergency GPS**, and **UPDATE/DELETE almost every table**
(`DELETE FROM bookings` / `users` / `emergency_requests` with no filter succeeds).
Treat this as an emergency deploy.

## What to run (in order)

You have no Supabase CLI locally, so use the **Dashboard → SQL Editor**. Paste and
Run each file **in numeric order**:

1. `supabase/migrations/0001_security_helpers_and_roles.sql`
2. `supabase/migrations/0002_commission_rates.sql`
3. `supabase/migrations/0003_rls_core_tables.sql`
4. `supabase/migrations/0004_bookings_server_side.sql`
5. `supabase/migrations/0005_storage_buckets.sql`

Each is idempotent (safe to re-run). If you later install the CLI:
`supabase link --project-ref cukfcclewuqaebnhhamo && supabase db push`.

## Grant yourself admin (once)
After migration 0001, in the SQL editor (service role):
```sql
insert into public.user_roles (user_id, role)
values ('<YOUR-AUTH-USER-UUID>', 'admin')
on conflict (user_id) do update set role = 'admin';
```
Find your UUID in Dashboard → Authentication → Users. Editors get `'editor'`.

## Verify

**A. Behaviour tests (rolls back, changes nothing):**
Run `supabase/tests/phase1_create_booking_test.sql` in the SQL editor. Expect
`✅ ALL PHASE 1 DB TESTS PASSED`.

**B. Black-box exit check (as an attacker with the anon key):**
```bash
bash supabase/audit/exit_check.sh
```
Before migrations: 9 FAIL / 4 PASS (the vulnerable baseline).
After migrations: **all PASS** (PII reads = 0, all client writes blocked,
commissions unreadable, direct booking insert blocked, RPC requires auth).

**C. Confirm exact policy state (optional):**
Run `supabase/audit/00_inspect_current_state.sql` — every table should show
`rls_enabled = true`.

## Ship the app
Deploy the updated Flutter build (booking now goes through the `create_booking`
RPC). The app keeps working for signed-in users; only the insecure direct writes
are removed.

## Rollback
If something breaks, RLS can be relaxed per-table without data loss, e.g.
`alter table public.<t> disable row level security;` (do NOT do this for the PII
tables). Policies can be dropped individually. No migration drops columns or data.

## Storage
Migration 0005 secures `site-images` / `hotel-images` / `guide-images`
(public read, editor write). In Dashboard → Storage, confirm no **other** bucket
has an anonymous INSERT policy.
