import * as React from "react";
import { CalendarRange, ChevronLeft, ChevronRight, Lock, StickyNote } from "lucide-react";
import { addDays, cn, isoDay, parseDay } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Field } from "@/components/form-fields";
import { useCurrentBusiness, unitWord, type Business } from "@/features/business/BusinessProvider";
import { ACTIVE, useBookings } from "@/features/bookings/api";
import { type DayRow, useAvailability, useClearDay, useSaveDays } from "./api";

const WEEKDAYS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

/** The 6-week grid (Monday first) that shows a month. */
function monthGrid(month: Date): Date[] {
  const first = new Date(month.getFullYear(), month.getMonth(), 1);
  const start = addDays(first, -((first.getDay() + 6) % 7));
  return Array.from({ length: 42 }, (_, i) => addDays(start, i));
}

type DayState = "past" | "closed" | "full" | "busy" | "free" | "open";

const STATE_STYLE: Record<DayState, string> = {
  past: "bg-muted/40 text-muted-foreground",
  closed: "bg-[repeating-linear-gradient(135deg,hsl(var(--destructive)/0.10)_0_6px,transparent_6px_12px)] border-destructive/40",
  full: "bg-destructive/10 border-destructive/40",
  busy: "bg-warning-bg border-warning/50",
  free: "bg-success-bg border-success/30",
  open: "bg-card",
};

export default function CalendarPage() {
  const business = useCurrentBusiness();
  const [month, setMonth] = React.useState(() => {
    const d = new Date();
    return new Date(d.getFullYear(), d.getMonth(), 1);
  });
  const grid = monthGrid(month);
  const from = isoDay(grid[0]);
  const to = isoDay(grid[grid.length - 1]);
  const availability = useAvailability(business, from, to);
  const bookings = useBookings(business);
  const [editDay, setEditDay] = React.useState<string | null>(null);
  const [rangeOpen, setRangeOpen] = React.useState(false);
  const today = isoDay(new Date());
  const units = unitWord(business.type);

  const rows = new Map((availability.data ?? []).map((r) => [r.day, r]));
  const online = (day: string) =>
    (bookings.data ?? []).filter(
      (b) => ACTIVE.has(b.status ?? "") && b.check_in && b.check_out && b.check_in <= day && b.check_out > day,
    ).length;

  function stateOf(day: string, row?: DayRow): DayState {
    if (day < today) return "past";
    if (!row) return "open";
    if (row.is_closed) return "closed";
    const used = row.booked + online(day);
    if (used >= row.capacity) return "full";
    if (row.capacity > 0 && used / row.capacity >= 0.7) return "busy";
    return "free";
  }

  // A new day starts from the limit this business uses most.
  const usual = (() => {
    const counts = new Map<number, number>();
    for (const r of availability.data ?? []) {
      if (!r.is_closed && r.capacity > 0) counts.set(r.capacity, (counts.get(r.capacity) ?? 0) + 1);
    }
    let best: number | null = null;
    for (const [cap, n] of counts) if (best === null || n > (counts.get(best) ?? 0)) best = cap;
    return best ?? 5;
  })();

  const title = month.toLocaleDateString("en-GB", { month: "long", year: "numeric" });

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center gap-2">
        <div className="flex items-center gap-1">
          <Button variant="outline" size="icon" aria-label="Previous month"
                  onClick={() => setMonth(new Date(month.getFullYear(), month.getMonth() - 1, 1))}>
            <ChevronLeft />
          </Button>
          <Button variant="outline" size="icon" aria-label="Next month"
                  onClick={() => setMonth(new Date(month.getFullYear(), month.getMonth() + 1, 1))}>
            <ChevronRight />
          </Button>
        </div>
        <h2 className="min-w-[10rem] text-xl font-extrabold">{title}</h2>
        <Button variant="ghost" size="sm" onClick={() => {
          const d = new Date();
          setMonth(new Date(d.getFullYear(), d.getMonth(), 1));
        }}>
          Today
        </Button>
        <div className="flex-1" />
        <Button onClick={() => setRangeOpen(true)}>
          <CalendarRange /> Set many days
        </Button>
      </div>

      <div className="flex flex-wrap gap-x-4 gap-y-1 text-xs text-muted-foreground">
        {(
          [
            ["open", "Open (no limit set)"],
            ["free", `${units[0].toUpperCase()}${units.slice(1)} free`],
            ["busy", "Almost full"],
            ["full", "Full"],
            ["closed", "Closed"],
          ] as const
        ).map(([s, label]) => (
          <span key={s} className="flex items-center gap-1.5">
            <span className={cn("h-3 w-3 rounded border", STATE_STYLE[s])} /> {label}
          </span>
        ))}
      </div>

      <div className="overflow-hidden rounded-xl border bg-card">
        <div className="grid grid-cols-7 border-b bg-muted/40 text-center text-xs font-semibold text-muted-foreground">
          {WEEKDAYS.map((d) => (
            <div key={d} className="py-2">{d}</div>
          ))}
        </div>
        <div className="grid grid-cols-7 gap-px bg-border">
          {grid.map((d) => {
            const day = isoDay(d);
            const row = rows.get(day);
            const state = stateOf(day, row);
            const inMonth = d.getMonth() === month.getMonth();
            const booked = online(day);
            const used = (row?.booked ?? 0) + booked;
            return (
              <button
                key={day}
                type="button"
                disabled={state === "past"}
                onClick={() => setEditDay(day)}
                aria-label={`${d.toLocaleDateString("en-GB", { weekday: "long", day: "numeric", month: "long" })}: ${
                  state === "closed" ? "closed" : row ? `${used} of ${row.capacity} booked` : booked ? `${booked} booked, no limit` : "open"
                }`}
                className={cn(
                  "relative flex min-h-[84px] flex-col items-start gap-1 border border-transparent p-1.5 text-left text-xs transition-colors sm:min-h-[96px] sm:p-2",
                  STATE_STYLE[state],
                  state !== "past" && "hover:ring-2 hover:ring-gold hover:ring-inset",
                  !inMonth && "opacity-45",
                  day === today && "ring-2 ring-inset ring-primary",
                )}
              >
                <span className={cn("text-sm font-bold", day === today && "text-primary")}>{d.getDate()}</span>
                {state === "closed" ? (
                  <span className="flex items-center gap-1 font-semibold text-destructive">
                    <Lock className="h-3 w-3" /> <span className="hidden sm:inline">Closed</span>
                  </span>
                ) : row && state !== "past" ? (
                  <>
                    <span className="font-semibold">
                      {used}/{row.capacity} <span className="hidden font-normal sm:inline">booked</span>
                    </span>
                    <span className="mt-auto h-1.5 w-full overflow-hidden rounded-full bg-black/10">
                      <span
                        className={cn(
                          "block h-full rounded-full",
                          state === "full" ? "bg-destructive" : state === "busy" ? "bg-warning" : "bg-success",
                        )}
                        style={{ width: `${row.capacity ? Math.min(100, (used / row.capacity) * 100) : 100}%` }}
                      />
                    </span>
                  </>
                ) : booked > 0 ? (
                  <span className="font-semibold">
                    {booked} <span className="hidden sm:inline">booked</span>
                  </span>
                ) : null}
                {row?.note && <StickyNote className="absolute right-1.5 top-1.5 h-3 w-3 text-muted-foreground" />}
              </button>
            );
          })}
        </div>
      </div>

      <p className="text-sm text-muted-foreground">
        Tap a day to set how many {units} you sell, or close it. Tourists cannot book a closed or
        full day in the Visit Gondar app. Days you never set stay open.
      </p>

      {editDay && (
        <DayDialog
          business={business}
          day={editDay}
          row={rows.get(editDay)}
          online={online(editDay)}
          usual={usual}
          onClose={() => setEditDay(null)}
        />
      )}
      {rangeOpen && <RangeDialog business={business} onClose={() => setRangeOpen(false)} />}
    </div>
  );
}

