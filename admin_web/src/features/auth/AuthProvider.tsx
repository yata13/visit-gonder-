import * as React from "react";
import type { Session } from "@supabase/supabase-js";
import { supabase } from "@/lib/supabase";

export type AdminRole = "admin" | "editor";

interface AuthContextValue {
  session: Session | null;
  /** null = signed in but has no role row (regular tourist account). */
  role: AdminRole | null;
  loading: boolean;
  signOut: () => Promise<void>;
}

const AuthContext = React.createContext<AuthContextValue | undefined>(undefined);

async function fetchRole(userId: string): Promise<AdminRole | null> {
  const { data, error } = await supabase
    .from("user_roles")
    .select("role")
    .eq("user_id", userId)
    .maybeSingle();
  if (error || !data) return null;
  return data.role === "admin" || data.role === "editor" ? data.role : null;
}

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [session, setSession] = React.useState<Session | null>(null);
  const [role, setRole] = React.useState<AdminRole | null>(null);
  const [loading, setLoading] = React.useState(true);

  React.useEffect(() => {
    let cancelled = false;

    async function apply(next: Session | null) {
      if (cancelled) return;
      setSession(next);
      if (next?.user) {
        const r = await fetchRole(next.user.id);
        if (!cancelled) setRole(r);
      } else {
        setRole(null);
      }
      if (!cancelled) setLoading(false);
    }

    supabase.auth
      .getSession()
      .then(({ data }) => apply(data.session))
      .catch(() => {
        if (!cancelled) setLoading(false);
      });

    const { data: sub } = supabase.auth.onAuthStateChange((_event, next) => {
      void apply(next);
    });

    return () => {
      cancelled = true;
      sub.subscription.unsubscribe();
    };
  }, []);

  const signOut = React.useCallback(async () => {
    await supabase.auth.signOut();
  }, []);

  const value = React.useMemo(
    () => ({ session, role, loading, signOut }),
    [session, role, loading, signOut],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthContextValue {
  const ctx = React.useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used inside <AuthProvider>");
  return ctx;
}
