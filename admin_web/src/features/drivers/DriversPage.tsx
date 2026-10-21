import * as React from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import { BadgeCheck, Ban, CarTaxiFront, Hourglass, Phone, Search, Star, Wifi } from "lucide-react";
import { supabase } from "@/lib/supabase";
import { cn, errorMessage, formatDate, timeAgo } from "@/lib/utils";
import type { Tables } from "@/lib/database.types";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Skeleton } from "@/components/ui/skeleton";
import { ConfirmDialog } from "@/components/confirm-dialog";

type Driver = Tables<"drivers">;
type Filter = "pending" | "approved" | "suspended" | "all";

/** Online = switched on in the Driver app and seen in the last 10 minutes
 *  (the app pings at least every minute; a closed app stops pinging). */
export function isOnline(d: Pick<Driver, "is_online" | "location_at">): boolean {
  if (!d.is_online || !d.location_at) return false;
  return Date.now() - new Date(d.location_at).getTime() < 10 * 60_000;
}

export function useDrivers() {
  return useQuery({
    queryKey: ["drivers"],
    queryFn: async (): Promise<Driver[]> => {
      const { data, error } = await supabase
        .from("drivers")
        .select("*")
        .order("created_at", { ascending: false })
        .limit(1000);
      if (error) throw error;
      return data ?? [];
    },
  });
}

const STATUS_STYLE: Record<string, string> = {
  pending: "bg-warning-bg text-warning",
  approved: "bg-success-bg text-success",
  suspended: "bg-destructive/10 text-destructive",
};

