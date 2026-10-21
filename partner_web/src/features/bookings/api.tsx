import * as React from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import { CalendarDays, Check, Mail, Phone, Users, X } from "lucide-react";
import { supabase } from "@/lib/supabase";
import type { Tables } from "@/lib/database.types";
import { cn, errorMessage, nightsBetween, shortDay, timeAgo, usd } from "@/lib/utils";
import { Badge, type BadgeProps } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { ConfirmDialog } from "@/components/confirm-dialog";
import type { Business } from "@/features/business/BusinessProvider";

export type Booking = Tables<"bookings">;
export type NewStatus = "confirmed" | "rejected" | "cancelled";

/** Bookings that hold a room / tour (they count on the calendar). */
export const ACTIVE = new Set(["pending", "confirmed", "approved"]);

export const STATUS: Record<string, { label: string; variant: BadgeProps["variant"] }> = {
  pending: { label: "New request", variant: "warning" },
  confirmed: { label: "Confirmed", variant: "success" },
  approved: { label: "Approved by office", variant: "success" },
  rejected: { label: "Declined", variant: "destructive" },
  cancelled: { label: "Cancelled", variant: "outline" },
};

/** All bookings for one of my businesses (the database only returns mine). */
export function useBookings(b: Business) {
  return useQuery({
    queryKey: ["bookings", b.type, b.id],
    queryFn: async (): Promise<Booking[]> => {
      const { data, error } = await supabase
        .from("bookings")
        .select("*")
        .eq("item_type", b.type)
        .eq("item_id", b.id)
        .order("created_at", { ascending: false })
        .limit(1000);
      if (error) throw error;
      return data ?? [];
    },
  });
}

export function useSetBookingStatus() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async ({ id, status }: { id: string; status: NewStatus }) => {
      const { data, error } = await supabase.rpc("partner_set_booking_status", {
        p_booking_id: id,
        p_status: status,
      });
      if (error) throw error;
      return data;
    },
    onSuccess: (_data, v) => {
      toast.success(
        v.status === "confirmed"
          ? "Confirmed — the guest gets a notification in the app."
          : v.status === "rejected"
            ? "Declined — the guest is told in the app."
            : "Booking cancelled — the guest is told in the app.",
      );
      void queryClient.invalidateQueries({ queryKey: ["bookings"] });
    },
    onError: (err) => toast.error(errorMessage(err)),
  });
}

export function StatusBadge({ status }: { status: string | null }) {
  const s = STATUS[status ?? "pending"] ?? { label: status ?? "—", variant: "outline" as const };
  return <Badge variant={s.variant}>{s.label}</Badge>;
}

function telHref(contact: string) {
  return `tel:${contact.replace(/[^\d+]/g, "")}`;
}

/** One booking with the guest, the dates, the money and the actions. */
export function BookingCard({
  booking: b,
  unit,
  compact = false,
}: {
  booking: Booking;
  unit: "night" | "day";
  compact?: boolean;
}) {
  const setStatus = useSetBookingStatus();
  const [ask, setAsk] = React.useState<NewStatus | null>(null);
  const n = nightsBetween(b.check_in, b.check_out);
  const contact = (b.customer_contact ?? "").trim();
  const isPhone = /\d{6,}/.test(contact.replace(/\D/g, "")) && !contact.includes("@");
  const busy = setStatus.isPending && setStatus.variables?.id === b.id;
  const total = b.total_price ?? b.price;

  return (
    <div
      className={cn(
        "rounded-xl border bg-card p-4 transition-shadow hover:shadow-sm",
        b.status === "pending" && "border-warning/50 live-flash",
      )}
    >
      <div className="flex flex-wrap items-start gap-3">
        <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-secondary text-sm font-bold text-primary">
          {(b.customer_name ?? "?").trim().charAt(0).toUpperCase() || "?"}
        </div>
        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-center gap-2">
            <span className="truncate font-semibold">{b.customer_name || "Visitor"}</span>
            <StatusBadge status={b.status} />
          </div>
          <div className="mt-1 flex flex-wrap gap-x-4 gap-y-1 text-sm text-muted-foreground">
            <span className="inline-flex items-center gap-1.5">
              <CalendarDays className="h-3.5 w-3.5" />
              {shortDay(b.check_in ?? b.booking_date)} → {shortDay(b.check_out)}
              {n > 0 && ` · ${n} ${unit}${n === 1 ? "" : "s"}`}
            </span>
            <span className="inline-flex items-center gap-1.5">
              <Users className="h-3.5 w-3.5" />
              {b.guests ?? 1} guest{(b.guests ?? 1) === 1 ? "" : "s"}
            </span>
          </div>
        </div>
        <div className="text-right">
          <div className="text-lg font-extrabold text-primary">{usd(total)}</div>
          <div className="text-xs text-muted-foreground">requested {timeAgo(b.created_at)}</div>
        </div>
      </div>

      {!compact && (contact || b.user_email) && (
        <div className="mt-3 flex flex-wrap gap-2 text-sm">
          {contact && (
            <a
              href={isPhone ? telHref(contact) : `mailto:${contact}`}
              className="inline-flex items-center gap-1.5 rounded-full bg-muted px-3 py-1 font-medium hover:bg-accent"
            >
              {isPhone ? <Phone className="h-3.5 w-3.5" /> : <Mail className="h-3.5 w-3.5" />}
              {contact}
            </a>
          )}
          {b.user_email && b.user_email !== contact && (
            <a
              href={`mailto:${b.user_email}`}
              className="inline-flex items-center gap-1.5 rounded-full bg-muted px-3 py-1 font-medium hover:bg-accent"
            >
              <Mail className="h-3.5 w-3.5" />
              {b.user_email}
            </a>
          )}
        </div>
      )}

      {(b.status === "pending" || b.status === "approved") && (
        <div className="mt-4 flex gap-2">
          <Button
            className="flex-1 bg-success text-white hover:bg-success/90"
            disabled={busy}
            onClick={() => setStatus.mutate({ id: b.id, status: "confirmed" })}
          >
            <Check /> Confirm
          </Button>
          <Button
            variant="outline"
            className="flex-1"
            disabled={busy}
            onClick={() => setAsk(b.status === "pending" ? "rejected" : "cancelled")}
          >
            <X /> {b.status === "pending" ? "Decline" : "Cancel"}
          </Button>
        </div>
      )}
      {b.status === "confirmed" && !compact && (
        <div className="mt-3 flex justify-end">
          <Button variant="ghost" size="sm" className="text-destructive" disabled={busy}
                  onClick={() => setAsk("cancelled")}>
            Cancel this booking
          </Button>
        </div>
      )}

      <ConfirmDialog
        open={ask !== null}
        onOpenChange={(open) => !open && setAsk(null)}
        title={ask === "rejected" ? "Decline this request?" : "Cancel this booking?"}
        description={`${b.customer_name || "The guest"} gets a notification in the Visit Gondar app. The ${
          unit === "night" ? "room" : "day"
        } becomes free again.`}
        confirmLabel={ask === "rejected" ? "Decline" : "Cancel booking"}
        destructive
        loading={busy}
        onConfirm={() => {
          if (!ask) return;
          setStatus.mutate({ id: b.id, status: ask }, { onSettled: () => setAsk(null) });
        }}
      />
    </div>
  );
}
