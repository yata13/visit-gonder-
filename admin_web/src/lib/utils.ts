import { type ClassValue, clsx } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function formatDate(value: string | null | undefined): string {
  if (!value) return "—";
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return value;
  return d.toLocaleDateString("en-GB", {
    day: "2-digit",
    month: "short",
    year: "numeric",
  });
}

export function formatDateTime(value: string | null | undefined): string {
  if (!value) return "—";
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return value;
  return d.toLocaleString("en-GB", {
    day: "2-digit",
    month: "short",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export function formatMoney(
  value: number | null | undefined,
  currency = "ETB",
): string {
  if (value === null || value === undefined) return "—";
  return `${Number(value).toLocaleString("en-US", { maximumFractionDigits: 2 })} ${currency}`;
}

/** "5m ago" / "3h ago" / "2d ago" — like the old admin's SOS cards. */
export function timeAgo(value: string | null | undefined): string {
  if (!value) return "";
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return "";
  const diffMs = Date.now() - d.getTime();
  const mins = Math.max(0, Math.floor(diffMs / 60_000));
  if (mins < 60) return `${mins}m ago`;
  const hours = Math.floor(mins / 60);
  if (hours < 24) return `${hours}h ago`;
  return `${Math.floor(hours / 24)}d ago`;
}

/** Supabase errors → a short human message for toasts. */
export function errorMessage(err: unknown): string {
  let msg = "Something went wrong. Please try again.";
  if (err && typeof err === "object" && "message" in err) {
    msg = String((err as { message: unknown }).message);
  }
  if (/failed to fetch|networkerror|fetch failed|load failed/i.test(msg)) {
    return "Cannot reach the database. Check your internet connection — or the Supabase project may be paused or deleted.";
  }
  return msg;
}
