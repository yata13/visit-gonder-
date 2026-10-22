import { createClient } from "@supabase/supabase-js";
import type { Database } from "./database.types";

const url = import.meta.env.VITE_SUPABASE_URL as string | undefined;
const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined;

/** Set when partner_web/.env is missing or incomplete; main.tsx then
 *  shows a setup screen instead of a blank page. */
export const supabaseConfigError =
  !url || !anonKey
    ? "Missing VITE_SUPABASE_URL or VITE_SUPABASE_ANON_KEY."
    : url.includes("YOUR_PROJECT_REF") || anonKey === "YOUR_ANON_KEY"
      ? "partner_web/.env still has the example values."
      : null;

// Public (anon) key only. What a partner can see and change is decided
// by the database rules (RLS + partner_* functions), not by this site.
export const supabase = createClient<Database>(
  supabaseConfigError ? "http://localhost" : url!,
  supabaseConfigError ? "missing" : anonKey!,
);
