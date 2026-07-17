# Visit Gondar — Tourist App 📱

Flutter app (Android / iOS) for tourists visiting Gondar, Ethiopia.

## Features

- **Home** — news feed posted by the admin, quick actions
- **Explore** — historical sites and events, with photos and details
- **SOS** — one-tap emergency: sends your GPS location to the admin, shows danger-zone alerts
- **Map** — interactive OpenStreetMap with every site, hotel, and service pin
- **Stay** — hotels and licensed tour guides with real-time booking (3% hotel / 10% guide commission, calculated server-side)
- **Timket guide** — roadmap and live schedule for the Timket festival
- English / Amharic language support

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
| `main.dart` | App entry point, bottom navigation |
| `core/` | Constants, error types, small shared widgets/utils |
| `models/` | Data classes (Site, Hotel, Guide, Booking, …) |
| `services/` | Supabase connection, auth, bookings, GPS, realtime alerts |
| `repositories/` | All database queries, one file per feature |
| `providers/` | Riverpod state (auth, language, data caching) |
| `screens/` | One folder per screen (home, explore, map, booking, …) |
| `theme/` | Colors, text styles, app-wide look |
| `widgets/` | Reusable UI pieces (shimmer image, …) |

**Rule of thumb:** screens never talk to Supabase directly —
they read providers, providers use repositories, repositories use services.
