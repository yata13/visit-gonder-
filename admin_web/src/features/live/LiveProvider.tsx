import * as React from "react";
import { useQueryClient } from "@tanstack/react-query";
import type { RealtimePostgresChangesPayload } from "@supabase/supabase-js";
import { supabase } from "@/lib/supabase";
import { formatMoney } from "@/lib/utils";

/* ═══════════════════════════════════════════════════════════════
   LIVE — one Supabase Realtime channel for the whole admin.
   Every change to a watched table:
     · refreshes all open queries (pages update without reload)
     · lands in the live feed / ticker on the dashboard
     · plays a chime on the office TV (when sound is on)
   Needs supabase/ENABLE_LIVE_UPDATES.sql (migration 0015).
   ═══════════════════════════════════════════════════════════════ */

export type LiveTone = "sos" | "money" | "info" | "alert";

export interface LiveEvent {
  id: string;
  table: string;
  title: string;
  detail: string;
  tone: LiveTone;
  at: string; // ISO time
  /** True for events that arrived live (not the initial history). */
  fresh: boolean;
}

interface LiveState {
  events: LiveEvent[];
  connected: boolean;
  /** Time of the last change seen, live or polled. */
  lastUpdate: Date | null;
  sound: boolean;
  setSound: (on: boolean) => void;
}

const LiveContext = React.createContext<LiveState | null>(null);

export function useLive(): LiveState {
  const ctx = React.useContext(LiveContext);
  if (!ctx) throw new Error("useLive must be used inside <LiveProvider>");
  return ctx;
}

const WATCHED = [
  "notifications",
  "bookings",
  "emergency_requests",
  "passport_checkins",
  "users",
  "danger_zones",
  "posts",
  "premium_requests",
  "deposits",
  "hotels",
  "sites",
  "guides",
  "events",
  "places",
] as const;

const MAX_EVENTS = 60;

type Row = Record<string, any>;

const LISTING_LABEL: Record<string, string> = {
  hotels: "Hotel",
  sites: "Site",
  guides: "Guide",
  events: "Event",
  places: "Map place",
};

/** Turns a database change into a line people can read on the wall. */
function describe(
  table: string,
  kind: "INSERT" | "UPDATE" | "DELETE",
  row: Row,
): Omit<LiveEvent, "id" | "at" | "fresh" | "table"> | null {
  const s = (v: unknown) => (v === null || v === undefined ? "" : String(v));
  switch (table) {
    case "notifications":
      if (kind !== "INSERT") return null;
      return {
        title: `Notification sent · ${s(row.title)}`,
        detail: s(row.message || row.body),
        tone: row.type === "safety" ? "alert" : "info",
      };
    case "bookings":
      if (kind === "INSERT")
        return {
          title: `New booking · ${s(row.item_name || row.item_type)}`,
          detail: `${s(row.customer_name) || "A visitor"} · ${formatMoney(row.total_price ?? row.price)}`,
          tone: "money",
        };
      if (kind === "UPDATE")
        return {
          title: `Booking ${s(row.status)} · ${s(row.item_name || row.item_type)}`,
          detail: s(row.customer_name),
          tone: row.status === "rejected" || row.status === "cancelled" ? "alert" : "money",
        };
      return null;
    case "emergency_requests":
      if (kind === "INSERT")
        return {
          title:
            !row.type || row.type === "sos"
              ? `SOS from ${s(row.name) || "a visitor"}`
              : `Help request (${s(row.type)}) · ${s(row.name) || "a visitor"}`,
          detail: s(row.message || row.location || row.phone),
          tone: "sos",
        };
      if (kind === "UPDATE")
        return {
          title: `SOS ${s(row.status)} · ${s(row.name) || "visitor"}`,
          detail: s(row.message),
          tone: row.status === "resolved" ? "info" : "sos",
        };
      return null;
    case "passport_checkins":
      return kind === "INSERT"
        ? { title: "Passport stamp collected", detail: `Check-in by ${s(row.method) || "code"}`, tone: "info" }
        : null;
    case "users":
      return kind === "INSERT"
        ? {
            title: `New tourist · ${s(row.full_name) || s(row.email) || "signed up"}`,
            detail: s(row.country),
            tone: "info",
          }
        : null;
    case "danger_zones":
      if (kind === "DELETE") return null;
      return {
        title: `${row.is_active === false ? "Safety zone cleared" : "Safety zone active"} · ${s(row.name)}`,
        detail: s(row.description),
        tone: row.is_active === false ? "info" : "alert",
      };
    case "posts":
      return kind === "INSERT"
        ? { title: `News posted · ${s(row.title)}`, detail: s(row.body).slice(0, 140), tone: "info" }
        : null;
    case "premium_requests":
      return kind === "INSERT"
        ? { title: "Premium request", detail: s(row.email), tone: "money" }
        : null;
    case "deposits":
      return row.status === "success"
        ? {
            title: "Deposit paid (Chapa)",
            detail: formatMoney(row.amount, s(row.currency) || "ETB"),
            tone: "money",
          }
        : null;
    default: {
      const label = LISTING_LABEL[table];
      if (!label) return null;
      const verb = kind === "INSERT" ? "added" : kind === "DELETE" ? "removed" : "updated";
      return {
        title: `${label} ${verb} · ${s(row.name || row.title) || "listing"}`,
        detail: row.publish_status ? `Status: ${s(row.publish_status)}` : "",
        tone: "info",
      };
    }
  }
}

