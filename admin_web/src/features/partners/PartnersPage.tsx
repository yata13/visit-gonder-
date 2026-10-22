import * as React from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import { Handshake, Hotel, Link2, Link2Off, Mail, Phone, Plus, UserRound, XCircle } from "lucide-react";
import { supabase } from "@/lib/supabase";
import { cn, errorMessage, formatDate, timeAgo } from "@/lib/utils";
import type { Tables } from "@/lib/database.types";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Skeleton } from "@/components/ui/skeleton";
import { ConfirmDialog } from "@/components/confirm-dialog";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";

type PartnerRequest = Tables<"partner_requests">;
type BizType = "hotel" | "guide";

interface Biz {
  type: BizType;
  id: string;
  name: string;
  ownerId: string | null;
  published: boolean;
}

function useBusinesses() {
  return useQuery({
    queryKey: ["partner-businesses"],
    queryFn: async (): Promise<Biz[]> => {
      const [h, g] = await Promise.all([
        supabase.from("hotels").select("id, name_en, owner_id, publish_status").order("name_en"),
        supabase.from("guides").select("id, name, owner_id, publish_status").order("name"),
      ]);
      if (h.error) throw h.error;
      if (g.error) throw g.error;
      return [
        ...(h.data ?? []).map((x) => ({
          type: "hotel" as const,
          id: x.id,
          name: x.name_en || "Unnamed hotel",
          ownerId: x.owner_id,
          published: (x.publish_status ?? "published") === "published",
        })),
        ...(g.data ?? []).map((x) => ({
          type: "guide" as const,
          id: x.id,
          name: x.name || "Unnamed guide",
          ownerId: x.owner_id,
          published: (x.publish_status ?? "published") === "published",
        })),
      ];
    },
  });
}

/** Best guess of which listing a request means (same words in the name). */
function bestMatch(name: string, options: Biz[]): string | undefined {
  const words = name.toLowerCase().split(/[^a-z0-9ሀ-፿]+/).filter((w) => w.length > 2 && w !== "hotel");
  let best: { id: string; score: number } | undefined;
  for (const o of options) {
    const n = o.name.toLowerCase();
    const score = words.filter((w) => n.includes(w)).length;
    if (score > 0 && (!best || score > best.score)) best = { id: o.id, score };
  }
  return best?.id;
}

