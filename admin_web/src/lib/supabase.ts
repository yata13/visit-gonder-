import { createClient } from "@supabase/supabase-js";
import type { Database } from "./database.types";

const url = import.meta.env.VITE_SUPABASE_URL as string | undefined;
const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined;

if (!url || !anonKey) {
  throw new Error(
    "Missing VITE_SUPABASE_URL or VITE_SUPABASE_ANON_KEY. " +
      "Copy admin_web/.env.example to admin_web/.env and fill in the values.",
  );
}

// Anon key only — RLS is the security boundary. Never put the
// service_role key in this app.
export const supabase = createClient<Database>(url, anonKey);
