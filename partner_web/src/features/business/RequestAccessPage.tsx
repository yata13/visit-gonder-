import * as React from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import { Clock3, Hotel, Link2, LogOut, Send, UserRound, XCircle } from "lucide-react";
import { supabase } from "@/lib/supabase";
import { cn, errorMessage, timeAgo } from "@/lib/utils";
import { useAuth } from "@/features/auth/AuthProvider";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Badge } from "@/components/ui/badge";
import { Field } from "@/components/form-fields";
import type { BusinessType } from "./BusinessProvider";

/**
 * A signed-in partner whose account is not linked to a hotel or guide
 * yet. They tell the office which business is theirs; the office links
 * it in the admin site and this page turns into the dashboard by itself.
 */
export default function RequestAccessPage() {
  const { session, signOut } = useAuth();
  const queryClient = useQueryClient();
  const uid = session!.user.id;
  const [type, setType] = React.useState<BusinessType>("hotel");
  const [name, setName] = React.useState("");
  const [phone, setPhone] = React.useState("");
  const [message, setMessage] = React.useState("");
  const [errors, setErrors] = React.useState<Record<string, string>>({});

  const requests = useQuery({
    queryKey: ["partner-requests", uid],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("partner_requests")
        .select("*")
        .eq("user_id", uid)
        .order("created_at", { ascending: false });
      if (error) throw error;
      return data ?? [];
    },
  });

  // Live: the office links the account → hotels/guides change → the
  // gate re-checks and opens the dashboard.
  React.useEffect(() => {
    const channel = supabase
      .channel(`partner-access-${uid}`)
      .on("postgres_changes", { event: "*", schema: "public", table: "partner_requests" }, () => {
        void queryClient.invalidateQueries({ queryKey: ["partner-requests"] });
        void queryClient.invalidateQueries({ queryKey: ["my-businesses"] });
      })
      .on("postgres_changes", { event: "*", schema: "public", table: "hotels" }, () =>
        void queryClient.invalidateQueries({ queryKey: ["my-businesses"] }),
      )
      .on("postgres_changes", { event: "*", schema: "public", table: "guides" }, () =>
        void queryClient.invalidateQueries({ queryKey: ["my-businesses"] }),
      )
      .subscribe();
    // Backup check every 20 s in case the live channel drops.
    const timer = window.setInterval(() => {
      void queryClient.invalidateQueries({ queryKey: ["my-businesses"] });
      void queryClient.invalidateQueries({ queryKey: ["partner-requests"] });
    }, 20_000);
    return () => {
      window.clearInterval(timer);
      void supabase.removeChannel(channel);
    };
  }, [uid, queryClient]);

  const send = useMutation({
    mutationFn: async () => {
      const { error } = await supabase.from("partner_requests").insert({
        email: session!.user.email ?? null,
        business_type: type,
        business_name: name.trim(),
        phone: phone.trim() || null,
        message: message.trim() || null,
      });
      if (error) throw error;
    },
    onSuccess: () => {
      toast.success("Sent! The Visit Gondar office will connect your business.");
      setName("");
      setMessage("");
      void queryClient.invalidateQueries({ queryKey: ["partner-requests"] });
    },
    onError: (err) => toast.error(errorMessage(err)),
  });

  function onSubmit(ev: React.FormEvent) {
    ev.preventDefault();
    const e: Record<string, string> = {};
    if (name.trim().length < 2) e.name = `Type the name of your ${type === "hotel" ? "hotel" : "guide service"}`;
    if ((phone.match(/\d/g) ?? []).length < 9) e.phone = "Type a phone number the office can call";
    setErrors(e);
    if (Object.keys(e).length === 0) send.mutate();
  }

  const pending = (requests.data ?? []).some((r) => r.status === "pending");

  return (
    <div className="min-h-dvh">
      <header className="flex items-center gap-3 border-b bg-card px-6 py-4">
        <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-primary">
          <Hotel className="h-[18px] w-[18px] text-gold" />
        </div>
        <div className="leading-tight">
          <div className="text-sm font-extrabold">Visit Gondar</div>
          <div className="text-xs text-muted-foreground">Partners</div>
        </div>
        <div className="flex-1" />
        <span className="hidden text-sm text-muted-foreground sm:block">{session?.user.email}</span>
        <Button variant="ghost" size="sm" onClick={() => void signOut()}>
          <LogOut /> Sign out
        </Button>
      </header>

      <main className="mx-auto grid max-w-5xl gap-8 p-6 md:grid-cols-[1.2fr_1fr] md:p-10">
        <section className="fade-up">
          <h1 className="text-3xl font-extrabold">Connect your business</h1>
          <p className="mt-2 text-muted-foreground">
            Tell us which hotel or tour guide service is yours. The Visit Gondar office checks it
            and connects it to this account — usually within a day. This page opens your
            dashboard by itself as soon as it is done.
          </p>

          <form onSubmit={onSubmit} className="mt-8 space-y-5 rounded-xl border bg-card p-6" noValidate>
            <div className="grid grid-cols-2 gap-3">
              {(
                [
                  { value: "hotel", label: "Hotel", icon: Hotel },
                  { value: "guide", label: "Tour guide", icon: UserRound },
                ] as const
              ).map(({ value, label, icon: Icon }) => (
                <button
                  key={value}
                  type="button"
                  onClick={() => setType(value)}
                  aria-pressed={type === value}
                  className={cn(
                    "flex flex-col items-center gap-2 rounded-xl border-2 p-4 font-bold transition-all",
                    type === value
                      ? "border-primary bg-primary text-primary-foreground shadow-md"
                      : "border-border bg-background hover:border-gold",
                  )}
                >
                  <Icon className={cn("h-7 w-7", type === value ? "text-gold" : "text-primary")} />
                  {label}
                </button>
              ))}
            </div>
            <Field
              label={type === "hotel" ? "Hotel name" : "Your name as a guide"}
              htmlFor="bname"
              error={errors.name}
            >
              <Input
                id="bname"
                placeholder={type === "hotel" ? "e.g. Goha Hotel" : "e.g. Abebe Tours"}
                value={name}
                onChange={(e) => setName(e.target.value)}
              />
            </Field>
            <Field label="Phone" htmlFor="phone" error={errors.phone} hint="The office may call you to check.">
              <Input id="phone" type="tel" placeholder="+251 9…" value={phone} onChange={(e) => setPhone(e.target.value)} />
            </Field>
            <Field label="Anything else? (optional)" htmlFor="msg">
              <Textarea
                id="msg"
                rows={3}
                placeholder="e.g. I am the manager. Our trade licence number is …"
                value={message}
                onChange={(e) => setMessage(e.target.value)}
              />
            </Field>
            <Button type="submit" className="h-10 w-full" disabled={send.isPending}>
              <Send /> {send.isPending ? "Sending…" : "Send to the Visit Gondar office"}
            </Button>
          </form>
        </section>

        <aside className="space-y-4 fade-up" style={{ animationDelay: "120ms" }}>
          <h2 className="text-lg font-bold">Your requests</h2>
          {(requests.data ?? []).length === 0 ? (
            <p className="rounded-xl border border-dashed p-6 text-sm text-muted-foreground">
              Nothing sent yet.
            </p>
          ) : (
            <ul className="space-y-3">
              {(requests.data ?? []).map((r) => (
                <li key={r.id} className="rounded-xl border bg-card p-4">
                  <div className="flex items-center gap-2">
                    {r.business_type === "hotel" ? (
                      <Hotel className="h-4 w-4 text-primary" />
                    ) : (
                      <UserRound className="h-4 w-4 text-primary" />
                    )}
                    <span className="font-semibold">{r.business_name}</span>
                    <span className="ml-auto text-xs text-muted-foreground">{timeAgo(r.created_at)}</span>
                  </div>
                  <div className="mt-3">
                    {r.status === "pending" && (
                      <Badge variant="warning" className="gap-1">
                        <Clock3 className="h-3 w-3" /> Waiting for the office
                      </Badge>
                    )}
                    {r.status === "linked" && (
                      <Badge variant="success" className="gap-1">
                        <Link2 className="h-3 w-3" /> Connected
                      </Badge>
                    )}
                    {r.status === "rejected" && (
                      <Badge variant="destructive" className="gap-1">
                        <XCircle className="h-3 w-3" /> Not approved — call the office
                      </Badge>
                    )}
                  </div>
                </li>
              ))}
            </ul>
          )}
          {pending && (
            <p className="flex items-center gap-2 text-sm text-muted-foreground">
              <span className="live-dot inline-block h-2 w-2 rounded-full bg-success" />
              Waiting live — no need to refresh.
            </p>
          )}
        </aside>
      </main>
    </div>
  );
}
