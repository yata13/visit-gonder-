import * as React from "react";
import { Navigate } from "react-router-dom";
import { toast } from "sonner";
import { BedDouble, CalendarCheck2, Hotel, Radio, Store, UserRoundCheck } from "lucide-react";
import { supabase } from "@/lib/supabase";
import { errorMessage } from "@/lib/utils";
import { useAuth } from "./AuthProvider";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Field } from "@/components/form-fields";

// Sign in only — no "create account" here. For security, partner
// accounts are made by the Visit Gondar office in person (they check
// the business and its documents), who then give the owner the email
// and password to sign in with.
export default function LoginPage() {
  const { session, loading } = useAuth();
  const [email, setEmail] = React.useState("");
  const [password, setPassword] = React.useState("");
  const [busy, setBusy] = React.useState(false);
  const [errors, setErrors] = React.useState<Record<string, string>>({});

  if (!loading && session) return <Navigate to="/" replace />;

  function validate(): boolean {
    const e: Record<string, string> = {};
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
      const { error } = await supabase.auth.signInWithPassword({ email: email.trim(), password });
      if (error) throw error;
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
          New here? Visit the Visit Gondar office with your business details — they set up your
          account and give you an email and password to sign in with.
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

          <h1 className="text-2xl font-extrabold">Welcome back</h1>
          <p className="mt-1 text-sm text-muted-foreground">Sign in to manage your bookings.</p>

          <form onSubmit={onSubmit} className="mt-6 space-y-4" noValidate>
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
                autoComplete="current-password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
              />
            </Field>
            <Button type="submit" className="h-10 w-full" disabled={busy}>
              {busy ? "Please wait…" : "Sign in"}
            </Button>
            <button
              type="button"
              onClick={() => void onForgot()}
              className="w-full text-center text-sm font-medium text-primary hover:underline"
            >
              Forgot password?
            </button>
          </form>

          <div className="mt-8 flex items-start gap-3 rounded-xl border bg-card p-4 text-sm text-muted-foreground lg:hidden">
            <Store className="mt-0.5 h-4 w-4 shrink-0 text-primary" />
            <span>
              New here? Visit the Visit Gondar office with your business details — they set up
              your account and give you an email and password.
            </span>
          </div>
        </div>
      </div>
    </div>
  );
}