function SettingsFields({
  business,
  capacity,
  setCapacity,
  booked,
  setBooked,
  closed,
  setClosed,
  note,
  setNote,
  showBooked = true,
}: {
  business: Business;
  capacity: string;
  setCapacity: (v: string) => void;
  booked: string;
  setBooked: (v: string) => void;
  closed: boolean;
  setClosed: (v: boolean) => void;
  note: string;
  setNote: (v: string) => void;
  showBooked?: boolean;
}) {
  const units = unitWord(business.type);
  return (
    <div className="space-y-4">
      <label className="flex cursor-pointer items-center justify-between gap-3 rounded-lg border p-3">
        <span>
          <span className="block font-semibold">Closed</span>
          <span className="text-xs text-muted-foreground">
            Nobody can book {showBooked ? "this day" : "these days"}. Bookings you already have stay.
          </span>
        </span>
        <input
          type="checkbox"
          className="h-5 w-5 accent-[hsl(var(--destructive))]"
          checked={closed}
          onChange={(e) => setClosed(e.target.checked)}
        />
      </label>
      {!closed && (
        <div className="grid grid-cols-2 gap-3">
          <Field label={`${units[0].toUpperCase()}${units.slice(1)} for sale`} hint="Your limit per day">
            <Input inputMode="numeric" value={capacity} onChange={(e) => setCapacity(e.target.value.replace(/\D/g, ""))} />
          </Field>
          {showBooked && (
            <Field label="Sold elsewhere" hint="Walk-ins, phone">
              <Input inputMode="numeric" value={booked} onChange={(e) => setBooked(e.target.value.replace(/\D/g, ""))} />
            </Field>
          )}
        </div>
      )}
      <Field label="Note for yourself (optional)">
        <Textarea rows={2} placeholder="e.g. Timket — group from Addis" value={note} onChange={(e) => setNote(e.target.value)} />
      </Field>
    </div>
  );
}

