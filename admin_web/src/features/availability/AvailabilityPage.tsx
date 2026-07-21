import * as React from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";
import { CalendarPlus, Pencil, Trash2 } from "lucide-react";
import { supabase } from "@/lib/supabase";
import { errorMessage, formatDate } from "@/lib/utils";
import type { Tables, TablesInsert } from "@/lib/database.types";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Skeleton } from "@/components/ui/skeleton";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
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
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { Field } from "@/components/form-fields";

type AvailabilityRow = Tables<"availability">;
type BusinessType = "hotel" | "guide";

interface BusinessOption {
  id: string;
  name: string;
}

async function listBusinesses(type: BusinessType): Promise<BusinessOption[]> {
  if (type === "hotel") {
    const { data, error } = await supabase
      .from("hotels")
      .select("id, name_en")
      .order("name_en");
    if (error) throw error;
    return (data ?? []).map((h) => ({ id: h.id, name: h.name_en ?? "Unnamed hotel" }));
  }
  const { data, error } = await supabase
    .from("guides")
    .select("id, name")
    .order("name");
  if (error) throw error;
  return (data ?? []).map((g) => ({ id: g.id, name: g.name ?? "Unnamed guide" }));
}

async function listAvailability(
  type: BusinessType,
  businessId: string,
): Promise<AvailabilityRow[]> {
  const { data, error } = await supabase
    .from("availability")
    .select("*")
    .eq("business_type", type)
    .eq("business_id", businessId)
    .order("day", { ascending: true })
    .limit(200);
  if (error) throw error;
  return data ?? [];
}

const formSchema = z.object({
  day: z.string().min(1, "Pick a date"),
  capacity: z
    .string()
    .refine((v) => v.trim() !== "" && Number.isInteger(Number(v)) && Number(v) >= 0, {
      message: "Capacity must be 0 or more",
    }),
  booked: z
    .string()
    .refine((v) => v.trim() === "" || (Number.isInteger(Number(v)) && Number(v) >= 0), {
      message: "Booked must be 0 or more",
    }),
  is_closed: z.boolean(),
  note: z.string(),
});
type FormValues = z.infer<typeof formSchema>;

