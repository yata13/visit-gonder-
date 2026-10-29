# Visit Gondar Driver

The app for partner **bajaj and taxi drivers**. It uses the same Supabase
project as the Visit Gondar tourist app, so the two apps talk to each other:

1. A tourist taps **Ride** in the Visit Gondar app and asks for a bajaj or a taxi.
2. Every online driver with that vehicle hears a sound and sees the request here.
3. The first driver to tap **Accept** gets the ride. The tourist sees the
   driver's name, plate and position on their map.
4. The driver taps **I've arrived → Start trip → Complete trip** and collects
   the fare in cash. The tourist rates the driver.

For security, drivers cannot create their own account in this app — there
is no sign-up screen. A new driver comes to the Visit Gondar office with
their ID and vehicle documents; the office:

1. Creates their sign-in in **Supabase Dashboard → Authentication → Users
   → Add user** (their email + a password the office gives them).
2. Adds their name, phone, vehicle and plate on the admin website's
   **Drivers** page → **Add driver**. They are approved immediately —
   the office just checked them in person.

The driver then opens this app and signs in with that email and password.
Nothing else to fill in.

## Run it (Windows PowerShell)

1. Once: run `supabase/RUN_RIDES_AND_PARTNERS.sql` in Supabase → SQL Editor.
2. Copy the `.env` file from the tourist app into this folder (same keys):
   ```powershell
   cd driver_app
   Copy-Item ..\visit_gondar_app\.env .\.env
   ```
3. Plug in the phone and start it:
   ```powershell
   flutter pub get
   flutter run
   ```
   Or make an APK to share with drivers:
   ```powershell
   flutter build apk --release
   ```
   The file is `build\app\outputs\flutter-apk\app-release.apk`.

## Good to know

- **Keep the app open while online.** The screen stays on, and new requests
  ring with a sound and a notification, even with the phone in a pocket.
  If Android closes the app completely, requests cannot ring. That needs
  Firebase push notifications (a later step).
- The driver's position is sent every few seconds while online (and every
  minute while parked), so tourists see the driver coming.
- Requests nobody accepts in 15 minutes expire, and the tourist is told.
- A driver can **hand back** a ride before the trip starts; it goes back to
  the other drivers.
- Prices (ETB): bajaj 25 + 15 per km (at least 40), taxi 60 + 30 per km
  (at least 100). The office can change them on the admin **Rides** page.
