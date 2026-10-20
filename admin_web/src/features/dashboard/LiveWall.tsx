import * as React from "react";
import {
  Bell,
  Maximize2,
  Minimize2,
  Siren,
  TriangleAlert,
  Volume2,
  VolumeX,
  Wallet,
  Zap,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { cn, timeAgo } from "@/lib/utils";
import { useLive, type LiveEvent, type LiveTone } from "@/features/live/LiveProvider";

/* Pieces of the live "trading floor" dashboard — made to be left
   running on the office TV: header with clock, ticker tape, the
   latest broadcast in big type, and a feed of everything happening. */

const TONE_ICON: Record<LiveTone, React.ComponentType<{ className?: string }>> = {
  sos: Siren,
  alert: TriangleAlert,
  money: Wallet,
  info: Zap,
};

const TONE_TEXT: Record<LiveTone, string> = {
  sos: "text-destructive",
  alert: "text-warning",
  money: "text-success",
  info: "text-primary",
};

/** Re-renders every `ms` so clocks and "5m ago" labels stay current. */
function useTick(ms: number) {
  const [, setN] = React.useState(0);
  React.useEffect(() => {
    const id = setInterval(() => setN((n) => n + 1), ms);
    return () => clearInterval(id);
  }, [ms]);
}

export function LiveHeader({
  tv,
  onToggleTv,
}: {
  tv: boolean;
  onToggleTv: () => void;
}) {
  const { connected, lastUpdate, sound, setSound } = useLive();
  useTick(1000);
  const now = new Date();

  return (
    <div className="flex flex-wrap items-center gap-3">
      <div className="min-w-0 flex-1">
        <div className="flex items-center gap-2.5">
          <h1 className={cn("font-extrabold", tv ? "text-3xl" : "text-xl")}>
            Visit Gondar — Live
          </h1>
          <span
            className={cn(
              "inline-flex items-center gap-1.5 rounded-full px-2.5 py-0.5 text-[11px] font-bold tracking-wider",
              connected ? "bg-success/15 text-success" : "bg-warning/15 text-warning",
            )}
          >
            <span className={cn("live-dot h-2 w-2 rounded-full", connected ? "bg-success" : "bg-warning")} />
            {connected ? "LIVE" : "CONNECTING…"}
          </span>
        </div>
        <p className="text-sm text-muted-foreground">
          {lastUpdate
            ? `Last change ${lastUpdate.toLocaleTimeString("en-GB")} · updates on its own, no refresh needed`
            : "Updates on its own the moment anything changes — no refresh needed"}
        </p>
      </div>

      <div className="text-right tabular-nums">
        <div className={cn("font-extrabold leading-none", tv ? "text-4xl" : "text-2xl")}>
          {now.toLocaleTimeString("en-GB")}
        </div>
        <div className="text-xs text-muted-foreground">
          {now.toLocaleDateString("en-GB", { weekday: "long", day: "numeric", month: "long" })}
        </div>
      </div>

      <div className="flex gap-2">
        <Button
          variant="outline"
          size="sm"
          onClick={() => setSound(!sound)}
          aria-pressed={sound}
          title={sound ? "Sound on — click to mute" : "Sound off — click to hear a chime on each event"}
        >
          {sound ? <Volume2 className="h-4 w-4" /> : <VolumeX className="h-4 w-4" />}
          <span className="ml-1.5">{sound ? "Sound on" : "Sound off"}</span>
        </Button>
        <Button size="sm" onClick={onToggleTv}>
          {tv ? <Minimize2 className="h-4 w-4" /> : <Maximize2 className="h-4 w-4" />}
          <span className="ml-1.5">{tv ? "Exit TV mode" : "TV mode"}</span>
        </Button>
      </div>
    </div>
  );
}

/** Scrolling tape of the latest events, like a stock ticker. */
export function Ticker() {
  const { events } = useLive();
  const items = events.slice(0, 14);
  if (items.length === 0) return null;

  const strip = items.map((e) => {
    const Icon = TONE_ICON[e.tone];
    return (
      <span key={e.id} className="inline-flex items-center gap-2 px-6">
        <Icon className={cn("h-4 w-4", e.tone === "sos" ? "text-red-400" : "text-gold")} />
        <span className="font-semibold text-white">{e.title}</span>
        {e.detail && <span className="text-white/60">{e.detail}</span>}
        <span className="text-white/40">· {timeAgo(e.at) || "now"}</span>
      </span>
    );
  });

  return (
    <div className="ticker overflow-hidden rounded-xl bg-sidebar py-2.5 text-sm" aria-label="Latest activity">
      {/* Two copies so the loop is seamless. */}
      <div className="ticker-track inline-flex whitespace-nowrap">
        <div className="inline-flex">{strip}</div>
        <div className="inline-flex" aria-hidden>
          {strip}
        </div>
      </div>
    </div>
  );
}

/** The most recent notification sent to tourists, in large type. */
export function BroadcastCard({ tv, compact = false }: { tv: boolean; compact?: boolean }) {
  const { events } = useLive();
  useTick(30_000);
  const last = events.find((e) => e.table === "notifications");

  return (
    <div
      key={last?.id ?? "none"}
      className={cn(
        "rounded-xl border-2 bg-card",
        compact ? "p-4" : "p-5",
        last?.fresh && "live-flash",
        last?.tone === "alert" ? "border-destructive/50" : "border-gold",
      )}
    >
      <div className="mb-2 flex items-center gap-2 text-xs font-bold uppercase tracking-wider text-muted-foreground">
        <Bell className="h-4 w-4 text-gold" />
        Latest notification to tourists
        {last && <span className="ml-auto normal-case tracking-normal">{timeAgo(last.at) || "just now"}</span>}
      </div>
      {last ? (
        <>
          <div
            className={cn(
              "font-extrabold leading-tight",
              compact ? (tv ? "text-2xl" : "text-lg") : tv ? "text-4xl" : "text-2xl",
            )}
          >
            {last.title.replace(/^Notification sent · /, "")}
          </div>
          {last.detail && (
            <p
              className={cn(
                "mt-1 text-muted-foreground",
                compact ? "line-clamp-2 text-sm" : tv ? "text-xl" : "text-base",
              )}
            >
              {last.detail}
            </p>
          )}
        </>
      ) : (
        <p className="text-muted-foreground">No notification sent yet.</p>
      )}
    </div>
  );
}

function FeedRow({ e }: { e: LiveEvent }) {
  const Icon = TONE_ICON[e.tone];
  return (
    <li
      className={cn(
        "flex gap-3 px-4 py-3",
        e.fresh && "live-slide-in",
        e.tone === "sos" && "bg-destructive/5",
      )}
    >
      <span
        className={cn(
          "mt-0.5 flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-muted",
          TONE_TEXT[e.tone],
          e.tone === "sos" && e.fresh && "live-dot",
        )}
      >
        <Icon className="h-4 w-4" />
      </span>
      <div className="min-w-0 flex-1">
        <div className="truncate text-sm font-semibold">{e.title}</div>
        {e.detail && <div className="truncate text-xs text-muted-foreground">{e.detail}</div>}
      </div>
      <span className="shrink-0 text-xs tabular-nums text-muted-foreground">{timeAgo(e.at) || "now"}</span>
    </li>
  );
}

/** Everything happening, newest first; new rows slide in. */
export function LiveFeed({ tv, fill = false }: { tv: boolean; fill?: boolean }) {
  const { events } = useLive();
  useTick(30_000);

  return (
    <div className={cn("flex min-h-0 flex-col rounded-xl border bg-card", fill && "flex-1")}>
      <div className="flex items-center gap-2 border-b px-4 py-3">
        <span className="live-dot h-2 w-2 rounded-full bg-success" />
        <h3 className="text-sm font-bold">Live activity</h3>
        <span className="ml-auto text-xs text-muted-foreground">{events.length} events</span>
      </div>
      {events.length === 0 ? (
        <p className="p-8 text-center text-sm text-muted-foreground">Waiting for the first event…</p>
      ) : (
        <ul
          className={cn(
            "divide-y overflow-y-auto",
            fill ? "max-h-[520px] flex-1" : tv ? "max-h-[60vh]" : "max-h-[460px]",
          )}
        >
          {events.map((e) => (
            <FeedRow key={e.id} e={e} />
          ))}
        </ul>
      )}
    </div>
  );
}
