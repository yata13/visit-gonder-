import * as React from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import {
  Car,
  CheckCircle2,
  Headset,
  MapPin,
  MessageCircle,
  Phone,
  RefreshCw,
  Siren,
  Trash2,
  User,
} from "lucide-react";
import { supabase } from "@/lib/supabase";
import { cn, errorMessage, timeAgo } from "@/lib/utils";
import type { Tables } from "@/lib/database.types";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { ConfirmDialog } from "@/components/confirm-dialog";

type EmergencyRequest = Tables<"emergency_requests">;
type StatusFilter = "all" | "pending" | "responding" | "resolved";

// Same type styling as the old Flutter admin's request cards.
const TYPE_STYLE: Record<
  string,
  {
    label: string;
    color: string;
    bg: string;
    icon: React.ComponentType<{ className?: string; style?: React.CSSProperties }>;
  }
> = {
  call: { label: "Call Request", color: "#1565C0", bg: "#1565C014", icon: Phone },
  transport: { label: "Transport", color: "#6A1B9A", bg: "#6A1B9A14", icon: Car },
  sos: { label: "SOS EMERGENCY", color: "#D32F2F", bg: "#D32F2F14", icon: Siren },
  message: { label: "Message", color: "#00695C", bg: "#00695C14", icon: MessageCircle },
};

const STATUS_COLOR: Record<string, string> = {
  pending: "#D32F2F",
  responding: "#EF6C00",
  resolved: "#2E7D32",
};

