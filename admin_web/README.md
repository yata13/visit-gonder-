# Visit Gondar — Admin Dashboard (Web) 🖥️

The TypeScript admin dashboard for the Visit Gondar platform.
Built with **Vite + React + TypeScript**, **Tailwind CSS** (shadcn-style
components), **Supabase**, **TanStack Query**, **React Router**,
**React Hook Form + Zod**.

It manages:

It is the full conversion of the old Flutter Web admin — same burnt-orange
& charcoal theme, same screens — plus the new features:

| Section | What you can do |
|---|---|
| Dashboard | Key counts: published listings, pending approvals, bookings, deposits, passport check-ins, users |
| Hotels / Guides / Sites / Events / News Feed / Map Manager | Full CRUD with the **draft → pending → published** workflow, bilingual EN/አማ fields, search + filter + pagination |
| Notifications | Compose broadcast alerts (news / moment / safety) + announcement log |
| Bookings | Money stats, approve / reject reservations, Chapa deposit status & filters |
| Safety | Danger-zone map (click to place, severity, radius) shown to tourists |
| Emergency | Live SOS / call / transport requests — respond, resolve, delete |
| Availability | Per-day capacity calendar for each hotel or guide |
| Gondar Passport | Check-in points (with printable QR codes), stories, trivia |
| Users & roles | List users, grant/revoke **admin** / **editor** roles |

## Before you start

The dashboard needs a working Supabase project with the schema applied:

1. Create the project at [supabase.com](https://supabase.com) (or restore the old one).
2. **Easiest:** paste [`../supabase/RUN_THIS_IN_SQL_EDITOR.sql`](../supabase/RUN_THIS_IN_SQL_EDITOR.sql)
   into the SQL Editor and press Run — it applies migrations `0001` … `0012`
   and grants the admin role in one go. (The numbered files in
   `migrations/` stay the source of truth.)

## Run it

```bash
cd admin_web

# 1. Add the keys (ask the project owner, or copy from Supabase → Settings → API)
cp .env.example .env       # then edit .env

# 2. Install and start
npm install
npm run dev                # → http://localhost:5173
```

> ⚠️ Never commit `.env`. Only the **anon** key goes in the client —
> never the `service_role` key. Row Level Security is the real guard;
> this app just gives admins a nice UI over it.

## Scripts

| Command | What it does |
|---|---|
| `npm run dev` | Start the dev server |
| `npm run build` | Typecheck + production build to `dist/` |
| `npm run preview` | Serve the production build locally |
| `npm run typecheck` | TypeScript check only |
| `npm run gen:types` | Regenerate `src/lib/database.types.ts` from the live DB (put your project ref in `package.json` first) |

`src/lib/database.types.ts` is currently **hand-written** to match
`supabase/migrations` (the live project was unreachable when this app
was built). Once your project is up, run `gen:types` to replace it with
generated types — the file format is identical.

## Folder structure

```
src/
  lib/            supabase client, database types, small helpers
  components/
    ui/           shadcn-style building blocks (button, dialog, table…)
    layout/       app shell (sidebar + top bar)
    …             data-table, confirm-dialog, form fields, error boundary
  features/
    auth/         login page, session + role context, route guard
    dashboard/    stat cards
    listings/     one config-driven CRUD module for 6 content tables
    bookings/     money stats, approve/reject, Chapa deposits
    notifications/ broadcast composer + logs
    safety/       danger-zone map (Leaflet)
    emergency/    SOS request cards + status workflow
    availability/ per-day capacity CRUD
    passport/     checkpoints (QR), stories, trivia
    users/        users list + role management (RPC-based)
```

## How roles work

Roles live in the `user_roles` table (`admin` or `editor`), **not** on
the user profile — so nobody can promote themselves. The app:

* reads your own role at login to gate the UI (`RequireAdmin`),
* changes roles only through the `admin_grant_role` / `admin_revoke_role`
  SQL functions, which check `is_admin()` server-side.

`editor` can manage content; only `admin` can manage users, roles and
see everything else. Tourists get a friendly "no access" screen.

## Known v1 limits

* Photos are added as URLs (no upload widget yet — images can be
  uploaded in Supabase Storage and the URL pasted here).
* Deposits are read-only: rows are written by the Chapa webhook
  (an Edge Function with the service role — not part of this app).
* Trivia correct answers are readable by a determined app user;
  acceptable for a friendly quiz.
