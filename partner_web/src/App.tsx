import { createBrowserRouter, Link, Navigate, RouterProvider } from "react-router-dom";
import { Loader2, WifiOff } from "lucide-react";
import { errorMessage } from "@/lib/utils";
import { useAuth } from "@/features/auth/AuthProvider";
import LoginPage from "@/features/auth/LoginPage";
import { BusinessProvider, useBusiness } from "@/features/business/BusinessProvider";
import RequestAccessPage from "@/features/business/RequestAccessPage";
import { LiveProvider } from "@/features/live/LiveProvider";
import Shell from "@/components/layout/Shell";
import OverviewPage from "@/features/overview/OverviewPage";
import BookingsPage from "@/features/bookings/BookingsPage";
import CalendarPage from "@/features/calendar/CalendarPage";
import ListingPage from "@/features/listing/ListingPage";
import { Button } from "@/components/ui/button";

function Loading() {
  return (
    <div className="flex min-h-dvh items-center justify-center">
      <Loader2 className="h-8 w-8 animate-spin text-primary" />
    </div>
  );
}

/** Signed in → is this account linked to a hotel / guide yet? */
function Linked() {
  const { businesses, loading, error } = useBusiness();
  if (loading) return <Loading />;
  if (error && businesses.length === 0) {
    return (
      <div className="flex min-h-dvh flex-col items-center justify-center gap-4 p-8 text-center">
        <WifiOff className="h-10 w-10 text-muted-foreground" />
        <p className="max-w-md text-sm text-muted-foreground">{errorMessage(error)}</p>
        <Button onClick={() => window.location.reload()}>Try again</Button>
      </div>
    );
  }
  if (businesses.length === 0) return <RequestAccessPage />;
  return (
    <LiveProvider>
      <Shell />
    </LiveProvider>
  );
}

function Gate() {
  const { session, loading } = useAuth();
  if (loading) return <Loading />;
  if (!session) return <Navigate to="/login" replace />;
  return (
    <BusinessProvider>
      <Linked />
    </BusinessProvider>
  );
}

function NotFound() {
  return (
    <div className="flex flex-col items-center gap-4 py-20 text-center">
      <h1 className="text-2xl font-semibold">Page not found</h1>
      <Button asChild>
        <Link to="/">Back to the overview</Link>
      </Button>
    </div>
  );
}

const router = createBrowserRouter([
  { path: "/login", element: <LoginPage /> },
  {
    path: "/",
    element: <Gate />,
    children: [
      { index: true, element: <OverviewPage /> },
      { path: "bookings", element: <BookingsPage /> },
      { path: "calendar", element: <CalendarPage /> },
      { path: "listing", element: <ListingPage /> },
      { path: "*", element: <NotFound /> },
    ],
  },
]);

export default function App() {
  return <RouterProvider router={router} />;
}