export default function EmergencyPage() {
  const queryClient = useQueryClient();
  const [filter, setFilter] = React.useState<StatusFilter>("all");
  const [deleteRow, setDeleteRow] = React.useState<EmergencyRequest | undefined>();

  const query = useQuery({
    queryKey: ["emergency"],
    queryFn: async (): Promise<EmergencyRequest[]> => {
      const { data, error } = await supabase
        .from("emergency_requests")
        .select("*")
        .order("created_at", { ascending: false })
        .limit(500);
      if (error) throw error;
      return data ?? [];
    },
    refetchInterval: 30_000, // keep the SOS list fresh
  });

  const requests = query.data ?? [];
  const filtered =
    filter === "all" ? requests : requests.filter((r) => (r.status ?? "pending") === filter);
  const count = (s: StatusFilter) =>
    s === "all" ? requests.length : requests.filter((r) => (r.status ?? "pending") === s).length;

  const statusMutation = useMutation({
    mutationFn: async ({ id, status }: { id: string; status: string }) => {
      const { error } = await supabase.rpc("admin_set_emergency_status", {
        p_id: id,
        p_status: status,
      });
      if (error) throw error;
    },
    onSuccess: (_d, { status }) => {
      toast.success(`Status updated to ${status}`);
      void queryClient.invalidateQueries({ queryKey: ["emergency"] });
    },
    onError: (err) => toast.error(errorMessage(err)),
  });

  const deleteMutation = useMutation({
    mutationFn: async (id: string) => {
      const { error } = await supabase.rpc("admin_delete_emergency", { p_id: id });
      if (error) throw error;
    },
    onSuccess: () => {
      toast.success("Request removed");
      setDeleteRow(undefined);
      void queryClient.invalidateQueries({ queryKey: ["emergency"] });
    },
    onError: (err) => toast.error(errorMessage(err)),
  });

  const pending = count("pending");

  return (
    <div className="space-y-4">
      {/* Header, like the old screen */}
      <div className="flex items-center gap-3">
        <div className="relative">
          <Siren className="h-7 w-7 text-[#D32F2F]" />
          {pending > 0 && (
            <span className="absolute -right-1 -top-1 flex h-4 w-4 items-center justify-center rounded-full bg-[#D32F2F] text-[9px] font-bold text-white">
              {pending}
            </span>
          )}
        </div>
        <div className="flex-1">
          <h2 className="text-xl font-bold">Emergency Requests</h2>
          <p className="text-sm text-muted-foreground">
            Live tourist SOS, calls, messages & transport requests
          </p>
        </div>
        <Button
          variant="ghost"
          size="icon"
          title="Refresh"
          onClick={() => void query.refetch()}
        >
          <RefreshCw className={cn("h-4 w-4 text-primary", query.isFetching && "animate-spin")} />
        </Button>
      </div>

      {/* Filter chips with counts */}
      <div className="flex flex-wrap gap-2">
        {(
          [
            ["all", "All", "#8C857F"],
            ["pending", "Pending", "#D32F2F"],
            ["responding", "Responding", "#EF6C00"],
            ["resolved", "Resolved", "#2E7D32"],
          ] as [StatusFilter, string, string][]
        ).map(([value, label, color]) => {
          const selected = filter === value;
          return (
            <button
              key={value}
              onClick={() => setFilter(value)}
              className="flex items-center gap-1.5 rounded-full border px-3.5 py-1.5 text-xs font-semibold transition-colors"
              style={{
                color: selected ? color : "#8C857F",
                borderColor: selected ? color : "hsl(var(--border))",
                backgroundColor: selected ? `${color}1E` : "hsl(var(--muted))",
              }}
            >
              {label}
              <span
                className="rounded-full px-1.5 py-px text-[11px] font-bold"
                style={{
                  backgroundColor: selected ? color : "#d4cfc9",
                  color: selected ? "white" : "#6b655f",
                }}
              >
                {count(value)}
              </span>
            </button>
          );
        })}
      </div>

      {/* Cards */}
      {query.isPending ? (
        <div className="space-y-3">
          {Array.from({ length: 3 }).map((_, i) => (
            <Skeleton key={i} className="h-36 w-full rounded-xl" />
          ))}
        </div>
      ) : filtered.length === 0 ? (
        <div className="flex flex-col items-center gap-2 rounded-xl border bg-card py-16 text-center">
          <CheckCircle2 className="h-12 w-12 text-success/40" />
          <p className="text-muted-foreground">
            {filter === "all" ? "No emergency requests yet" : `No ${filter} requests`}
          </p>
          <p className="text-sm text-muted-foreground/70">All tourists are safe ✅</p>
        </div>
      ) : (
        <div className="space-y-3">
          {filtered.map((r) => {
            const t = TYPE_STYLE[r.type ?? "message"] ?? TYPE_STYLE.message;
            const status = r.status ?? "pending";
            const sColor = STATUS_COLOR[status] ?? STATUS_COLOR.pending;
            const TypeIcon = t.icon;
            return (
              <div
                key={r.id}
                className={cn(
                  "rounded-xl border bg-card p-4 shadow-sm",
                  status === "pending" && "border-[#D32F2F]/40",
                )}
              >
                <div className="flex items-center gap-2.5">
                  <div
                    className="rounded-lg p-2"
                    style={{ backgroundColor: t.bg }}
                  >
                    <TypeIcon className="h-5 w-5" style={{ color: t.color }} />
                  </div>
                  <div className="min-w-0 flex-1">
                    <div className="text-sm font-bold" style={{ color: t.color }}>
                      {t.label}
                    </div>
                    <div className="text-xs text-muted-foreground">
                      {timeAgo(r.created_at)}
                    </div>
                  </div>
                  <span
                    className="rounded-full border px-2.5 py-1 text-[10px] font-bold"
                    style={{
                      color: sColor,
                      borderColor: `${sColor}80`,
                      backgroundColor: `${sColor}14`,
                    }}
                  >
                    {status.toUpperCase()}
                  </span>
                </div>

                <div className="my-3 border-t" />

                <div className="space-y-1.5 text-[13px]">
                  {r.name && <InfoRow icon={User} text={r.name} />}
                  {r.phone && <InfoRow icon={Phone} text={r.phone} />}
                  {(r.location || (r.lat !== null && r.lng !== null)) && (
                    <InfoRow
                      icon={MapPin}
                      text={
                        r.location ??
                        `${Number(r.lat).toFixed(4)}, ${Number(r.lng).toFixed(4)}`
                      }
                      link={
                        r.lat !== null && r.lng !== null
                          ? `https://www.openstreetmap.org/?mlat=${r.lat}&mlon=${r.lng}#map=17/${r.lat}/${r.lng}`
                          : undefined
                      }
                    />
                  )}
                  {r.message && <InfoRow icon={MessageCircle} text={r.message} />}
                </div>

                <div className="mt-3 flex items-center gap-2">
                  {status === "pending" && (
                    <Button
                      variant="outline"
                      size="sm"
                      className="flex-1 border-[#EF6C00] text-[#EF6C00] hover:bg-[#EF6C00]/10 hover:text-[#EF6C00]"
                      disabled={statusMutation.isPending}
                      onClick={() =>
                        statusMutation.mutate({ id: r.id, status: "responding" })
                      }
                    >
                      <Headset /> Responding
                    </Button>
                  )}
                  {status !== "resolved" && (
                    <Button
                      size="sm"
                      className="flex-1 bg-[#2E7D32] text-white hover:bg-[#2E7D32]/90"
                      disabled={statusMutation.isPending}
                      onClick={() =>
                        statusMutation.mutate({ id: r.id, status: "resolved" })
                      }
                    >
                      <CheckCircle2 /> Resolved
                    </Button>
                  )}
                  <Button
                    variant="ghost"
                    size="icon"
                    title="Delete"
                    onClick={() => setDeleteRow(r)}
                  >
                    <Trash2 className="h-4 w-4 text-destructive" />
                  </Button>
                </div>
              </div>
            );
          })}
        </div>
      )}

      <ConfirmDialog
        open={!!deleteRow}
        onOpenChange={(open) => !open && setDeleteRow(undefined)}
        title="Delete this request?"
        description="It will be removed from the emergency log."
        confirmLabel="Delete"
        destructive
        loading={deleteMutation.isPending}
        onConfirm={() => deleteRow && deleteMutation.mutate(deleteRow.id)}
      />
    </div>
  );
}

function InfoRow({
  icon: Icon,
  text,
  link,
}: {
  icon: React.ComponentType<{ className?: string }>;
  text: string;
  link?: string;
}) {
  const content = (
    <span className="flex items-start gap-2">
      <Icon className="mt-0.5 h-4 w-4 shrink-0 text-muted-foreground" />
      <span className={cn(link && "underline decoration-dotted")}>{text}</span>
    </span>
  );
  if (link) {
    return (
      <a href={link} target="_blank" rel="noreferrer" className="block hover:text-primary">
        {content}
      </a>
    );
  }
  return content;
}
