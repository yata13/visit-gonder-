import { createClient } from "@supabase/supabase-js";
import type { Database } from "./database.types";

const url = import.meta.env.VITE_SUPABASE_URL as string | undefined;
const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined;

/** Set when admin_web/.env is missing or incomplete; main.tsx then shows
 *  a setup screen instead of the app (rather than a blank page). */
export const supabaseConfigError =
  !url || !anonKey
    ? "Missing VITE_SUPABASE_URL or VITE_SUPABASE_ANON_KEY."
    : url.includes("YOUR_PROJECT_REF") || anonKey === "YOUR_ANON_KEY"
      ? "admin_web/.env still has the example values."
      : null;

// Anon key only — RLS is the security boundary. Never put the
// service_role key in this app. (Placeholder values keep imports from
// crashing while the setup screen is shown.)
export const supabase = createClient<Database>(
  supabaseConfigError ? "http://localhost" : url!,
  supabaseConfigError ? "missing" : anonKey!,
);
