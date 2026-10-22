/** Shown instead of the site when partner_web/.env is not set up. */
export function SetupNeeded({ reason }: { reason: string }) {
  return (
    <div className="flex min-h-dvh items-center justify-center p-8">
      <div className="max-w-lg space-y-4 text-sm">
        <h1 className="text-xl font-semibold">Connect the Partners site to Supabase</h1>
        <p className="text-destructive">{reason}</p>
        <ol className="list-decimal space-y-2 pl-5">
          <li>
            Copy the <code>.env</code> file from the <code>admin_web</code> folder into the{" "}
            <code>partner_web</code> folder (same keys), or copy <code>.env.example</code> to{" "}
            <code>.env</code> and fill it in.
          </li>
          <li>
            The values come from Supabase → Project Settings → API (the project URL and the
            public anon key).
          </li>
          <li>
            Stop the server (<code>Ctrl + C</code>) and run <code>npm run dev</code> again — the
            file is only read at start.
          </li>
        </ol>
      </div>
    </div>
  );
}
