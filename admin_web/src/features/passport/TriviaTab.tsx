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
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { Field, BilingualRow } from "@/components/form-fields";
import { checkpointName, useCheckpoints, type Trivia } from "./usePassportData";

const toLines = (v: string) =>
  v
    .split("\n")
    .map((s) => s.trim())
    .filter(Boolean);

const schema = z
  .object({
    checkpoint_id: z.string().min(1, "Choose a checkpoint"),
    question_en: z.string().min(1, "English question is required"),
    question_am: z.string(),
    options_en: z.string().refine((v) => toLines(v).length >= 2, {
      message: "Give at least 2 answer options (one per line)",
    }),
    options_am: z.string(),
    correct_index: z
      .string()
      .refine((v) => Number.isInteger(Number(v)) && Number(v) >= 1, {
        message: "Correct answer number must be 1 or more",
      }),
    points: z
      .string()
      .refine((v) => v.trim() === "" || Number.isInteger(Number(v)), {
        message: "Points must be a whole number",
      }),
    is_active: z.boolean(),
  })
  .superRefine((values, ctx) => {
    const count = toLines(values.options_en).length;
    const idx = Number(values.correct_index);
    if (Number.isInteger(idx) && idx >= 1 && idx > count) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["correct_index"],
        message: `You only have ${count} options — pick a number from 1 to ${count}`,
      });
    }
  });
type FormValues = z.infer<typeof schema>;

const emptyValues: FormValues = {
  checkpoint_id: "",
  question_en: "",
  question_am: "",
  options_en: "",
  options_am: "",
  correct_index: "1",
  points: "5",
  is_active: true,
};

export default function TriviaTab() {
  const queryClient = useQueryClient();
  const checkpoints = useCheckpoints();

  const trivia = useQuery({
    queryKey: ["passport", "trivia"],
    queryFn: async (): Promise<Trivia[]> => {
      const { data, error } = await supabase
        .from("passport_trivia")
        .select("*")
        .order("created_at", { ascending: true })
        .limit(500);
      if (error) throw error;
      return data ?? [];
    },
  });

  const [formOpen, setFormOpen] = React.useState(false);
  const [editRow, setEditRow] = React.useState<Trivia | undefined>();
  const [deleteRow, setDeleteRow] = React.useState<Trivia | undefined>();

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
              question_en: editRow.question_en,
              question_am: editRow.question_am ?? "",
              options_en: editRow.options_en.join("\n"),
              options_am: editRow.options_am.join("\n"),
              // Stored 0-based; people count from 1.
              correct_index: String(editRow.correct_index + 1),
              points: String(editRow.points),
              is_active: editRow.is_active,
            }
          : emptyValues,
      );
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [formOpen, editRow?.id]);

  const saveMutation = useMutation({
    mutationFn: async (values: FormValues) => {
      const payload: TablesInsert<"passport_trivia"> = {
        checkpoint_id: values.checkpoint_id,
        question_en: values.question_en.trim(),
        question_am: values.question_am.trim() || null,
        options_en: toLines(values.options_en),
        options_am: toLines(values.options_am),
        correct_index: Number(values.correct_index) - 1,
        points: values.points.trim() === "" ? 5 : Number(values.points),
        is_active: values.is_active,
      };
      if (editRow) {
        const { error } = await supabase
          .from("passport_trivia")
          .update(payload)
          .eq("id", editRow.id);
        if (error) throw error;
      } else {
        const { error } = await supabase.from("passport_trivia").insert(payload);
        if (error) throw error;
      }
    },
    onSuccess: () => {
      toast.success(editRow ? "Question updated" : "Question created");
      setFormOpen(false);
      setEditRow(undefined);
      void queryClient.invalidateQueries({ queryKey: ["passport", "trivia"] });
    },
    onError: (err) => toast.error(errorMessage(err)),
  });

  const deleteMutation = useMutation({
    mutationFn: async (id: string) => {
      const { error } = await supabase.from("passport_trivia").delete().eq("id", id);
      if (error) throw error;
    },
    onSuccess: () => {
      toast.success("Question deleted");
      setDeleteRow(undefined);
      void queryClient.invalidateQueries({ queryKey: ["passport", "trivia"] });
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
          <Plus /> New question
        </Button>
      </div>

      {trivia.isPending ? (
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
                <TableHead>Question</TableHead>
                <TableHead>Checkpoint</TableHead>
                <TableHead>Correct answer</TableHead>
                <TableHead>Points</TableHead>
                <TableHead>Status</TableHead>
                <TableHead className="w-20" />
              </TableRow>
            </TableHeader>
            <TableBody>
              {(trivia.data ?? []).length === 0 && (
                <TableRow className="hover:bg-transparent">
                  <TableCell colSpan={6}>
                    <p className="py-8 text-center text-sm text-muted-foreground">
                      No trivia yet. Add a fun question about Gondar!
                    </p>
                  </TableCell>
                </TableRow>
              )}
              {(trivia.data ?? []).map((row) => (
                <TableRow key={row.id}>
                  <TableCell className="max-w-[260px]">
                    <div className="truncate font-medium">{row.question_en}</div>
                    {row.question_am && (
                      <div className="truncate text-xs text-muted-foreground">
                        {row.question_am}
                      </div>
                    )}
                  </TableCell>
                  <TableCell className="text-muted-foreground">
                    {checkpointName(checkpoints.data, row.checkpoint_id)}
                  </TableCell>
                  <TableCell className="max-w-[160px] truncate">
                    {row.options_en[row.correct_index] ?? "—"}
                  </TableCell>
                  <TableCell>{row.points}</TableCell>
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
            <DialogTitle>{editRow ? "Edit question" : "New question"}</DialogTitle>
            <DialogDescription>
              Write the answers one per line. Then say which line number is
              correct (1 = first line).
            </DialogDescription>
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
              label="Question"
              errorEn={form.formState.errors.question_en?.message}
              en={<Textarea rows={2} {...form.register("question_en")} />}
              am={<Textarea rows={2} {...form.register("question_am")} />}
            />
            <BilingualRow
              label="Answer options (one per line)"
              errorEn={form.formState.errors.options_en?.message}
              en={<Textarea rows={4} {...form.register("options_en")} />}
              am={<Textarea rows={4} {...form.register("options_am")} />}
            />
            <div className="grid grid-cols-2 gap-2">
              <Field
                label="Correct answer (line number)"
                error={form.formState.errors.correct_index?.message}
              >
                <Input inputMode="numeric" {...form.register("correct_index")} />
              </Field>
              <Field label="Points" error={form.formState.errors.points?.message}>
                <Input inputMode="numeric" {...form.register("points")} />
              </Field>
            </div>
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
        title="Delete this question?"
        description="This cannot be undone."
        confirmLabel="Delete"
        destructive
        loading={deleteMutation.isPending}
        onConfirm={() => deleteRow && deleteMutation.mutate(deleteRow.id)}
      />
    </div>
  );
}
