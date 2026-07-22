import * as React from "react";
import {
  keepPreviousData,
  useMutation,
  useQuery,
  useQueryClient,
} from "@tanstack/react-query";
import { toast } from "sonner";
import {
  CheckCircle2,
  DollarSign,
  Hourglass,
  ReceiptText,
} from "lucide-react";
import { supabase } from "@/lib/supabase";
import { errorMessage, formatDate } from "@/lib/utils";
import type { Tables } from "@/lib/database.types";
import { useAuth } from "@/features/auth/AuthProvider";
import { DataTable, useDebounced, type Column } from "@/components/data-table";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";

type Booking = Tables<"bookings">;
type Deposit = Tables<"deposits">;

const PAGE_SIZE = 10;

async function listBookings(params: {
  page: number;
  search: string;
  type: string;
  status: string;
}): Promise<{ rows: Booking[]; total: number; deposits: Map<string, Deposit[]> }> {
  let query = supabase
    .from("bookings")
    .select("*", { count: "exact" })
    .order("created_at", { ascending: false })
    .range(params.page * PAGE_SIZE, params.page * PAGE_SIZE + PAGE_SIZE - 1);

  if (params.search.trim()) {
    const s = `%${params.search.trim()}%`;
    query = query.or(
      `customer_name.ilike.${s},item_name.ilike.${s},customer_contact.ilike.${s}`,
    );
  }
  if (params.type !== "all") query = query.eq("item_type", params.type);
  if (params.status !== "all") query = query.eq("status", params.status);

  const { data, error, count } = await query;
  if (error) throw error;
  const rows = (data ?? []) as Booking[];

  // Chapa deposits for this page. If the deposits table is not created
  // yet (RUN_THIS_IN_SQL_EDITOR.sql not run), just show bookings alone.
  const deposits = new Map<string, Deposit[]>();
  if (rows.length > 0) {
    const { data: depositRows, error: depErr } = await supabase
      .from("deposits")
      .select("*")
      .in(
        "booking_id",
        rows.map((r) => r.id),
      )
      .order("created_at", { ascending: false });
    if (!depErr) {
      for (const d of (depositRows ?? []) as Deposit[]) {
        const list = deposits.get(d.booking_id) ?? [];
        list.push(d);
        deposits.set(d.booking_id, list);
      }
    }
  }

  return { rows, total: count ?? 0, deposits };
}

/** Money metrics over all bookings, like the old admin's stat cards. */
async function bookingStats() {
  const { data, error } = await supabase
    .from("bookings")
    .select("status, price, total_price, commission_amount, commission_earned")
    .limit(2000);
  if (error) throw error;
  let sales = 0;
  let commission = 0;
  let pending = 0;
  let approved = 0;
  for (const b of data ?? []) {
    if (b.status === "pending") pending++;
    if (b.status === "approved" || b.status === "confirmed") {
      approved++;
      sales += Number(b.total_price ?? b.price ?? 0);
      commission += Number(b.commission_amount ?? b.commission_earned ?? 0);
    }
  }
  return { sales, commission, pending, approved };
}

function StatusBadge({ value }: { value: string | null }) {
  const s = value ?? "pending";
  if (s === "approved" || s === "confirmed")
    return <Badge variant="success">{s.toUpperCase()}</Badge>;
  if (s === "rejected" || s === "cancelled")
    return <Badge variant="destructive">{s.toUpperCase()}</Badge>;
  return <Badge variant="warning">PENDING</Badge>;
}

function PaymentInfo({ booking, deposit }: { booking: Booking; deposit?: Deposit }) {
  const v = booking.payment_status ?? "unpaid";
  const badge =
    v === "deposit_paid" ? (
      <Badge variant="success">Deposit paid</Badge>
    ) : v === "deposit_pending" ? (
      <Badge variant="warning">Deposit pending</Badge>
    ) : v === "refunded" ? (
      <Badge variant="outline">Refunded</Badge>
    ) : (
      <Badge variant="secondary">Unpaid</Badge>
    );
  return (
    <div className="space-y-1">
      {badge}
      {deposit && (
        <div className="text-xs text-muted-foreground">
          {Number(deposit.amount).toLocaleString()} {deposit.currency} · {deposit.status}
        </div>
      )}
    </div>
  );
}

