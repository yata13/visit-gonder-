import { supabase } from "@/lib/supabase";
import type { PublishStatus } from "@/lib/database.types";
import type { AnyRow, ListingType } from "./registry";

/**
 * The one deliberately loose boundary in the app: six content tables
 * share this CRUD API, so rows travel as AnyRow here. Everything the
 * payloads contain is produced by the per-table configs in
 * registry.tsx, which mirror the real columns.
 */

export interface ListParams {
  page: number;
  pageSize: number;
  search: string;
  searchColumn: string;
  status: PublishStatus | "all";
}

export async function listListings(
  type: ListingType,
  { page, pageSize, search, searchColumn, status }: ListParams,
): Promise<{ rows: AnyRow[]; total: number }> {
  let query = supabase
    .from(type as "hotels")
    .select("*", { count: "exact" })
    .order("created_at", { ascending: false })
    .range(page * pageSize, page * pageSize + pageSize - 1);

  if (search.trim()) {
    query = query.ilike(searchColumn, `%${search.trim()}%`);
  }
  if (status !== "all") {
    // Legacy rows may have NULL publish_status, which the app treats
    // as published.
    query =
      status === "published"
        ? query.or(`publish_status.eq.published,publish_status.is.null`)
        : query.eq("publish_status", status);
  }

  const { data, error, count } = await query;
  if (error) throw error;
  return { rows: (data ?? []) as AnyRow[], total: count ?? 0 };
}

export async function createListing(
  type: ListingType,
  payload: Record<string, unknown>,
): Promise<void> {
  const { error } = await supabase.from(type as "hotels").insert(payload as never);
  if (error) throw error;
}

export async function updateListing(
  type: ListingType,
  id: string,
  payload: Record<string, unknown>,
): Promise<void> {
  const { error } = await supabase
    .from(type as "hotels")
    .update(payload as never)
    .eq("id", id);
  if (error) throw error;
}

export async function deleteListing(type: ListingType, id: string): Promise<void> {
  const { error } = await supabase.from(type as "hotels").delete().eq("id", id);
  if (error) throw error;
}

export async function setListingStatus(
  type: ListingType,
  id: string,
  status: PublishStatus,
): Promise<void> {
  const { error } = await supabase
    .from(type as "hotels")
    .update({ publish_status: status } as never)
    .eq("id", id);
  if (error) throw error;
}
