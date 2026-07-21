import { Badge } from "@/components/ui/badge";
import type { PublishStatus } from "@/lib/database.types";

export function normalizePublishStatus(value: string | null | undefined): PublishStatus {
  if (value === "draft" || value === "pending") return value;
  return "published";
}

export function PublishBadge({ status }: { status: string | null | undefined }) {
  const s = normalizePublishStatus(status);
  if (s === "published") return <Badge variant="success">Published</Badge>;
  if (s === "pending") return <Badge variant="warning">Pending</Badge>;
  return <Badge variant="secondary">Draft</Badge>;
}
