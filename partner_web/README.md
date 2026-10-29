# Visit Gondar Partners

The website for **hotels and tour guides**. It uses the same Supabase
project as the Visit Gondar app and the admin site, so everything is live:

- A tourist books in the app → the partner hears a sound and sees the
  request on **Overview** / **Bookings**.
- The partner taps **Confirm** or **Decline** → the tourist gets a
  notification in the app.
- **Calendar**: set how many rooms (or tours) you sell per day, or close
  days. The app refuses bookings on closed or full days.
- **My listing**: description, price, contact, location and photos. The
  app shows the changes at once. The name, stars and publishing stay with
  the Visit Gondar office.

## Run it on your PC (Windows PowerShell)

1. Once: run `supabase/RUN_RIDES_AND_PARTNERS.sql` in Supabase → SQL Editor.
2. Copy the admin site's `.env` (same keys):
   ```powershell
   cd partner_web
   Copy-Item ..\admin_web\.env .\.env
   npm install
   npm run dev
   ```
3. Open http://localhost:5174 (the admin site stays on 5173).

## How a hotel or guide gets in

For security, partners cannot create their own account on this site —
there is no sign-up screen; the office needs to see their business
details and documents first. A new partner comes to (or calls) the
office, and the office:

1. Creates their sign-in in **Supabase Dashboard → Authentication →
   Users → Add user** (their email + a password the office gives them).
2. Opens the admin website → **Partners** → **Link an owner by email** →
   picks the hotel or guide and types that same email.

The partner then opens this site and signs in. If the office created the
login before linking it, the partner sees **Connect your business** —
they can tell the office which listing is theirs from there instead of
waiting for a call back. Once linked, their dashboard opens by itself.

## Put it on the internet

`npm run build` makes the `dist` folder. Upload it to Netlify, Vercel or
any static host (the `_redirects` file is included for Netlify). Then in
Supabase → Authentication → URL Configuration, add the site address so
email confirmation and password reset links come back to it.
