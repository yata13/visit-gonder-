import * as React from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import L from "leaflet";
import { MapContainer, Marker, Polyline, TileLayer, Tooltip } from "react-leaflet";
import "leaflet/dist/leaflet.css";
import { CarTaxiFront, CircleDollarSign, Clock3, Flag, Phone, Route, Save, Users, XCircle } from "lucide-react";
import { supabase } from "@/lib/supabase";
import { cn, errorMessage, formatMoney, timeAgo } from "@/lib/utils";
import type { Tables } from "@/lib/database.types";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Skeleton } from "@/components/ui/skeleton";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { isOnline, useDrivers } from "@/features/drivers/DriversPage";

type Ride = Tables<"rides">;
type Fare = Tables<"ride_fares">;
type Filter = "live" | "today" | "all";

const LIVE = new Set(["requested", "accepted", "arrived", "in_progress"]);
const GONDAR: [number, number] = [12.6075, 37.4592];

const STATUS: Record<string, { label: string; className: string }> = {
  requested: { label: "Finding a driver", className: "bg-warning-bg text-warning" },
  accepted: { label: "Driver on the way", className: "bg-info-bg text-info" },
  arrived: { label: "Driver at pickup", className: "bg-info-bg text-info" },
  in_progress: { label: "On the trip", className: "bg-success-bg text-success" },
  completed: { label: "Completed", className: "bg-muted text-foreground" },
  cancelled: { label: "Cancelled", className: "bg-destructive/10 text-destructive" },
  expired: { label: "No driver found", className: "bg-destructive/10 text-destructive" },
};

function dot(color: string, label: string) {
  return L.divIcon({
    className: "",
    iconSize: [26, 26],
    iconAnchor: [13, 13],
    html: `<div style="width:26px;height:26px;border-radius:50%;background:${color};border:3px solid white;box-shadow:0 1px 6px #0006;color:white;font:700 11px/20px system-ui;text-align:center">${label}</div>`,
  });
}
const PICKUP = dot("#1F7A4D", "");
const DRIVER = dot("#7C4928", "🛺");
const DROPOFF = L.divIcon({
  className: "",
  iconSize: [14, 14],
  iconAnchor: [7, 7],
  html: `<div style="width:14px;height:14px;border-radius:3px;background:#7C4928;border:2px solid white;box-shadow:0 1px 4px #0006"></div>`,
});

function isToday(iso: string | null) {
  if (!iso) return false;
  const d = new Date(iso);
  const n = new Date();
  return d.getFullYear() === n.getFullYear() && d.getMonth() === n.getMonth() && d.getDate() === n.getDate();
}

