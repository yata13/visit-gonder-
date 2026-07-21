import * as React from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";
import { QRCodeSVG } from "qrcode.react";
import { Copy, Pencil, Plus, QrCode, RefreshCw, Trash2 } from "lucide-react";
import { supabase } from "@/lib/supabase";
import { errorMessage } from "@/lib/utils";
import type { TablesInsert } from "@/lib/database.types";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Skeleton } from "@/components/ui/skeleton";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { Field, BilingualRow } from "@/components/form-fields";
import { useCheckpoints, type Checkpoint } from "./usePassportData";

const requiredNumber = (label: string) =>
  z.string().refine((v) => v.trim() !== "" && !Number.isNaN(Number(v)), {
    message: `${label} is required and must be a number`,
  });
const optionalInt = (label: string) =>
  z.string().refine((v) => v.trim() === "" || Number.isInteger(Number(v)), {
    message: `${label} must be a whole number`,
  });

const schema = z.object({
  name_en: z.string().min(1, "English name is required"),
  name_am: z.string(),
  description_en: z.string(),
  description_am: z.string(),
  photo: z.string(),
  lat: requiredNumber("Latitude"),
  lng: requiredNumber("Longitude"),
  points: optionalInt("Points"),
  sort_order: optionalInt("Order"),
  is_active: z.boolean(),
});
type FormValues = z.infer<typeof schema>;

const emptyValues: FormValues = {
  name_en: "",
  name_am: "",
  description_en: "",
  description_am: "",
  photo: "",
  lat: "",
  lng: "",
  points: "10",
  sort_order: "0",
  is_active: true,
};

