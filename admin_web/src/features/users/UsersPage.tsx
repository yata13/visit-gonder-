import * as React from "react";
import {
  keepPreviousData,
  useMutation,
  useQuery,
  useQueryClient,
} from "@tanstack/react-query";
import { toast } from "sonner";
import {
  Crown,
  Headset,
  MoreHorizontal,
  ShieldCheck,
  ShieldMinus,
  UserCog,
  UserRound,
} from "lucide-react";
import { supabase } from "@/lib/supabase";
import { errorMessage, formatDate } from "@/lib/utils";
import type { Tables } from "@/lib/database.types";
import { useAuth } from "@/features/auth/AuthProvider";
import { DataTable, useDebounced, type Column } from "@/components/data-table";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";

type UserRow = Tables<"users">;
type RoleRow = Tables<"user_roles">;
type TierRow = Tables<"user_tiers">;
type PremiumRequest = Tables<"premium_requests">;

const PAGE_SIZE = 10;

async function listUsers(params: {
  page: number;
  search: string;
}): Promise<{ rows: UserRow[]; total: number }> {
  let query = supabase
    .from("users")
    .select("*", { count: "exact" })
    .order("created_at", { ascending: false, nullsFirst: false })
    .range(params.page * PAGE_SIZE, params.page * PAGE_SIZE + PAGE_SIZE - 1);

  if (params.search.trim()) {
    const s = `%${params.search.trim()}%`;
    query = query.or(`full_name.ilike.${s},email.ilike.${s}`);
  }

  const { data, error, count } = await query;
  if (error) throw error;
  return { rows: data ?? [], total: count ?? 0 };
}

async function listRoles(): Promise<Map<string, string>> {
  const { data, error } = await supabase.from("user_roles").select("*");
  if (error) throw error;
  return new Map((data as RoleRow[]).map((r) => [r.user_id, r.role]));
}

/** Visitor plans (Free / Premium). Empty map if migration 0014 is not applied yet. */
async function listTiers(): Promise<Map<string, TierRow>> {
  const { data, error } = await supabase.from("user_tiers").select("*");
  if (error) return new Map();
  return new Map(data.map((t) => [t.user_id, t]));
}

async function listPremiumRequests(): Promise<PremiumRequest[]> {
  const { data, error } = await supabase
    .from("premium_requests")
    .select("*")
    .eq("status", "pending")
    .order("created_at");
  if (error) return [];
  return data;
}

function isActivePremium(t: TierRow | undefined): boolean {
  return (
    t?.tier === "premium" &&
    (t.premium_until === null || new Date(t.premium_until) > new Date())
  );
}

type GrantableRole = "admin" | "editor" | "staff";

type PendingAction =
  | { kind: "grant"; role: GrantableRole; user: UserRow }
  | { kind: "revoke"; user: UserRow }
  | { kind: "tier"; tier: "free" | "premium"; user: UserRow };

const ROLE_EXPLANATION: Record<GrantableRole, string> = {
  admin: "Admins can manage all content, bookings, money, users and roles.",
  editor: "Editors can manage content but not users, roles or money.",
  staff:
    "Staff (employees) run daily operations — bookings, SOS requests, content — but cannot see money or manage users.",
};

