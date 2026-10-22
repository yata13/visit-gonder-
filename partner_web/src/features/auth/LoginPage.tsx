import * as React from "react";
import { Navigate } from "react-router-dom";
import { toast } from "sonner";
import { BedDouble, CalendarCheck2, Hotel, MailCheck, Radio, UserRoundCheck } from "lucide-react";
import { supabase } from "@/lib/supabase";
import { cn, errorMessage } from "@/lib/utils";
import { useAuth } from "./AuthProvider";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Field } from "@/components/form-fields";

type Mode = "signin" | "signup";

export default function LoginPage() {
  const { session, loading } = useAuth();
  const [mode, setMode] = React.useState<Mode>("signin");
  const [name, setName] = React.useState("");
  const [email, setEmail] = React.useState("");
  const [password, setPassword] = React.useState("");
  const [busy, setBusy] = React.useState(false);
  const [sentTo, setSentTo] = React.useState<string | null>(null);
  const [errors, setErrors] = React.useState<Record<string, string>>({});

  if (!loading && session) return <Navigate to="/" replace />;

  function validate(): boolean {
    const e: Record<string, string> = {};
    if (mode === "signup" && name.trim().length < 2) e.name = "Type your full name";
    if (!/^\S+@\S+\.\S+$/.test(email.trim())) e.email = "Enter a valid email";
    if (password.length < 6) e.password = "At least 6 characters";
    setErrors(e);
    return Object.keys(e).length === 0;
  }

  async function onSubmit(ev: React.FormEvent) {
    ev.preventDefault();
    if (!validate()) return;
    setBusy(true);
    try {
      if (mode === "signin") {
        const { error } = await supabase.auth.signInWithPassword({
          email: email.trim(),
          password,
        });
        if (error) throw error;
      } else {
        const { data, error } = await supabase.auth.signUp({
          email: email.trim(),
          password,
          options: { data: { full_name: name.trim() } },
        });
        if (error) throw error;
        // Projects that confirm emails return no session yet.
        if (!data.session) {
          setSentTo(email.trim());
          setMode("signin");
        }
      }
    } catch (err) {
      toast.error(errorMessage(err));
    } finally {
      setBusy(false);
    }
  }

  async function onForgot() {
    if (!/^\S+@\S+\.\S+$/.test(email.trim())) {
      setErrors({ email: "Type your email first" });
      return;
    }
    const { error } = await supabase.auth.resetPasswordForEmail(email.trim());
    if (error) toast.error(errorMessage(error));
    else toast.success(`Password reset link sent to ${email.trim()}`);
  }

  return (
    <div className="grid min-h-dvh lg:grid-cols-[1.1fr_1fr]">
      {/* Brand side */}
      <div className="relative hidden overflow-hidden bg-sidebar p-12 text-white lg:flex lg:flex-col">
        <div
          aria-hidden
          className="absolute inset-0 opacity-[0.07]"
          style={{
            backgroundImage:
              "repeating-linear-gradient(45deg, #D5A562 0 2px, transparent 2px 22px), repeating-linear-gradient(-45deg, #D5A562 0 2px, transparent 2px 22px)",
          }}
        />
        <div className="relative flex items-center gap-3">
          <div className="flex h-11 w-11 items-center justify-center rounded-xl bg-gold">
            <Hotel className="h-6 w-6 text-sidebar" />
          </div>
          <div className="leading-tight">
            <div className="text-lg font-extrabold">Visit Gondar</div>
            <div className="text-sm text-white/50">Partners</div>
          </div>
        </div>
        <div className="relative mt-auto max-w-md space-y-6 fade-up">
          <h2 className="text-4xl font-extrabold leading-tight">
            Your hotel or tour,
            <br />
            <span className="text-gold">booked by Gondar's visitors.</span>
          </h2>
          <ul className="space-y-4 text-white/80">
            {[
              { icon: Radio, text: "New booking requests arrive live, with a sound." },
              { icon: CalendarCheck2, text: "Confirm or decline in one click — the guest is told in the app." },
              { icon: BedDouble, text: "Close full days on your calendar so nobody books them." },
              { icon: UserRoundCheck, text: "Keep your prices, photos and contact up to date." },
            ].map(({ icon: Icon, text }) => (
              <li key={text} className="flex items-start gap-3">
                <span className="mt-0.5 flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-white/10">
                  <Icon className="h-4 w-4 text-gold" />
                </span>
                <span className="pt-1 text-[15px]">{text}</span>
              </li>
            ))}
          </ul>
        </div>
        <p className="relative mt-12 text-xs text-white/40">
          Same account as the Visit Gondar app. The Visit Gondar office connects your
          business to your account.
        </p>
      </div>

      {/* Form side */}
      <div className="flex items-center justify-center p-6">
        <div className="w-full max-w-sm fade-up">
          <div className="mb-8 flex items-center gap-3 lg:hidden">
            <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-primary">
              <Hotel className="h-5 w-5 text-gold" />
            </div>
            <div className="leading-tight">
              <div className="font-extrabold">Visit Gondar</div>
              <div className="text-sm text-muted-foreground">Partners</div>
            </div>
          </div>

          <h1 className="text-2xl font-extrabold">
            {mode === "signin" ? "Welcome back" : "Create your partner account"}
          </h1>
          <p className="mt-1 text-sm text-muted-foreground">
            {mode === "signin"
              ? "Sign in to manage your bookings."
              : "For hotels and tour guides in Gondar."}
          </p>

          <div className="mt-6 grid grid-cols-2 rounded-lg border bg-card p-1" role="tablist">
            {(["signin", "signup"] as const).map((m) => (
              <button
                key={m}
                type="button"
                role="tab"
                aria-selected={mode === m}
                onClick={() => {
                  setMode(m);
                  setErrors({});
                }}
                className={cn(
                  "rounded-md py-2 text-sm font-semibold transition-colors",
                  mode === m ? "bg-primary text-primary-foreground" : "text-muted-foreground hover:bg-accent",
                )}
              >
                {m === "signin" ? "Sign in" : "New partner"}
              </button>
            ))}
          </div>

          {sentTo && (
            <div className="mt-4 flex items-start gap-2 rounded-lg bg-success-bg p-3 text-sm text-success">
              <MailCheck className="mt-0.5 h-4 w-4 shrink-0" />
              <span>
                We sent a link to <b>{sentTo}</b>. Open it to confirm your email, then sign in here.
              </span>
            </div>
          )}

          <form onSubmit={onSubmit} className="mt-5 space-y-4" noValidate>
            {mode === "signup" && (
              <Field label="Full name" htmlFor="name" error={errors.name}>
                <Input id="name" autoComplete="name" value={name} onChange={(e) => setName(e.target.value)} />
              </Field>
            )}
            <Field label="Email" htmlFor="email" error={errors.email}>
              <Input
                id="email"
                type="email"
                autoComplete="email"
                placeholder="you@yourhotel.com"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
              />
            </Field>
            <Field label="Password" htmlFor="password" error={errors.password}>
              <Input
                id="password"
                type="password"
                autoComplete={mode === "signin" ? "current-password" : "new-password"}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
              />
            </Field>
            <Button type="submit" className="h-10 w-full" disabled={busy}>
              {busy ? "Please wait…" : mode === "signin" ? "Sign in" : "Create account"}
            </Button>
            {mode === "signin" && (
              <button
                type="button"
                onClick={() => void onForgot()}
                className="w-full text-center text-sm font-medium text-primary hover:underline"
              >
                Forgot password?
              </button>
            )}
          </form>
        </div>
      </div>
    </div>
  );
}
