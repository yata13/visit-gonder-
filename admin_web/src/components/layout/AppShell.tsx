import * as React from "react";
import { NavLink, Outlet, useLocation } from "react-router-dom";
import {
  Bell,
  Building2,
  CalendarRange,
  CircleUserRound,
  Hotel,
  Landmark,
  LayoutDashboard,
  LogOut,
  MapPin,
  Menu,
  Newspaper,
  PartyPopper,
  ReceiptText,
  Shield,
  Siren,
  Stamp,
  Users,
  X,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { useAuth } from "@/features/auth/AuthProvider";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";

// Same order and labels as the old Flutter admin's sidebar, with the
// three new sections (Availability, Passport, Users) appended.
const NAV = [
  { to: "/", label: "Dashboard", icon: LayoutDashboard, end: true },
  { to: "/listings/hotels", label: "Hotels", icon: Hotel },
  { to: "/listings/guides", label: "Guides", icon: CircleUserRound },
  { to: "/listings/sites", label: "Sites", icon: Landmark },
  { to: "/listings/events", label: "Events", icon: PartyPopper },
  { to: "/notifications", label: "Notifications", icon: Bell },
  { to: "/listings/posts", label: "News Feed", icon: Newspaper },
  { to: "/listings/places", label: "Map Manager", icon: MapPin },
  { to: "/bookings", label: "Bookings", icon: ReceiptText },
  { to: "/safety", label: "Safety", icon: Shield },
  { to: "/emergency", label: "Emergency", icon: Siren },
  { to: "/availability", label: "Availability", icon: CalendarRange },
  { to: "/passport", label: "Gondar Passport", icon: Stamp },
  { to: "/users", label: "Users & Roles", icon: Users },
];

function SidebarTile({
  to,
  label,
  icon: Icon,
  end,
  onNavigate,
}: {
  to: string;
  label: string;
  icon: React.ComponentType<{ className?: string }>;
  end?: boolean;
  onNavigate?: () => void;
}) {
  return (
    <NavLink
      to={to}
      end={end}
      onClick={onNavigate}
      className={({ isActive }) =>
        cn(
          "my-0.5 flex items-center gap-2.5 rounded-lg border px-3 py-2.5 text-[13px] transition-colors",
          isActive
            ? "border-primary/40 bg-primary/20 font-bold text-primary"
            : "border-transparent font-medium text-white/70 hover:bg-white/5",
        )
      }
    >
      <Icon className="h-[18px] w-[18px] shrink-0" />
      {label}
    </NavLink>
  );
}

function Sidebar({ onNavigate }: { onNavigate?: () => void }) {
  const { signOut, role } = useAuth();
  // Users & Roles is the settings area — admins only.
  const items = NAV.filter((n) => n.to !== "/users" || role === "admin");
  return (
    <div className="flex h-full flex-col bg-sidebar">
      {/* Logo area — orange tile + brand, like the Flutter shell */}
      <div className="flex items-center gap-2.5 px-5 py-6">
        <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-primary">
          <Building2 className="h-[18px] w-[18px] text-white" />
        </div>
        <div className="leading-tight">
          <div className="text-[13px] font-extrabold text-white">Visit Gondar</div>
          <div className="text-[11px] text-white/40">Admin</div>
        </div>
      </div>

      <div className="border-t border-white/10" />

      <nav className="mt-2 flex-1 overflow-y-auto px-3">
        {items.map((item) => (
          <SidebarTile key={item.to} {...item} onNavigate={onNavigate} />
        ))}
      </nav>

      <div className="border-t border-white/10" />
      <div className="p-3">
        <button
          onClick={() => void signOut()}
          className="flex w-full items-center gap-2.5 rounded-lg px-3 py-2.5 text-[13px] font-medium text-red-400/90 transition-colors hover:bg-white/5"
        >
          <LogOut className="h-[18px] w-[18px]" />
          Sign out
        </button>
      </div>
    </div>
  );
}

export default function AppShell() {
  const { session, role } = useAuth();
  const location = useLocation();
  const [mobileOpen, setMobileOpen] = React.useState(false);

  const current = NAV.find((n) =>
    n.end ? location.pathname === n.to : location.pathname.startsWith(n.to),
  );
  const email = session?.user.email ?? "Admin";
  const initial = email.charAt(0).toUpperCase();

  return (
    <div className="flex min-h-dvh">
      {/* Desktop sidebar — 220px charcoal, like the old admin */}
      <aside className="hidden w-[220px] shrink-0 md:block">
        <div className="sticky top-0 h-dvh">
          <Sidebar />
        </div>
      </aside>

      {/* Mobile sidebar */}
      {mobileOpen && (
        <div className="fixed inset-0 z-40 md:hidden">
          <div
            className="absolute inset-0 bg-black/50"
            onClick={() => setMobileOpen(false)}
          />
          <aside className="absolute inset-y-0 left-0 w-64 shadow-xl">
            <div className="absolute right-2 top-4 z-10">
              <button
                className="rounded-md p-1.5 text-white/70 hover:bg-white/10"
                onClick={() => setMobileOpen(false)}
              >
                <X className="h-4 w-4" />
              </button>
            </div>
            <Sidebar onNavigate={() => setMobileOpen(false)} />
          </aside>
        </div>
      )}

      <div className="flex min-w-0 flex-1 flex-col">
        {/* Top bar — white, page title left, user chip right */}
        <header className="sticky top-0 z-30 flex h-16 items-center gap-3 border-b bg-card px-6">
          <Button
            variant="ghost"
            size="icon"
            className="md:hidden"
            onClick={() => setMobileOpen(true)}
          >
            <Menu className="h-5 w-5" />
            <span className="sr-only">Open menu</span>
          </Button>
          <h1 className="truncate text-xl font-extrabold">
            {current?.label ?? "Admin"}
          </h1>
          <div className="flex-1" />
          <Badge variant={role === "admin" ? "default" : "secondary"}>
            {role === "admin" ? "Admin" : role === "staff" ? "Staff" : "Editor"}
          </Badge>
          <div className="hidden items-center gap-2 rounded-full border bg-background py-1.5 pl-1.5 pr-3 sm:flex">
            <span className="flex h-7 w-7 items-center justify-center rounded-full bg-primary text-xs font-bold text-white">
              {initial}
            </span>
            <span className="max-w-[200px] truncate text-[13px] font-medium text-muted-foreground">
              {email}
            </span>
          </div>
        </header>

        <main className="min-w-0 flex-1 p-4 md:p-6">
          <div className="mx-auto w-full max-w-6xl">
            <Outlet />
          </div>
        </main>
      </div>
    </div>
  );
}
