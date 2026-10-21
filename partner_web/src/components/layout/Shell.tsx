import { NavLink, Outlet, useLocation } from "react-router-dom";
import { BedDouble, CalendarDays, Hotel, LayoutDashboard, LogOut, ReceiptText, Store, UserRound, Volume2, VolumeX } from "lucide-react";
import { cn } from "@/lib/utils";
import { useAuth } from "@/features/auth/AuthProvider";
import { useBusiness, useCurrentBusiness } from "@/features/business/BusinessProvider";
import { useLive } from "@/features/live/LiveProvider";
import { useBookings } from "@/features/bookings/api";

const NAV = [
  { to: "/", label: "Overview", icon: LayoutDashboard, end: true },
  { to: "/bookings", label: "Bookings", icon: ReceiptText },
  { to: "/calendar", label: "Calendar", icon: CalendarDays },
  { to: "/listing", label: "My listing", icon: Store },
];

function usePendingCount() {
  const business = useCurrentBusiness();
  const bookings = useBookings(business);
  return (bookings.data ?? []).filter((b) => b.status === "pending" || b.status === "approved").length;
}

function BusinessSwitcher({ dark = false }: { dark?: boolean }) {
  const { businesses, current, select } = useBusiness();
  if (!current) return null;
  const Icon = current.type === "hotel" ? Hotel : UserRound;
  if (businesses.length < 2) {
    return (
      <div className={cn("flex items-center gap-2 rounded-lg px-3 py-2.5", dark ? "bg-white/5" : "bg-muted")}>
        <Icon className={cn("h-4 w-4 shrink-0", dark ? "text-gold" : "text-primary")} />
        <span className={cn("truncate text-[13px] font-bold", dark ? "text-white" : "")}>{current.name}</span>
      </div>
    );
  }
  return (
    <label className="block">
      <span className="sr-only">Business</span>
      <select
        value={current.id}
        onChange={(e) => select(e.target.value)}
        className={cn(
          "w-full truncate rounded-lg border px-3 py-2.5 text-[13px] font-bold outline-none",
          dark ? "border-white/10 bg-white/5 text-white [&>option]:text-black" : "bg-card",
        )}
      >
        {businesses.map((b) => (
          <option key={b.id} value={b.id}>
            {b.type === "hotel" ? "🏨" : "🧭"} {b.name}
          </option>
        ))}
      </select>
    </label>
  );
}

function LiveBadge() {
  const { connected } = useLive();
  return (
    <span
      className={cn(
        "inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-xs font-semibold",
        connected ? "bg-success-bg text-success" : "bg-muted text-muted-foreground",
      )}
      title={connected ? "New bookings appear instantly" : "Reconnecting — the page still checks every 30 seconds"}
    >
      <span className={cn("h-2 w-2 rounded-full", connected ? "live-dot bg-success" : "bg-muted-foreground")} />
      {connected ? "Live" : "Connecting…"}
    </span>
  );
}

