import * as React from "react";
import { Navigate, useLocation } from "react-router-dom";
import { ShieldX } from "lucide-react";
import { useAuth } from "./AuthProvider";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";

/**
 * Gate: only signed-in users with a row in user_roles (admin or editor)
 * may pass. Everyone else is bounced to /login or told they have no
 * access. RLS enforces the same rule server-side — this is just UX.
 */
export default function RequireAdmin({ children }: { children: React.ReactNode }) {
  const { session, role, loading, signOut } = useAuth();
  const location = useLocation();

  if (loading) {
    return (
      <div className="flex min-h-dvh items-center justify-center">
        <div className="w-full max-w-md space-y-3 p-8">
          <Skeleton className="h-8 w-2/3" />
          <Skeleton className="h-4 w-full" />
          <Skeleton className="h-4 w-5/6" />
        </div>
      </div>
    );
  }

  if (!session) {
    return <Navigate to="/login" replace state={{ from: location }} />;
  }

  if (!role) {
    return (
      <div className="flex min-h-dvh flex-col items-center justify-center gap-4 p-8 text-center">
        <ShieldX className="h-12 w-12 text-destructive" />
        <h1 className="text-xl font-semibold">No admin access</h1>
        <p className="max-w-sm text-sm text-muted-foreground">
          You are signed in as <strong>{session.user.email}</strong>, but this
          account has no admin or editor role. Ask a project admin to grant you
          one from the Users page.
        </p>
        <Button variant="outline" onClick={() => void signOut()}>
          Sign out
        </Button>
      </div>
    );
  }

  return <>{children}</>;
}
