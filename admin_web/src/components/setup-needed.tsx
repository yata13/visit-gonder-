/** Shown instead of the app when admin_web/.env is not set up. */
export function SetupNeeded({ reason }: { reason: string }) {
  return (
    <div className="flex min-h-dvh items-center justify-center p-8">
      <div className="max-w-lg space-y-4 text-sm">
        <h1 className="text-xl font-semibold">Connect the dashboard to Supabase</h1>
        <p className="text-destructive">{reason}</p>
        <ol className="list-decimal space-y-2 pl-5">
          <li>
            In the <code>admin_web</code> folder, make a file named exactly{" "}
            <code>.env</code> (not <code>.env.txt</code>) — copy it from{" "}
            <code>.env.example</code>.
          </li>
          <li>
            Fill in <code>VITE_SUPABASE_URL</code> and{" "}
            <code>VITE_SUPABASE_ANON_KEY</code> (or <code>SUPABASE_URL</code> / <code>SUPABASE_ANON_KEY</code>) from Supabase → Project
            Settings → API.
          </li>
          <li>
            Stop the server (<code>Ctrl + C</code>) and run{" "}
            <code>npm run dev</code> again — the file is only read at start.
          </li>
        </ol>
      </div>
    </div>
  );
}