export default function DriversPage() {
  const queryClient = useQueryClient();
  const drivers = useDrivers();
  const [filter, setFilter] = React.useState<Filter>("pending");
  const [q, setQ] = React.useState("");
  const [suspend, setSuspend] = React.useState<Driver | undefined>();

  const setStatus = useMutation({
    mutationFn: async ({ id, status }: { id: string; status: "approved" | "suspended" | "pending" }) => {
      const { error } = await supabase.rpc("admin_set_driver_status", { p_user_id: id, p_status: status });
      if (error) throw error;
      return status;
    },
    onSuccess: (status) => {
      toast.success(
        status === "approved"
          ? "Driver approved — their app opens by itself."
          : status === "suspended"
            ? "Driver paused — they are taken offline."
            : "Driver set back to waiting.",
      );
      setSuspend(undefined);
      void queryClient.invalidateQueries({ queryKey: ["drivers"] });
    },
    onError: (err) => toast.error(errorMessage(err)),
  });

  const all = drivers.data ?? [];
  const count = (f: Filter) => (f === "all" ? all.length : all.filter((d) => d.status === f).length);
  const online = all.filter(isOnline).length;
  const needle = q.trim().toLowerCase();
  const rows = all
    .filter((d) => filter === "all" || d.status === filter)
    .filter((d) => !needle || [d.full_name, d.phone, d.plate].some((v) => (v ?? "").toLowerCase().includes(needle)));

  const tiles = [
    { label: "Waiting for approval", value: count("pending"), icon: Hourglass, tone: count("pending") ? "text-warning" : "text-muted-foreground" },
    { label: "Approved drivers", value: count("approved"), icon: BadgeCheck, tone: "text-success" },
    { label: "Online now", value: online, icon: Wifi, tone: "text-success" },
    { label: "Paused", value: count("suspended"), icon: Ban, tone: "text-destructive" },
  ];

  return (
    <div className="space-y-4">
      <p className="text-sm text-muted-foreground">
        Bajaj and taxi drivers sign up in the <b>Visit Gondar Driver</b> app. Check their phone and
        plate, then approve them — tourists can then ride with them.
      </p>

      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        {tiles.map(({ label, value, icon: Icon, tone }) => (
          <div key={label} className="rounded-xl border bg-card p-4">
            <div className="flex items-center gap-2 text-sm text-muted-foreground">
              <Icon className={cn("h-4 w-4", tone)} /> {label}
            </div>
            <div className="mt-1 text-3xl font-extrabold">{drivers.isPending ? "…" : value}</div>
          </div>
        ))}
      </div>

      <div className="flex flex-wrap items-center gap-2">
        <div className="flex flex-wrap gap-1 rounded-lg border bg-card p-1">
          {(["pending", "approved", "suspended", "all"] as const).map((f) => (
            <button
              key={f}
              type="button"
              onClick={() => setFilter(f)}
              className={cn(
                "rounded-md px-3 py-1.5 text-sm font-semibold capitalize transition-colors",
                filter === f ? "bg-primary text-primary-foreground" : "text-muted-foreground hover:bg-accent",
              )}
            >
              {f === "pending" ? "Waiting" : f === "suspended" ? "Paused" : f} ({count(f)})
            </button>
          ))}
        </div>
        <div className="relative ml-auto w-full max-w-xs">
          <Search className="absolute left-2.5 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
          <Input className="pl-8" placeholder="Name, phone or plate" value={q} onChange={(e) => setQ(e.target.value)} />
        </div>
      </div>

      {drivers.isPending ? (
        <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-3">
          {Array.from({ length: 3 }).map((_, i) => (
            <Skeleton key={i} className="h-44" />
          ))}
        </div>
      ) : drivers.isError ? (
        <p className="rounded-xl border bg-card p-8 text-center text-sm text-destructive">
          {errorMessage(drivers.error)} — run supabase/RUN_RIDES_AND_PARTNERS.sql if the drivers table is missing.
        </p>
      ) : rows.length === 0 ? (
        <p className="rounded-xl border border-dashed bg-card p-10 text-center text-sm text-muted-foreground">
          {filter === "pending" ? "No drivers waiting for approval." : "No drivers here."}
        </p>
      ) : (
        <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-3">
          {rows.map((d) => {
            const on = isOnline(d);
            const rating = d.rating_count ? d.rating_sum / d.rating_count : null;
            const busy = setStatus.isPending && setStatus.variables?.id === d.user_id;
            return (
              <div key={d.user_id} className="flex flex-col rounded-xl border bg-card p-4">
                <div className="flex items-start gap-3">
                  <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-primary text-gold">
                    <CarTaxiFront className="h-5 w-5" />
                  </div>
                  <div className="min-w-0 flex-1">
                    <div className="flex flex-wrap items-center gap-2">
                      <span className="truncate font-bold">{d.full_name}</span>
                      <span className={cn("rounded-full px-2 py-0.5 text-xs font-semibold", STATUS_STYLE[d.status])}>
                        {d.status === "pending" ? "Waiting" : d.status === "suspended" ? "Paused" : "Approved"}
                      </span>
                    </div>
                    <div className="mt-0.5 text-sm text-muted-foreground">
                      {d.vehicle_type === "taxi" ? "Taxi" : "Bajaj"} · <b className="text-foreground">{d.plate}</b>
                      {d.vehicle_desc ? ` · ${d.vehicle_desc}` : ""}
                    </div>
                  </div>
                </div>

                <div className="mt-3 grid grid-cols-3 gap-2 text-center text-xs">
                  <div className="rounded-lg bg-muted/60 p-2">
                    <div className="flex items-center justify-center gap-1 text-base font-extrabold">
                      {rating ? (
                        <>
                          <Star className="h-3.5 w-3.5 fill-gold text-gold" /> {rating.toFixed(1)}
                        </>
                      ) : (
                        "—"
                      )}
                    </div>
                    <div className="text-muted-foreground">{d.rating_count} ratings</div>
                  </div>
                  <div className="rounded-lg bg-muted/60 p-2">
                    <div className="text-base font-extrabold">{d.rides_completed}</div>
                    <div className="text-muted-foreground">trips</div>
                  </div>
                  <div className="rounded-lg bg-muted/60 p-2">
                    <div className={cn("text-base font-extrabold", on ? "text-success" : "text-muted-foreground")}>
                      {on ? "Online" : "Offline"}
                    </div>
                    <div className="text-muted-foreground">
                      {d.location_at ? `seen ${timeAgo(d.location_at)}` : "never online"}
                    </div>
                  </div>
                </div>

                <div className="mt-3 flex flex-wrap items-center gap-2 text-sm">
                  <a
                    href={`tel:${d.phone.replace(/[^\d+]/g, "")}`}
                    className="inline-flex items-center gap-1.5 rounded-full bg-muted px-3 py-1 font-medium hover:bg-accent"
                  >
                    <Phone className="h-3.5 w-3.5" /> {d.phone}
                  </a>
                  <span className="text-xs text-muted-foreground">applied {formatDate(d.created_at)}</span>
                </div>

                <div className="mt-auto flex gap-2 pt-4">
                  {d.status !== "approved" && (
                    <Button
                      className="flex-1 bg-success text-white hover:bg-success/90"
                      disabled={busy}
                      onClick={() => setStatus.mutate({ id: d.user_id, status: "approved" })}
                    >
                      <BadgeCheck /> {d.status === "suspended" ? "Approve again" : "Approve"}
                    </Button>
                  )}
                  {d.status !== "suspended" && (
                    <Button variant="outline" className="flex-1" disabled={busy} onClick={() => setSuspend(d)}>
                      <Ban /> {d.status === "pending" ? "Don't approve" : "Pause"}
                    </Button>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      )}

      <ConfirmDialog
        open={!!suspend}
        onOpenChange={(open) => !open && setSuspend(undefined)}
        title={suspend?.status === "pending" ? "Don't approve this driver?" : "Pause this driver?"}
        description={`${suspend?.full_name ?? "The driver"} cannot go online or take rides until you approve them again.`}
        confirmLabel={suspend?.status === "pending" ? "Don't approve" : "Pause driver"}
        destructive
        loading={setStatus.isPending}
        onConfirm={() => suspend && setStatus.mutate({ id: suspend.user_id, status: "suspended" })}
      />
    </div>
  );
}
