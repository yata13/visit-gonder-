import * as React from "react";
import { FunctionsHttpError } from "@supabase/supabase-js";
import { BarChart3, Loader2, Send } from "lucide-react";
import { supabase } from "@/lib/supabase";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";

/* "Ask the City" (proposal page 7): the team asks its own numbers in
   plain words — "How many guests came on Saturday?" — and the AI
   answers from dashboard data and drafts notices in Amharic + English.
   Runs through the ask-gondar edge function (mode "city"). */

type Turn = { role: "user" | "assistant"; content: string };

const EXAMPLES = [
  "How many bookings did we get this week?",
  "Which hotel or guide is booked the most?",
  "Draft a road notice for Timket in Amharic and English.",
];

const ERRORS: Record<string, string> = {
  team_only: "Only team members can use Ask the City.",
  daily_limit: "Today's question limit is reached. Try again tomorrow.",
  sign_in_required: "Please sign in again.",
};

export function AskTheCity() {
  const [turns, setTurns] = React.useState<Turn[]>([]);
  const [input, setInput] = React.useState("");
  const [loading, setLoading] = React.useState(false);

  async function ask(text: string) {
    const question = text.trim();
    if (!question || loading) return;
    const next: Turn[] = [...turns, { role: "user", content: question }];
    setTurns(next);
    setInput("");
    setLoading(true);
    let answer: string;
    try {
      const { data, error } = await supabase.functions.invoke("ask-gondar", {
        body: { mode: "city", lang: "en", messages: next },
      });
      if (error) {
        let code = "";
        if (error instanceof FunctionsHttpError) {
          code = (await error.context.json().catch(() => ({})))?.error ?? "";
        }
        answer = ERRORS[code] ?? "The AI is not available right now. Please try again.";
      } else {
        answer = String(data?.answer ?? "");
      }
    } catch {
      answer = "The AI is not available right now. Please try again.";
    }
    setTurns([...next, { role: "assistant", content: answer }]);
    setLoading(false);
  }

  return (
    <div className="flex flex-col rounded-xl border bg-card p-4">
      <h3 className="mb-1 flex items-center gap-2 text-sm font-bold">
        <BarChart3 className="h-4 w-4 text-primary" /> Ask the City
      </h3>
      <p className="mb-3 text-xs text-muted-foreground">
        Ask your own numbers in plain words. Answers come only from dashboard data.
      </p>

      <div className="mb-3 max-h-72 min-h-24 space-y-2 overflow-y-auto">
        {turns.length === 0 && (
          <div className="flex flex-wrap gap-2">
            {EXAMPLES.map((e) => (
              <button
                key={e}
                type="button"
                onClick={() => void ask(e)}
                className="rounded-full border px-3 py-1 text-left text-xs hover:bg-muted"
              >
                {e}
              </button>
            ))}
          </div>
        )}
        {turns.map((t, i) => (
          <div
            key={i}
            className={
              t.role === "user"
                ? "ml-auto w-fit max-w-[85%] rounded-lg bg-primary px-3 py-2 text-sm text-primary-foreground"
                : "w-fit max-w-[95%] whitespace-pre-wrap rounded-lg border bg-muted/40 px-3 py-2 text-sm"
            }
          >
            {t.content}
          </div>
        ))}
        {loading && (
          <div className="flex items-center gap-2 text-sm text-muted-foreground">
            <Loader2 className="h-4 w-4 animate-spin" /> Thinking…
          </div>
        )}
      </div>

      <form
        className="mt-auto flex gap-2"
        onSubmit={(e) => {
          e.preventDefault();
          void ask(input);
        }}
      >
        <Textarea
          value={input}
          onChange={(e) => setInput(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter" && !e.shiftKey) {
              e.preventDefault();
              void ask(input);
            }
          }}
          placeholder="How many guests came on Saturday?"
          rows={1}
          className="min-h-10 resize-none"
        />
        <Button type="submit" size="icon" disabled={loading || !input.trim()}>
          <Send className="h-4 w-4" />
          <span className="sr-only">Ask</span>
        </Button>
      </form>
    </div>
  );
}
