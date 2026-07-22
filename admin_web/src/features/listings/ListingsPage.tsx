import * as React from "react";
import { useParams } from "react-router-dom";
import {
  keepPreviousData,
  useMutation,
  useQuery,
  useQueryClient,
} from "@tanstack/react-query";
import { toast } from "sonner";
import {
  CheckCircle2,
  EyeOff,
  MoreHorizontal,
  Pencil,
  Plus,
  Send,
  Trash2,
} from "lucide-react";
import { DataTable, useDebounced, type Column } from "@/components/data-table";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { errorMessage } from "@/lib/utils";
import type { PublishStatus } from "@/lib/database.types";
import { normalizePublishStatus } from "@/components/publish-badge";
import { LISTINGS, isListingType, type AnyRow } from "./registry";
import { deleteListing, listListings, setListingStatus } from "./api";
import { ListingForm } from "./ListingForm";
import { PlacesMap } from "./PlacesMap";

const PAGE_SIZE = 10;

export default function ListingsPage() {
  const { type } = useParams<{ type: string }>();

  if (!isListingType(type)) {
    return (
      <p className="py-20 text-center text-muted-foreground">
        Unknown listing type: {type}
      </p>
    );
  }
  return <ListingsInner key={type} type={type} />;
}

function ListingsInner({ type }: { type: keyof typeof LISTINGS }) {
  const config = LISTINGS[type];
  const queryClient = useQueryClient();

  const [page, setPage] = React.useState(0);
  const [search, setSearch] = React.useState("");
  const [status, setStatus] = React.useState<PublishStatus | "all">("all");
  const debouncedSearch = useDebounced(search);

  const listKey = [
    "listings",
    type,
    { page, search: debouncedSearch, status },
  ] as const;

  const query = useQuery({
    queryKey: listKey,
    queryFn: () =>
      listListings(type, {
        page,
        pageSize: PAGE_SIZE,
        search: debouncedSearch,
        searchColumn: config.searchColumn,
        status,
      }),
    placeholderData: keepPreviousData,
  });

  const [formOpen, setFormOpen] = React.useState(false);
  const [editRow, setEditRow] = React.useState<AnyRow | undefined>(undefined);
  const [deleteRow, setDeleteRow] = React.useState<AnyRow | undefined>(undefined);

  // Publish transitions are optimistic: flip the badge at once, roll
  // back if Supabase rejects it.
  const statusMutation = useMutation({
    mutationFn: ({ id, next }: { id: string; next: PublishStatus }) =>
      setListingStatus(type, id, next),
    onMutate: async ({ id, next }) => {
      await queryClient.cancelQueries({ queryKey: ["listings", type] });
      const previous = queryClient.getQueryData(listKey);
      queryClient.setQueryData(
        listKey,
        (old: { rows: AnyRow[]; total: number } | undefined) =>
          old && {
            ...old,
            rows: old.rows.map((r) =>
              r.id === id ? { ...r, publish_status: next } : r,
            ),
          },
      );
      return { previous };
    },
    onError: (err, _vars, ctx) => {
      if (ctx?.previous) queryClient.setQueryData(listKey, ctx.previous);
      toast.error(errorMessage(err));
    },
    onSuccess: (_data, { next }) => {
      toast.success(
        next === "published"
          ? "Published — visible in the app"
          : next === "pending"
            ? "Sent for review"
            : "Unpublished (draft)",
      );
    },
    onSettled: () => {
      void queryClient.invalidateQueries({ queryKey: ["listings", type] });
      void queryClient.invalidateQueries({ queryKey: ["dashboard"] });
    },
  });

  const deleteMutation = useMutation({
    mutationFn: (id: string) => deleteListing(type, id),
    onSuccess: () => {
      toast.success(`${config.singular} deleted`);
      setDeleteRow(undefined);
      void queryClient.invalidateQueries({ queryKey: ["listings", type] });
      void queryClient.invalidateQueries({ queryKey: ["dashboard"] });
    },
    onError: (err) => toast.error(errorMessage(err)),
  });

  const actionsColumn: Column<AnyRow> = {
    key: "actions",
    header: "",
    className: "w-10",
    render: (row) => {
      const current = normalizePublishStatus(row.publish_status);
      return (
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button variant="ghost" size="icon">
              <MoreHorizontal className="h-4 w-4" />
              <span className="sr-only">Actions</span>
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end">
            <DropdownMenuItem
              onClick={() => {
                setEditRow(row);
                setFormOpen(true);
              }}
            >
              <Pencil /> Edit
            </DropdownMenuItem>
            <DropdownMenuSeparator />
            {current !== "published" && (
              <DropdownMenuItem
                onClick={() => statusMutation.mutate({ id: row.id, next: "published" })}
              >
                <CheckCircle2 /> Approve & publish
              </DropdownMenuItem>
            )}
            {current === "draft" && (
              <DropdownMenuItem
                onClick={() => statusMutation.mutate({ id: row.id, next: "pending" })}
              >
                <Send /> Submit for review
              </DropdownMenuItem>
            )}
            {current !== "draft" && (
              <DropdownMenuItem
                onClick={() => statusMutation.mutate({ id: row.id, next: "draft" })}
              >
                <EyeOff /> Unpublish (back to draft)
              </DropdownMenuItem>
            )}
            <DropdownMenuSeparator />
            <DropdownMenuItem
              className="text-destructive focus:text-destructive"
              onClick={() => setDeleteRow(row)}
            >
              <Trash2 /> Delete
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      );
    },
  };

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-xl font-semibold">{config.title}</h1>
          <p className="text-sm text-muted-foreground">
            Draft → pending → published. Only published rows appear in the
            tourist app.
          </p>
        </div>
        <Button
          onClick={() => {
            setEditRow(undefined);
            setFormOpen(true);
          }}
        >
          <Plus /> New {config.singular}
        </Button>
      </div>

      {/* The Map Manager shows the live map above its table. */}
      {type === "places" && <PlacesMap />}

      <DataTable
        columns={[...config.columns, actionsColumn]}
        rows={query.data?.rows}
        rowKey={(r) => String(r.id)}
        loading={query.isPending}
        total={query.data?.total ?? 0}
        page={page}
        pageSize={PAGE_SIZE}
        onPageChange={setPage}
        search={search}
        onSearchChange={(v) => {
          setSearch(v);
          setPage(0);
        }}
        searchPlaceholder={`Search ${config.title.toLowerCase()}…`}
        toolbar={
          <Select
            value={status}
            onValueChange={(v) => {
              setStatus(v as PublishStatus | "all");
              setPage(0);
            }}
          >
            <SelectTrigger className="w-40">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All statuses</SelectItem>
              <SelectItem value="draft">Draft</SelectItem>
              <SelectItem value="pending">Pending</SelectItem>
              <SelectItem value="published">Published</SelectItem>
            </SelectContent>
          </Select>
        }
        emptyTitle={`No ${config.title.toLowerCase()} found`}
        emptyHint={
          debouncedSearch || status !== "all"
            ? "Try clearing the search or the status filter."
            : `Click “New ${config.singular}” to add the first one.`
        }
      />

      <ListingForm
        config={config}
        row={editRow}
        open={formOpen}
        onOpenChange={setFormOpen}
      />

      <ConfirmDialog
        open={!!deleteRow}
        onOpenChange={(open) => !open && setDeleteRow(undefined)}
        title={`Delete this ${config.singular}?`}
        description="This cannot be undone. Bookings that reference it are kept."
        confirmLabel="Delete"
        destructive
        loading={deleteMutation.isPending}
        onConfirm={() => deleteRow && deleteMutation.mutate(deleteRow.id)}
      />
    </div>
  );
}
