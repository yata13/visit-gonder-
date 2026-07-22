import * as React from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";
import {
  BellRing,
  CheckCircle2,
  Flame,
  Megaphone,
  Send,
  Trash2,
  TriangleAlert,
  Volume2,
} from "lucide-react";
import { supabase } from "@/lib/supabase";
import { cn, errorMessage, formatDateTime } from "@/lib/utils";
import type { Tables, TablesInsert } from "@/lib/database.types";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Skeleton } from "@/components/ui/skeleton";
import { Field } from "@/components/form-fields";
import { ConfirmDialog } from "@/components/confirm-dialog";

type Notification = Tables<"notifications">;

// Same three broadcast types as the old admin's composer.
const TYPES = [
  { value: "news", label: "📰 NEWS" },
  { value: "moment", label: "⚡ MOMENT" },
  { value: "safety", label: "⚠️ SAFETY" },
] as const;

const schema = z.object({
  title: z.string().min(1, "Required"),
  message: z.string().min(1, "Required"),
  type: z.enum(["news", "moment", "safety"]),
  send_to_all: z.boolean(),
});
type FormValues = z.infer<typeof schema>;

export default function NotificationsPage() {
  const queryClient = useQueryClient();
  const [successMsg, setSuccessMsg] = React.useState<string | null>(null);
  const [deleteRow, setDeleteRow] = React.useState<Notification | undefined>();

  const query = useQuery({
    queryKey: ["notifications"],
    queryFn: async (): Promise<Notification[]> => {
      const { data, error } = await supabase
        .from("notifications")
        .select("*")
        .order("created_at", { ascending: false })
        .limit(200);
      if (error) throw error;
      return data ?? [];
    },
  });

  const form = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: { title: "", message: "", type: "news", send_to_all: true },
  });
  const type = form.watch("type");

  const sendMutation = useMutation({
    mutationFn: async (values: FormValues) => {
      const payload: TablesInsert<"notifications"> = {
        title: values.title.trim(),
        message: values.message.trim(),
        body: values.message.trim(),
        type: values.type,
        send_to_all: values.send_to_all,
      };
      const { error } = await supabase.from("notifications").insert(payload);
      if (error) throw error;
      return values.title.trim();
    },
    onSuccess: (title) => {
      form.reset({ title: "", message: "", type: "news", send_to_all: true });
      setSuccessMsg(`Alert "${title}" dispatched to all tourists!`);
      setTimeout(() => setSuccessMsg(null), 4000);
      void queryClient.invalidateQueries({ queryKey: ["notifications"] });
    },
    onError: (err) => toast.error(errorMessage(err)),
  });

  const deleteMutation = useMutation({
    mutationFn: async (id: string) => {
      const { error } = await supabase.from("notifications").delete().eq("id", id);
      if (error) throw error;
    },
    onSuccess: () => {
      toast.success("Notification deleted");
      setDeleteRow(undefined);
      void queryClient.invalidateQueries({ queryKey: ["notifications"] });
    },
    onError: (err) => toast.error(errorMessage(err)),
  });

  return (
    <div className="space-y-4">
      <div>
        <h2 className="text-[22px] font-extrabold">Advisory Alerts & Moments</h2>
        <p className="text-sm text-muted-foreground">
          Compose push alerts, news posts and safety warnings for Gondar tourists.
        </p>
      </div>
      <div className="border-t" />

      <div className="grid grid-cols-1 gap-5 lg:grid-cols-[360px_1fr]">
        {/* ── Composer ── */}
        <div className="h-fit rounded-[14px] border bg-card p-5">
          <div className="mb-4 flex items-center gap-2">
            <Volume2 className="h-[18px] w-[18px] text-primary" />
            <span className="text-xs font-extrabold tracking-wide">
              COMPOSE BROADCAST
            </span>
          </div>

          {successMsg && (
            <div className="mb-3 flex items-start gap-2 rounded-lg border-l-[3px] border-success bg-success-bg p-3 text-xs text-success">
              <CheckCircle2 className="h-4 w-4 shrink-0" />
              {successMsg}
            </div>
          )}

          <form
            onSubmit={form.handleSubmit((v) => sendMutation.mutate(v))}
            className="space-y-4"
            noValidate
          >
            <div className="space-y-2">
              <span className="text-[11px] font-bold tracking-wide text-muted-foreground">
                ANNOUNCEMENT TYPE
              </span>
              <div className="flex gap-2">
                {TYPES.map((t) => {
                  const selected = type === t.value;
                  return (
                    <button
                      key={t.value}
                      type="button"
                      onClick={() => form.setValue("type", t.value)}
                      className={cn(
                        "flex-1 rounded-lg border py-2 font-mono text-[10px] font-bold transition-colors",
                        selected
                          ? t.value === "safety"
                            ? "border-red-400 bg-red-100 text-foreground"
                            : t.value === "moment"
                              ? "border-amber-500 bg-amber-100 text-foreground"
                              : "border-primary bg-secondary text-foreground"
                          : "bg-card text-muted-foreground hover:bg-accent",
                      )}
                    >
                      {t.label}
                    </button>
                  );
                })}
              </div>
            </div>

            <Field label="HEADLINE / TITLE" error={form.formState.errors.title?.message}>
              <Input
                placeholder="e.g. Fasilides Castle Closed Earlier Today"
                {...form.register("title")}
              />
            </Field>

            <Field label="MESSAGE BODY" error={form.formState.errors.message?.message}>
              <Textarea
                rows={4}
                placeholder="Write notice instructions or news detail…"
                {...form.register("message")}
              />
            </Field>

            <label className="flex items-center gap-2 text-xs font-semibold text-muted-foreground">
              <input
                type="checkbox"
                className="h-4 w-4 rounded border-input accent-[hsl(var(--primary))]"
                checked={form.watch("send_to_all")}
                onChange={(e) => form.setValue("send_to_all", e.target.checked)}
              />
              Broadcast to all tourists on foot
            </label>

            <Button type="submit" className="h-11 w-full" disabled={sendMutation.isPending}>
              <Send /> {sendMutation.isPending ? "DISPATCHING…" : "DISPATCH BROADCAST ALERT"}
            </Button>
          </form>
        </div>

        {/* ── Logs ── */}
        <div className="rounded-[14px] border bg-card p-5">
          <div className="flex items-center gap-2">
            <BellRing className="h-4 w-4 text-red-500" />
            <span className="text-xs font-extrabold tracking-wide">
              ANNOUNCEMENT LOGS ({query.data?.length ?? 0})
            </span>
          </div>
          <div className="my-3 border-t" />

          {query.isPending ? (
            <div className="space-y-2">
              {Array.from({ length: 4 }).map((_, i) => (
                <Skeleton key={i} className="h-16 w-full rounded-lg" />
              ))}
            </div>
          ) : (query.data ?? []).length === 0 ? (
            <p className="py-10 text-center text-muted-foreground">
              No notifications sent yet.
            </p>
          ) : (
            <div className="space-y-2.5">
              {(query.data ?? []).map((n) => (
                <div
                  key={n.id}
                  className="flex items-start gap-2.5 rounded-lg border bg-background p-3.5"
                >
                  <TypeIcon type={n.type} />
                  <div className="min-w-0 flex-1">
                    <div className="flex items-center gap-2">
                      <TypeBadge type={n.type} />
                      <span className="font-mono text-[10px] text-muted-foreground">
                        {formatDateTime(n.created_at)}
                      </span>
                    </div>
                    <div className="mt-1 text-xs font-bold">{n.title}</div>
                    <div className="text-[11px] leading-relaxed text-muted-foreground">
                      {n.message ?? n.body}
                    </div>
                  </div>
                  <button
                    className="p-1 text-muted-foreground transition-colors hover:text-destructive"
                    title="Delete"
                    onClick={() => setDeleteRow(n)}
                  >
                    <Trash2 className="h-4 w-4" />
                  </button>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      <ConfirmDialog
        open={!!deleteRow}
        onOpenChange={(open) => !open && setDeleteRow(undefined)}
        title="Delete notification?"
        confirmLabel="Delete"
        destructive
        loading={deleteMutation.isPending}
        onConfirm={() => deleteRow && deleteMutation.mutate(deleteRow.id)}
      />
    </div>
  );
}

function TypeIcon({ type }: { type: string | null }) {
  if (type === "safety") return <TriangleAlert className="h-[18px] w-[18px] text-red-500" />;
  if (type === "moment") return <Flame className="h-[18px] w-[18px] text-amber-500" />;
  return <Megaphone className="h-[18px] w-[18px] text-primary" />;
}

function TypeBadge({ type }: { type: string | null }) {
  const t = type ?? "news";
  const cls =
    t === "safety"
      ? "bg-red-50 text-red-800"
      : t === "moment"
        ? "bg-amber-50 text-amber-900"
        : "bg-blue-50 text-blue-800";
  return (
    <span className={cn("rounded px-1.5 py-0.5 font-mono text-[9px] font-bold", cls)}>
      {t.toUpperCase()}
    </span>
  );
}
