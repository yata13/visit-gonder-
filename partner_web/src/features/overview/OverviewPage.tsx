import * as React from "react";
import { Link } from "react-router-dom";
import { Bar, BarChart, CartesianGrid, Tooltip, XAxis, YAxis } from "recharts";
import { ArrowRight, BellRing, CalendarClock, CircleDollarSign, Eye, EyeOff, Hotel, PartyPopper } from "lucide-react";
import { addDays, cn, isoDay, parseDay, shortDay, usd } from "@/lib/utils";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { useCurrentBusiness, unitWord } from "@/features/business/BusinessProvider";
import { useAvailability } from "@/features/calendar/api";
import { ACTIVE, BookingCard, type Booking, useBookings } from "@/features/bookings/api";

// Validated pair (dataviz validator, light surface): confirmed / waiting.
const CONFIRMED = "#A34A16";
const WAITING = "#B8862B";

/** Bookings that cover a given day (check-in night up to the night before check-out). */
function covers(b: Booking, day: string) {
  return !!b.check_in && !!b.check_out && b.check_in <= day && b.check_out > day;
}

function Kpi({
  icon: Icon,
  label,
  value,
  hint,
  tone = "default",
  to,
}: {
  icon: React.ComponentType<{ className?: string }>;
  label: string;
  value: React.ReactNode;
  hint?: string;
  tone?: "default" | "alert";
  to?: string;
}) {
  const body = (
    <div
      className={cn(
        "h-full rounded-xl border bg-card p-4 transition-shadow",
        to && "hover:shadow-md",
        tone === "alert" && "border-warning/60 bg-warning-bg",
      )}
    >
      <div className="flex items-center gap-2 text-sm font-medium text-muted-foreground">
        <Icon className={cn("h-4 w-4", tone === "alert" ? "text-warning" : "text-gold")} />
        {label}
      </div>
      <div className="mt-2 text-3xl font-extrabold tracking-tight">{value}</div>
      {hint && <div className="mt-1 text-xs text-muted-foreground">{hint}</div>}
    </div>
  );
  return to ? <Link to={to}>{body}</Link> : body;
}

