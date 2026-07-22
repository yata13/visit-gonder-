import * as React from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";
import { Pencil, Plus, Trash2 } from "lucide-react";
import { supabase } from "@/lib/supabase";
import { errorMessage } from "@/lib/utils";
import type { TablesInsert } from "@/lib/database.types";
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
import { Field, BilingualRow } from "@/components/form-fields";
import { checkpointName, useCheckpoints, type Story } from "./usePassportData";

const schema = z.object({
  checkpoint_id: z.string().min(1, "Choose a checkpoint"),
  title_en: z.string().min(1, "English title is required"),
  title_am: z.string(),
  body_en: z.string(),
  body_am: z.string(),
  media_url: z.string(),
  sort_order: z
    .string()
    .refine((v) => v.trim() === "" || Number.isInteger(Number(v)), {
      message: "Order must be a whole number",
    }),
  is_active: z.boolean(),
});
type FormValues = z.infer<typeof schema>;

const emptyValues: FormValues = {
  checkpoint_id: "",
  title_en: "",
  title_am: "",
  body_en: "",
  body_am: "",
  media_url: "",
  sort_order: "0",
  is_active: true,
};

export default function StoriesTab() {
  const queryClient = useQueryClient();
  const checkpoints = useCheckpoints();

  const stories = useQuery({
    queryKey: ["passport", "stories"],
    queryFn: async (): Promise<Story[]> => {
      const { data, error } = await supabase
        .from("passport_stories")
        .select("*")
        .order("sort_order", { ascending: true })
        .limit(500);
      if (error) throw error;
      return data ?? [];
    },
  });

  const [formOpen, setFormOpen] = React.useState(false);
  const [editRow, setEditRow] = React.useState<Story | undefined>();
  const [deleteRow, setDeleteRow] = React.useState<Story | undefined>();

  const form = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: emptyValues,
  });

  React.useEffect(() => {
    if (formOpen) {
      form.reset(
        editRow
          ? {
              checkpoint_id: editRow.checkpoint_id,
              title_en: editRow.title_en,
              title_am: editRow.title_am ?? "",
              body_en: editRow.body_en ?? "",
              body_am: editRow.body_am ?? "",
              media_url: editRow.media_url ?? "",
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
      const payload: TablesInsert<"passport_stories"> = {
        checkpoint_id: values.checkpoint_id,
        title_en: values.title_en.trim(),
        title_am: values.title_am.trim() || null,
        body_en: values.body_en.trim() || null,
        body_am: values.body_am.trim() || null,
        media_url: values.media_url.trim() || null,
        sort_order: values.sort_order.trim() === "" ? 0 : Number(values.sort_order),
        is_active: values.is_active,
      };
      if (editRow) {
        const { error } = await supabase
          .from("passport_stories")
          .update(payload)
          .eq("id", editRow.id);
        if (error) throw error;
      } else {
        const { error } = await supabase.from("passport_stories").insert(payload);
        if (error) throw error;
      }
    },
    onSuccess: () => {
      toast.success(editRow ? "Story updated" : "Story created");
      setFormOpen(false);
      setEditRow(undefined);
      void queryClient.invalidateQueries({ queryKey: ["passport", "stories"] });
    },
    onError: (err) => toast.error(errorMessage(err)),
  });

  const deleteMutation = useMutation({
    mutationFn: async (id: string) => {
      const { error } = await supabase.from("passport_stories").delete().eq("id", id);
      if (error) throw error;
    },
    onSuccess: () => {
      toast.success("Story deleted");
      setDeleteRow(undefined);
      void queryClient.invalidateQueries({ queryKey: ["passport", "stories"] });
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
          <Plus /> New story
        </Button>
      </div>

      {stories.isPending ? (
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
                <TableHead>Title</TableHead>
                <TableHead>Checkpoint</TableHead>
                <TableHead>Order</TableHead>
                <TableHead>Status</TableHead>
                <TableHead className="w-20" />
              </TableRow>
            </TableHeader>
            <TableBody>
              {(stories.data ?? []).length === 0 && (
                <TableRow className="hover:bg-transparent">
                  <TableCell colSpan={5}>
                    <p className="py-8 text-center text-sm text-muted-foreground">
                      No stories yet. Stories unlock when a tourist checks in.
                    </p>
                  </TableCell>
                </TableRow>
              )}
              {(stories.data ?? []).map((row) => (
                <TableRow key={row.id}>
                  <TableCell>
                    <div className="font-medium">{row.title_en}</div>
                    {row.title_am && (
                      <div className="text-xs text-muted-foreground">{row.title_am}</div>
                    )}
                  </TableCell>
                  <TableCell className="text-muted-foreground">
                    {checkpointName(checkpoints.data, row.checkpoint_id)}
                  </TableCell>
                  <TableCell>{row.sort_order}</TableCell>
                  <TableCell>
                    {row.is_active ? (
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
              ))}
            </TableBody>
          </Table>
        </div>
      )}

      <Dialog open={formOpen} onOpenChange={setFormOpen}>
        <DialogContent className="max-w-xl">
          <DialogHeader>
            <DialogTitle>{editRow ? "Edit story" : "New story"}</DialogTitle>
          </DialogHeader>
          <form
            onSubmit={form.handleSubmit((v) => saveMutation.mutate(v))}
            className="space-y-4"
            noValidate
          >
            <Field
              label="Checkpoint"
              error={form.formState.errors.checkpoint_id?.message}
            >
              <Select
                value={form.watch("checkpoint_id") || undefined}
                onValueChange={(v) =>
                  form.setValue("checkpoint_id", v, { shouldValidate: true })
                }
              >
                <SelectTrigger>
                  <SelectValue placeholder="Choose a checkpoint…" />
                </SelectTrigger>
                <SelectContent>
                  {(checkpoints.data ?? []).map((c) => (
                    <SelectItem key={c.id} value={c.id}>
                      {c.name_en}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </Field>
            <BilingualRow
              label="Title"
              errorEn={form.formState.errors.title_en?.message}
              en={<Input {...form.register("title_en")} />}
              am={<Input {...form.register("title_am")} />}
            />
            <BilingualRow
              label="Story text"
              en={<Textarea rows={4} {...form.register("body_en")} />}
              am={<Textarea rows={4} {...form.register("body_am")} />}
            />
            <Field label="Image / audio URL (optional)">
              <Input {...form.register("media_url")} />
            </Field>
            <Field label="Sort order" error={form.formState.errors.sort_order?.message}>
              <Input inputMode="numeric" {...form.register("sort_order")} />
            </Field>
            <label className="flex items-center gap-2 text-sm font-medium">
              <input
                type="checkbox"
                className="h-4 w-4 rounded border-input accent-[hsl(var(--primary))]"
                checked={form.watch("is_active")}
                onChange={(e) => form.setValue("is_active", e.target.checked)}
              />
              Active
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

      <ConfirmDialog
        open={!!deleteRow}
        onOpenChange={(open) => !open && setDeleteRow(undefined)}
        title={`Delete “${deleteRow?.title_en}”?`}
        description="This cannot be undone."
        confirmLabel="Delete"
        destructive
        loading={deleteMutation.isPending}
        onConfirm={() => deleteRow && deleteMutation.mutate(deleteRow.id)}
      />
    </div>
  );
}
