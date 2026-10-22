import * as React from "react";
import { useQuery } from "@tanstack/react-query";
import { supabase } from "@/lib/supabase";
import type { Tables } from "@/lib/database.types";
import { useAuth } from "@/features/auth/AuthProvider";

export type BusinessType = "hotel" | "guide";

export interface Business {
  type: BusinessType;
  id: string;
  name: string;
  published: boolean;
  price: number | null;
  hotel?: Tables<"hotels">;
  guide?: Tables<"guides">;
}

/** "rooms" / "tours" — what a hotel or a guide sells per day. */
export function unitWord(type: BusinessType, n = 2): string {
  if (type === "hotel") return n === 1 ? "room" : "rooms";
  return n === 1 ? "tour" : "tours";
}

interface BusinessContextValue {
  businesses: Business[];
  current: Business | null;
  loading: boolean;
  error: unknown;
  select: (id: string) => void;
}

const BusinessContext = React.createContext<BusinessContextValue | undefined>(undefined);
const STORE_KEY = "vg-partner-business";

/** The hotels and guide profiles the Visit Gondar office linked to
 *  this account (hotels.owner_id / guides.owner_id). */
async function myBusinesses(uid: string): Promise<Business[]> {
  const [hotels, guides] = await Promise.all([
    supabase.from("hotels").select("*").eq("owner_id", uid).order("name_en"),
    supabase.from("guides").select("*").eq("owner_id", uid).order("name"),
  ]);
  if (hotels.error) throw hotels.error;
  if (guides.error) throw guides.error;
  return [
    ...(hotels.data ?? []).map((h) => ({
      type: "hotel" as const,
      id: h.id,
      name: h.name_en || "Your hotel",
      published: (h.publish_status ?? "published") === "published",
      price: h.price,
      hotel: h,
    })),
    ...(guides.data ?? []).map((g) => ({
      type: "guide" as const,
      id: g.id,
      name: g.name || "Your guide profile",
      published: (g.publish_status ?? "published") === "published",
      price: g.price,
      guide: g,
    })),
  ];
}

export function BusinessProvider({ children }: { children: React.ReactNode }) {
  const { session } = useAuth();
  const uid = session?.user.id;
  const [picked, setPicked] = React.useState<string | null>(() => {
    try {
      return localStorage.getItem(STORE_KEY);
    } catch {
      return null;
    }
  });

  const query = useQuery({
    queryKey: ["my-businesses", uid],
    queryFn: () => myBusinesses(uid!),
    enabled: !!uid,
  });

  const businesses = React.useMemo(() => query.data ?? [], [query.data]);
  const current = businesses.find((b) => b.id === picked) ?? businesses[0] ?? null;

  const select = React.useCallback((id: string) => {
    setPicked(id);
    try {
      localStorage.setItem(STORE_KEY, id);
    } catch {
      /* private window — fine */
    }
  }, []);

  const value = React.useMemo(
    () => ({ businesses, current, loading: query.isPending, error: query.error, select }),
    [businesses, current, query.isPending, query.error, select],
  );
  return <BusinessContext.Provider value={value}>{children}</BusinessContext.Provider>;
}

export function useBusiness(): BusinessContextValue {
  const ctx = React.useContext(BusinessContext);
  if (!ctx) throw new Error("useBusiness must be used inside <BusinessProvider>");
  return ctx;
}

/** For pages inside the shell, where a business is always chosen. */
export function useCurrentBusiness(): Business {
  const { current } = useBusiness();
  if (!current) throw new Error("No business selected");
  return current;
}