export default function RidesPage() {
  const queryClient = useQueryClient();
  const [filter, setFilter] = React.useState<Filter>("live");
  const [cancelRide, setCancelRide] = React.useState<Ride | undefined>();
  const [reason, setReason] = React.useState("");

  const rides = useQuery({
    queryKey: ["rides"],
    queryFn: async (): Promise<Ride[]> => {
      const { data, error } = await supabase
        .from("rides")
        .select("*")
        .order("created_at", { ascending: false })
        .limit(300);
      if (error) throw error;
      return data ?? [];
    },
  });
  const drivers = useDrivers();

  const cancel = useMutation({
    mutationFn: async () => {
      const { error } = await supabase.rpc("admin_cancel_ride", {
        p_ride_id: cancelRide!.id,
        p_reason: reason.trim() || null,
      });
      if (error) throw error;
    },
    onSuccess: () => {
      toast.success("Ride cancelled — the tourist and the driver are told.");
      setCancelRide(undefined);
      setReason("");
      void queryClient.invalidateQueries({ queryKey: ["rides"] });
    },
    onError: (err) => toast.error(errorMessage(err)),
  });

  const all = rides.data ?? [];
  // A request older than 15 minutes is expired even before the server marks it.
  const stale = (r: Ride) => r.status === "requested" && Date.now() - new Date(r.created_at).getTime() > 15 * 60_000;
  const live = all.filter((r) => LIVE.has(r.status) && !stale(r));
  const today = all.filter((r) => isToday(r.created_at));
  const doneToday = all.filter((r) => r.status === "completed" && isToday(r.completed_at));
  const faresToday = doneToday.reduce((s, r) => s + Number(r.fare_estimate), 0);
  const online = (drivers.data ?? []).filter(isOnline).length;
  const rows = filter === "live" ? live : filter === "today" ? today : all;

  const tiles = [
    { label: "Rides live now", value: live.length, icon: Route },
    { label: "Waiting for a driver", value: live.filter((r) => r.status === "requested").length, icon: Clock3 },
    { label: "Completed today", value: doneToday.length, icon: Flag },
    { label: "Fares today (cash)", value: formatMoney(faresToday), icon: CircleDollarSign },
    { label: "Drivers online", value: online, icon: Users },
  ];

  return (
    <div className="space-y-4">
      <div className="grid grid-cols-2 gap-3 md:grid-cols-3 xl:grid-cols-5">
        {tiles.map(({ label, value, icon: Icon }) => (
          <div key={label} className="rounded-xl border bg-card p-4">
            <div className="flex items-center gap-2 text-sm text-muted-foreground">
              <Icon className="h-4 w-4 text-gold" /> {label}
            </div>
            <div className="mt-1 text-2xl font-extrabold">{rides.isPending ? "…" : value}</div>
          </div>
        ))}
      </div>

      <div className="grid grid-cols-1 gap-4 xl:grid-cols-[minmax(0,1fr)_380px]">
        <div className="relative h-[380px] overflow-hidden rounded-xl border xl:h-[460px]">
          <MapContainer center={GONDAR} zoom={13} scrollWheelZoom>
            <TileLayer
              url="https://tile.openstreetmap.org/{z}/{x}/{y}.png"
              attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
              maxZoom={19}
            />
            {live.map((r) => (
              <React.Fragment key={r.id}>
                <Polyline
                  positions={[[r.pickup_lat, r.pickup_lng], [r.dropoff_lat, r.dropoff_lng]]}
                  pathOptions={{ color: "#7C4928", weight: 3, dashArray: "8 8", opacity: 0.7 }}
                />
                <Marker position={[r.dropoff_lat, r.dropoff_lng]} icon={DROPOFF}>
                  <Tooltip>{r.dropoff_label || "Destination"}</Tooltip>
                </Marker>
                <Marker position={[r.pickup_lat, r.pickup_lng]} icon={PICKUP}>
                  <Tooltip>
                    {r.rider_name || "Tourist"} · {STATUS[r.status]?.label} · {r.pickup_label} → {r.dropoff_label}
                  </Tooltip>
                </Marker>
                {r.driver_lat != null && r.driver_lng != null && (
                  <Marker position={[r.driver_lat, r.driver_lng]} icon={DRIVER}>
                    <Tooltip>
                      {r.driver_name} · {r.vehicle_plate}
                    </Tooltip>
                  </Marker>
                )}
              </React.Fragment>
            ))}
          </MapContainer>
          <div className="pointer-events-none absolute right-3 top-3 z-[400] rounded-lg bg-card/95 px-3 py-1.5 text-xs font-semibold shadow">
            {live.length === 0 ? "No rides right now" : `${live.length} live ride${live.length === 1 ? "" : "s"}`}
          </div>
        </div>
        <FaresCard />
      </div>

      <div className="flex flex-wrap gap-1 rounded-lg border bg-card p-1 sm:w-max">
        {(
          [
            ["live", `Live (${live.length})`],
            ["today", `Today (${today.length})`],
            ["all", "Latest 300"],
          ] as const
        ).map(([f, label]) => (
          <button
            key={f}
            type="button"
            onClick={() => setFilter(f)}
            className={cn(
              "rounded-md px-3 py-1.5 text-sm font-semibold transition-colors",
              filter === f ? "bg-primary text-primary-foreground" : "text-muted-foreground hover:bg-accent",
            )}
          >
            {label}
          </button>
        ))}
      </div>

      {rides.isPending ? (
        <Skeleton className="h-40 w-full" />
      ) : rides.isError ? (
        <p className="rounded-xl border bg-card p-8 text-center text-sm text-destructive">
          {errorMessage(rides.error)} — run supabase/RUN_RIDES_AND_PARTNERS.sql if the rides table is missing.
        </p>
      ) : rows.length === 0 ? (
        <p className="rounded-xl border border-dashed bg-card p-10 text-center text-sm text-muted-foreground">
          {filter === "live" ? "No rides right now. They appear here live." : "No rides."}
        </p>
      ) : (
        <div className="overflow-hidden rounded-xl border bg-card">
          <ul className="divide-y">
            {rows.map((r) => {
              const s = stale(r) ? STATUS.expired : STATUS[r.status] ?? { label: r.status, className: "bg-muted" };
              return (
                <li
                  key={r.id}
                  className="flex flex-wrap items-center gap-x-4 gap-y-2 p-4 lg:grid lg:grid-cols-[40px_minmax(0,2.2fr)_minmax(0,1fr)_minmax(0,1.3fr)_96px_96px]"
                >
                  <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-secondary text-primary">
                    <CarTaxiFront className="h-5 w-5" />
                  </div>
                  <div className="min-w-[220px] flex-1 lg:min-w-0">
                    <div className="flex flex-wrap items-center gap-2">
                      <span className="font-semibold">
                        {r.pickup_label || "Pickup"} → {r.dropoff_label || "Destination"}
                      </span>
                      <span className={cn("rounded-full px-2 py-0.5 text-xs font-semibold", s.className)}>{s.label}</span>
                    </div>
                    <div className="mt-0.5 text-sm text-muted-foreground">
                      {r.vehicle_type === "taxi" ? "Taxi" : "Bajaj"} · {Number(r.distance_km).toFixed(1)} km ·{" "}
                      {timeAgo(r.created_at)}
                      {r.cancelled_by && ` · cancelled by ${r.cancelled_by}`}
                      {r.cancel_reason && ` (${r.cancel_reason})`}
                      {r.rider_rating ? ` · rated ${"★".repeat(r.rider_rating)}` : ""}
                    </div>
                  </div>
                  <div className="min-w-[150px] text-sm lg:min-w-0">
                    <div className="font-medium">{r.rider_name || "Tourist"}</div>
                    {r.rider_phone && (
                      <a href={`tel:${r.rider_phone}`} className="inline-flex items-center gap-1 text-muted-foreground hover:underline">
                        <Phone className="h-3 w-3" /> {r.rider_phone}
                      </a>
                    )}
                  </div>
                  <div className="min-w-[150px] text-sm lg:min-w-0">
                    {r.driver_name ? (
                      <>
                        <div className="font-medium">{r.driver_name}</div>
                        <div className="text-muted-foreground">
                          {r.vehicle_plate}
                          {r.driver_phone && (
                            <a href={`tel:${r.driver_phone}`} className="ml-1 hover:underline">· {r.driver_phone}</a>
                          )}
                        </div>
                      </>
                    ) : (
                      <span className="text-muted-foreground">No driver yet</span>
                    )}
                  </div>
                  <div className="w-24 text-right font-extrabold text-primary">{formatMoney(r.fare_estimate)}</div>
                  {LIVE.has(r.status) && !stale(r) ? (
                    <Button variant="ghost" size="sm" className="text-destructive" onClick={() => setCancelRide(r)}>
                      <XCircle /> Cancel
                    </Button>
                  ) : (
                    <span className="hidden lg:block" />
                  )}
                </li>
              );
            })}
          </ul>
        </div>
      )}

      <Dialog open={!!cancelRide} onOpenChange={(open) => !open && setCancelRide(undefined)}>
        <DialogContent className="max-w-md">
          <DialogHeader>
            <DialogTitle>Cancel this ride?</DialogTitle>
            <DialogDescription>
              {cancelRide?.rider_name || "The tourist"}
              {cancelRide?.driver_name ? ` and ${cancelRide.driver_name}` : ""} will be told in their apps.
            </DialogDescription>
          </DialogHeader>
          <Textarea
            rows={2}
            placeholder="Reason (optional), e.g. road closed for Timket"
            value={reason}
            onChange={(e) => setReason(e.target.value)}
          />
          <DialogFooter>
            <Button variant="outline" onClick={() => setCancelRide(undefined)} disabled={cancel.isPending}>
              Back
            </Button>
            <Button variant="destructive" onClick={() => cancel.mutate()} disabled={cancel.isPending}>
              {cancel.isPending ? "Cancelling…" : "Cancel ride"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}

/** Prices for both vehicle types (ride_fares). The app quotes from these. */
function FaresCard() {
  const queryClient = useQueryClient();
  const fares = useQuery({
    queryKey: ["ride-fares"],
    queryFn: async (): Promise<Fare[]> => {
      const { data, error } = await supabase.from("ride_fares").select("*").order("vehicle_type");
      if (error) throw error;
      return data ?? [];
    },
  });
  const [edit, setEdit] = React.useState<Record<string, { base_fare: string; per_km: string; minimum: string }>>({});

  React.useEffect(() => {
    if (!fares.data) return;
    setEdit(
      Object.fromEntries(
        fares.data.map((f) => [f.vehicle_type, { base_fare: String(f.base_fare), per_km: String(f.per_km), minimum: String(f.minimum) }]),
      ),
    );
  }, [fares.data]);

  const save = useMutation({
    mutationFn: async (type: string) => {
      const e = edit[type];
      const values = { base_fare: Number(e.base_fare), per_km: Number(e.per_km), minimum: Number(e.minimum) };
      if (Object.values(values).some((v) => !Number.isFinite(v) || v < 0)) throw new Error("Prices must be 0 or more.");
      const { error } = await supabase
        .from("ride_fares")
        .update({ ...values, updated_at: new Date().toISOString() })
        .eq("vehicle_type", type);
      if (error) throw error;
      return type;
    },
    onSuccess: (type) => {
      toast.success(`${type === "taxi" ? "Taxi" : "Bajaj"} prices saved — new rides use them.`);
      void queryClient.invalidateQueries({ queryKey: ["ride-fares"] });
    },
    onError: (err) => toast.error(errorMessage(err)),
  });

  return (
    <div className="rounded-xl border bg-card p-4">
      <h2 className="font-bold">Prices (ETB)</h2>
      <p className="text-xs text-muted-foreground">
        Start price + price per km, never below the minimum. Rounded to 5 birr.
      </p>
      <div className="mt-3 space-y-4">
        {(fares.data ?? []).map((f) => {
          const e = edit[f.vehicle_type];
          if (!e) return null;
          const example = Math.max(Number(e.minimum), Math.round((Number(e.base_fare) + Number(e.per_km) * 3) / 5) * 5);
          const set = (k: keyof typeof e) => (ev: React.ChangeEvent<HTMLInputElement>) =>
            setEdit({ ...edit, [f.vehicle_type]: { ...e, [k]: ev.target.value.replace(/[^\d.]/g, "") } });
          return (
            <div key={f.vehicle_type} className="rounded-lg border p-3">
              <div className="mb-2 flex items-center gap-2 font-semibold">
                <CarTaxiFront className="h-4 w-4 text-primary" />
                {f.vehicle_type === "taxi" ? "Taxi" : "Bajaj"}
                <span className="ml-auto text-xs font-normal text-muted-foreground">
                  3 km ≈ {Number.isFinite(example) ? example : "—"} ETB
                </span>
              </div>
              <div className="grid grid-cols-3 gap-2">
                {(
                  [
                    ["base_fare", "Start"],
                    ["per_km", "Per km"],
                    ["minimum", "Minimum"],
                  ] as const
                ).map(([k, label]) => (
                  <label key={k} className="text-xs text-muted-foreground">
                    {label}
                    <Input inputMode="decimal" className="mt-1" value={e[k]} onChange={set(k)} />
                  </label>
                ))}
              </div>
              <Button
                size="sm"
                variant="outline"
                className="mt-2 w-full"
                disabled={save.isPending}
                onClick={() => save.mutate(f.vehicle_type)}
              >
                <Save /> Save {f.vehicle_type === "taxi" ? "taxi" : "bajaj"} prices
              </Button>
            </div>
          );
        })}
        {fares.isPending && <Skeleton className="h-40 w-full" />}
      </div>
    </div>
  );
}
