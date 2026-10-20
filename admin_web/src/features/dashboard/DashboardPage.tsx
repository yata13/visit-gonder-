import * as React from "react";
import { useQuery } from "@tanstack/react-query";
import { Link } from "react-router-dom";
import {
  Area,
  AreaChart,
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  Line,
  LineChart,
  Pie,
  PieChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import {
  ClipboardList,
  LifeBuoy,
  Stamp,
  Store,
  Users,
  Wallet,
} from "lucide-react";
import { supabase } from "@/lib/supabase";
import { useAuth } from "@/features/auth/AuthProvider";
import { Skeleton } from "@/components/ui/skeleton";
import { cn, formatMoney } from "@/lib/utils";
import { WeatherCard } from "./WeatherCard";
import { AskTheCity } from "./AskTheCity";
import { BroadcastCard, LiveFeed, LiveHeader, Ticker } from "./LiveWall";

/* ═══════════════════════════════════════════════════════════════
   CITY DASHBOARD — a full-width, chart-first wall for the office TV
   and the mayor's office. Numbers come as tiles with a 14-day trend
   line; everything else is a chart. Refreshes live (LiveProvider)
   with a 20 s poll as backup.
   ═══════════════════════════════════════════════════════════════ */

const POLL_MS = 20_000;

const CONTENT_TABLES = [
  ["hotels", "Hotels"],
  ["guides", "Guides"],
  ["sites", "Sites"],
  ["places", "Map places"],
  ["events", "Events"],
  ["posts", "News"],
] as const;

/* Chart colors — validated with the dataviz checks script.
   Single-series marks use one brand hue; booking status uses the
   reserved status set (always shown with labels + counts). */
const C = {
  brand: "#9A5524", // brand brown, chroma-boosted for marks
  money: "#1F7A4D",
  alert: "#C0392B",
  grid: "#E2D9D0",
  tick: "#6B5B4F",
  status: {
    confirmed: "#1F7A4D",
    approved: "#1F7A4D",
    pending: "#D08A00",
    cancelled: "#2F6FB0",
    rejected: "#C0392B",
  } as Record<string, string>,
};

const tooltipStyle = {
  borderRadius: 8,
  border: "1px solid #E2D9D0",
  fontSize: 12,
  boxShadow: "0 2px 8px rgba(0,0,0,0.08)",
};

type Row = Record<string, any>;

/** Fetches rows; a missing table/column (migration not run) → []. */
async function rows(table: string, columns: string, timeCol = "created_at", limit = 5000): Promise<Row[]> {
  const { data, error } = await supabase
    .from(table as "bookings")
    .select(columns)
    .order(timeCol as "created_at", { ascending: false })
    .limit(limit);
  if (error) return [];
  return (data ?? []) as Row[];
}

async function count(table: string, modify?: (q: any) => any): Promise<number> {
  let q = supabase.from(table as "hotels").select("*", { count: "exact", head: true });
  if (modify) q = modify(q);
  const { count: n, error } = await q;
  return error ? 0 : (n ?? 0);
}

async function fetchWall() {
  const [bookings, users, checkins, help, published, pending, usersTotal] = await Promise.all([
    rows(
      "bookings",
      "created_at, status, item_name, item_type, total_price, price, commission_amount, commission_earned",
    ),
    rows("users", "created_at"),
    rows("passport_checkins", "checked_in_at", "checked_in_at"),
    rows("emergency_requests", "created_at, type, status"),
    Promise.all(
      CONTENT_TABLES.map(([t]) =>
        count(t, (q) => q.or("publish_status.eq.published,publish_status.is.null")).then((n) =>
          n === 0 ? count(t) : n,
        ),
      ),
    ),
    Promise.all(CONTENT_TABLES.map(([t]) => count(t, (q) => q.eq("publish_status", "pending")))),
    count("users"),
  ]);
  return { bookings, users, checkins, help, published, pending, usersTotal };
}

/* ── Time helpers ─────────────────────────────────────────────── */
const DAY = 86_400_000;
const dayKey = (d: Date) => d.toISOString().slice(0, 10);

/** Counts per day for the last `days` days (oldest first). */
function perDay(list: Row[], col: string, days: number, value?: (r: Row) => number) {
  const sums = new Map<string, number>();
  for (const r of list) {
    if (!r[col]) continue;
    const k = dayKey(new Date(r[col]));
    sums.set(k, (sums.get(k) ?? 0) + (value ? value(r) : 1));
  }
  const out: { day: string; label: string; v: number }[] = [];
  for (let i = days - 1; i >= 0; i--) {
    const d = new Date(Date.now() - i * DAY);
    out.push({
      day: dayKey(d),
      label: d.toLocaleDateString("en-GB", { day: "numeric", month: "short" }),
      v: sums.get(dayKey(d)) ?? 0,
    });
  }
  return out;
}

/** Last 7 days vs the 7 before, as a % change (null if no base). */
function weekChange(series: { v: number }[]) {
  const last = series.slice(-7).reduce((a, b) => a + b.v, 0);
  const prev = series.slice(-14, -7).reduce((a, b) => a + b.v, 0);
  if (prev === 0) return last > 0 ? { pct: null, up: true } : null;
  return { pct: Math.round(((last - prev) / prev) * 100), up: last >= prev };
}

const commissionOf = (r: Row) =>
  r.status === "confirmed" || r.status === "approved"
    ? Number(r.commission_amount ?? r.commission_earned ?? 0)
    : 0;

/* ── Pieces ───────────────────────────────────────────────────── */
function Panel({
  title,
  className,
  children,
  right,
}: {
  title: string;
  className?: string;
  children: React.ReactNode;
  right?: React.ReactNode;
}) {
  return (
    <section className={cn("flex min-w-0 flex-col rounded-xl border bg-card p-4", className)}>
      <div className="mb-2 flex items-center gap-2">
        <h3 className="text-[13px] font-bold uppercase tracking-wide text-muted-foreground">{title}</h3>
        <div className="ml-auto">{right}</div>
      </div>
      <div className="min-h-0 flex-1">{children}</div>
    </section>
  );
}

function Kpi({
  to,
  icon: Icon,
  label,
  value,
  spark,
  color = C.brand,
  upIsBad = false,
  loading,
}: {
  to: string;
  icon: React.ComponentType<{ className?: string }>;
  label: string;
  value: string | number | undefined;
  spark: { v: number }[];
  color?: string;
  upIsBad?: boolean;
  loading: boolean;
}) {
  // Flash + ▲ when the number moves, like a trading screen.
  const prev = React.useRef<string | number | undefined>(undefined);
  const [flash, setFlash] = React.useState(0);
  React.useEffect(() => {
    if (value !== undefined && prev.current !== undefined && value !== prev.current) setFlash(Date.now());
    prev.current = value;
  }, [value]);

  const change = weekChange(spark);
  const good = change && (upIsBad ? !change.up : change.up);
  const gradId = `spark-${label.replace(/\W/g, "")}`;

  return (
    <Link
      to={to}
      key={flash}
      className={cn(
        "group flex min-w-0 flex-col rounded-xl border bg-card p-4 transition-shadow hover:shadow-md",
        flash && "live-flash",
      )}
    >
      <div className="flex items-center gap-2 text-muted-foreground">
        <Icon className="h-4 w-4 shrink-0" />
        <span className="truncate text-xs font-semibold uppercase tracking-wide">{label}</span>
      </div>
      <div className="mt-1 flex items-end gap-2">
        {loading ? (
          <Skeleton className="h-8 w-16" />
        ) : (
          <span className="text-3xl font-extrabold leading-none tabular-nums">{value}</span>
        )}
        {change && (
          <span
            className={cn("mb-0.5 text-xs font-bold tabular-nums", good ? "text-success" : "text-destructive")}
            title="Last 7 days vs the 7 days before"
          >
            {change.up ? "▲" : "▼"} {change.pct === null ? "new" : `${Math.abs(change.pct)}%`}
          </span>
        )}
      </div>
      {spark.length === 0 ? (
        <div className="mt-2 flex h-10 items-end text-[11px] text-muted-foreground">Live in the tourist app</div>
      ) : (
      <>
      <div className="mt-2 h-10" aria-hidden>
        <ResponsiveContainer width="100%" height="100%">
          <AreaChart data={spark} margin={{ top: 2, right: 0, left: 0, bottom: 0 }}>
            <defs>
              <linearGradient id={gradId} x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stopColor={color} stopOpacity={0.28} />
                <stop offset="100%" stopColor={color} stopOpacity={0} />
              </linearGradient>
            </defs>
            <Area type="monotone" dataKey="v" stroke={color} strokeWidth={2} fill={`url(#${gradId})`} isAnimationActive={false} />
          </AreaChart>
        </ResponsiveContainer>
      </div>
      <span className="mt-1 text-[11px] text-muted-foreground">14-day trend</span>
      </>
      )}
    </Link>
  );
}

function HBars({ data, color = C.brand, height }: { data: { name: string; v: number }[]; color?: string; height: number }) {
  if (data.every((d) => d.v === 0)) {
    return <p className="py-10 text-center text-sm text-muted-foreground">No data yet</p>;
  }
  return (
    <ResponsiveContainer width="100%" height={height}>
      <BarChart data={data} layout="vertical" margin={{ top: 0, right: 28, left: 0, bottom: 0 }} barCategoryGap={6}>
        <XAxis type="number" hide allowDecimals={false} />
        <YAxis
          type="category"
          dataKey="name"
          width={110}
          tick={{ fontSize: 12, fill: C.tick }}
          axisLine={false}
          tickLine={false}
        />
        <Tooltip contentStyle={tooltipStyle} cursor={{ fill: "rgba(0,0,0,0.04)" }} formatter={(v) => [v, null]} />
        <Bar
          dataKey="v"
          fill={color}
          radius={[0, 4, 4, 0]}
          maxBarSize={18}
          label={{ position: "right", fontSize: 12, fill: C.tick }}
        />
      </BarChart>
    </ResponsiveContainer>
  );
}

/* ── Page ─────────────────────────────────────────────────────── */
export default function DashboardPage() {
  const { role } = useAuth();
  const isAdmin = role === "admin";
  const { data, isPending } = useQuery({ queryKey: ["dashboard", "wall"], queryFn: fetchWall, refetchInterval: POLL_MS });

  // TV mode = the dashboard alone, full screen.
  const wallRef = React.useRef<HTMLDivElement>(null);
  const [tv, setTv] = React.useState(false);
  React.useEffect(() => {
    const onChange = () => setTv(document.fullscreenElement === wallRef.current);
    document.addEventListener("fullscreenchange", onChange);
    return () => document.removeEventListener("fullscreenchange", onChange);
  }, []);
  const toggleTv = () => {
    if (document.fullscreenElement) void document.exitFullscreen();
    else void wallRef.current?.requestFullscreen?.();
  };

  const d = React.useMemo(() => {
    if (!data) return null;
    const { bookings, users, checkins, help } = data;
    const bookings30 = perDay(bookings, "created_at", 30);
    const bookings14 = bookings30.slice(-14);
    const money14 = perDay(bookings, "created_at", 14, commissionOf);
    const users14 = perDay(users, "created_at", 14);
    const stamps14 = perDay(checkins, "checked_in_at", 14);
    const help14 = perDay(help, "created_at", 14);

    const statusCounts = new Map<string, number>();
    for (const b of bookings) {
      const s = b.status ?? "pending";
      statusCounts.set(s, (statusCounts.get(s) ?? 0) + 1);
    }
    const status = [...statusCounts.entries()]
      .map(([name, v]) => ({ name, v }))
      .sort((a, b) => b.v - a.v);

    const top = new Map<string, number>();
    for (const b of bookings) {
      const n = b.item_name || b.item_type || "Other";
      top.set(n, (top.get(n) ?? 0) + 1);
    }
    const topListings = [...top.entries()]
      .map(([name, v]) => ({ name, v }))
      .sort((a, b) => b.v - a.v)
      .slice(0, 6);

    const helpType = new Map<string, number>();
    for (const h of help) {
      const t = h.type ? String(h.type) : "sos";
      helpType.set(t, (helpType.get(t) ?? 0) + 1);
    }
    const helpByType = [...helpType.entries()]
      .map(([name, v]) => ({ name: name === "sos" ? "SOS" : name[0].toUpperCase() + name.slice(1), v }))
      .sort((a, b) => b.v - a.v);
    const helpOpen = help.filter((h) => h.status !== "resolved").length;

    const listings = CONTENT_TABLES.map(([, label], i) => ({ name: label, v: data.published[i] }));

    // Commission per month (6 months) — admins only.
    const months: { label: string; v: number }[] = [];
    const now = new Date();
    for (let i = 5; i >= 0; i--) {
      const m = new Date(now.getFullYear(), now.getMonth() - i, 1);
      const key = `${m.getFullYear()}-${String(m.getMonth() + 1).padStart(2, "0")}`;
      months.push({
        label: m.toLocaleDateString("en-GB", { month: "short" }),
        v: Math.round(
          bookings.filter((b) => String(b.created_at ?? "").startsWith(key)).reduce((a, b) => a + commissionOf(b), 0),
        ),
      });
    }

    return {
      bookings30,
      bookings14,
      money14,
      users14,
      stamps14,
      help14,
      status,
      statusTotal: bookings.length,
      topListings,
      helpByType,
      helpOpen,
      listings,
      months,
      commissionTotal: bookings.reduce((a, b) => a + commissionOf(b), 0),
      published: data.published.reduce((a, b) => a + b, 0),
      pending: data.pending.reduce((a, b) => a + b, 0),
    };
  }, [data]);

  const loading = isPending || !d;
  const engagement = d
    ? d.users14.map((u, i) => ({ label: u.label, tourists: u.v, stamps: d.stamps14[i].v }))
    : [];

  return (
    <div
      ref={wallRef}
      className={cn("space-y-4", tv && "h-dvh overflow-y-auto bg-background p-6")}
    >
      <LiveHeader tv={tv} onToggleTv={toggleTv} />
      <Ticker />

      {/* ── KPI tiles with 14-day trend ── */}
      <div className="grid grid-cols-2 gap-3 md:grid-cols-3 xl:grid-cols-6">
        <Kpi to="/bookings" icon={ClipboardList} label="Bookings" value={data?.bookings.length} spark={d?.bookings14 ?? []} loading={loading} />
        {isAdmin && (
          <Kpi
            to="/bookings"
            icon={Wallet}
            label="Commission"
            value={d ? formatMoney(d.commissionTotal) : undefined}
            spark={d?.money14 ?? []}
            color={C.money}
            loading={loading}
          />
        )}
        <Kpi to="/users" icon={Users} label="Tourists" value={data?.usersTotal} spark={d?.users14 ?? []} loading={loading} />
        <Kpi to="/passport" icon={Stamp} label="Passport stamps" value={data?.checkins.length} spark={d?.stamps14 ?? []} loading={loading} />
        <Kpi
          to="/emergency"
          icon={LifeBuoy}
          label="Open help requests"
          value={d?.helpOpen}
          spark={d?.help14 ?? []}
          color={C.alert}
          upIsBad
          loading={loading}
        />
        <Kpi
          to="/listings/hotels"
          icon={Store}
          label={`Listings · ${d?.pending ?? 0} pending`}
          value={d?.published}
          spark={[]}
          loading={loading}
        />
      </div>

      {/* ── Main grid ── */}
      <div className="grid grid-cols-1 gap-3 md:grid-cols-6 xl:grid-cols-12">
        <Panel title="Bookings · last 30 days" className="md:col-span-6 xl:col-span-6">
          {loading ? (
            <Skeleton className="h-[240px] w-full" />
          ) : (
            <ResponsiveContainer width="100%" height={240}>
              <AreaChart data={d!.bookings30} margin={{ top: 8, right: 8, left: -22, bottom: 0 }}>
                <defs>
                  <linearGradient id="bookings30" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stopColor={C.brand} stopOpacity={0.3} />
                    <stop offset="100%" stopColor={C.brand} stopOpacity={0} />
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke={C.grid} vertical={false} />
                <XAxis dataKey="label" interval={4} tick={{ fontSize: 11, fill: C.tick }} axisLine={false} tickLine={false} />
                <YAxis allowDecimals={false} tick={{ fontSize: 11, fill: C.tick }} axisLine={false} tickLine={false} />
                <Tooltip contentStyle={tooltipStyle} formatter={(v) => [`${v} bookings`, null]} />
                <Area type="monotone" dataKey="v" stroke={C.brand} strokeWidth={2} fill="url(#bookings30)" activeDot={{ r: 4 }} />
              </AreaChart>
            </ResponsiveContainer>
          )}
        </Panel>

        <Panel title="Booking status" className="md:col-span-3 xl:col-span-3">
          {loading ? (
            <Skeleton className="h-[240px] w-full" />
          ) : d!.statusTotal === 0 ? (
            <p className="py-16 text-center text-sm text-muted-foreground">No bookings yet</p>
          ) : (
            <div className="flex h-[240px] flex-col">
              <div className="relative min-h-0 flex-1">
                <ResponsiveContainer width="100%" height="100%">
                  <PieChart>
                    <Tooltip contentStyle={tooltipStyle} formatter={(v, n) => [v, n]} />
                    <Pie
                      data={d!.status}
                      dataKey="v"
                      nameKey="name"
                      innerRadius="62%"
                      outerRadius="92%"
                      paddingAngle={2}
                      stroke="hsl(var(--card))"
                      strokeWidth={2}
                    >
                      {d!.status.map((s) => (
                        <Cell key={s.name} fill={C.status[s.name] ?? C.tick} />
                      ))}
                    </Pie>
                  </PieChart>
                </ResponsiveContainer>
                <div className="pointer-events-none absolute inset-0 flex flex-col items-center justify-center">
                  <span className="text-2xl font-extrabold tabular-nums">{d!.statusTotal}</span>
                  <span className="text-[11px] text-muted-foreground">bookings</span>
                </div>
              </div>
              <ul className="mt-2 grid grid-cols-2 gap-x-3 gap-y-1 text-xs">
                {d!.status.map((s) => (
                  <li key={s.name} className="flex items-center gap-1.5">
                    <span className="h-2.5 w-2.5 shrink-0 rounded-sm" style={{ backgroundColor: C.status[s.name] ?? C.tick }} />
                    <span className="capitalize">{s.name}</span>
                    <span className="ml-auto font-semibold tabular-nums">{s.v}</span>
                  </li>
                ))}
              </ul>
            </div>
          )}
        </Panel>

        <div className="flex min-w-0 flex-col gap-3 md:col-span-3 xl:col-span-3 xl:row-span-2">
          <BroadcastCard tv={tv} compact />
          <LiveFeed tv={tv} fill />
        </div>

        <Panel title="Tourists & passport stamps · 14 days" className="md:col-span-3 xl:col-span-3">
          {loading ? (
            <Skeleton className="h-[220px] w-full" />
          ) : (
            <div className="space-y-1">
              {(
                [
                  ["tourists", "New tourists", C.brand],
                  ["stamps", "Passport stamps", C.money],
                ] as const
              ).map(([key, label, color]) => (
                <div key={key}>
                  <div className="flex items-center gap-1.5 text-xs font-semibold">
                    <span className="h-0.5 w-3 rounded" style={{ backgroundColor: color }} />
                    {label}
                    <span className="ml-auto tabular-nums text-muted-foreground">
                      {engagement.reduce((a, b) => a + b[key], 0)} in 14 days
                    </span>
                  </div>
                  <ResponsiveContainer width="100%" height={112}>
                    <LineChart data={engagement} margin={{ top: 6, right: 6, left: -26, bottom: 0 }}>
                      <CartesianGrid strokeDasharray="3 3" stroke={C.grid} vertical={false} />
                      <XAxis dataKey="label" interval={3} tick={{ fontSize: 10, fill: C.tick }} axisLine={false} tickLine={false} />
                      <YAxis allowDecimals={false} tick={{ fontSize: 10, fill: C.tick }} axisLine={false} tickLine={false} />
                      <Tooltip contentStyle={tooltipStyle} formatter={(v) => [v, label]} />
                      <Line type="monotone" dataKey={key} stroke={color} strokeWidth={2} dot={false} activeDot={{ r: 4 }} />
                    </LineChart>
                  </ResponsiveContainer>
                </div>
              ))}
            </div>
          )}
        </Panel>

        <Panel title="Most booked" className="md:col-span-3 xl:col-span-3">
          {loading ? <Skeleton className="h-[260px] w-full" /> : <HBars data={d!.topListings} height={260} />}
        </Panel>

        <Panel title="Help requests by type" className="md:col-span-3 xl:col-span-3">
          {loading ? (
            <Skeleton className="h-[220px] w-full" />
          ) : (
            <HBars data={d!.helpByType} color={C.alert} height={260} />
          )}
        </Panel>

        <Panel title="Live listings by type" className="md:col-span-3 xl:col-span-3">
          {loading ? <Skeleton className="h-[220px] w-full" /> : <HBars data={d!.listings} height={220} />}
        </Panel>

        {isAdmin && (
          <Panel title="Commission per month" className="md:col-span-3 xl:col-span-3">
            {loading ? (
              <Skeleton className="h-[200px] w-full" />
            ) : (
              <ResponsiveContainer width="100%" height={200}>
                <BarChart data={d!.months} margin={{ top: 16, right: 8, left: -14, bottom: 0 }}>
                  <CartesianGrid strokeDasharray="3 3" stroke={C.grid} vertical={false} />
                  <XAxis dataKey="label" tick={{ fontSize: 11, fill: C.tick }} axisLine={false} tickLine={false} />
                  <YAxis tick={{ fontSize: 11, fill: C.tick }} axisLine={false} tickLine={false} />
                  <Tooltip contentStyle={tooltipStyle} formatter={(v) => [formatMoney(Number(v)), null]} />
                  <Bar dataKey="v" fill={C.money} radius={[4, 4, 0, 0]} maxBarSize={36} />
                </BarChart>
              </ResponsiveContainer>
            )}
          </Panel>
        )}

        <div className={cn("md:col-span-3 [&>*]:h-full", isAdmin ? "xl:col-span-3" : "xl:col-span-4")}>
          <WeatherCard />
        </div>
        <div className={cn("md:col-span-3 [&>*]:h-full", isAdmin ? "xl:col-span-3" : "xl:col-span-5")}>
          <AskTheCity />
        </div>
      </div>
    </div>
  );
}
