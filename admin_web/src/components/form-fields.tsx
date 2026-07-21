import * as React from "react";
import { Label } from "@/components/ui/label";

/** Label + control + validation message, stacked. */
export function Field({
  label,
  error,
  hint,
  children,
}: {
  label: string;
  error?: string;
  hint?: string;
  children: React.ReactNode;
}) {
  return (
    <div className="space-y-1.5">
      <Label>{label}</Label>
      {children}
      {hint && !error && <p className="text-xs text-muted-foreground">{hint}</p>}
      {error && <p className="text-xs text-destructive">{error}</p>}
    </div>
  );
}

/** Two controls side by side, labelled EN / አማ (Amharic). */
export function BilingualRow({
  label,
  en,
  am,
  errorEn,
  errorAm,
}: {
  label: string;
  en: React.ReactNode;
  am: React.ReactNode;
  errorEn?: string;
  errorAm?: string;
}) {
  return (
    <div className="space-y-1.5">
      <Label>{label}</Label>
      <div className="grid grid-cols-1 gap-2 sm:grid-cols-2">
        <div className="space-y-1">
          <span className="text-xs font-medium text-muted-foreground">English</span>
          {en}
          {errorEn && <p className="text-xs text-destructive">{errorEn}</p>}
        </div>
        <div className="space-y-1">
          <span className="text-xs font-medium text-muted-foreground">አማርኛ (Amharic)</span>
          {am}
          {errorAm && <p className="text-xs text-destructive">{errorAm}</p>}
        </div>
      </div>
    </div>
  );
}