export default function AvailabilityPage() {
  const queryClient = useQueryClient();
  const [businessType, setBusinessType] = React.useState<BusinessType>("hotel");
  const [businessId, setBusinessId] = React.useState<string>("");
  const [formOpen, setFormOpen] = React.useState(false);
  const [editRow, setEditRow] = React.useState<AvailabilityRow | undefined>();
  const [deleteRow, setDeleteRow] = React.useState<AvailabilityRow | undefined>();

  const businesses = useQuery({
    queryKey: ["businesses", businessType],
    queryFn: () => listBusinesses(businessType),
  });

  const rowsQuery = useQuery({
    queryKey: ["availability", businessType, businessId],
    queryFn: () => listAvailability(businessType, businessId),
    enabled: !!businessId,
  });

  const form = useForm<FormValues>({
    resolver: zodResolver(formSchema),
    defaultValues: { day: "", capacity: "1", booked: "0", is_closed: false, note: "" },
  });

  React.useEffect(() => {
    if (formOpen) {
      form.reset(
        editRow
          ? {
              day: editRow.day,
              capacity: String(editRow.capacity),
              booked: String(editRow.booked),
              is_closed: editRow.is_closed,
              note: editRow.note ?? "",
            }
          : { day: "", capacity: "1", booked: "0", is_closed: false, note: "" },
      );
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [formOpen, editRow?.id]);

  const saveMutation = useMutation({
    mutationFn: async (values: FormValues) => {
      const payload: TablesInsert<"availability"> = {
        business_type: businessType,
        business_id: businessId,
        day: values.day,
        capacity: Number(values.capacity),
        booked: values.booked.trim() === "" ? 0 : Number(values.booked),
        is_closed: values.is_closed,
        note: values.note.trim() === "" ? null : values.note.trim(),
      };
      if (editRow) {
        const { error } = await supabase
          .from("availability")
          .update(payload)
          .eq("id", editRow.id);
        if (error) throw error;
      } else {
        const { error } = await supabase.from("availability").insert(payload);
        if (error) throw error;
      }
    },
    onSuccess: () => {
      toast.success(editRow ? "Day updated" : "Day added");
      setFormOpen(false);
      setEditRow(undefined);
      void queryClient.invalidateQueries({
        queryKey: ["availability", businessType, businessId],
      });
    },
    onError: (err: unknown) => {
      const msg = errorMessage(err);
      toast.error(
        msg.includes("duplicate") || msg.includes("unique")
          ? "There is already a row for that day. Edit it instead."
          : msg,
      );
    },
  });

  const deleteMutation = useMutation({
    mutationFn: async (id: string) => {
      const { error } = await supabase.from("availability").delete().eq("id", id);
      if (error) throw error;
    },
    onSuccess: () => {
      toast.success("Day removed");
      setDeleteRow(undefined);
      void queryClient.invalidateQueries({
        queryKey: ["availability", businessType, businessId],
      });
    },
    onError: (err) => toast.error(errorMessage(err)),
  });

  return (
    <div className="space-y-4">
      <div>
        <h1 className="text-xl font-semibold">Availability</h1>
        <p className="text-sm text-muted-foreground">
          Per-day capacity for a hotel or guide. Days without a row use the
          business default in the app.
        </p>
      </div>

      <div className="flex flex-wrap items-center gap-2">
        <Select
          value={businessType}
          onValueChange={(v) => {
            setBusinessType(v as BusinessType);
            setBusinessId("");
          }}
        >
          <SelectTrigger className="w-32">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="hotel">Hotels</SelectItem>
            <SelectItem value="guide">Guides</SelectItem>
          </SelectContent>
        </Select>

        <Select
          value={businessId || undefined}
          onValueChange={(v) => setBusinessId(v)}
        >
          <SelectTrigger className="w-64">
            <SelectValue
              placeholder={
                businesses.isPending
                  ? "Loading…"
                  : `Choose a ${businessType}…`
              }
            />
          </SelectTrigger>
          <SelectContent>
            {(businesses.data ?? []).map((b) => (
              <SelectItem key={b.id} value={b.id}>
                {b.name}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>

        {businessId && (
          <Button
            className="ml-auto"
            onClick={() => {
              setEditRow(undefined);
              setFormOpen(true);
            }}
          >
            <CalendarPlus /> Add day
          </Button>
        )}
      </div>

      {!businessId ? (
        <p className="rounded-lg border bg-card p-10 text-center text-sm text-muted-foreground">
          Choose a business above to manage its calendar.
        </p>
      ) : rowsQuery.isPending ? (
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
                <TableHead>Date</TableHead>
                <TableHead>Capacity</TableHead>
                <TableHead>Booked</TableHead>
                <TableHead>Free</TableHead>
                <TableHead>Status</TableHead>
                <TableHead>Note</TableHead>
                <TableHead className="w-20" />
              </TableRow>
            </TableHeader>
            <TableBody>
              {(rowsQuery.data ?? []).length === 0 && (
                <TableRow className="hover:bg-transparent">
                  <TableCell colSpan={7}>
                    <p className="py-8 text-center text-sm text-muted-foreground">
                      No days configured yet. Click “Add day”.
                    </p>
                  </TableCell>
                </TableRow>
              )}
              {(rowsQuery.data ?? []).map((row) => {
                const free = Math.max(0, row.capacity - row.booked);
                return (
                  <TableRow key={row.id}>
                    <TableCell className="whitespace-nowrap font-medium">
                      {formatDate(row.day)}
                    </TableCell>
                    <TableCell>{row.capacity}</TableCell>
                    <TableCell>{row.booked}</TableCell>
                    <TableCell>{row.is_closed ? 0 : free}</TableCell>
                    <TableCell>
                      {row.is_closed ? (
                        <Badge variant="destructive">Closed</Badge>
                      ) : free === 0 ? (
                        <Badge variant="warning">Full</Badge>
                      ) : (
                        <Badge variant="success">Open</Badge>
                      )}
                    </TableCell>
                    <TableCell className="max-w-[200px] truncate text-muted-foreground">
                      {row.note ?? ""}
                    </TableCell>
                    <TableCell>
                      <div className="flex gap-1">
                        <Button
                          variant="ghost"
                          size="icon"
                          onClick={() => {
                            setEditRow(row);
                            setFormOpen(true);
                          }}
                        >
                          <Pencil className="h-4 w-4" />
                        </Button>
                        <Button
                          variant="ghost"
                          size="icon"
                          onClick={() => setDeleteRow(row)}
                        >
                          <Trash2 className="h-4 w-4 text-destructive" />
                        </Button>
                      </div>
                    </TableCell>
                  </TableRow>
                );
              })}
            </TableBody>
          </Table>
        </div>
      )}

      <Dialog open={formOpen} onOpenChange={setFormOpen}>
        <DialogContent className="max-w-md">
          <DialogHeader>
            <DialogTitle>{editRow ? "Edit day" : "Add day"}</DialogTitle>
          </DialogHeader>
          <form
            onSubmit={form.handleSubmit((v) => saveMutation.mutate(v))}
            className="space-y-4"
            noValidate
          >
            <Field label="Date" error={form.formState.errors.day?.message}>
              <Input type="date" {...form.register("day")} disabled={!!editRow} />
            </Field>
            <div className="grid grid-cols-2 gap-2">
              <Field label="Capacity" error={form.formState.errors.capacity?.message}>
                <Input inputMode="numeric" {...form.register("capacity")} />
              </Field>
              <Field label="Already booked" error={form.formState.errors.booked?.message}>
                <Input inputMode="numeric" {...form.register("booked")} />
              </Field>
            </div>
            <label className="flex items-center gap-2 text-sm font-medium">
              <input
                type="checkbox"
                className="h-4 w-4 rounded border-input accent-[hsl(var(--primary))]"
                checked={form.watch("is_closed")}
                onChange={(e) => form.setValue("is_closed", e.target.checked)}
              />
              Closed this day (no bookings)
            </label>
            <Field label="Note (optional)">
              <Textarea rows={2} {...form.register("note")} />
            </Field>
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

      <ConfirmDialog
        open={!!deleteRow}
        onOpenChange={(open) => !open && setDeleteRow(undefined)}
        title="Remove this day?"
        description={
          deleteRow
            ? `${formatDate(deleteRow.day)} will fall back to the business default.`
            : undefined
        }
        confirmLabel="Remove"
        destructive
        loading={deleteMutation.isPending}
        onConfirm={() => deleteRow && deleteMutation.mutate(deleteRow.id)}
      />
    </div>
  );
}