export default function UsersPage() {
  const { session, role: myRole } = useAuth();
  const queryClient = useQueryClient();

  const [page, setPage] = React.useState(0);
  const [search, setSearch] = React.useState("");
  const debouncedSearch = useDebounced(search);
  const [pending, setPending] = React.useState<PendingAction | undefined>();

  const usersQuery = useQuery({
    queryKey: ["users", { page, search: debouncedSearch }],
    queryFn: () => listUsers({ page, search: debouncedSearch }),
    placeholderData: keepPreviousData,
  });

  const rolesQuery = useQuery({
    queryKey: ["user-roles"],
    queryFn: listRoles,
  });

  const tiersQuery = useQuery({ queryKey: ["user-tiers"], queryFn: listTiers });
  const requestsQuery = useQuery({
    queryKey: ["premium-requests"],
    queryFn: listPremiumRequests,
    enabled: myRole === "admin",
  });

  const requestMutation = useMutation({
    mutationFn: async ({ req, approve }: { req: PremiumRequest; approve: boolean }) => {
      if (approve) {
        // Also marks the request approved (see admin_set_user_tier).
        const { error } = await supabase.rpc("admin_set_user_tier", {
          p_user_id: req.user_id,
          p_tier: "premium",
        });
        if (error) throw error;
      } else {
        const { error } = await supabase
          .from("premium_requests")
          .update({
            status: "rejected",
            handled_at: new Date().toISOString(),
            handled_by: session?.user.id ?? null,
          })
          .eq("id", req.id);
        if (error) throw error;
      }
    },
    onSuccess: (_d, { approve }) => {
      toast.success(approve ? "Premium approved" : "Request declined");
      void queryClient.invalidateQueries({ queryKey: ["premium-requests"] });
      void queryClient.invalidateQueries({ queryKey: ["user-tiers"] });
    },
    onError: (err) => toast.error(errorMessage(err)),
  });

  const actionMutation = useMutation({
    mutationFn: async (action: PendingAction) => {
      if (action.kind === "tier") {
        const { error } = await supabase.rpc("admin_set_user_tier", {
          p_user_id: action.user.id,
          p_tier: action.tier,
        });
        if (error) throw error;
      } else if (action.kind === "grant") {
        const { error } = await supabase.rpc("admin_grant_role", {
          p_user_id: action.user.id,
          p_role: action.role,
        });
        if (error) throw error;
      } else {
        const { error } = await supabase.rpc("admin_revoke_role", {
          p_user_id: action.user.id,
        });
        if (error) throw error;
      }
    },
    onSuccess: (_data, action) => {
      const who = action.user.full_name || action.user.email || "User";
      toast.success(
        action.kind === "tier"
          ? `${who} is now on the ${action.tier === "premium" ? "Premium" : "Free"} plan`
          : action.kind === "grant"
            ? `${who} is now ${action.role}`
            : "Role removed",
      );
      setPending(undefined);
      void queryClient.invalidateQueries({
        queryKey: [action.kind === "tier" ? "user-tiers" : "user-roles"],
      });
    },
    onError: (err) => toast.error(errorMessage(err)),
  });

  const roles = rolesQuery.data;
  const tiers = tiersQuery.data;

  const columns: Column<UserRow>[] = [
    {
      key: "name",
      header: "Name",
      render: (u) => (
        <div className="min-w-[140px]">
          <div className="flex items-center gap-2 font-medium">
            {u.full_name || "—"}
            {u.id === session?.user.id && <Badge variant="outline">You</Badge>}
          </div>
          <div className="text-xs text-muted-foreground">{u.email ?? ""}</div>
        </div>
      ),
    },
    {
      key: "phone",
      header: "Phone",
      render: (u) => u.phone ?? "—",
    },
    {
      key: "country",
      header: "Country",
      render: (u) => u.country ?? "—",
    },
    {
      key: "role",
      header: "Role",
      render: (u) => {
        const r = roles?.get(u.id);
        if (r === "admin") return <Badge>Admin</Badge>;
        if (r === "editor") return <Badge variant="secondary">Editor</Badge>;
        if (r === "staff") return <Badge variant="warning">Staff</Badge>;
        return <span className="text-muted-foreground">Tourist</span>;
      },
    },
    {
      key: "plan",
      header: "Plan",
      render: (u) =>
        isActivePremium(tiers?.get(u.id)) ? (
          <Badge>
            <Crown className="mr-1 h-3 w-3" /> Premium
          </Badge>
        ) : (
          <span className="text-muted-foreground">Free</span>
        ),
    },
    {
      key: "created",
      header: "Joined",
      className: "whitespace-nowrap",
      render: (u) => formatDate(u.created_at),
    },
  ];

  if (myRole === "admin") {
    columns.push({
      key: "actions",
      header: "",
      className: "w-10",
      render: (u) => {
        const isSelf = u.id === session?.user.id;
        const r = roles?.get(u.id);
        return (
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="ghost" size="icon" disabled={isSelf}>
                <MoreHorizontal className="h-4 w-4" />
                <span className="sr-only">Role actions</span>
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end">
              <DropdownMenuLabel>Change role</DropdownMenuLabel>
              {r !== "admin" && (
                <DropdownMenuItem
                  onClick={() => setPending({ kind: "grant", role: "admin", user: u })}
                >
                  <ShieldCheck /> Make admin
                </DropdownMenuItem>
              )}
              {r !== "editor" && (
                <DropdownMenuItem
                  onClick={() => setPending({ kind: "grant", role: "editor", user: u })}
                >
                  <UserCog /> Make editor
                </DropdownMenuItem>
              )}
              {r !== "staff" && (
                <DropdownMenuItem
                  onClick={() => setPending({ kind: "grant", role: "staff", user: u })}
                >
                  <Headset /> Make staff (employee)
                </DropdownMenuItem>
              )}
              {r && (
                <DropdownMenuItem
                  className="text-destructive focus:text-destructive"
                  onClick={() => setPending({ kind: "revoke", user: u })}
                >
                  <ShieldMinus /> Remove role
                </DropdownMenuItem>
              )}
              <DropdownMenuLabel>Visitor plan</DropdownMenuLabel>
              {isActivePremium(tiers?.get(u.id)) ? (
                <DropdownMenuItem
                  onClick={() => setPending({ kind: "tier", tier: "free", user: u })}
                >
                  <UserRound /> Back to Free
                </DropdownMenuItem>
              ) : (
                <DropdownMenuItem
                  onClick={() => setPending({ kind: "tier", tier: "premium", user: u })}
                >
                  <Crown /> Make Premium
                </DropdownMenuItem>
              )}
            </DropdownMenuContent>
          </DropdownMenu>
        );
      },
    });
  }

  return (
    <div className="space-y-4">
      <div>
        <h1 className="text-xl font-semibold">Users & roles</h1>
        <p className="text-sm text-muted-foreground">
          Everyone with an account. Admins manage everything; editors manage
          content; staff run daily operations (no money, no user management);
          tourists have no dashboard access. Visitors are on the Free plan
          (safety always free) or Premium (Ask Gondar AI and extras).
        </p>
      </div>

      {myRole === "admin" && (requestsQuery.data?.length ?? 0) > 0 && (
        <div className="rounded-lg border bg-card">
          <div className="border-b px-4 py-3 text-sm font-bold">
            Premium requests ({requestsQuery.data!.length})
          </div>
          <div className="divide-y">
            {requestsQuery.data!.map((req) => (
              <div key={req.id} className="flex flex-wrap items-center gap-3 px-4 py-3 text-sm">
                <div className="min-w-[160px] flex-1">
                  <div className="font-medium">{req.email ?? req.user_id}</div>
                  <div className="text-xs text-muted-foreground">
                    Asked {formatDate(req.created_at)}
                    {req.note ? ` · ${req.note}` : ""}
                  </div>
                </div>
                <Button
                  size="sm"
                  disabled={requestMutation.isPending}
                  onClick={() => requestMutation.mutate({ req, approve: true })}
                >
                  <Crown /> Approve
                </Button>
                <Button
                  size="sm"
                  variant="outline"
                  disabled={requestMutation.isPending}
                  onClick={() => requestMutation.mutate({ req, approve: false })}
                >
                  Decline
                </Button>
              </div>
            ))}
          </div>
        </div>
      )}

      <DataTable
        columns={columns}
        rows={usersQuery.data?.rows}
        rowKey={(u) => u.id}
        loading={usersQuery.isPending || rolesQuery.isPending}
        total={usersQuery.data?.total ?? 0}
        page={page}
        pageSize={PAGE_SIZE}
        onPageChange={setPage}
        search={search}
        onSearchChange={(v) => {
          setSearch(v);
          setPage(0);
        }}
        searchPlaceholder="Search name or email…"
        emptyTitle="No users found"
        emptyHint="Users appear here after they sign up in the tourist app."
      />

      <ConfirmDialog
        open={!!pending}
        onOpenChange={(open) => !open && setPending(undefined)}
        title={
          pending?.kind === "tier"
            ? `Move ${pending.user.full_name || pending.user.email || "this user"} to ${pending.tier === "premium" ? "Premium" : "Free"}?`
            : pending?.kind === "grant"
              ? `Make ${pending.user.full_name || pending.user.email || "this user"} ${pending.role}?`
              : `Remove ${pending?.user.full_name || pending?.user.email || "this user"}'s role?`
        }
        description={
          pending?.kind === "tier"
            ? pending.tier === "premium"
              ? "They get Ask Gondar AI and every Premium extra in the app right away."
              : "They keep every free feature (safety is always free) but lose Premium extras."
            : pending?.kind === "grant"
              ? ROLE_EXPLANATION[pending.role]
              : "They will lose access to this dashboard immediately."
        }
        confirmLabel={
          pending?.kind === "tier"
            ? "Yes, change plan"
            : pending?.kind === "grant"
              ? "Yes, change role"
              : "Yes, remove"
        }
        destructive={pending?.kind === "revoke"}
        loading={actionMutation.isPending}
        onConfirm={() => pending && actionMutation.mutate(pending)}
      />
    </div>
  );
}
