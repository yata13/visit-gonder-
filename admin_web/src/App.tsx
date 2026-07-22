import { createBrowserRouter, Link, Navigate, RouterProvider } from "react-router-dom";
import RequireAdmin from "@/features/auth/RequireAdmin";
import { useAuth } from "@/features/auth/AuthProvider";
import LoginPage from "@/features/auth/LoginPage";
import AppShell from "@/components/layout/AppShell";
import DashboardPage from "@/features/dashboard/DashboardPage";
import ListingsPage from "@/features/listings/ListingsPage";
import BookingsPage from "@/features/bookings/BookingsPage";
import AvailabilityPage from "@/features/availability/AvailabilityPage";
import PassportPage from "@/features/passport/PassportPage";
import UsersPage from "@/features/users/UsersPage";
import NotificationsPage from "@/features/notifications/NotificationsPage";
import SafetyPage from "@/features/safety/SafetyPage";
import EmergencyPage from "@/features/emergency/EmergencyPage";
import { Button } from "@/components/ui/button";

/** Settings pages (Users & Roles) are for admins only — staff/editors are sent home. */
function AdminOnly({ children }: { children: React.ReactNode }) {
  const { role } = useAuth();
  if (role !== "admin") return <Navigate to="/" replace />;
  return <>{children}</>;
}

function NotFound() {
  return (
    <div className="flex flex-col items-center gap-4 py-20 text-center">
      <h1 className="text-2xl font-semibold">Page not found</h1>
      <p className="text-sm text-muted-foreground">
        This page does not exist in the admin dashboard.
      </p>
      <Button asChild>
        <Link to="/">Back to the dashboard</Link>
      </Button>
    </div>
  );
}

const router = createBrowserRouter([
  { path: "/login", element: <LoginPage /> },
  {
    path: "/",
    element: (
      <RequireAdmin>
        <AppShell />
      </RequireAdmin>
    ),
    children: [
      { index: true, element: <DashboardPage /> },
      { path: "listings/:type", element: <ListingsPage /> },
      { path: "bookings", element: <BookingsPage /> },
      { path: "notifications", element: <NotificationsPage /> },
      { path: "safety", element: <SafetyPage /> },
      { path: "emergency", element: <EmergencyPage /> },
      { path: "availability", element: <AvailabilityPage /> },
      { path: "passport", element: <PassportPage /> },
      {
        path: "users",
        element: (
          <AdminOnly>
            <UsersPage />
          </AdminOnly>
        ),
      },
      { path: "*", element: <NotFound /> },
    ],
  },
]);

export default function App() {
  return <RouterProvider router={router} />;
}
