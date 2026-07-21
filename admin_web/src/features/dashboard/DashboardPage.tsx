import * as React from "react";
import { useQuery } from "@tanstack/react-query";
import { Link } from "react-router-dom";
import {
  CalendarCheck2,
  CheckCircle2,
  ClipboardList,
  Hourglass,
  Stamp,
  Users,
} from "lucide-react";
import { supabase } from "@/lib/supabase";
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
    countRows("users"),
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

export default function DashboardPage() {
  const { data, isPending, isError, error } = useQuery({
    queryKey: ["dashboard"],
    queryFn: fetchStats,
  });

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
                {formatMoney(b.total_price ?? b.price)} · {formatDate(b.created_at)}
              </span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
