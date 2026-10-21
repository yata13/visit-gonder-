import * as React from "react";
import { Label } from "@/components/ui/label";

/** Label + control + hint or validation message, stacked. The label is
 *  tied to the control (its id, or one made up here). */
export function Field({
  label,
  htmlFor,
  error,
  hint,
  children,
}: {
  label: string;
  htmlFor?: string;
  error?: string;
  hint?: string;
  children: React.ReactNode;
}) {
  const autoId = React.useId();
  let control = children;
  let forId = htmlFor;
  if (!forId && React.isValidElement<{ id?: string }>(children)) {
    forId = children.props.id ?? autoId;
    control = React.cloneElement(children, { id: forId });
  }
  return (
    <div className="space-y-1.5">
      <Label htmlFor={forId}>{label}</Label>
      {control}
      {hint && !error && <p className="text-xs text-muted-foreground">{hint}</p>}
      {error && <p className="text-xs text-destructive">{error}</p>}
    </div>
  );
}
