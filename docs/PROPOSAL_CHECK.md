# App vs. "Explore Gondar" proposal (v15)

A page-by-page check of what the proposal promises against what the code does.
✅ built · 🟡 partly built · ❌ not built yet.

## Added in this change

| Proposal | What was built |
|---|---|
| **Two kinds of visitor** — Free and Premium (p. 9) | `user_tiers` table + `is_premium()` (migration `0014`). App: plan card on Account, Plans screen (Free vs Premium lists from the proposal), "Request Premium" button. Admin: Plan column in **Users & Roles**, *Make Premium* / *Back to Free*, and a **Premium requests** list to approve or decline. Only admins can change a plan (same design as roles). Team members count as Premium so they can test. |
| **Ask Gondar** — Premium AI guide (p. 7) | `supabase/functions/ask-gondar` (Google Gemini — free tier, no card needed). Answers only from City-approved data: the new **AI Knowledge** admin page plus published sites, events, news, safety notices, danger zones, verified hotels/guides and the weather. Amharic and English. Only Gondar and Amhara. If it is not sure, it says so and gives the Safety Desk number. App: **Ask Gondar** banner on Home → chat screen. Free users see a "Premium feature" screen. Limit: 50 questions per visitor per day. |
| **Ask the City** — for the Mayor's team (p. 7) | Same function, `mode: "city"`, team members only. Dashboard panel: ask your own numbers ("How many bookings this week?") or draft a notice in Amharic + English. |
| **Live weather** — today + 7 days (p. 6, 7) | Open-Meteo (free, no key). App: weather card on Home and a forecast + tip on each day of the Trip Planner. Dashboard: weather card. The AI uses it too ("Rain likely — keep churches for the afternoon"). |
| Account screen could not be opened | Profile button added to the Home top bar. |

## Already in the app

| Proposal | Status |
|---|---|
| Discover sites, stories, hours, events (p. 4) | ✅ Sites, Events, Timket, Gondar Passport stories |
| City-verified hotels and guides with posted prices (p. 4) | ✅ publish/approval workflow in admin |
| SOS → City Safety Desk with live location (p. 5) | ✅ emergency requests + admin Emergency page |
| Safety notices, roads, closures (p. 5) | ✅ notifications + danger zones |
| City broadcast / approve providers / evidence charts (p. 6) | ✅ Notifications, publish status, Dashboard charts |
| Commission only when a booking happens (p. 9) | ✅ commission rates (3% hotels, 10% guides) |
| Amharic + English (p. 7) | ✅ language toggle |

## Still missing (next steps)

| Proposal | Status | Note |
|---|---|---|
| Bajaj rides as City-verified, bookable listings (p. 4, 8) | 🟡 | Stay → Taxi only shows fixed phone numbers. Needs a `rides`/bajaj listing type + booking. |
| Plan with route, time and distance + "Start navigation" (p. 4) | 🟡 | Planner gives days and sites, no times/distances/route line. |
| "Only when staffed" SOS switch (p. 5) | ❌ | No on/off for the Safety Desk; SOS is always shown. |
| Offline guide packs + audio guides — Premium (p. 9) | ❌ | Home says "Offline Mode Ready" but nothing is downloaded. Should be fixed or the banner removed. |
| Official news / full planner / priority booking as Premium extras (p. 9) | 🟡 | These features exist but are free for everyone. They can be gated with `userTierProvider` when the City decides. |
| Paying for Premium (p. 9, 12) | ❌ | Visitors request Premium and an admin approves. Chapa payment can be added once commercial terms are agreed with the City. |
| After the trip: review and share (p. 4) | ❌ | `reviews` table is named in constants but there is no review screen. |
| Live arrivals / visitors count on the dashboard (p. 6) | 🟡 | Dashboard counts users, bookings, passport check-ins; no "visitors this week" number. |
| Public QR codes and screens (p. 10) | 🟡 | Passport QR exists; no QR for downloading the app. |
| Virtual tours (p. 9) | ❌ | Proposal says "later phase". |

## To switch the new features on

1. **Database:** run `supabase/migrations/0014_premium_tier_and_ai.sql` in the SQL Editor
   (it is also at the end of `supabase/RUN_THIS_IN_SQL_EDITOR.sql`).
2. **AI function:** get a free key at https://aistudio.google.com/apikey (sign in with
   Google, click "Create API key" — no credit card needed), then:
   ```bash
   supabase secrets set GEMINI_API_KEY=AI...
   supabase secrets set SAFETY_DESK_PHONE=<the desk number>   # optional, default 991
   supabase functions deploy ask-gondar
   ```
3. **Content:** in the dashboard, add answers in **AI Knowledge** (opening hours,
   Timket routes, transport, prices) and set them to *Published*.
4. **App:** `flutter pub get` (new `http` package for weather).
