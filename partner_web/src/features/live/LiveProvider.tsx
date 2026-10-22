import * as React from "react";
import { useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import { supabase } from "@/lib/supabase";
import { shortDay } from "@/lib/utils";
import { useAuth } from "@/features/auth/AuthProvider";
import { useBusiness } from "@/features/business/BusinessProvider";

/**
 * One live channel for the whole site. The database only sends this
 * partner the rows they may see (their own bookings, calendar and
 * listings), so every change simply refreshes the pages. A new booking
 * request also rings and pops up.
 */
interface LiveContextValue {
  connected: boolean;
  sound: boolean;
  setSound: (on: boolean) => void;
}

const LiveContext = React.createContext<LiveContextValue>({
  connected: false,
  sound: true,
  setSound: () => {},
});

let audioCtx: AudioContext | null = null;
function chime() {
  try {
    audioCtx ??= new AudioContext();
    const ctx = audioCtx;
    void ctx.resume();
    [784, 988, 1319].forEach((freq, i) => {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      const t = ctx.currentTime + i * 0.16;
      osc.type = "sine";
      osc.frequency.value = freq;
      gain.gain.setValueAtTime(0.0001, t);
      gain.gain.exponentialRampToValueAtTime(0.25, t + 0.02);
      gain.gain.exponentialRampToValueAtTime(0.0001, t + 0.35);
      osc.connect(gain).connect(ctx.destination);
      osc.start(t);
      osc.stop(t + 0.37);
    });
  } catch {
    /* audio is blocked until the first click — the pop-up still shows */
  }
}

type Row = Record<string, unknown>;
const str = (v: unknown) => (typeof v === "string" ? v : "");

export function LiveProvider({ children }: { children: React.ReactNode }) {
  const queryClient = useQueryClient();
  const { session } = useAuth();
  const { businesses } = useBusiness();
  const [connected, setConnected] = React.useState(false);
  const [sound, setSoundState] = React.useState(() => {
    try {
      return localStorage.getItem("vg-partner-sound") !== "off";
    } catch {
      return true;
    }
  });
  const soundRef = React.useRef(sound);
  soundRef.current = sound;
  const mine = React.useRef(new Set<string>());
  mine.current = new Set(businesses.map((b) => b.id));

  const setSound = React.useCallback((on: boolean) => {
    setSoundState(on);
    try {
      localStorage.setItem("vg-partner-sound", on ? "on" : "off");
    } catch {
      /* ignore */
    }
    if (on) chime(); // also unlocks audio after the click
  }, []);

  React.useEffect(() => {
    const uid = session?.user.id;
    if (!uid) return;
    let cancelled = false;

    const refresh = (...keys: string[]) => {
      for (const k of keys) void queryClient.invalidateQueries({ queryKey: [k] });
    };

    const onBooking = (payload: { eventType: string; new: Row }) => {
      refresh("bookings");
      const row = payload.new ?? {};
      if (payload.eventType !== "INSERT" || !mine.current.has(str(row.item_id))) return;
      if (str(row.status) !== "pending") return;
      if (soundRef.current) chime();
      toast.info(`New booking request — ${str(row.customer_name) || "a visitor"}`, {
        description: `${shortDay(str(row.check_in))} → ${shortDay(str(row.check_out))} · ${String(row.guests ?? 1)} guest(s). Confirm it on Bookings.`,
        duration: 12_000,
      });
    };

    const channel = supabase
      .channel(`partner-live-${uid}`)
      .on("postgres_changes", { event: "*", schema: "public", table: "bookings" }, onBooking)
      .on("postgres_changes", { event: "*", schema: "public", table: "availability" }, () =>
        refresh("availability"),
      )
      .on("postgres_changes", { event: "*", schema: "public", table: "hotels" }, () =>
        refresh("my-businesses"),
      )
      .on("postgres_changes", { event: "*", schema: "public", table: "guides" }, () =>
        refresh("my-businesses"),
      )
      .subscribe((status) => {
        if (!cancelled) setConnected(status === "SUBSCRIBED");
      });

    // Backup: re-check every 30 s in case the live channel drops.
    const timer = window.setInterval(() => refresh("bookings", "availability"), 30_000);
    return () => {
      cancelled = true;
      window.clearInterval(timer);
      void supabase.removeChannel(channel);
    };
  }, [session?.user.id, queryClient]);

  const value = React.useMemo(() => ({ connected, sound, setSound }), [connected, sound, setSound]);
  return <LiveContext.Provider value={value}>{children}</LiveContext.Provider>;
}

export function useLive(): LiveContextValue {
  return React.useContext(LiveContext);
}
