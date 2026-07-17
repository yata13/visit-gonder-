# Visit Gondar — Phase 1, Step 1: RLS Audit Report

**Date:** 2026-07-07
**Method:** Live probing of the PostgREST API (`https://cukfcclewuqaebnhhamo.supabase.co`)
using the **public anon key** shipped in the app's bundled `.env` — i.e. exactly the
access any attacker who unzips the APK has. Reads confirmed by row counts; write
authorization confirmed with impossible-filter `PATCH`/`DELETE` (a `204` means the
write was *authorized* and simply matched zero rows — nothing was modified).

> Exact policy definitions and the `rowsecurity` flag can only be read with the
> service role / SQL editor, not the anon REST API. Run
> [`00_inspect_current_state.sql`](../audit/00_inspect_current_state.sql) in the
> Supabase SQL editor to dump the authoritative `pg_policies` + RLS-enabled state.
> Everything below is inferred from black-box behaviour and is sufficient to prove
> the DB is wide open.

---

## 🔴 Headline: the database is effectively unprotected

With nothing but the public anon key, an attacker can **read, modify, and delete
almost every row in every table**, including all customer PII and live emergency
GPS coordinates. This is live and trivially exploitable today.

| Severity | Finding |
|---|---|
| 🔴 CRITICAL | Anon can `DELETE FROM bookings / emergency_requests / users / danger_zones / notifications` — a single unauthenticated request can wipe these tables. |
| 🔴 CRITICAL | Anon can `SELECT` **all** `emergency_requests` — victims' name, phone, message, and exact lat/lng. |
| 🔴 CRITICAL | Anon can `SELECT` **all** `users` (full_name, phone, country) and **all** `bookings` (customer_name, contact, email). |
| 🔴 CRITICAL | Anon can `UPDATE` any row of any table (e.g. flip any booking to `confirmed`, rewrite any user's phone, deactivate danger zones). |
| 🟠 HIGH | Booking price & commission are computed **client-side** and inserted directly (`lib/services/booking_service.dart`) — a modified client sets any price/commission it wants. |
| 🟠 HIGH | No `publish_status` on `sites`/`places`; the client "filter" for hotels/guides is cosmetic since anon can read the table directly regardless. |
| 🟡 MED | `commissions` table does not exist live; commission data lives on `bookings` and is fully anon-readable/writable. |
| 🟢 GOOD | No `service_role` key found anywhere in client source or `.env`. Only the anon key ships (that is expected). |

---

## Schema reality vs. the brief

The live DB does **not** match `supabase_update.sql` (which was superseded and never
fully applied — its `commissions` table 404s). The brief's task list assumes columns
that don't exist. Adapting to the **live** schema:

- `bookings` links to the owner by **`user_email`**, not `user_id`.
- `users` has **no `role` column** → admin roles must be built from scratch (`user_roles` + `is_admin()`), which is actually the safer design the brief asked for anyway.
- `hotels`/`guides` have **no `commission_rate` column** and no `phone`; hotels use `contact`. Rates will live in a new `commission_rates` table keyed by `target_type`.
- `hotels`/`guides` already have `publish_status`; `sites`/`places` do **not** (Phase 2).
- `lib/repositories/bookings_repository.dart` + `lib/models/booking_model.dart` reference the old schema (`user_id`, `reference_id`, `check_in`) and are **dead code**. The live path is `BookingService`.

---

## Table-by-table

Legend — Read/Write columns describe the **current** anon capability observed.
"Required" is the target state after the Phase 1 migration.

### PII / transactional tables

| Table | Anon READ (now) | Anon WRITE (now) | Required policy |
|---|---|---|---|
| `bookings` | ✅ all 10 rows | ✅ INSERT/UPDATE/DELETE | SELECT/INSERT **own** (`user_email = auth.jwt()->>email`); **no** client UPDATE/DELETE; INSERT only via `create_booking` RPC (direct INSERT revoked). |
| `emergency_requests` | ✅ all 8 rows | ✅ INSERT/UPDATE/DELETE | INSERT own + SELECT own only (`user_id = auth.uid()`); no UPDATE/DELETE for clients. |
| `users` | ✅ all 10 rows | ✅ UPDATE/DELETE | SELECT/UPDATE **own row** only; role never self-settable (role lives in separate `user_roles`, not here). No client DELETE. |
| `commissions` | n/a (404) | n/a | Table created with **RLS on and zero policies** → no client access at all; service role / SECURITY DEFINER only. |

### Content tables (public catalogue)

| Table | Anon READ (now) | Anon WRITE (now) | Required policy |
|---|---|---|---|
| `sites` | ✅ | ✅ UPDATE/DELETE | Public SELECT (published only, after Phase 2 adds `publish_status`); writes admin-only. |
| `places` | ✅ | ✅ UPDATE/DELETE | Public SELECT (published only, Phase 2); writes admin-only. |
| `hotels` | ✅ | ✅ UPDATE/DELETE | Public SELECT (published only — column exists); writes admin-only. |
| `guides` | ✅ | ✅ UPDATE/DELETE | Public SELECT (published only — column exists); writes admin-only. |
| `events` | ✅ | ✅ (open like the rest) | Public SELECT; writes admin-only. |
| `posts` | ✅ | ✅ UPDATE/DELETE | Public SELECT; writes admin-only. |
| `notifications` | ✅ | ✅ UPDATE/DELETE | Public SELECT; writes admin-only (composer is admin). |
| `danger_zones` | ✅ | ✅ UPDATE/DELETE | Public SELECT (active); writes admin-only. |
| `reviews` | ✅ (empty) | (assumed open) | Public SELECT; INSERT authenticated-own; UPDATE/DELETE own or admin. |

### To be created in Phase 1

| Table | Purpose | Policy |
|---|---|---|
| `commission_rates` | Single source of truth for rates (`hotels`=0.03, `guides`=0.10). | Public SELECT (rates are not secret); writes admin-only. |
| `user_roles` | `admin` / `editor` assignment, checked by `is_admin()`/`is_editor()`. | SELECT own; **no** client writes (service role only). |
| `admin_audit_log` | Phase 3 audit trail. | No client access; written by SECURITY DEFINER RPCs. |

---

## What I cannot do from here (needs you)

I only hold the anon key over REST, so I **cannot apply DDL** (enable RLS, create
policies). I will deliver numbered migrations under `supabase/migrations/`; you apply
them via the Supabase SQL editor or `supabase db push`. Given the DELETE exposure is
live, treat the Phase 1 migration as an **emergency deploy**.
