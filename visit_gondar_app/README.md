# Visit Gondar — Tourist App 📱

Flutter app (Android / iOS) for tourists visiting Gondar, Ethiopia.

## Features

Five tabs in a floating glass bar, with a red **SOS** button on every screen:

- **Home** — Timket countdown (both calendars), Hotels / Guides / Bajaj / Safety map tiles, Passport progress, places near you, live weather, city news, search
- **Explore** — one searchable list of Sites, Hotels, Guides, Bajaj and Events, plus the live map
- **Passport** — Gondar Passport: collect a stamp at each site (enter the code on the site's sign), unlock its story and trivia, earn badges
- **Ask AI** — the Ask Gondar AI guide (Premium)
- **Me** — profile, plan, bookings, notifications, language, log out
- **SOS** — hold the red button 3 seconds to send your GPS location to the Safety Desk; Police 991 / Ambulance 907 one tap away
- Hotels and licensed guides with booking (3% hotel / 10% guide commission, calculated server-side)
- English / Amharic everywhere; dates shown in both Gregorian and Ethiopian calendars

## Design

The look follows the Claude Design canvas *"Gondar Tourism App — Design"*
(v0.5 · black & white glass). Tokens live in `lib/theme/app_theme.dart`:

- Neutrals carry the look: Ink `#2B2B2B`, Black `#1C1C1C`, Ground `#F4F4F4`, frosted white glass cards
- Colour is meaning only: **red = SOS and danger**, green = safe, amber = pending, blue = confirmed / verified, clay = form errors
- Fonts: Schibsted Grotesk (Latin) + Noto Sans Ethiopic (Amharic), via `google_fonts`
- Shared pieces (app mark, glass buttons, SOS button, tags) are in `lib/widgets/ui.dart`

## Run it

```bash
# 1. One-time setup: create your .env file
#    Copy .env.example → .env and fill in the Supabase keys
#    (ask the project owner for the values)

# 2. Install packages
flutter pub get

# 3. Start the app (phone connected or emulator running)
flutter run
```

Build a release APK for testing on real phones:

```bash
flutter build apk --release
# APK appears at: build/app/outputs/flutter-apk/app-release.apk
```

## Folder map (`lib/`)

| Folder | What lives there |
|---|---|
| `main.dart` | App entry point, splash, glass tab bar + SOS |
| `core/` | Constants, error types, small shared widgets/utils |
| `models/` | Data classes (Site, Hotel, Guide, Booking, …) |
| `services/` | Supabase connection, auth, bookings, GPS, realtime alerts |
| `repositories/` | All database queries, one file per feature |
| `providers/` | Riverpod state (auth, language, data caching) |
| `screens/` | One folder per screen (home, explore, map, booking, …) |
| `theme/` | Colors, text styles, app-wide look |
| `widgets/` | Reusable UI pieces (`ui.dart` design pieces, shimmer image, …) |

**Rule of thumb:** screens never talk to Supabase directly —
they read providers, providers use repositories, repositories use services.