export default function CheckpointsTab() {
  const queryClient = useQueryClient();
  const checkpoints = useCheckpoints();

  const [formOpen, setFormOpen] = React.useState(false);
  const [editRow, setEditRow] = React.useState<Checkpoint | undefined>();
  const [deleteRow, setDeleteRow] = React.useState<Checkpoint | undefined>();
  const [qrRow, setQrRow] = React.useState<Checkpoint | undefined>();

  const form = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: emptyValues,
  });

  React.useEffect(() => {
    if (formOpen) {
      form.reset(
        editRow
          ? {
              name_en: editRow.name_en,
              name_am: editRow.name_am ?? "",
              description_en: editRow.description_en ?? "",
              description_am: editRow.description_am ?? "",
              photo: editRow.photo ?? "",
              lat: String(editRow.lat),
              lng: String(editRow.lng),
              points: String(editRow.points),
              sort_order: String(editRow.sort_order),
              is_active: editRow.is_active,
            }
          : emptyValues,
      );
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [formOpen, editRow?.id]);

  const saveMutation = useMutation({
    mutationFn: async (values: FormValues) => {
      const payload: TablesInsert<"passport_checkpoints"> = {
        name_en: values.name_en.trim(),
        name_am: values.name_am.trim() || null,
        description_en: values.description_en.trim() || null,
        description_am: values.description_am.trim() || null,
        photo: values.photo.trim() || null,
        lat: Number(values.lat),
        lng: Number(values.lng),
        points: values.points.trim() === "" ? 10 : Number(values.points),
        sort_order: values.sort_order.trim() === "" ? 0 : Number(values.sort_order),
        is_active: values.is_active,
      };
      if (editRow) {
        const { error } = await supabase
          .from("passport_checkpoints")
          .update(payload)
          .eq("id", editRow.id);
        if (error) throw error;
      } else {
        const { error } = await supabase.from("passport_checkpoints").insert(payload);
        if (error) throw error;
      }
    },
    onSuccess: () => {
      toast.success(editRow ? "Checkpoint updated" : "Checkpoint created");
      setFormOpen(false);
      setEditRow(undefined);
      void queryClient.invalidateQueries({ queryKey: ["passport"] });
    },
    onError: (err) => toast.error(errorMessage(err)),
  });

  const deleteMutation = useMutation({
    mutationFn: async (id: string) => {
      const { error } = await supabase
        .from("passport_checkpoints")
        .delete()
        .eq("id", id);
      if (error) throw error;
    },
    onSuccess: () => {
      toast.success("Checkpoint deleted (its stories and trivia too)");
      setDeleteRow(undefined);
      void queryClient.invalidateQueries({ queryKey: ["passport"] });
    },
    onError: (err) => toast.error(errorMessage(err)),
  });

  return (
    <div className="space-y-3">
      <div className="flex justify-end">
        <Button
          onClick={() => {
            setEditRow(undefined);
            setFormOpen(true);
          }}
        >
          <Plus /> New checkpoint
        </Button>
      </div>

      {checkpoints.isPending ? (
        <div className="space-y-2">
          {Array.from({ length: 4 }).map((_, i) => (
            <Skeleton key={i} className="h-10 w-full" />
          ))}
        </div>
      ) : (
        <div className="rounded-lg border bg-card">
          <Table>
            <TableHeader>
              <TableRow className="hover:bg-transparent">
                <TableHead>Name</TableHead>
                <TableHead>GPS</TableHead>
                <TableHead>Points</TableHead>
                <TableHead>Status</TableHead>
                <TableHead className="w-32" />
              </TableRow>
            </TableHeader>
            <TableBody>
              {(checkpoints.data ?? []).length === 0 && (
                <TableRow className="hover:bg-transparent">
                  <TableCell colSpan={5}>
                    <p className="py-8 text-center text-sm text-muted-foreground">
                      No checkpoints yet. Start with Fasil Ghebbi!
                    </p>
                  </TableCell>
                </TableRow>
              )}
              {(checkpoints.data ?? []).map((c) => (
                <TableRow key={c.id}>
                  <TableCell>
                    <div className="font-medium">{c.name_en}</div>
                    {c.name_am && (
                      <div className="text-xs text-muted-foreground">{c.name_am}</div>
                    )}
                  </TableCell>
                  <TableCell className="whitespace-nowrap text-muted-foreground">
                    {Number(c.lat).toFixed(4)}, {Number(c.lng).toFixed(4)}
                  </TableCell>
                  <TableCell>{c.points}</TableCell>
                  <TableCell>
                    {c.is_active ? (
                      <Badge variant="success">Active</Badge>
                    ) : (
                      <Badge variant="secondary">Inactive</Badge>
                    )}
                  </TableCell>
                  <TableCell>
                    <div className="flex gap-1">
                      <Button
                        variant="ghost"
                        size="icon"
                        title="QR code"
                        onClick={() => setQrRow(c)}
                      >
                        <QrCode className="h-4 w-4" />
                      </Button>
                      <Button
                        variant="ghost"
                        size="icon"
                        title="Edit"
                        onClick={() => {
                          setEditRow(c);
                          setFormOpen(true);
                        }}
                      >
                        <Pencil className="h-4 w-4" />
                      </Button>
                      <Button
                        variant="ghost"
                        size="icon"
                        title="Delete"
                        onClick={() => setDeleteRow(c)}
                      >
                        <Trash2 className="h-4 w-4 text-destructive" />
                      </Button>
                    </div>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </div>
      )}

      {/* Create / edit dialog */}
      <Dialog open={formOpen} onOpenChange={setFormOpen}>
        <DialogContent className="max-w-xl">
          <DialogHeader>
            <DialogTitle>
              {editRow ? "Edit checkpoint" : "New checkpoint"}
            </DialogTitle>
          </DialogHeader>
          <form
            onSubmit={form.handleSubmit((v) => saveMutation.mutate(v))}
            className="space-y-4"
            noValidate
          >
            <BilingualRow
              label="Name"
              errorEn={form.formState.errors.name_en?.message}
              en={<Input {...form.register("name_en")} />}
              am={<Input {...form.register("name_am")} />}
            />
            <BilingualRow
              label="Description"
              en={<Textarea rows={2} {...form.register("description_en")} />}
              am={<Textarea rows={2} {...form.register("description_am")} />}
            />
            <Field label="Photo URL">
              <Input {...form.register("photo")} />
            </Field>
            <div className="grid grid-cols-2 gap-2">
              <Field
                label="Latitude"
                error={form.formState.errors.lat?.message}
                hint="e.g. 12.6043"
              >
                <Input inputMode="decimal" {...form.register("lat")} />
              </Field>
              <Field
                label="Longitude"
                error={form.formState.errors.lng?.message}
                hint="e.g. 37.4700"
              >
                <Input inputMode="decimal" {...form.register("lng")} />
              </Field>
            </div>
            <div className="grid grid-cols-2 gap-2">
              <Field label="Points" error={form.formState.errors.points?.message}>
                <Input inputMode="numeric" {...form.register("points")} />
              </Field>
              <Field
                label="Sort order"
                error={form.formState.errors.sort_order?.message}
              >
                <Input inputMode="numeric" {...form.register("sort_order")} />
              </Field>
            </div>
            <label className="flex items-center gap-2 text-sm font-medium">
              <input
                type="checkbox"
                className="h-4 w-4 rounded border-input accent-[hsl(var(--primary))]"
                checked={form.watch("is_active")}
                onChange={(e) => form.setValue("is_active", e.target.checked)}
              />
              Active (visible in the app)
            </label>
            <DialogFooter>
              <Button
                type="button"
                variant="outline"
                onClick={() => setFormOpen(false)}
                disabled={saveMutation.isPending}
              >
                Cancel
              </Button>
              <Button type="submit" disabled={saveMutation.isPending}>
                {saveMutation.isPending ? "Saving…" : "Save"}
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>

      <QrDialog checkpoint={qrRow} onClose={() => setQrRow(undefined)} />

      <ConfirmDialog
        open={!!deleteRow}
        onOpenChange={(open) => !open && setDeleteRow(undefined)}
        title={`Delete “${deleteRow?.name_en}”?`}
        description="Its stories, trivia and check-ins are deleted with it. This cannot be undone."
        confirmLabel="Delete"
        destructive
        loading={deleteMutation.isPending}
        onConfirm={() => deleteRow && deleteMutation.mutate(deleteRow.id)}
      />
    </div>
  );
}

/** Shows the QR token for a checkpoint; admins can rotate it. */
function QrDialog({
  checkpoint,
  onClose,
}: {
  checkpoint: Checkpoint | undefined;
  onClose: () => void;
}) {
  const queryClient = useQueryClient();

  const secret = useQuery({
    queryKey: ["passport", "secret", checkpoint?.id],
    enabled: !!checkpoint,
    queryFn: async () => {
      const { data, error } = await supabase
        .from("passport_checkpoint_secrets")
        .select("*")
        .eq("checkpoint_id", checkpoint!.id)
        .maybeSingle();
      if (error) throw error;
      return data;
    },
  });

  const rotateMutation = useMutation({
    mutationFn: async () => {
      const { data, error } = await supabase.rpc("admin_rotate_checkpoint_qr", {
        p_checkpoint_id: checkpoint!.id,
      });
      if (error) throw error;
      return data;
    },
    onSuccess: () => {
      toast.success("New QR token generated — reprint the sign!");
      void queryClient.invalidateQueries({
        queryKey: ["passport", "secret", checkpoint?.id],
      });
    },
    onError: (err) => toast.error(errorMessage(err)),
  });

  const token = secret.data?.qr_token;

  return (
    <Dialog open={!!checkpoint} onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="max-w-sm">
        <DialogHeader>
          <DialogTitle>QR code — {checkpoint?.name_en}</DialogTitle>
          <DialogDescription>
            Print this code and place it at the checkpoint. Tourists scan it in
            the app to check in.
          </DialogDescription>
        </DialogHeader>

        {secret.isPending ? (
          <Skeleton className="mx-auto h-48 w-48" />
        ) : token ? (
          <div className="flex flex-col items-center gap-3">
            <div className="rounded-lg bg-white p-4">
              <QRCodeSVG value={token} size={192} />
            </div>
            <code className="max-w-full break-all rounded bg-muted px-2 py-1 text-xs">
              {token}
            </code>
            <div className="flex gap-2">
              <Button
                variant="outline"
                size="sm"
                onClick={() => {
                  void navigator.clipboard.writeText(token);
                  toast.success("Token copied");
                }}
              >
                <Copy /> Copy
              </Button>
              <Button
                variant="outline"
                size="sm"
                disabled={rotateMutation.isPending}
                onClick={() => rotateMutation.mutate()}
              >
                <RefreshCw /> New token
              </Button>
            </div>
          </div>
        ) : (
          <p className="text-center text-sm text-muted-foreground">
            No token found. Run migration 0010 and re-open this dialog.
          </p>
        )}
      </DialogContent>
    </Dialog>
  );
}
