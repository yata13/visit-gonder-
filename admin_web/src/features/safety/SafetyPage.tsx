import * as React from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import L from "leaflet";
import {
  Circle,
  MapContainer,
  Marker,
  TileLayer,
  Tooltip,
  useMapEvents,
} from "react-leaflet";
import "leaflet/dist/leaflet.css";
import {
  CheckCircle2,
  Info,
  MapPinPlus,
  OctagonAlert,
  Pointer,
  Shield,
  Trash2,
  TriangleAlert,
  X,
} from "lucide-react";
import { supabase } from "@/lib/supabase";
import { cn, errorMessage } from "@/lib/utils";
import type { Tables, TablesInsert } from "@/lib/database.types";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Skeleton } from "@/components/ui/skeleton";
import { ConfirmDialog } from "@/components/confirm-dialog";

type DangerZone = Tables<"danger_zones">;
type Severity = "low" | "medium" | "high" | "critical";

const GONDAR: [number, number] = [12.603, 37.4521];

// Same severity colors as the old Flutter safety screen.
const SEVERITY_COLOR: Record<Severity, string> = {
  low: "#4CAF50",
  medium: "#FFC107",
  high: "#FF9800",
  critical: "#D32F2F",
};

function severityColor(s: string | null): string {
  return SEVERITY_COLOR[(s ?? "medium") as Severity] ?? SEVERITY_COLOR.medium;
}

function SeverityIcon({ s, className }: { s: string | null; className?: string }) {
  if (s === "low") return <Info className={className} />;
  if (s === "critical") return <OctagonAlert className={className} />;
  return <TriangleAlert className={className} />;
}

function zoneIcon(color: string): L.DivIcon {
  return L.divIcon({
    className: "",
    iconSize: [30, 30],
    iconAnchor: [15, 15],
    html: `<div style="width:30px;height:30px;border-radius:50%;background:${color};border:2px solid white;box-shadow:0 0 8px ${color}99;display:flex;align-items:center;justify-content:center;color:white;font-weight:700;font-size:14px">!</div>`,
  });
}

const PIN_ICON = L.divIcon({
  className: "",
  iconSize: [34, 34],
  iconAnchor: [17, 30],
  html: `<div style="font-size:30px;line-height:34px;text-align:center">📍</div>`,
});

function ClickCatcher({ onPick }: { onPick: (lat: number, lng: number) => void }) {
  useMapEvents({
    click: (e) => onPick(e.latlng.lat, e.latlng.lng),
  });
  return null;
}