function DayDialog({
  business,
  day,
  row,
  online,
  usual,
  onClose,
}: {
  business: Business;
  day: string;
  row?: DayRow;
  online: number;
  usual: number;
  onClose: () => void;
}) {
  const save = useSaveDays(business);
  const clear = useClearDay();
  const [capacity, setCapacity] = React.useState(String(row?.capacity ?? Math.max(online + 1, usual)));
  const [booked, setBooked] = React.useState(String(row?.booked ?? 0));
  const [closed, setClosed] = React.useState(row?.is_closed ?? false);
  const [note, setNote] = React.useState(row?.note ?? "");
  const cap = Number(capacity || 0);
  const used = Number(booked || 0) + online;

  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="max-w-md">
        <DialogHeader>
          <DialogTitle>
            {parseDay(day).toLocaleDateString("en-GB", { weekday: "long", day: "numeric", month: "long" })}
          </DialogTitle>
          <DialogDescription>
            {online === 0
              ? "No bookings from the app on this day yet."
              : `${online} booking${online === 1 ? "" : "s"} from the Visit Gondar app on this day.`}
          </DialogDescription>
        </DialogHeader>
        <SettingsFields
          business={business}
          capacity={capacity}
          setCapacity={setCapacity}
          booked={booked}
          setBooked={setBooked}
          closed={closed}
          setClosed={setClosed}
          note={note}
          setNote={setNote}
        />
        {!closed && (
          <p className={cn("text-sm font-medium", used >= cap ? "text-destructive" : "text-success")}>
            {used >= cap
              ? `Full — new bookings for this day will be refused.`
              : `${cap - used} ${unitWord(business.type, cap - used)} still free for app bookings.`}
          </p>
        )}
        <DialogFooter className="gap-2 sm:justify-between">
          {row ? (
            <Button variant="ghost" className="text-destructive" disabled={clear.isPending}
                    onClick={() => clear.mutate(row.id, { onSuccess: onClose })}>
              Remove limit
            </Button>
          ) : (
            <span />
          )}
          <div className="flex gap-2">
            <Button variant="outline" onClick={onClose}>Cancel</Button>
            <Button
              disabled={save.isPending || (!closed && capacity === "")}
              onClick={() =>
                save.mutate(
                  {
                    days: [day],
                    settings: { capacity: cap, booked: Number(booked || 0), is_closed: closed, note: note.trim() || null },
                  },
                  { onSuccess: onClose },
                )
              }
            >
              {save.isPending ? "Saving…" : closed ? "Save" : `Save (${cap} ${unitWord(business.type, cap)})`}
            </Button>
          </div>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

function RangeDialog({ business, onClose }: { business: Business; onClose: () => void }) {
  const save = useSaveDays(business);
  const today = isoDay(new Date());
  const [from, setFrom] = React.useState(today);
  const [to, setTo] = React.useState(isoDay(addDays(new Date(), 6)));
  const [capacity, setCapacity] = React.useState("5");
  const [closed, setClosed] = React.useState(false);
  const [note, setNote] = React.useState("");
  const [booked, setBooked] = React.useState("0");

  const days: string[] = [];
  if (from && to && from <= to) {
    for (let d = parseDay(from); isoDay(d) <= to && days.length < 366; d = addDays(d, 1)) days.push(isoDay(d));
  }
  const error =
    !from || !to ? "Pick both dates" : from < today ? "Start today or later" : from > to ? "The end is before the start" : null;

  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="max-w-md">
        <DialogHeader>
          <DialogTitle>Set many days</DialogTitle>
          <DialogDescription>
            Same limit for every day in the range — for example your normal number of{" "}
            {unitWord(business.type)}, or close a holiday.
          </DialogDescription>
        </DialogHeader>
        <div className="grid grid-cols-2 gap-3">
          <Field label="From">
            <Input type="date" min={today} value={from} onChange={(e) => setFrom(e.target.value)} />
          </Field>
          <Field label="To (included)">
            <Input type="date" min={from || today} value={to} onChange={(e) => setTo(e.target.value)} />
          </Field>
        </div>
        <SettingsFields
          business={business}
          capacity={capacity}
          setCapacity={setCapacity}
          booked={booked}
          setBooked={setBooked}
          closed={closed}
          setClosed={setClosed}
          note={note}
          setNote={setNote}
          showBooked={false}
        />
        {error && <p className="text-sm text-destructive">{error}</p>}
        <DialogFooter>
          <Button variant="outline" onClick={onClose}>Cancel</Button>
          <Button
            disabled={!!error || save.isPending || (!closed && capacity === "")}
            onClick={() =>
              save.mutate(
                {
                  days,
                  settings: { capacity: Number(capacity || 0), is_closed: closed, note: note.trim() || null },
                },
                { onSuccess: onClose },
              )
            }
          >
            {save.isPending ? "Saving…" : `Save ${days.length} day${days.length === 1 ? "" : "s"}`}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