export default function PartnersPage() {
  const queryClient = useQueryClient();
  const businesses = useBusinesses();
  const requests = useQuery({
    queryKey: ["partner-requests"],
    queryFn: async (): Promise<PartnerRequest[]> => {
      const { data, error } = await supabase
        .from("partner_requests")
        .select("*")
        .order("created_at", { ascending: false })
        .limit(300);
      if (error) throw error;
      return data ?? [];
    },
  });
  const [linkFor, setLinkFor] = React.useState<{ request?: PartnerRequest } | null>(null);
  const [rejectReq, setRejectReq] = React.useState<PartnerRequest | undefined>();
  const [unlink, setUnlink] = React.useState<Biz | undefined>();

  const refresh = () => {
    void queryClient.invalidateQueries({ queryKey: ["partner-requests"] });
    void queryClient.invalidateQueries({ queryKey: ["partner-businesses"] });
  };

  const reject = useMutation({
    mutationFn: async (r: PartnerRequest) => {
      const { data: me } = await supabase.auth.getUser();
      const { error } = await supabase
        .from("partner_requests")
        .update({ status: "rejected", handled_at: new Date().toISOString(), handled_by: me.user?.id ?? null })
        .eq("id", r.id);
      if (error) throw error;
    },
    onSuccess: () => {
      toast.success("Request turned down — the partner sees it on their page.");
      setRejectReq(undefined);
      refresh();
    },
    onError: (err) => toast.error(errorMessage(err)),
  });

  const unlinkM = useMutation({
    mutationFn: async (b: Biz) => {
      const { error } = await supabase.rpc("admin_unlink_owner", { p_type: b.type, p_business_id: b.id });
      if (error) throw error;
    },
    onSuccess: () => {
      toast.success("Owner removed — that account no longer manages this listing.");
      setUnlink(undefined);
      refresh();
    },
    onError: (err) => toast.error(errorMessage(err)),
  });

  const all = requests.data ?? [];
  const pending = all.filter((r) => r.status === "pending");
  const handled = all.filter((r) => r.status !== "pending").slice(0, 20);
  const linked = (businesses.data ?? []).filter((b) => b.ownerId);
  const emailOf = (uid: string | null) => all.find((r) => r.user_id === uid && r.email)?.email ?? null;

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-start gap-3">
        <p className="max-w-2xl text-sm text-muted-foreground">
          Hotels and guides sign up on the <b>Visit Gondar Partners</b> website and ask to manage their
          listing. Check who they are (call them), then link the request to the right hotel or guide.
          Their dashboard opens by itself.
        </p>
        <Button className="ml-auto" onClick={() => setLinkFor({})}>
          <Plus /> Link an owner by email
        </Button>
      </div>

      <section className="space-y-3">
        <h2 className="flex items-center gap-2 text-lg font-bold">
          Waiting requests
          <span className={cn("rounded-full px-2 text-sm", pending.length ? "bg-warning text-white" : "bg-muted")}>
            {pending.length}
          </span>
        </h2>
        {requests.isPending ? (
          <Skeleton className="h-28 w-full" />
        ) : requests.isError ? (
          <p className="rounded-xl border bg-card p-8 text-center text-sm text-destructive">
            {errorMessage(requests.error)} — run supabase/RUN_RIDES_AND_PARTNERS.sql if the table is missing.
          </p>
        ) : pending.length === 0 ? (
          <p className="rounded-xl border border-dashed bg-card p-8 text-center text-sm text-muted-foreground">
            No requests waiting. New ones appear here live.
          </p>
        ) : (
          <div className="grid gap-3 lg:grid-cols-2">
            {pending.map((r) => (
              <div key={r.id} className="rounded-xl border border-warning/40 bg-card p-4 live-flash">
                <div className="flex items-start gap-3">
                  <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-secondary text-primary">
                    {r.business_type === "hotel" ? <Hotel className="h-5 w-5" /> : <UserRound className="h-5 w-5" />}
                  </div>
                  <div className="min-w-0 flex-1">
                    <div className="font-bold">{r.business_name}</div>
                    <div className="text-sm text-muted-foreground">
                      {r.business_type === "hotel" ? "Hotel" : "Tour guide"} · asked {timeAgo(r.created_at)}
                    </div>
                  </div>
                </div>
                <div className="mt-3 flex flex-wrap gap-2 text-sm">
                  {r.email && (
                    <a href={`mailto:${r.email}`} className="inline-flex items-center gap-1.5 rounded-full bg-muted px-3 py-1 font-medium hover:bg-accent">
                      <Mail className="h-3.5 w-3.5" /> {r.email}
                    </a>
                  )}
                  {r.phone && (
                    <a href={`tel:${r.phone.replace(/[^\d+]/g, "")}`} className="inline-flex items-center gap-1.5 rounded-full bg-muted px-3 py-1 font-medium hover:bg-accent">
                      <Phone className="h-3.5 w-3.5" /> {r.phone}
                    </a>
                  )}
                </div>
                {r.message && <p className="mt-2 rounded-lg bg-muted/60 p-2 text-sm">“{r.message}”</p>}
                <div className="mt-4 flex gap-2">
                  <Button className="flex-1" onClick={() => setLinkFor({ request: r })}>
                    <Link2 /> Link to a listing…
                  </Button>
                  <Button variant="outline" onClick={() => setRejectReq(r)}>
                    <XCircle /> Turn down
                  </Button>
                </div>
              </div>
            ))}
          </div>
        )}
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-bold">Listings managed by their owners ({linked.length})</h2>
        {linked.length === 0 ? (
          <p className="rounded-xl border border-dashed bg-card p-6 text-center text-sm text-muted-foreground">
            No hotel or guide is linked to an owner yet.
          </p>
        ) : (
          <div className="overflow-hidden rounded-xl border bg-card">
            <ul className="divide-y">
              {linked.map((b) => (
                <li key={b.id} className="flex flex-wrap items-center gap-3 p-3">
                  {b.type === "hotel" ? <Hotel className="h-4 w-4 text-primary" /> : <UserRound className="h-4 w-4 text-primary" />}
                  <span className="font-semibold">{b.name}</span>
                  {!b.published && <span className="rounded-full bg-muted px-2 text-xs">hidden</span>}
                  <span className="text-sm text-muted-foreground">
                    {emailOf(b.ownerId) ?? `account ${b.ownerId?.slice(0, 8)}…`}
                  </span>
                  <Button variant="ghost" size="sm" className="ml-auto text-destructive" onClick={() => setUnlink(b)}>
                    <Link2Off /> Remove owner
                  </Button>
                </li>
              ))}
            </ul>
          </div>
        )}
      </section>

      {handled.length > 0 && (
        <section className="space-y-2">
          <h2 className="text-sm font-semibold text-muted-foreground">Handled recently</h2>
          <ul className="space-y-1 text-sm">
            {handled.map((r) => (
              <li key={r.id} className="flex flex-wrap gap-2 text-muted-foreground">
                <span className={cn("font-semibold", r.status === "linked" ? "text-success" : "text-destructive")}>
                  {r.status === "linked" ? "Linked" : "Turned down"}
                </span>
                {r.business_name} · {r.email} · {formatDate(r.handled_at ?? r.created_at)}
              </li>
            ))}
          </ul>
        </section>
      )}

      {linkFor && (
        <LinkDialog
          request={linkFor.request}
          businesses={businesses.data ?? []}
          onClose={() => setLinkFor(null)}
          onDone={refresh}
        />
      )}
      <ConfirmDialog
        open={!!rejectReq}
        onOpenChange={(open) => !open && setRejectReq(undefined)}
        title="Turn down this request?"
        description={`${rejectReq?.business_name ?? ""} — the partner sees “Not approved — call the office”.`}
        confirmLabel="Turn down"
        destructive
        loading={reject.isPending}
        onConfirm={() => rejectReq && reject.mutate(rejectReq)}
      />
      <ConfirmDialog
        open={!!unlink}
        onOpenChange={(open) => !open && setUnlink(undefined)}
        title="Remove the owner?"
        description={`The owner of ${unlink?.name ?? "this listing"} can no longer see its bookings or edit it.`}
        confirmLabel="Remove owner"
        destructive
        loading={unlinkM.isPending}
        onConfirm={() => unlink && unlinkM.mutate(unlink)}
      />
    </div>
  );
}