export default function OverviewPage() {
  const business = useCurrentBusiness();
  const bookings = useBookings(business);
  const [asTable, setAsTable] = React.useState(false);
  const today = isoDay(new Date());
  const in30 = isoDay(addDays(new Date(), 29));
  const availability = useAvailability(business, today, in30);
  const unit = business.type === "hotel" ? "night" : "day";

  const all = bookings.data ?? [];
  const pending = all.filter((b) => b.status === "pending" || b.status === "approved");
  const confirmed = all.filter((b) => b.status === "confirmed");
  const week = isoDay(addDays(new Date(), 7));
  const arriving = confirmed
    .filter((b) => b.check_in && b.check_in >= today && b.check_in < week)
    .sort((a, b) => (a.check_in ?? "").localeCompare(b.check_in ?? ""));
  const upcoming = confirmed
    .filter((b) => b.check_in && b.check_in >= today)
    .sort((a, b) => (a.check_in ?? "").localeCompare(b.check_in ?? ""))
    .slice(0, 6);
  const month = today.slice(0, 7);
  const monthTotal = confirmed
    .filter((b) => (b.check_in ?? "").startsWith(month))
    .reduce((s, b) => s + Number(b.total_price ?? b.price ?? 0), 0);

  const avByDay = new Map((availability.data ?? []).map((a) => [a.day, a]));
  const days = Array.from({ length: 30 }, (_, i) => {
    const day = isoDay(addDays(new Date(), i));
    const active = all.filter((b) => ACTIVE.has(b.status ?? "") && covers(b, day));
    const av = avByDay.get(day);
    return {
      day,
      label: parseDay(day).getDate().toString(),
      confirmed: active.filter((b) => b.status !== "pending").length,
      waiting: active.filter((b) => b.status === "pending").length,
      capacity: av ? (av.is_closed ? 0 : av.capacity) : null,
      closed: av?.is_closed ?? false,
    };
  });
  const tonight = days[0];
  const tonightUsed = tonight.confirmed + tonight.waiting;

  return (
    <div className="space-y-6">
      {/* Greeting */}
      <div className="flex flex-wrap items-center gap-3 fade-up">
        <div>
          <h1 className="text-2xl font-extrabold">Selam! Here is {business.name} today.</h1>
          <p className="text-sm text-muted-foreground">
            Everything on this page updates live — new requests ring.
          </p>
        </div>
        <div className="flex-1" />
        {business.published ? (
          <Badge variant="success" className="gap-1">
            <Eye className="h-3 w-3" /> Visible in the app
          </Badge>
        ) : (
          <Badge variant="outline" className="gap-1">
            <EyeOff className="h-3 w-3" /> Hidden — the office publishes it
          </Badge>
        )}
      </div>

      {/* KPIs */}
      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4 fade-up" style={{ animationDelay: "60ms" }}>
        <Kpi
          icon={BellRing}
          label="New requests"
          value={bookings.isPending ? "…" : pending.length}
          hint={pending.length ? "Waiting for your answer" : "All answered"}
          tone={pending.length ? "alert" : "default"}
          to="/bookings"
        />
        <Kpi
          icon={CalendarClock}
          label="Arriving this week"
          value={bookings.isPending ? "…" : arriving.length}
          hint={arriving[0] ? `Next: ${arriving[0].customer_name ?? "guest"}, ${shortDay(arriving[0].check_in)}` : "No arrivals in the next 7 days"}
        />
        <Kpi
          icon={CircleDollarSign}
          label="Confirmed this month"
          value={bookings.isPending ? "…" : usd(monthTotal)}
          hint="Stays starting this month"
        />
        <Kpi
          icon={Hotel}
          label={business.type === "hotel" ? "Booked tonight" : "Tours today"}
          value={
            bookings.isPending ? "…" : tonight.closed ? "Closed" : tonight.capacity !== null
              ? `${tonightUsed} / ${tonight.capacity}`
              : tonightUsed
          }
          hint={
            tonight.capacity !== null
              ? `${Math.max(0, (tonight.capacity ?? 0) - tonightUsed)} ${unitWord(business.type)} free`
              : "Set your daily limit on the Calendar"
          }
          to="/calendar"
        />
      </div>

      <div className="grid grid-cols-1 gap-6 xl:grid-cols-[minmax(0,1.25fr)_minmax(0,1fr)]">
        {/* Requests */}
        <section className="space-y-3 fade-up" style={{ animationDelay: "120ms" }}>
          <div className="flex items-center gap-2">
            <h2 className="text-lg font-bold">New booking requests</h2>
            {pending.length > 0 && <Badge variant="warning">{pending.length}</Badge>}
            <div className="flex-1" />
            <Button asChild variant="ghost" size="sm">
              <Link to="/bookings">
                All bookings <ArrowRight />
              </Link>
            </Button>
          </div>
          {bookings.isPending ? (
            <Skeleton className="h-36 w-full" />
          ) : pending.length === 0 ? (
            <div className="flex flex-col items-center gap-2 rounded-xl border border-dashed bg-card p-10 text-center">
              <PartyPopper className="h-8 w-8 text-gold" />
              <p className="font-semibold">You are all caught up</p>
              <p className="text-sm text-muted-foreground">
                New requests from the Visit Gondar app appear here with a sound.
              </p>
            </div>
          ) : (
            <div className="space-y-3">
              {pending.slice(0, 5).map((b) => (
                <BookingCard key={b.id} booking={b} unit={unit} />
              ))}
              {pending.length > 5 && (
                <Button asChild variant="outline" className="w-full">
                  <Link to="/bookings">See all {pending.length} requests</Link>
                </Button>
              )}
            </div>
          )}
        </section>

        <div className="space-y-6">
          {/* Next 30 days */}
          <section className="rounded-xl border bg-card p-4 fade-up" style={{ animationDelay: "180ms" }}>
            <div className="mb-3 flex flex-wrap items-center gap-x-4 gap-y-2">
              <h2 className="font-bold">
                {business.type === "hotel" ? "Rooms booked" : "Tours booked"} · next 30 days
              </h2>
              <div className="flex items-center gap-3 text-xs text-muted-foreground">
                <span className="flex items-center gap-1.5">
                  <span className="h-2.5 w-2.5 rounded-sm" style={{ background: CONFIRMED }} /> Confirmed
                </span>
                <span className="flex items-center gap-1.5">
                  <span className="h-2.5 w-2.5 rounded-sm" style={{ background: WAITING }} /> Waiting
                </span>
              </div>
              <div className="flex-1" />
              <div className="flex rounded-md border p-0.5 text-xs">
                {["Chart", "Table"].map((v) => (
                  <button
                    key={v}
                    type="button"
                    onClick={() => setAsTable(v === "Table")}
                    className={cn(
                      "rounded px-2 py-0.5 font-medium",
                      (v === "Table") === asTable ? "bg-secondary text-primary" : "text-muted-foreground",
                    )}
                  >
                    {v}
                  </button>
                ))}
              </div>
            </div>
            {asTable ? (
              <div className="max-h-56 overflow-y-auto text-sm">
                <table className="w-full">
                  <thead className="text-left text-xs text-muted-foreground">
                    <tr>
                      <th className="py-1 font-medium">Day</th>
                      <th className="py-1 font-medium">Confirmed</th>
                      <th className="py-1 font-medium">Waiting</th>
                      <th className="py-1 font-medium">Limit</th>
                    </tr>
                  </thead>
                  <tbody>
                    {days.map((d) => (
                      <tr key={d.day} className="border-t">
                        <td className="py-1">{shortDay(d.day)}</td>
                        <td className="py-1">{d.confirmed}</td>
                        <td className="py-1">{d.waiting}</td>
                        <td className="py-1">{d.closed ? "Closed" : d.capacity ?? "—"}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            ) : (
              <div className="h-56 w-full" role="img" aria-label="Rooms booked per day for the next 30 days">
                <ChartBox>
                  {(width) => (
                    <BarChart width={width} height={224} data={days} margin={{ top: 4, right: 4, left: -28, bottom: 0 }} barCategoryGap={3}>
                      <CartesianGrid vertical={false} stroke="hsl(var(--border))" strokeDasharray="0" />
                      <XAxis dataKey="label" tickLine={false} axisLine={false} interval={2}
                             tick={{ fontSize: 11, fill: "hsl(var(--muted-foreground))" }} />
                      <YAxis allowDecimals={false} tickLine={false} axisLine={false}
                             tick={{ fontSize: 11, fill: "hsl(var(--muted-foreground))" }} />
                      <Tooltip
                        cursor={{ fill: "hsl(var(--secondary))" }}
                        content={({ active, payload }) => {
                          const d = payload?.[0]?.payload as (typeof days)[number] | undefined;
                          if (!active || !d) return null;
                          return (
                            <div className="rounded-lg border bg-card px-3 py-2 text-xs shadow-md">
                              <div className="mb-1 font-semibold">{shortDay(d.day)}</div>
                              <div>Confirmed: <b>{d.confirmed}</b></div>
                              <div>Waiting: <b>{d.waiting}</b></div>
                              <div className="text-muted-foreground">
                                {d.closed ? "Closed" : d.capacity !== null ? `Limit: ${d.capacity}` : "No limit set"}
                              </div>
                            </div>
                          );
                        }}
                      />
                      <Bar dataKey="confirmed" stackId="a" fill={CONFIRMED} stroke="#fff" strokeWidth={1} isAnimationActive={false} />
                      <Bar dataKey="waiting" stackId="a" fill={WAITING} stroke="#fff" strokeWidth={1} radius={[4, 4, 0, 0]} isAnimationActive={false} />
                    </BarChart>
                  )}
                </ChartBox>
              </div>
            )}
          </section>

          {/* Coming up */}
          <section className="rounded-xl border bg-card p-4 fade-up" style={{ animationDelay: "240ms" }}>
            <h2 className="mb-3 font-bold">Coming up</h2>
            {upcoming.length === 0 ? (
              <p className="py-4 text-sm text-muted-foreground">No confirmed guests coming yet.</p>
            ) : (
              <ul className="divide-y">
                {upcoming.map((b) => (
                  <li key={b.id} className="flex items-center gap-3 py-2.5">
                    <div className="w-16 shrink-0 text-center">
                      <div className="text-xs font-semibold uppercase text-muted-foreground">
                        {parseDay(b.check_in!).toLocaleDateString("en-GB", { month: "short" })}
                      </div>
                      <div className="text-xl font-extrabold leading-none">{parseDay(b.check_in!).getDate()}</div>
                    </div>
                    <div className="min-w-0 flex-1">
                      <div className="truncate font-semibold">{b.customer_name || "Guest"}</div>
                      <div className="truncate text-xs text-muted-foreground">
                        {b.guests ?? 1} guest{(b.guests ?? 1) === 1 ? "" : "s"} · until {shortDay(b.check_out)}
                        {b.customer_contact ? ` · ${b.customer_contact}` : ""}
                      </div>
                    </div>
                    <div className="text-sm font-bold text-primary">{usd(b.total_price ?? b.price)}</div>
                  </li>
                ))}
              </ul>
            )}
          </section>
        </div>
      </div>
    </div>
  );
}

/** Gives the chart its parent's width (and follows window resizes). */
function ChartBox({ children }: { children: (width: number) => React.ReactNode }) {
  const ref = React.useRef<HTMLDivElement>(null);
  const [width, setWidth] = React.useState(0);
  React.useLayoutEffect(() => {
    const el = ref.current;
    if (!el) return;
    const ro = new ResizeObserver(() => setWidth(el.clientWidth));
    ro.observe(el);
    setWidth(el.clientWidth);
    return () => ro.disconnect();
  }, []);
  return (
    <div ref={ref} className="h-full w-full min-w-0 overflow-hidden">
      {width > 0 && children(width)}
    </div>
  );
}