export default function Shell() {
  const { session, signOut } = useAuth();
  const { sound, setSound } = useLive();
  const pending = usePendingCount();
  const location = useLocation();
  const current = NAV.find((n) => (n.end ? location.pathname === n.to : location.pathname.startsWith(n.to)));
  const email = session?.user.email ?? "";

  return (
    <div className="flex min-h-dvh">
      {/* Desktop sidebar */}
      <aside className="hidden w-[232px] shrink-0 md:block">
        <div className="sticky top-0 flex h-dvh flex-col bg-sidebar">
          <div className="flex items-center gap-2.5 px-5 py-6">
            <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-gold">
              <BedDouble className="h-[18px] w-[18px] text-sidebar" />
            </div>
            <div className="leading-tight">
              <div className="text-[13px] font-extrabold text-white">Visit Gondar</div>
              <div className="text-[11px] text-white/40">Partners</div>
            </div>
          </div>
          <div className="px-3">
            <BusinessSwitcher dark />
          </div>
          <nav className="mt-4 flex-1 space-y-0.5 px-3">
            {NAV.map(({ to, label, icon: Icon, end }) => (
              <NavLink
                key={to}
                to={to}
                end={end}
                className={({ isActive }) =>
                  cn(
                    "flex items-center gap-2.5 rounded-lg border px-3 py-2.5 text-[13px] transition-colors",
                    isActive
                      ? "border-gold/40 bg-gold/15 font-bold text-gold"
                      : "border-transparent font-medium text-white/70 hover:bg-white/5",
                  )
                }
              >
                <Icon className="h-[18px] w-[18px] shrink-0" />
                {label}
                {to === "/bookings" && pending > 0 && (
                  <span className="ml-auto rounded-full bg-gold px-2 text-[11px] font-bold text-sidebar">{pending}</span>
                )}
              </NavLink>
            ))}
          </nav>
          <div className="space-y-1 border-t border-white/10 p-3">
            <button
              onClick={() => setSound(!sound)}
              className="flex w-full items-center gap-2.5 rounded-lg px-3 py-2.5 text-[13px] font-medium text-white/70 hover:bg-white/5"
            >
              {sound ? <Volume2 className="h-[18px] w-[18px]" /> : <VolumeX className="h-[18px] w-[18px]" />}
              Booking sound: {sound ? "on" : "off"}
            </button>
            <button
              onClick={() => void signOut()}
              className="flex w-full items-center gap-2.5 rounded-lg px-3 py-2.5 text-[13px] font-medium text-red-300/90 hover:bg-white/5"
            >
              <LogOut className="h-[18px] w-[18px]" />
              Sign out
            </button>
          </div>
        </div>
      </aside>

      <div className="flex min-w-0 flex-1 flex-col">
        <header className="sticky top-0 z-30 flex h-16 items-center gap-3 border-b bg-card/95 px-4 backdrop-blur md:px-6">
          <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-primary md:hidden">
            <BedDouble className="h-[18px] w-[18px] text-gold" />
          </div>
          <h1 className="truncate text-xl font-extrabold">{current?.label ?? "Partners"}</h1>
          <LiveBadge />
          <div className="flex-1" />
          <button
            onClick={() => setSound(!sound)}
            className="rounded-md p-2 text-muted-foreground hover:bg-accent md:hidden"
            aria-label={sound ? "Turn sound off" : "Turn sound on"}
          >
            {sound ? <Volume2 className="h-5 w-5" /> : <VolumeX className="h-5 w-5" />}
          </button>
          <button
            onClick={() => void signOut()}
            className="rounded-md p-2 text-muted-foreground hover:bg-accent md:hidden"
            aria-label="Sign out"
          >
            <LogOut className="h-5 w-5" />
          </button>
          <div className="hidden items-center gap-2 rounded-full border bg-background py-1.5 pl-1.5 pr-3 sm:flex">
            <span className="flex h-7 w-7 items-center justify-center rounded-full bg-primary text-xs font-bold text-white">
              {email.charAt(0).toUpperCase() || "P"}
            </span>
            <span className="max-w-[200px] truncate text-[13px] font-medium text-muted-foreground">{email}</span>
          </div>
        </header>

        <div className="border-b bg-card px-4 py-2 md:hidden">
          <BusinessSwitcher />
        </div>

        <main className="min-w-0 flex-1 p-4 pb-24 md:p-6 md:pb-6">
          <div key={location.pathname} className="mx-auto w-full max-w-6xl fade-up">
            <Outlet />
          </div>
        </main>

        {/* Phone tab bar */}
        <nav className="fixed inset-x-0 bottom-0 z-30 grid grid-cols-4 border-t bg-card/95 backdrop-blur md:hidden">
          {NAV.map(({ to, label, icon: Icon, end }) => (
            <NavLink
              key={to}
              to={to}
              end={end}
              className={({ isActive }) =>
                cn(
                  "relative flex flex-col items-center gap-0.5 py-2 text-[11px] font-semibold",
                  isActive ? "text-primary" : "text-muted-foreground",
                )
              }
            >
              <Icon className="h-5 w-5" />
              {label}
              {to === "/bookings" && pending > 0 && (
                <span className="absolute right-[22%] top-1 rounded-full bg-warning px-1.5 text-[10px] font-bold text-white">
                  {pending}
                </span>
              )}
            </NavLink>
          ))}
        </nav>
      </div>
    </div>
  );
}