function StatCard({
  title,
  value,
  sub,
  icon: Icon,
  className,
  iconClass,
}: {
  title: string;
  value: string;
  sub: string;
  icon: React.ComponentType<{ className?: string }>;
  className: string;
  iconClass: string;
}) {
  return (
    <div className={`flex items-center gap-3 rounded-xl border p-4 ${className}`}>
      <Icon className={`h-6 w-6 shrink-0 ${iconClass}`} />
      <div className="min-w-0">
        <div className="font-mono text-[10px] font-bold text-muted-foreground">
          {title}
        </div>
        <div className={`text-lg font-extrabold ${iconClass}`}>{value}</div>
        <div className="text-[10px] text-muted-foreground">{sub}</div>
      </div>
    </div>
  );
}

export default function BookingsPage() {
  const queryClient = useQueryClient();
  const { role } = useAuth();
  // Finance is admin-only: staff/editors manage bookings without seeing money.
  const isAdmin = role === "admin";
  const [page, setPage] = React.useState(0);
  const [search, setSearch] = React.useState("");
  const [type, setType] = React.useState("all");
  const [status, setStatus] = React.useState("all");
  const debouncedSearch = useDebounced(search);

  const query = useQuery({
    queryKey: ["bookings", { page, search: debouncedSearch, type, status }],
    queryFn: () => listBookings({ page, search: debouncedSearch, type, status }),
    placeholderData: keepPreviousData,
  });

  const stats = useQuery({
    queryKey: ["bookings", "stats"],
    queryFn: bookingStats,
    enabled: isAdmin,
  });

  const statusMutation = useMutation({
    mutationFn: async ({ id, next }: { id: string; next: string }) => {
      const { error } = await supabase.rpc("admin_set_booking_status", {
        p_booking_id: id,
        p_status: next,
      });
      if (error) throw error;
    },
    onSuccess: (_d, { next }) => {
      toast.success(`Booking ${next}`);
      void queryClient.invalidateQueries({ queryKey: ["bookings"] });
      void queryClient.invalidateQueries({ queryKey: ["dashboard"] });
    },
    onError: (err) => toast.error(errorMessage(err)),
  });

  const deposits = query.data?.deposits;

  const columns: Column<Booking>[] = [
    {
      key: "id",
      header: "BOOKING ID",
      render: (b) => (
        <span className="font-mono text-[11px] text-muted-foreground">
          {b.id.slice(0, 8)}
        </span>
      ),
    },
    {
      key: "traveler",
      header: "TRAVELER",
      render: (b) => (
        <div className="min-w-[130px]">
          <div className="text-xs font-bold">{b.customer_name ?? "—"}</div>
          <div className="font-mono text-[10px] text-muted-foreground">
            {b.customer_contact ?? b.user_email ?? ""}
          </div>
        </div>
      ),
    },
    {
      key: "outlet",
      header: "OUTLET",
      render: (b) => (
        <div className="flex min-w-[140px] items-center gap-1.5">
          <span className="rounded bg-muted px-1.5 py-0.5 font-mono text-[9px] font-bold text-muted-foreground">
            {(b.item_type ?? "hotel").toUpperCase()}
          </span>
          <span className="text-xs font-semibold">{b.item_name ?? "—"}</span>
        </div>
      ),
    },
    {
      key: "date",
      header: "DATE",
      className: "whitespace-nowrap",
      render: (b) =>
        b.check_in ? (
          <span className="font-mono text-[11px]">
            {formatDate(b.check_in)} → {formatDate(b.check_out)}
          </span>
        ) : (
          <span className="font-mono text-[11px]">
            {(b.booking_date ?? "").slice(0, 10) || "—"}
          </span>
        ),
    },
    {
      key: "fare",
      header: "FARE",
      className: "whitespace-nowrap",
      render: (b) => (
        <span className="font-mono">
          ${Number(b.total_price ?? b.price ?? 0).toFixed(0)}
        </span>
      ),
    },
    ...(isAdmin
      ? [
          {
            key: "commission",
            header: "COMMISSION",
            className: "whitespace-nowrap",
            render: (b: Booking) => (
              <span className="font-mono font-bold text-success">
                ${Number(b.commission_amount ?? b.commission_earned ?? 0).toFixed(0)}
              </span>
            ),
          } satisfies Column<Booking>,
        ]
      : []),
    {
      key: "payment",
      header: "CHAPA DEPOSIT",
      render: (b) => <PaymentInfo booking={b} deposit={deposits?.get(b.id)?.[0]} />,
    },
    {
      key: "status",
      header: "STATUS",
      render: (b) => <StatusBadge value={b.status} />,
    },
    {
      key: "actions",
      header: "ACTIONS",
      render: (b) =>
        (b.status ?? "pending") === "pending" ? (
          <div className="flex gap-1.5">
            <Button
              size="sm"
              className="h-7 bg-success-bg px-2.5 text-[10px] font-bold text-success hover:bg-success hover:text-white"
              disabled={statusMutation.isPending}
              onClick={() => statusMutation.mutate({ id: b.id, next: "approved" })}
            >
              APPROVE
            </Button>
            <Button
              size="sm"
              className="h-7 bg-red-50 px-2.5 text-[10px] font-bold text-red-800 hover:bg-destructive hover:text-white"
              disabled={statusMutation.isPending}
              onClick={() => statusMutation.mutate({ id: b.id, next: "rejected" })}
            >
              REJECT
            </Button>
          </div>
        ) : (
          <span className="text-[10px] italic text-muted-foreground">Processed</span>
        ),
    },
  ];

  return (
    <div className="space-y-4">
      <div>
        <h2 className="text-[22px] font-extrabold">Reservations & Commissions Panel</h2>
        <p className="text-sm text-muted-foreground">
          {isAdmin
            ? "Review bookings, service status and commission (3% hotels · 10% guides). Deposit status comes from the Chapa payment webhook."
            : "Review reservations and approve or reject them. Deposit status comes from the Chapa payment webhook."}
        </p>
      </div>
      <div className="border-t" />

      {/* Money stat cards — admin only (staff manage bookings without seeing finance) */}
      {isAdmin && (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <StatCard
            title="APPROVED SALES"
            value={`$${(stats.data?.sales ?? 0).toFixed(2)}`}
            sub="Gross income"
            icon={DollarSign}
            className="bg-success-bg"
            iconClass="text-success"
          />
          <StatCard
            title="COMMISSION"
            value={`$${(stats.data?.commission ?? 0).toFixed(2)}`}
            sub="Visit Gondar cut"
            icon={ReceiptText}
            className="bg-secondary"
            iconClass="text-primary"
          />
          <StatCard
            title="PENDING APPROVAL"
            value={`${stats.data?.pending ?? 0} Requests`}
            sub="Awaiting your action"
            icon={Hourglass}
            className="bg-warning-bg"
            iconClass="text-warning"
          />
          <StatCard
            title="APPROVED BOOKINGS"
            value={`${stats.data?.approved ?? 0} Bookings`}
            sub="Settled payments"
            icon={CheckCircle2}
            className="bg-success-bg"
            iconClass="text-success"
          />
        </div>
      )}

      <DataTable
        columns={columns}
        rows={query.data?.rows}
        rowKey={(b) => b.id}
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
        searchPlaceholder="Search traveler, hotel or guide…"
        toolbar={
          <>
            <Select
              value={type}
              onValueChange={(v) => {
                setType(v);
                setPage(0);
              }}
            >
              <SelectTrigger className="w-32">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All types</SelectItem>
                <SelectItem value="hotel">🏨 Hotels</SelectItem>
                <SelectItem value="guide">🧭 Guides</SelectItem>
              </SelectContent>
            </Select>
            <Select
              value={status}
              onValueChange={(v) => {
                setStatus(v);
                setPage(0);
              }}
            >
              <SelectTrigger className="w-36">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All statuses</SelectItem>
                <SelectItem value="pending">⏳ Pending</SelectItem>
                <SelectItem value="approved">✅ Approved</SelectItem>
                <SelectItem value="rejected">❌ Rejected</SelectItem>
                <SelectItem value="cancelled">🚫 Cancelled</SelectItem>
              </SelectContent>
            </Select>
          </>
        }
        emptyTitle="No matching reservations found"
        emptyHint="Bookings made in the tourist app appear here."
      />
    </div>
  );
}
