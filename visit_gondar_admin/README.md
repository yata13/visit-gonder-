# Visit Gondar — Admin Dashboard 🖥️

Flutter **Web** dashboard where the Visit Gondar team manages everything the
tourist app shows. Uses the same Supabase project as the app — publish a hotel
here and tourists see it instantly.

## Tabs

| Tab | What it manages |
|---|---|
| Dashboard | Overview numbers (bookings, revenue, commission) |
| Hotels / Guides / Sites / Events | Add, edit, publish or hide listings |
| Notifications | Push a popup notification to every app user (realtime) |
| News Feed | Facebook-style posts that appear on the app home screen |
| Map Manager | Control every pin on the app's map |
| Bookings | See all hotel/guide bookings and commission earned |
| Safety | Draw danger zones — the app warns tourists inside them |
| Emergency | Live SOS requests from tourists, with their GPS location |

## Run it

```bash
# 1. One-time setup: create your .env file
#    Copy .env.example → .env and fill in the Supabase keys
#    (ask the project owner for the values)

# 2. Install packages
flutter pub get

# 3. Start in Chrome
flutter run -d chrome
```

Build for hosting (Netlify, Vercel, Firebase Hosting, …):

```bash
flutter build web --release
# Output: build/web/  → upload this folder to your host
```

## Folder map (`lib/`)

| Folder | What lives there |
|---|---|
| `main.dart` | Entry point — login check, then the shell |
| `screens/dashboard/admin_shell.dart` | Sidebar navigation frame around every page |
| `screens/<feature>/` | One folder per tab (hotels, guides, safety, …) |
| `services/admin_supabase.dart` | Supabase connection + admin sign-in |
| `services/admin_data_service.dart` | Models + create/read/update/delete for every tab |
| `theme/` | Dashboard colors and styles |

## Adding a new tab

1. Create `lib/screens/yourfeature/yourfeature_screen.dart`
2. In `admin_shell.dart` add one `_NavItem` **and** one screen entry — same position in both lists.