/* ── Chime (Web Audio — no sound file needed) ────────────────── */
let audioCtx: AudioContext | null = null;
function chime(tone: LiveTone) {
  try {
    audioCtx ??= new AudioContext();
    const ctx = audioCtx;
    // Urgent events get a rising two-tone alarm, the rest a soft "ding".
    const notes = tone === "sos" ? [880, 1175, 880, 1175] : tone === "money" ? [784, 1047] : [988];
    notes.forEach((freq, i) => {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      const t = ctx.currentTime + i * 0.18;
      osc.type = tone === "sos" ? "square" : "sine";
      osc.frequency.value = freq;
      gain.gain.setValueAtTime(0.0001, t);
      gain.gain.exponentialRampToValueAtTime(tone === "sos" ? 0.15 : 0.25, t + 0.02);
      gain.gain.exponentialRampToValueAtTime(0.0001, t + 0.3);
      osc.connect(gain).connect(ctx.destination);
      osc.start(t);
      osc.stop(t + 0.32);
    });
  } catch {
    /* audio blocked until the first click — ignore */
  }
}

/** The last few rows of the busiest tables, so the wall is never empty. */
async function loadHistory(): Promise<LiveEvent[]> {
  const sources: { table: string; time: string }[] = [
    { table: "notifications", time: "created_at" },
    { table: "bookings", time: "created_at" },
    { table: "emergency_requests", time: "created_at" },
    { table: "passport_checkins", time: "checked_in_at" },
    { table: "users", time: "created_at" },
  ];
  const lists = await Promise.all(
    sources.map(async ({ table, time }) => {
      const { data } = await supabase
        .from(table as "bookings")
        .select("*")
        .order(time as "created_at", { ascending: false })
        .limit(8);
      return ((data ?? []) as Row[]).flatMap((row) => {
        const d = describe(table, "INSERT", row);
        if (!d) return [];
        return [{ ...d, id: `${table}:${row.id}`, table, at: String(row[time] ?? ""), fresh: false }];
      });
    }),
  );
  return lists
    .flat()
    .filter((e) => e.at)
    .sort((a, b) => b.at.localeCompare(a.at))
    .slice(0, 25);
}

export function LiveProvider({ children }: { children: React.ReactNode }) {
  const queryClient = useQueryClient();
  const [events, setEvents] = React.useState<LiveEvent[]>([]);
  const [connected, setConnected] = React.useState(false);
  const [lastUpdate, setLastUpdate] = React.useState<Date | null>(null);
  const [sound, setSoundState] = React.useState(() => {
    try {
      return localStorage.getItem("live-sound") === "on";
    } catch {
      return false;
    }
  });
  const soundRef = React.useRef(sound);

  const setSound = React.useCallback((on: boolean) => {
    soundRef.current = on;
    setSoundState(on);
    try {
      localStorage.setItem("live-sound", on ? "on" : "off");
    } catch {
      /* private window — keep it for this visit only */
    }
    if (on) chime("info"); // also unlocks audio after the click
  }, []);

  React.useEffect(() => {
    let cancelled = false;
    loadHistory()
      .then((history) => {
        if (cancelled) return;
        setEvents((live) => {
          const seen = new Set(live.map((e) => e.id));
          return [...live, ...history.filter((e) => !seen.has(e.id))].slice(0, MAX_EVENTS);
        });
      })
      .catch(() => {});

    // Coalesce bursts of changes into one refresh.
    let refreshTimer: ReturnType<typeof setTimeout> | undefined;
    const refreshSoon = () => {
      clearTimeout(refreshTimer);
      refreshTimer = setTimeout(() => queryClient.invalidateQueries(), 250);
    };

    const onChange = (table: string) => (payload: RealtimePostgresChangesPayload<Row>) => {
      setLastUpdate(new Date());
      refreshSoon();
      const row = (payload.eventType === "DELETE" ? payload.old : payload.new) as Row;
      const d = describe(table, payload.eventType, row ?? {});
      if (!d) return;
      const event: LiveEvent = {
        ...d,
        id: `${table}:${row?.id ?? Math.random()}:${payload.eventType}:${Date.now()}`,
        table,
        at: new Date().toISOString(),
        fresh: true,
      };
      setEvents((list) => [event, ...list].slice(0, MAX_EVENTS));
      if (soundRef.current) chime(d.tone);
    };

    let channel = supabase.channel("admin-live");
    for (const table of WATCHED) {
      channel = channel.on(
        "postgres_changes",
        { event: "*", schema: "public", table },
        onChange(table),
      );
    }
    channel.subscribe((status) => {
      if (cancelled) return;
      setConnected(status === "SUBSCRIBED");
    });

    return () => {
      cancelled = true;
      clearTimeout(refreshTimer);
      supabase.removeChannel(channel);
    };
  }, [queryClient]);

  const value = React.useMemo(
    () => ({ events, connected, lastUpdate, sound, setSound }),
    [events, connected, lastUpdate, sound, setSound],
  );
  return <LiveContext.Provider value={value}>{children}</LiveContext.Provider>;
}
