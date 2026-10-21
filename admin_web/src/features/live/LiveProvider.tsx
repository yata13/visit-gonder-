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
  "rides",
  "drivers",
  "partner_requests",
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

/* Driver location pings rewrite rides / drivers rows every few seconds.
   Only a change of these fields is news; pings just refresh those pages
   now and then. */
const SIGNATURE: Partial<Record<string, (r: Row) => string>> = {
  rides: (r) => `${r.status}|${r.driver_id ?? ""}`,
  drivers: (r) => `${r.status}|${r.is_online}`,
};
const keyOf = (table: string, r: Row) => `${table}:${r.id ?? r.user_id}`;

/** Turns a database change into a line people can read on the wall.
 *  `before` is the row's last known signature (rides / drivers). */
function describe(
  table: string,
  kind: "INSERT" | "UPDATE" | "DELETE",
  row: Row,
  before?: string,
): Omit<LiveEvent, "id" | "at" | "fresh" | "table"> | null {
  const s = (v: unknown) => (v === null || v === undefined ? "" : String(v));
  const vehicle = (r: Row) => (r.vehicle_type === "taxi" ? "Taxi" : "Bajaj");
  switch (table) {
    case "rides": {
      const route = `${s(row.pickup_label) || "pickup"} → ${s(row.dropoff_label) || "destination"}`;
      if (kind === "INSERT")
        return {
          title: `Ride requested · ${vehicle(row)}`,
          detail: `${s(row.rider_name) || "A tourist"} · ${route} · ${formatMoney(row.fare_estimate)}`,
          tone: "info",
        };
      if (kind !== "UPDATE") return null;
      switch (row.status) {
        case "accepted":
          return { title: `Ride accepted · ${s(row.driver_name)}`, detail: `${s(row.vehicle_plate)} · ${route}`, tone: "info" };
        case "arrived":
          return { title: `Driver at pickup · ${s(row.driver_name)}`, detail: s(row.pickup_label), tone: "info" };
        case "in_progress":
          return { title: "Trip started", detail: `${s(row.driver_name)} · ${route}`, tone: "info" };
        case "completed":
          return { title: `Trip completed · ${formatMoney(row.fare_estimate)}`, detail: `${s(row.driver_name)} · ${route}`, tone: "money" };
        case "cancelled":
          return { title: `Ride cancelled by ${s(row.cancelled_by) || "someone"}`, detail: s(row.cancel_reason) || route, tone: "alert" };
        case "expired":
          return { title: "Ride request expired — no driver free", detail: route, tone: "alert" };
        case "requested":
          return before?.startsWith("requested") ? null : { title: "Driver handed back a ride", detail: route, tone: "alert" };
        default:
          return null;
      }
    }
    case "drivers": {
      if (kind === "INSERT")
        return {
          title: `New driver application · ${s(row.full_name)}`,
          detail: `${vehicle(row)} ${s(row.plate)} — approve on the Drivers page`,
          tone: "alert",
        };
      if (kind !== "UPDATE") return null;
      const [prevStatus, prevOnline] = (before ?? "").split("|");
      if (row.status !== prevStatus) {
        if (row.status === "approved") return { title: `Driver approved · ${s(row.full_name)}`, detail: `${vehicle(row)} ${s(row.plate)}`, tone: "info" };
        if (row.status === "suspended") return { title: `Driver paused · ${s(row.full_name)}`, detail: s(row.plate), tone: "alert" };
        return { title: `Driver needs a new check · ${s(row.full_name)}`, detail: `New vehicle or plate: ${s(row.plate)}`, tone: "alert" };
      }
      if (row.is_online && prevOnline === "false")
        return { title: `Driver online · ${s(row.full_name)}`, detail: `${vehicle(row)} ${s(row.plate)}`, tone: "info" };
      return null;
    }
    case "partner_requests":
      return kind === "INSERT"
        ? {
            title: `Partner request · ${s(row.business_name)}`,
            detail: `${row.business_type === "guide" ? "Tour guide" : "Hotel"} · ${s(row.email)} — link it on Partners`,
            tone: "alert",
          }
        : null;
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

    // Last known status of rides / drivers, so a location ping is not news.
    const known = new Map<string, string>();
    Promise.all([
      supabase.from("rides").select("id, status, driver_id").order("created_at", { ascending: false }).limit(500),
      supabase.from("drivers").select("user_id, status, is_online").limit(2000),
    ])
      .then(([r, d]) => {
        for (const x of (r.data ?? []) as Row[]) if (!known.has(keyOf("rides", x))) known.set(keyOf("rides", x), SIGNATURE.rides!(x));
        for (const x of (d.data ?? []) as Row[]) if (!known.has(keyOf("drivers", x))) known.set(keyOf("drivers", x), SIGNATURE.drivers!(x));
      })
      .catch(() => {});
    let pingTimer: ReturnType<typeof setTimeout> | undefined;
    const refreshAfterPings = () => {
      if (pingTimer) return;
      pingTimer = setTimeout(() => {
        pingTimer = undefined;
        void queryClient.invalidateQueries({ queryKey: ["rides"] });
        void queryClient.invalidateQueries({ queryKey: ["drivers"] });
      }, 15_000);
    };

    const onChange = (table: string) => (payload: RealtimePostgresChangesPayload<Row>) => {
      setLastUpdate(new Date());
      const row = (payload.eventType === "DELETE" ? payload.old : payload.new) as Row;
      let before: string | undefined;
      const sig = SIGNATURE[table];
      if (sig && row && payload.eventType !== "DELETE") {
        const key = keyOf(table, row);
        const now = sig(row);
        before = known.get(key);
        known.set(key, now);
        if (payload.eventType === "UPDATE" && (before === now || before === undefined)) {
          refreshAfterPings(); // a location ping (or a row from before we started)
          return;
        }
      }
      refreshSoon();
      const d = describe(table, payload.eventType, row ?? {}, before);
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
      clearTimeout(pingTimer);
      supabase.removeChannel(channel);
    };
  }, [queryClient]);

  const value = React.useMemo(
    () => ({ events, connected, lastUpdate, sound, setSound }),
    [events, connected, lastUpdate, sound, setSound],
  );
  return <LiveContext.Provider value={value}>{children}</LiveContext.Provider>;
}
