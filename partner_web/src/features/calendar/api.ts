import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import { supabase } from "@/lib/supabase";
import type { Tables } from "@/lib/database.types";
import { errorMessage } from "@/lib/utils";
import type { Business } from "@/features/business/BusinessProvider";

export type DayRow = Tables<"availability">;

/** Calendar rows (one per day the partner set) between two days. */
export function useAvailability(b: Business, from: string, to: string) {
  return useQuery({
    queryKey: ["availability", b.type, b.id, from, to],
    queryFn: async (): Promise<DayRow[]> => {
      const { data, error } = await supabase
        .from("availability")
        .select("*")
        .eq("business_type", b.type)
        .eq("business_id", b.id)
        .gte("day", from)
        .lte("day", to)
        .order("day");
      if (error) throw error;
      return data ?? [];
    },
  });
}

export interface DaySettings {
  capacity: number;
  /** Rooms/tours sold outside the app. Leave out to keep each day's value. */
  booked?: number;
  is_closed: boolean;
  note: string | null;
}

/** Saves the same settings on one or many days (one row per day). */
export function useSaveDays(b: Business) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async ({ days, settings }: { days: string[]; settings: DaySettings }) => {
      const kept = new Map<string, number>();
      if (settings.booked === undefined && days.length) {
        const sorted = [...days].sort();
        const { data, error } = await supabase
          .from("availability")
          .select("day, booked")
          .eq("business_type", b.type)
          .eq("business_id", b.id)
          .gte("day", sorted[0])
          .lte("day", sorted[sorted.length - 1]);
        if (error) throw error;
        for (const r of data ?? []) kept.set(r.day, r.booked);
      }
      const rows = days.map((day) => ({
        business_type: b.type,
        business_id: b.id,
        day,
        capacity: settings.capacity,
        booked: settings.booked ?? kept.get(day) ?? 0,
        is_closed: settings.is_closed,
        note: settings.note,
      }));
      const { error } = await supabase
        .from("availability")
        .upsert(rows, { onConflict: "business_type,business_id,day" });
      if (error) throw error;
      return days.length;
    },
    onSuccess: (n) => {
      toast.success(n === 1 ? "Day saved — the app uses it now." : `${n} days saved — the app uses them now.`);
      void queryClient.invalidateQueries({ queryKey: ["availability"] });
    },
    onError: (err) => toast.error(errorMessage(err)),
  });
}

/** Back to "open, no limit" for a day. */
export function useClearDay() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (id: string) => {
      const { error } = await supabase.from("availability").delete().eq("id", id);
      if (error) throw error;
    },
    onSuccess: () => {
      toast.success("Limit removed — the day is open again.");
      void queryClient.invalidateQueries({ queryKey: ["availability"] });
    },
    onError: (err) => toast.error(errorMessage(err)),
  });
}
