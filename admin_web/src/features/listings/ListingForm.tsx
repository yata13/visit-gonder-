import * as React from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Field, BilingualRow } from "@/components/form-fields";
import { errorMessage } from "@/lib/utils";
import { createListing, updateListing } from "./api";
import type { AnyRow, FieldDef, ListingConfig } from "./registry";

interface ListingFormProps {
  config: ListingConfig;
  /** undefined = create; a row = edit. */
  row: AnyRow | undefined;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

export function ListingForm({ config, row, open, onOpenChange }: ListingFormProps) {
  const queryClient = useQueryClient();
  const form = useForm<Record<string, any>>({
    resolver: zodResolver(config.schema as never),
    defaultValues: config.fromRow(row),
  });

  // Re-seed the form whenever a different row (or create mode) opens.
  React.useEffect(() => {
    if (open) form.reset(config.fromRow(row));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open, row?.id, config.table]);

  const mutation = useMutation({
    mutationFn: async (values: Record<string, any>) => {
      const payload = config.toPayload(values);
      if (row?.id) {
        await updateListing(config.table, row.id, payload);
      } else {
        await createListing(config.table, payload);
      }
    },
    onSuccess: () => {
      toast.success(row?.id ? `${config.singular} updated` : `${config.singular} created`);
      void queryClient.invalidateQueries({ queryKey: ["listings", config.table] });
      void queryClient.invalidateQueries({ queryKey: ["dashboard"] });
      onOpenChange(false);
    },
    onError: (err) => toast.error(errorMessage(err)),
  });

  const errors = form.formState.errors as Record<string, { message?: string } | undefined>;
  const errOf = (name: string) => errors[name]?.message;

  function renderField(field: FieldDef, index: number) {
    switch (field.kind) {
      case "text":
        return (
          <Field key={index} label={field.label} error={errOf(field.name)} hint={field.hint}>
            <Input {...form.register(field.name)} />
          </Field>
        );
      case "number":
        return (
          <Field key={index} label={field.label} error={errOf(field.name)}>
            <Input inputMode="decimal" {...form.register(field.name)} />
          </Field>
        );
      case "textarea":
        return (
          <Field key={index} label={field.label} error={errOf(field.name)}>
            <Textarea rows={3} {...form.register(field.name)} />
          </Field>
        );
      case "bilingual": {
        const control = (name: string) =>
          field.textarea ? (
            <Textarea rows={3} {...form.register(name)} />
          ) : (
            <Input {...form.register(name)} />
          );
        return (
          <BilingualRow
            key={index}
            label={field.label}
            errorEn={errOf(field.nameEn)}
            errorAm={errOf(field.nameAm)}
            en={control(field.nameEn)}
            am={control(field.nameAm)}
          />
        );
      }
      case "select": {
        const value = form.watch(field.name) as string;
        return (
          <Field key={index} label={field.label} error={errOf(field.name)}>
            <Select
              value={value}
              onValueChange={(v) =>
                form.setValue(field.name, v, { shouldValidate: true })
              }
            >
              <SelectTrigger>
                <SelectValue placeholder="Choose…" />
              </SelectTrigger>
              <SelectContent>
                {field.options.map((opt) => (
                  <SelectItem key={opt.value} value={opt.value}>
                    {opt.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </Field>
        );
      }
      case "checkbox": {
        const checked = Boolean(form.watch(field.name));
        return (
          <label key={index} className="flex items-center gap-2 text-sm font-medium">
            <input
              type="checkbox"
              className="h-4 w-4 rounded border-input accent-[hsl(var(--primary))]"
              checked={checked}
              onChange={(e) =>
                form.setValue(field.name, e.target.checked, { shouldValidate: true })
              }
            />
            {field.label}
          </label>
        );
      }
      case "list":
        return (
          <Field key={index} label={field.label} error={errOf(field.name)} hint={field.hint}>
            <Textarea rows={3} {...form.register(field.name)} />
          </Field>
        );
      case "latlng":
        return (
          <div key={index} className="grid grid-cols-2 gap-2">
            <Field label="Latitude" error={errOf("lat")} hint="e.g. 12.6043">
              <Input inputMode="decimal" {...form.register("lat")} />
            </Field>
            <Field label="Longitude" error={errOf("lng")} hint="e.g. 37.4700">
              <Input inputMode="decimal" {...form.register("lng")} />
            </Field>
          </div>
        );
    }
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-xl">
        <DialogHeader>
          <DialogTitle>
            {row?.id ? `Edit ${config.singular}` : `New ${config.singular}`}
          </DialogTitle>
          <DialogDescription>
            Fields with an English/Amharic pair are shown side by side.
          </DialogDescription>
        </DialogHeader>
        <form
          onSubmit={form.handleSubmit((values) => mutation.mutate(values))}
          className="space-y-4"
          noValidate
        >
          {config.fields.map(renderField)}
          <DialogFooter>
            <Button
              type="button"
              variant="outline"
              onClick={() => onOpenChange(false)}
              disabled={mutation.isPending}
            >
              Cancel
            </Button>
            <Button type="submit" disabled={mutation.isPending}>
              {mutation.isPending ? "Saving…" : "Save"}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
