# Visit Gondar 🏰

A tourism platform for **Gondar, Ethiopia** — home of the Fasil Ghebbi castles,
Debre Berhan Selassie church, and the world-famous **Timket** festival.

The platform has two apps that share one Supabase backend:

| Folder | What it is | Runs on |
|---|---|---|
| [`visit_gondar_app/`](visit_gondar_app/) | Tourist app — explore sites, book hotels & guides, live map, SOS emergency | Android / iOS (Flutter) |
| [`admin_web/`](admin_web/) | Admin dashboard — hotels, guides, sites, events, news, map manager, bookings & Chapa deposits, safety zones, SOS requests, notifications, availability, Gondar Passport, users & roles | Web browser (React + TypeScript) |
| [`supabase/`](supabase/) | Migrations + docs for the shared Supabase database | Supabase SQL Editor |
| [`docs/`](docs/) | Team documentation (Git workflow guide, etc.) | — |

> The old Flutter Web admin (`visit_gondar_admin/`) was fully converted to
> `admin_web/` and removed. It still exists in git history if ever needed.

## Quick start

**Requirements:** [Flutter](https://docs.flutter.dev/get-started/install) 3.44+ and a Supabase account.

```bash
# 1. Get the code
git clone https://github.com/yata13/visit-gonder-.git
cd visit-gonder-

# 2. Add your secret keys (ask the project owner for the values)
#    Copy .env.example to .env inside EACH project:
#      visit_gondar_app/.env.example  →  visit_gondar_app/.env
#      admin_web/.env.example         →  admin_web/.env

# 3. Run the tourist app (phone/emulator)
cd visit_gondar_app
flutter pub get
flutter run

# 4. Run the admin dashboard (browser) — needs Node.js 18+
cd ../admin_web
npm install
npm run dev
```

> ⚠️ **Never commit the `.env` files.** They are git-ignored on purpose.
> Share keys with teammates privately (not in chat groups or screenshots).

## Tech stack

- **Flutter + Dart** — the tourist app (Android / iOS)
- **React + TypeScript + Vite + Tailwind** — the admin dashboard
- **Supabase** — database (Postgres), auth, storage, realtime alerts
- **flutter_map & Leaflet / OpenStreetMap** — free interactive maps

## For the team

New to the project? Read **[docs/GIT_TEAM_GUIDE.md](docs/GIT_TEAM_GUIDE.md)** —
it explains how we work with branches and pull requests, step by step.

Database setup and every SQL script is explained in **[supabase/README.md](supabase/README.md)**.
