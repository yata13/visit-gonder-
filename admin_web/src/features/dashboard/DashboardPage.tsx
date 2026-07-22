import * as React from "react";
import { useQuery } from "@tanstack/react-query";
import { Link } from "react-router-dom";
import {
  Bar,
  BarChart,
  CartesianGrid,
  Line,
  LineChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import {
  CalendarCheck2,
  CheckCircle2,
  ClipboardList,
  Hourglass,
  Stamp,
  Users,
} from "lucide-react";
import { supabase } from "@/lib/supabase";
import { useAuth } from "@/features/auth/AuthProvider";
import { Card, CardContent } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { Badge } from "@/components/ui/badge";
import { formatDate, formatMoney } from "@/lib/utils";
import type { Tables } from "@/lib/database.types";

const CONTENT_TABLES = [
  "hotels",
  "guides",
  "sites",
  "places",
  "events",
  "posts",
] as const;

/* Chart palette — validated with the dataviz six-checks script
   (lightness band, chroma floor, CVD separation, 3:1 contrast on white). */
const CHART = {
  bars: "#B5481F", // bookings volume (brand burnt orange)
  money: "#1F7A4D", // commission line (green = money)
  grid: "#EAE5E0",
  tick: "#8C857F",
  status: {
    pending: "#D2541A",
    approved: "#1F7A4D",
    confirmed: "#1F7A4D",
    rejected: "#BA1A1A",
    cancelled: "#3D6DA8",
  } as Record<string, string>,
};

async function countRows(
  table: string,
  modify?: (q: any) => any,
): Promise<number> {
  let q = supabase.from(table as "hotels").select("*", {
    count: "exact",
    head: true,
  });
  if (modify) q = modify(q);
  const { count, error } = await q;
  if (error) throw error;
  return count ?? 0;
}

async function fetchStats() {
  // Every count falls back to 0 if its table/column is not created yet
  // (i.e. supabase/RUN_THIS_IN_SQL_EDITOR.sql has not been run) so one
  // missing migration never blanks the whole dashboard.
  const publishedPerTable = Promise.all(
    CONTENT_TABLES.map((t) =>
      countRows(t, (q) =>
        q.or("publish_status.eq.published,publish_status.is.null"),
      ).catch(() => countRows(t).catch(() => 0)),
    ),
  );
  const pendingPerTable = Promise.all(
    CONTENT_TABLES.map((t) =>
      countRows(t, (q) => q.eq("publish_status", "pending")).catch(() => 0),
    ),
  );

  const [
    published,
    pending,
    bookingsTotal,
    bookingsPending,
    depositsPaid,
    checkins,
    users,
    recent,
  ] = await Promise.all([
    publishedPerTable,
    pendingPerTable,
    countRows("bookings"),
    countRows("bookings", (q) => q.eq("status", "pending")),
    countRows("deposits", (q) => q.eq("status", "success")).catch(() => 0),
    countRows("passport_checkins").catch(() => 0),
    countRows("users").catch(() => 0),
    supabase
      .from("bookings")
      .select("*")
      .order("created_at", { ascending: false })
      .limit(5)
      .then(({ data, error }) => {
        if (error) throw error;
        return (data ?? []) as Tables<"bookings">[];
      }),
  ]);

  return {
    published: published.reduce((a, b) => a + b, 0),
    pending: pending.reduce((a, b) => a + b, 0),
    bookingsTotal,
    bookingsPending,
    depositsPaid,
    checkins,
    users,
    recent,
  };
}

interface ChartRow {
  created_at: string | null;
  status: string | null;
  commission_amount: number | null;
  commission_earned: number | null;
}

async function fetchChartRows(): Promise<ChartRow[]> {
  const { data, error } = await supabase
    .from("bookings")
    .select("created_at, status, commission_amount, commission_earned")
    .order("created_at", { ascending: false })
    .limit(2000);
  if (error) throw error;
  return data ?? [];
}

function dayKey(d: Date): string {
  return d.toISOString().slice(0, 10);
}

function bookingsPerDay(rows: ChartRow[], days = 30) {
  const counts = new Map<string, number>();
  for (const r of rows) {
    if (!r.created_at) continue;
    counts.set(dayKey(new Date(r.created_at)), (counts.get(dayKey(new Date(r.created_at))) ?? 0) + 1);
  }
  const out: { label: string; count: number }[] = [];
  const today = new Date();
  for (let i = days - 1; i >= 0; i--) {
    const d = new Date(today);
    d.setDate(today.getDate() - i);
    out.push({
      label: d.toLocaleDateString("en-GB", { day: "numeric", month: "short" }),
      count: counts.get(dayKey(d)) ?? 0,
    });
  }
  return out;
}

function statusBreakdown(rows: ChartRow[]) {
  const counts = new Map<string, number>();
  for (const r of rows) {
    const s = r.status ?? "pending";
    counts.set(s, (counts.get(s) ?? 0) + 1);
  }
  const order = ["pending", "approved", "confirmed", "rejected", "cancelled"];
  return order
    .filter((s) => counts.has(s))
    .concat([...counts.keys()].filter((s) => !order.includes(s)))
    .map((s) => ({ status: s, count: counts.get(s) ?? 0 }));
}

function commissionPerMonth(rows: ChartRow[], months = 6) {
  const sums = new Map<string, number>();
  for (const r of rows) {
    if (!r.created_at) continue;
    if (r.status !== "approved" && r.status !== "confirmed") continue;
    const key = r.created_at.slice(0, 7);
    sums.set(key, (sums.get(key) ?? 0) + Number(r.commission_amount ?? r.commission_earned ?? 0));
  }
  const out: { label: string; amount: number }[] = [];
  const now = new Date();
  for (let i = months - 1; i >= 0; i--) {
    const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
    const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`;
    out.push({
      label: d.toLocaleDateString("en-GB", { month: "short" }),
      amount: Math.round((sums.get(key) ?? 0) * 100) / 100,
    });
  }
  return out;
}

function StatCard({
  to,
  icon: Icon,
  label,
  value,
  loading,
}: {
  to: string;
  icon: React.ComponentType<{ className?: string }>;
  label: string;
  value: number | undefined;
  loading: boolean;
}) {
  return (
    <Link to={to}>
      <Card className="transition-shadow hover:shadow-md">
        <CardContent className="flex items-center gap-4 p-5">
          <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-md bg-primary/10 text-primary">
            <Icon className="h-5 w-5" />
          </div>
          <div className="min-w-0">
            {loading ? (
              <Skeleton className="mb-1 h-7 w-14" />
            ) : (
              <div className="text-2xl font-semibold leading-tight">{value}</div>
            )}
            <div className="truncate text-sm text-muted-foreground">{label}</div>
          </div>
        </CardContent>
      </Card>
    </Link>
  );
}

function ChartCard({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <div className="rounded-xl border bg-card p-4">
      <h3 className="mb-3 text-sm font-bold">{title}</h3>
      {children}
    </div>
  );
}

const tooltipStyle = {
  borderRadius: 8,
  border: "1px solid #EAE5E0",
  fontSize: 12,
  boxShadow: "0 2px 8px rgba(0,0,0,0.08)",
};

export default function DashboardPage() {
  const { role } = useAuth();
  const isAdmin = role === "admin";

  const { data, isPending, isError, error } = useQuery({
    queryKey: ["dashboard"],
    queryFn: fetchStats,
  });

  const charts = useQuery({ queryKey: ["dashboard", "charts"], queryFn: fetchChartRows });

  const perDay = React.useMemo(
    () => (charts.data ? bookingsPerDay(charts.data) : []),
    [charts.data],
  );
  const byStatus = React.useMemo(
    () => (charts.data ? statusBreakdown(charts.data) : []),
    [charts.data],
  );
  const perMonth = React.useMemo(
    () => (charts.data ? commissionPerMonth(charts.data) : []),
    [charts.data],
  );
  const maxStatus = Math.max(1, ...byStatus.map((s) => s.count));

  if (isError) {
    return (
      <div className="py-20 text-center">
        <p className="font-medium">Could not load the dashboard.</p>
        <p className="mt-1 text-sm text-muted-foreground">{String(error)}</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-xl font-semibold">Dashboard</h1>
        <p className="text-sm text-muted-foreground">
          What is happening across Visit Gondar right now.
        </p>
      </div>

      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
        <StatCard
          to="/listings/hotels"
          icon={CheckCircle2}
          label="Published listings"
          value={data?.published}
          loading={isPending}
        />
        <StatCard
          to="/listings/hotels"
          icon={Hourglass}
          label="Waiting for approval"
          value={data?.pending}
          loading={isPending}
        />
        <StatCard
          to="/bookings"
          icon={ClipboardList}
          label={`Bookings (${data?.bookingsPending ?? 0} pending)`}
          value={data?.bookingsTotal}
          loading={isPending}
        />
        <StatCard
          to="/bookings"
          icon={CalendarCheck2}
          label="Deposits paid (Chapa)"
          value={data?.depositsPaid}
          loading={isPending}
        />
        <StatCard
          to="/passport"
          icon={Stamp}
          label="Passport check-ins"
          value={data?.checkins}
          loading={isPending}
        />
        <StatCard
          to="/users"
          icon={Users}
          label="Registered users"
          value={data?.users}
          loading={isPending}
        />
      </div>

      {/* ── Graphs ── */}
      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <ChartCard title="Bookings — last 30 days">
          {charts.isPending ? (
            <Skeleton className="h-[220px] w-full" />
          ) : (
            <ResponsiveContainer width="100%" height={220}>
              <BarChart data={perDay} margin={{ top: 4, right: 4, left: -22, bottom: 0 }}>
                <CartesianGrid strokeDasharray="3 3" stroke={CHART.grid} vertical={false} />
                <XAxis
                  dataKey="label"
                  interval={4}
                  tick={{ fontSize: 11, fill: CHART.tick }}
                  axisLine={false}
                  tickLine={false}
                />
                <YAxis
                  allowDecimals={false}
                  tick={{ fontSize: 11, fill: CHART.tick }}
                  axisLine={false}
                  tickLine={false}
                />
                <Tooltip
                  contentStyle={tooltipStyle}
                  formatter={(value) => [`${value} bookings`, null]}
                  cursor={{ fill: "rgba(0,0,0,0.04)" }}
                />
                <Bar dataKey="count" fill={CHART.bars} radius={[4, 4, 0, 0]} maxBarSize={16} />
              </BarChart>
            </ResponsiveContainer>
          )}
        </ChartCard>

        <ChartCard title="Bookings by status">
          {charts.isPending ? (
            <Skeleton className="h-[220px] w-full" />
          ) : byStatus.length === 0 ? (
            <p className="py-16 text-center text-sm text-muted-foreground">
              No bookings yet.
            </p>
          ) : (
            <div className="space-y-3 py-2">
              {byStatus.map((s) => (
                <div key={s.status} className="space-y-1">
                  <div className="flex items-center justify-between text-xs">
                    <span className="flex items-center gap-1.5 font-medium capitalize">
                      <span
                        className="inline-block h-2.5 w-2.5 rounded-sm"
                        style={{ backgroundColor: CHART.status[s.status] ?? CHART.tick }}
                      />
                      {s.status}
                    </span>
                    <span className="text-muted-foreground">{s.count}</span>
                  </div>
                  <div className="h-2.5 w-full overflow-hidden rounded-full bg-muted">
                    <div
                      className="h-full rounded-full"
                      style={{
                        width: `${(s.count / maxStatus) * 100}%`,
                        backgroundColor: CHART.status[s.status] ?? CHART.tick,
                      }}
                    />
                  </div>
                </div>
              ))}
            </div>
          )}
        </ChartCard>

        {/* Finance graph — admin only */}
        {isAdmin && (
          <ChartCard title="Commission earned per month (approved bookings, $)">
            {charts.isPending ? (
              <Skeleton className="h-[220px] w-full" />
            ) : (
              <ResponsiveContainer width="100%" height={220}>
                <LineChart data={perMonth} margin={{ top: 8, right: 8, left: -14, bottom: 0 }}>
                  <CartesianGrid strokeDasharray="3 3" stroke={CHART.grid} vertical={false} />
                  <XAxis
                    dataKey="label"
                    tick={{ fontSize: 11, fill: CHART.tick }}
                    axisLine={false}
                    tickLine={false}
                  />
                  <YAxis
                    tick={{ fontSize: 11, fill: CHART.tick }}
                    axisLine={false}
                    tickLine={false}
                  />
                  <Tooltip
                    contentStyle={tooltipStyle}
                    formatter={(value) => [`$${Number(value).toFixed(2)}`, null]}
                  />
                  <Line
                    type="monotone"
                    dataKey="amount"
                    stroke={CHART.money}
                    strokeWidth={2}
                    dot={false}
                    activeDot={{ r: 4 }}
                  />
                </LineChart>
              </ResponsiveContainer>
            )}
          </ChartCard>
        )}
      </div>

      <div className="space-y-2">
        <h2 className="font-medium">Latest bookings</h2>
        <div className="divide-y rounded-lg border bg-card">
          {isPending &&
            Array.from({ length: 3 }).map((_, i) => (
              <div key={i} className="p-4">
                <Skeleton className="h-4 w-1/2" />
              </div>
            ))}
          {!isPending && data?.recent.length === 0 && (
            <p className="p-6 text-center text-sm text-muted-foreground">
              No bookings yet.
            </p>
          )}
          {data?.recent.map((b) => (
            <div key={b.id} className="flex flex-wrap items-center gap-2 p-4 text-sm">
              <span className="font-medium">{b.customer_name ?? "Unknown"}</span>
              <span className="text-muted-foreground">booked</span>
              <span className="font-medium">{b.item_name ?? b.item_type}</span>
              <Badge variant={b.status === "pending" ? "warning" : "secondary"}>
                {b.status}
              </Badge>
              <span className="ml-auto text-muted-foreground">
                {isAdmin ? `${formatMoney(b.total_price ?? b.price)} · ` : ""}
                {formatDate(b.created_at)}
              </span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