function LinkDialog({
  request,
  businesses,
  onClose,
  onDone,
}: {
  request?: PartnerRequest;
  businesses: Biz[];
  onClose: () => void;
  onDone: () => void;
}) {
  const [type, setType] = React.useState<BizType>((request?.business_type as BizType) ?? "hotel");
  const options = businesses.filter((b) => b.type === type);
  const [businessId, setBusinessId] = React.useState<string>(
    () => (request ? bestMatch(request.business_name, options) : undefined) ?? "",
  );
  const [email, setEmail] = React.useState(request?.email ?? "");
  const chosen = options.find((b) => b.id === businessId);

  const link = useMutation({
    mutationFn: async () => {
      const { error } = await supabase.rpc("admin_link_owner", {
        p_type: type,
        p_business_id: businessId,
        p_email: email.trim(),
      });
      if (error) throw error;
    },
    onSuccess: () => {
      toast.success(`Linked — ${email.trim()} now manages ${chosen?.name ?? "the listing"}.`);
      onDone();
      onClose();
    },
    onError: (err) => toast.error(errorMessage(err)),
  });

  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="max-w-md">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <Handshake className="h-5 w-5 text-gold" /> Link an owner
          </DialogTitle>
          <DialogDescription>
            {request
              ? `“${request.business_name}” asked to manage a ${request.business_type === "hotel" ? "hotel" : "guide profile"}.`
              : "The partner must have signed up on the Partners website first."}
          </DialogDescription>
        </DialogHeader>
        <div className="space-y-4">
          {!request && (
            <div className="grid grid-cols-2 gap-2">
              {(["hotel", "guide"] as const).map((t) => (
                <button
                  key={t}
                  type="button"
                  onClick={() => {
                    setType(t);
                    setBusinessId("");
                  }}
                  className={cn(
                    "rounded-lg border-2 py-2 text-sm font-bold",
                    type === t ? "border-primary bg-primary text-primary-foreground" : "border-border",
                  )}
                >
                  {t === "hotel" ? "Hotel" : "Guide"}
                </button>
              ))}
            </div>
          )}
          <label className="block space-y-1.5 text-sm font-medium">
            {type === "hotel" ? "Hotel" : "Guide"}
            <select
              value={businessId}
              onChange={(e) => setBusinessId(e.target.value)}
              className="block w-full rounded-md border bg-card px-3 py-2 text-sm"
            >
              <option value="">Choose…</option>
              {options.map((b) => (
                <option key={b.id} value={b.id}>
                  {b.name}
                  {b.ownerId ? " (already has an owner)" : ""}
                </option>
              ))}
            </select>
          </label>
          <label className="block space-y-1.5 text-sm font-medium">
            Partner's email (their account)
            <Input type="email" value={email} onChange={(e) => setEmail(e.target.value)} placeholder="manager@hotel.com" />
          </label>
          {chosen?.ownerId && (
            <p className="rounded-lg bg-warning-bg p-2 text-sm text-warning">
              This listing already has an owner — linking replaces them.
            </p>
          )}
          {options.length === 0 && (
            <p className="text-sm text-muted-foreground">
              No {type === "hotel" ? "hotels" : "guides"} yet — add it on the {type === "hotel" ? "Hotels" : "Guides"} page first.
            </p>
          )}
        </div>
        <DialogFooter>
          <Button variant="outline" onClick={onClose} disabled={link.isPending}>
            Cancel
          </Button>
          <Button
            onClick={() => link.mutate()}
            disabled={link.isPending || !businessId || !/^\S+@\S+\.\S+$/.test(email.trim())}
          >
            {link.isPending ? "Linking…" : "Link owner"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
