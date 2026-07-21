import * as React from "react";
import {
  keepPreviousData,
  useMutation,
  useQuery,
  useQueryClient,
} from "@tanstack/react-query";
import { toast } from "sonner";
import { MoreHorizontal, ShieldCheck, ShieldMinus, UserCog } from "lucide-react";
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
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";

type UserRow = Tables<"users">;
type RoleRow = Tables<"user_roles">;

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

type PendingAction =
  | { kind: "grant"; role: "admin" | "editor"; user: UserRow }
  | { kind: "revoke"; user: UserRow };

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

  const actionMutation = useMutation({
    mutationFn: async (action: PendingAction) => {
      if (action.kind === "grant") {
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
      toast.success(
        action.kind === "grant"
          ? `${action.user.full_name || action.user.email || "User"} is now ${action.role}`
          : "Role removed",
      );
      setPending(undefined);
      void queryClient.invalidateQueries({ queryKey: ["user-roles"] });
    },
    onError: (err) => toast.error(errorMessage(err)),
  });

  const roles = rolesQuery.data;

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
        return <span className="text-muted-foreground">Tourist</span>;
      },
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
              {r && (
                <DropdownMenuItem
                  className="text-destructive focus:text-destructive"
                  onClick={() => setPending({ kind: "revoke", user: u })}
                >
                  <ShieldMinus /> Remove role
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
          content; tourists have no dashboard access.
        </p>
      </div>

      {myRole !== "admin" && (
        <Alert variant="warning">
          <AlertTitle>View only</AlertTitle>
          <AlertDescription>
            Only admins can change roles. You are signed in as an editor.
          </AlertDescription>
        </Alert>
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
          pending?.kind === "grant"
            ? `Make ${pending.user.full_name || pending.user.email || "this user"} ${pending.role}?`
            : `Remove ${pending?.user.full_name || pending?.user.email || "this user"}'s role?`
        }
        description={
          pending?.kind === "grant"
            ? pending.role === "admin"
              ? "Admins can manage all content, bookings, users and roles."
              : "Editors can manage content but not users or roles."
            : "They will lose access to this dashboard immediately."
        }
        confirmLabel={pending?.kind === "grant" ? "Yes, change role" : "Yes, remove"}
        destructive={pending?.kind === "revoke"}
        loading={actionMutation.isPending}
        onConfirm={() => pending && actionMutation.mutate(pending)}
      />
    </div>
  );
}