export default function SafetyPage() {
  const queryClient = useQueryClient();

  const [showForm, setShowForm] = React.useState(false);
  const [pin, setPin] = React.useState<[number, number] | null>(null);
  const [name, setName] = React.useState("");
  const [description, setDescription] = React.useState("");
  const [severity, setSeverity] = React.useState<Severity>("medium");
  const [radius, setRadius] = React.useState(500);
  const [deleteRow, setDeleteRow] = React.useState<DangerZone | undefined>();

  const query = useQuery({
    queryKey: ["danger-zones"],
    queryFn: async (): Promise<DangerZone[]> => {
      const { data, error } = await supabase
        .from("danger_zones")
        .select("*")
        .order("created_at", { ascending: false });
      if (error) throw error;
      return data ?? [];
    },
  });
  const zones = query.data ?? [];

  function resetForm() {
    setShowForm(false);
    setPin(null);
    setName("");
    setDescription("");
    setSeverity("medium");
    setRadius(500);
  }

  const saveMutation = useMutation({
    mutationFn: async () => {
      if (!pin || !name.trim()) return;
      const payload: TablesInsert<"danger_zones"> = {
        name: name.trim(),
        description: description.trim() || null,
        severity,
        lat: pin[0],
        lng: pin[1],
        radius,
        is_active: true,
      };
      const { error } = await supabase.from("danger_zones").insert(payload);
      if (error) throw error;
    },
    onSuccess: () => {
      toast.success("Danger zone added!");
      resetForm();
      void queryClient.invalidateQueries({ queryKey: ["danger-zones"] });
    },
    onError: (err) => toast.error(errorMessage(err)),
  });

  const toggleMutation = useMutation({
    mutationFn: async (z: DangerZone) => {
      const { error } = await supabase
        .from("danger_zones")
        .update({ is_active: !z.is_active })
        .eq("id", z.id);
      if (error) throw error;
    },
    onSuccess: () => void queryClient.invalidateQueries({ queryKey: ["danger-zones"] }),
    onError: (err) => toast.error(errorMessage(err)),
  });

  const deleteMutation = useMutation({
    mutationFn: async (id: string) => {
      const { error } = await supabase.from("danger_zones").delete().eq("id", id);
      if (error) throw error;
    },
    onSuccess: () => {
      toast.success("Zone deleted");
      setDeleteRow(undefined);
      void queryClient.invalidateQueries({ queryKey: ["danger-zones"] });
    },
    onError: (err) => toast.error(errorMessage(err)),
  });

  return (
    <div className="space-y-4">
      {/* Header */}
      <div className="flex items-center gap-3">
        <Shield className="h-6 w-6 text-primary" />
        <div className="flex-1">
          <h2 className="text-xl font-bold">Safety Map</h2>
          <p className="text-sm text-muted-foreground">
            Mark danger zones — tourists see them on their map
          </p>
        </div>
        {!showForm && (
          <Button onClick={() => setShowForm(true)}>
            <MapPinPlus /> Add Zone
          </Button>
        )}
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-[1fr_320px]">
        {/* ── Map ── */}
        <div className="relative h-[420px] overflow-hidden rounded-xl border lg:h-[560px]">
          <MapContainer center={GONDAR} zoom={13} scrollWheelZoom>
            <TileLayer
              url="https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png"
              attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> &copy; <a href="https://carto.com/">CARTO</a>'
              subdomains={["a", "b", "c", "d"]}
            />
            {showForm && <ClickCatcher onPick={(lat, lng) => setPin([lat, lng])} />}

            {zones.map((z) => {
              const color = severityColor(z.severity);
              const active = z.is_active ?? true;
              return (
                <React.Fragment key={z.id}>
                  <Circle
                    center={[z.lat, z.lng]}
                    radius={z.radius ?? 500}
                    pathOptions={{
                      color,
                      opacity: active ? 0.8 : 0.3,
                      fillColor: color,
                      fillOpacity: active ? 0.24 : 0.08,
                      weight: 2,
                    }}
                  />
                  <Marker position={[z.lat, z.lng]} icon={zoneIcon(active ? color : "#B0AAA4")}>
                    <Tooltip direction="top" offset={[0, -14]}>
                      <b>{z.name}</b>
                      <br />
                      {(z.severity ?? "medium").toUpperCase()} · {z.radius ?? 500}m
                    </Tooltip>
                  </Marker>
                </React.Fragment>
              );
            })}

            {pin && <Marker position={pin} icon={PIN_ICON} />}
          </MapContainer>

          {showForm && !pin && (
            <div className="pointer-events-none absolute left-1/2 top-4 z-[1000] -translate-x-1/2">
              <div className="flex items-center gap-2 rounded-full bg-foreground px-4 py-2.5 text-[13px] text-white shadow-lg">
                <Pointer className="h-4 w-4" />
                Tap on the map to place the danger zone
              </div>
            </div>
          )}
        </div>

        {/* ── Right panel ── */}
        <div className="rounded-xl border bg-card">
          {showForm ? (
            <div className="space-y-4 p-5">
              <div className="flex items-center justify-between">
                <h3 className="font-bold">New Danger Zone</h3>
                <Button variant="ghost" size="icon" onClick={resetForm}>
                  <X className="h-4 w-4" />
                </Button>
              </div>

              {pin ? (
                <div className="flex items-start gap-2 rounded-lg bg-success-bg p-2.5 text-xs">
                  <CheckCircle2 className="h-4 w-4 shrink-0 text-success" />
                  <span>
                    Pin placed at
                    <br />
                    {pin[0].toFixed(4)}, {pin[1].toFixed(4)}
                  </span>
                </div>
              ) : (
                <div className="flex items-center gap-2 rounded-lg bg-warning-bg p-2.5 text-xs">
                  <Pointer className="h-4 w-4 shrink-0 text-warning" />
                  Tap the map to place pin first
                </div>
              )}

              <div className="space-y-1.5">
                <span className="text-xs font-semibold">Zone Name</span>
                <Input
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  placeholder="e.g. North Road Checkpoint"
                />
              </div>

              <div className="space-y-1.5">
                <span className="text-xs font-semibold">Description</span>
                <Textarea
                  rows={2}
                  value={description}
                  onChange={(e) => setDescription(e.target.value)}
                  placeholder="What is the danger? Advise tourists…"
                />
              </div>

              <div className="space-y-1.5">
                <span className="text-xs font-semibold">Severity Level</span>
                <div className="flex gap-1">
                  {(Object.keys(SEVERITY_COLOR) as Severity[]).map((s) => {
                    const selected = severity === s;
                    return (
                      <button
                        key={s}
                        type="button"
                        onClick={() => setSeverity(s)}
                        className={cn(
                          "flex-1 rounded-md border py-2 text-[11px] font-semibold capitalize transition-colors",
                          !selected && "bg-muted text-muted-foreground",
                        )}
                        style={
                          selected
                            ? {
                                backgroundColor: SEVERITY_COLOR[s],
                                borderColor: SEVERITY_COLOR[s],
                                color: "white",
                              }
                            : undefined
                        }
                      >
                        {s}
                      </button>
                    );
                  })}
                </div>
              </div>

              <div className="space-y-1.5">
                <span className="text-xs font-semibold">Warning Radius</span>
                <div className="flex items-center gap-3">
                  <input
                    type="range"
                    min={100}
                    max={3000}
                    step={100}
                    value={radius}
                    onChange={(e) => setRadius(Number(e.target.value))}
                    className="flex-1 accent-[hsl(var(--primary))]"
                  />
                  <span className="w-14 text-[13px] font-semibold">{radius}m</span>
                </div>
              </div>

              <Button
                className="w-full"
                disabled={!pin || !name.trim() || saveMutation.isPending}
                onClick={() => saveMutation.mutate()}
              >
                <MapPinPlus /> {saveMutation.isPending ? "Adding…" : "Add Danger Zone"}
              </Button>
            </div>
          ) : query.isPending ? (
            <div className="space-y-2 p-4">
              {Array.from({ length: 4 }).map((_, i) => (
                <Skeleton key={i} className="h-14 w-full rounded-lg" />
              ))}
            </div>
          ) : zones.length === 0 ? (
            <div className="flex flex-col items-center gap-2 py-16 text-center">
              <Shield className="h-12 w-12 text-muted-foreground/30" />
              <p className="text-muted-foreground">No danger zones yet</p>
              <p className="text-xs text-muted-foreground/70">
                Click “Add Zone” and tap the map
              </p>
            </div>
          ) : (
            <div className="flex h-full flex-col">
              <div className="flex items-center justify-between px-4 pt-4">
                <span className="font-bold">
                  {zones.length} zone{zones.length !== 1 ? "s" : ""}
                </span>
                <span className="text-xs text-success">
                  {zones.filter((z) => z.is_active).length} active
                </span>
              </div>
              <div className="max-h-[480px] space-y-2 overflow-y-auto p-3">
                {zones.map((z) => {
                  const color = severityColor(z.severity);
                  const active = z.is_active ?? true;
                  return (
                    <div
                      key={z.id}
                      className="flex items-center gap-3 rounded-[10px] border p-3"
                      style={
                        active
                          ? { borderColor: `${color}80`, backgroundColor: `${color}0F` }
                          : undefined
                      }
                    >
                      <span
                        className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-white"
                        style={{ backgroundColor: active ? color : "#CBC5BF" }}
                      >
                        <SeverityIcon s={z.severity} className="h-[18px] w-[18px]" />
                      </span>
                      <div className="min-w-0 flex-1">
                        <div
                          className={cn(
                            "truncate text-[13px] font-semibold",
                            !active && "text-muted-foreground",
                          )}
                        >
                          {z.name}
                        </div>
                        <div
                          className="text-[11px]"
                          style={{ color: active ? color : "#8C857F" }}
                        >
                          {(z.severity ?? "medium").toUpperCase()} • {z.radius ?? 500}m radius
                        </div>
                      </div>
                      <label className="flex cursor-pointer items-center" title="Active on tourist map">
                        <input
                          type="checkbox"
                          className="h-4 w-4 rounded border-input accent-[hsl(var(--primary))]"
                          checked={active}
                          onChange={() => toggleMutation.mutate(z)}
                        />
                      </label>
                      <button
                        className="p-1 text-destructive/80 hover:text-destructive"
                        title="Delete"
                        onClick={() => setDeleteRow(z)}
                      >
                        <Trash2 className="h-4 w-4" />
                      </button>
                    </div>
                  );
                })}
              </div>
            </div>
          )}
        </div>
      </div>

      <ConfirmDialog
        open={!!deleteRow}
        onOpenChange={(open) => !open && setDeleteRow(undefined)}
        title="Delete danger zone?"
        description="This will remove it from the tourist map."
        confirmLabel="Delete"
        destructive
        loading={deleteMutation.isPending}
        onConfirm={() => deleteRow && deleteMutation.mutate(deleteRow.id)}
      />
    </div>
  );
}
