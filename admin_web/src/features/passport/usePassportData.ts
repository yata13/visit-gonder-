import { useQuery } from "@tanstack/react-query";
import { supabase } from "@/lib/supabase";
import type { Tables } from "@/lib/database.types";

export type Checkpoint = Tables<"passport_checkpoints">;
export type Story = Tables<"passport_stories">;
export type Trivia = Tables<"passport_trivia">;

/** All checkpoints, ordered — shared by the three passport tabs. */
export function useCheckpoints() {
  return useQuery({
    queryKey: ["passport", "checkpoints"],
    queryFn: async (): Promise<Checkpoint[]> => {
      const { data, error } = await supabase
        .from("passport_checkpoints")
        .select("*")
        .order("sort_order", { ascending: true })
        .order("created_at", { ascending: true })
        .limit(200);
      if (error) throw error;
      return data ?? [];
    },
  });
}

export function checkpointName(
  checkpoints: Checkpoint[] | undefined,
  id: string,
): string {
  return checkpoints?.find((c) => c.id === id)?.name_en ?? "Unknown checkpoint";
}
