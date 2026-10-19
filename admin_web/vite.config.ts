import { defineConfig, loadEnv } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";
import { fileURLToPath } from "node:url";

export default defineConfig(({ mode }) => {
  // Also accept the app's names (SUPABASE_URL / SUPABASE_ANON_KEY) so the
  // same .env lines work in both projects. Only these two exact keys are
  // passed to the browser — never other SUPABASE_* secrets.
  const env = loadEnv(mode, process.cwd(), "");
  const url = env.VITE_SUPABASE_URL || env.SUPABASE_URL || "";
  const anonKey = env.VITE_SUPABASE_ANON_KEY || env.SUPABASE_ANON_KEY || "";

  return {
    plugins: [react(), tailwindcss()],
    define: {
      "import.meta.env.VITE_SUPABASE_URL": JSON.stringify(url),
      "import.meta.env.VITE_SUPABASE_ANON_KEY": JSON.stringify(anonKey),
    },
    resolve: {
      alias: {
        "@": fileURLToPath(new URL("./src", import.meta.url)),
      },
    },
  };
});
