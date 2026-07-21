import * as React from "react";
import { ChevronLeft, ChevronRight, Inbox, Search } from "lucide-react";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { cn } from "@/lib/utils";

export interface Column<T> {
  key: string;
  header: string;
  render: (row: T) => React.ReactNode;
  className?: string;
}

interface DataTableProps<T> {
  columns: Column<T>[];
  rows: T[] | undefined;
  rowKey: (row: T) => string;
  loading?: boolean;
  /** Total row count for pagination (server-side). */
  total?: number;
  page: number;
  pageSize: number;
  onPageChange: (page: number) => void;
  search?: string;
  onSearchChange?: (value: string) => void;
  searchPlaceholder?: string;
  /** Extra filter controls rendered next to the search box. */
  toolbar?: React.ReactNode;
  emptyTitle?: string;
  emptyHint?: string;
}

export function DataTable<T>({
  columns,
  rows,
  rowKey,
  loading = false,
  total = 0,
  page,
  pageSize,
  onPageChange,
  search,
  onSearchChange,
  searchPlaceholder = "Search…",
  toolbar,
  emptyTitle = "Nothing here yet",
  emptyHint,
}: DataTableProps<T>) {
  const pageCount = Math.max(1, Math.ceil(total / pageSize));
  const from = total === 0 ? 0 : page * pageSize + 1;
  const to = Math.min(total, (page + 1) * pageSize);

  return (
    <div className="space-y-3">
      {(onSearchChange || toolbar) && (
        <div className="flex flex-wrap items-center gap-2">
          {onSearchChange && (
            <div className="relative w-full max-w-xs">
              <Search className="absolute left-2.5 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
              <Input
                value={search ?? ""}
                onChange={(e) => onSearchChange(e.target.value)}
                placeholder={searchPlaceholder}
                className="pl-8"
              />
            </div>
          )}
          {toolbar}
        </div>
      )}

      <div className="rounded-lg border bg-card">
        <Table>
          <TableHeader>
            <TableRow className="hover:bg-transparent">
              {columns.map((col) => (
                <TableHead key={col.key} className={col.className}>
                  {col.header}
                </TableHead>
              ))}
            </TableRow>
          </TableHeader>
          <TableBody>
            {loading &&
              Array.from({ length: 5 }).map((_, i) => (
                <TableRow key={`skeleton-${i}`}>
                  {columns.map((col) => (
                    <TableCell key={col.key}>
                      <Skeleton className="h-4 w-full max-w-[160px]" />
                    </TableCell>
                  ))}
                </TableRow>
              ))}

            {!loading && rows && rows.length === 0 && (
              <TableRow className="hover:bg-transparent">
                <TableCell colSpan={columns.length}>
                  <div className="flex flex-col items-center gap-2 py-10 text-center">
                    <Inbox className="h-8 w-8 text-muted-foreground" />
                    <div className="font-medium">{emptyTitle}</div>
                    {emptyHint && (
                      <div className="text-sm text-muted-foreground">{emptyHint}</div>
                    )}
                  </div>
                </TableCell>
              </TableRow>
            )}

            {!loading &&
              rows?.map((row) => (
                <TableRow key={rowKey(row)}>
                  {columns.map((col) => (
                    <TableCell key={col.key} className={cn(col.className)}>
                      {col.render(row)}
                    </TableCell>
                  ))}
                </TableRow>
              ))}
          </TableBody>
        </Table>
      </div>

      <div className="flex items-center justify-between text-sm text-muted-foreground">
        <span>
          {total > 0 ? `${from}–${to} of ${total}` : loading ? "Loading…" : "0 items"}
        </span>
        <div className="flex items-center gap-2">
          <Button
            variant="outline"
            size="sm"
            disabled={page === 0 || loading}
            onClick={() => onPageChange(page - 1)}
          >
            <ChevronLeft className="h-4 w-4" /> Prev
          </Button>
          <span>
            Page {page + 1} / {pageCount}
          </span>
          <Button
            variant="outline"
            size="sm"
            disabled={page + 1 >= pageCount || loading}
            onClick={() => onPageChange(page + 1)}
          >
            Next <ChevronRight className="h-4 w-4" />
          </Button>
        </div>
      </div>
    </div>
  );
}

/** Debounce a changing value (used for search boxes). */
export function useDebounced<T>(value: T, ms = 300): T {
  const [debounced, setDebounced] = React.useState(value);
  React.useEffect(() => {
    const t = setTimeout(() => setDebounced(value), ms);
    return () => clearTimeout(t);
  }, [value, ms]);
  return debounced;
}
