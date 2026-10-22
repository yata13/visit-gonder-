import * as React from "react";
import { Search } from "lucide-react";
import { cn, isoDay } from "@/lib/utils";
import { Input } from "@/components/ui/input";
import { Skeleton } from "@/components/ui/skeleton";
import { useCurrentBusiness } from "@/features/business/BusinessProvider";
import { BookingCard, type Booking, useBookings } from "./api";

type Tab = "requests" | "upcoming" | "past" | "closed" | "all";

const TABS: { key: Tab; label: string }[] = [
  { key: "requests", label: "Requests" },
  { key: "upcoming", label: "Upcoming" },
  { key: "past", label: "Past stays" },
  { key: "closed", label: "Declined & cancelled" },
  { key: "all", label: "All" },
];

function inTab(b: Booking, tab: Tab, today: string): boolean {
  const s = b.status ?? "pending";
  switch (tab) {
    case "requests":
      return s === "pending" || s === "approved";
    case "upcoming":
      return s === "confirmed" && (b.check_out ?? b.check_in ?? "") > today;
    case "past":
      return s === "confirmed" && (b.check_out ?? b.check_in ?? "") <= today;
    case "closed":
      return s === "rejected" || s === "cancelled";
    case "all":
      return true;
  }
}

export default function BookingsPage() {
  const business = useCurrentBusiness();
  const bookings = useBookings(business);
  const [tab, setTab] = React.useState<Tab>("requests");
  const [q, setQ] = React.useState("");
  const today = isoDay(new Date());
  const unit = business.type === "hotel" ? "night" : "day";

  const all = bookings.data ?? [];
  const counts = Object.fromEntries(TABS.map((t) => [t.key, all.filter((b) => inTab(b, t.key, today)).length]));
  const needle = q.trim().toLowerCase();
  const rows = all
    .filter((b) => inTab(b, tab, today))
    .filter(
      (b) =>
        !needle ||
        [b.customer_name, b.customer_contact, b.user_email]
          .some((v) => (v ?? "").toLowerCase().includes(needle)),
    )
    .sort((a, b) =>
      tab === "upcoming"
        ? (a.check_in ?? "").localeCompare(b.check_in ?? "")
        : (b.created_at ?? "").localeCompare(a.created_at ?? ""),
    );

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center gap-3">
        <div className="-mx-4 w-[calc(100%+2rem)] overflow-x-auto px-4 sm:mx-0 sm:w-auto sm:px-0">
        <div className="flex w-max gap-1 rounded-lg border bg-card p-1" role="tablist">
          {TABS.map((t) => (
            <button
              key={t.key}
              type="button"
              role="tab"
              aria-selected={tab === t.key}
              onClick={() => setTab(t.key)}
              className={cn(
                "flex items-center gap-1.5 whitespace-nowrap rounded-md px-3 py-1.5 text-sm font-semibold transition-colors",
                tab === t.key ? "bg-primary text-primary-foreground" : "text-muted-foreground hover:bg-accent",
              )}
            >
              {t.label}
              <span
                className={cn(
                  "rounded-full px-1.5 text-xs",
                  tab === t.key
                    ? "bg-white/20"
                    : t.key === "requests" && counts.requests
                      ? "bg-warning text-white"
                      : "bg-muted",
                )}
              >
                {counts[t.key]}
              </span>
            </button>
          ))}
        </div>
        </div>
        <div className="relative ml-auto w-full sm:w-64">
          <Search className="absolute left-2.5 top-2.5 h-4 w-4 text-muted-foreground" />
          <Input className="pl-8" placeholder="Search guest name or contact" value={q} onChange={(e) => setQ(e.target.value)} />
        </div>
      </div>

      {bookings.isPending ? (
        <div className="space-y-3">
          {Array.from({ length: 3 }).map((_, i) => (
            <Skeleton key={i} className="h-28 w-full" />
          ))}
        </div>
      ) : rows.length === 0 ? (
        <p className="rounded-xl border border-dashed bg-card p-12 text-center text-sm text-muted-foreground">
          {needle ? "No booking matches your search." : tab === "requests" ? "No requests waiting — new ones appear here live." : "Nothing here yet."}
        </p>
      ) : (
        <div className="grid gap-3 lg:grid-cols-2">
          {rows.map((b) => (
            <BookingCard key={b.id} booking={b} unit={unit} />
          ))}
        </div>
      )}
    </div>
  );
}
