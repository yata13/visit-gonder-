// ============================================================
//  ask-gondar — the AI guide from the proposal (page 7)
//
//  mode "visitor"  Ask Gondar. Premium visitors chat in Amharic or
//                  English. Answers ONLY from City-approved data
//                  (ai_knowledge + published sites/events/news +
//                  safety notices + live weather). Never guesses:
//                  if unsure it says so and gives the Safety Desk.
//  mode "city"     Ask the City. Team members (admin/editor/staff)
//                  ask about their own numbers in plain words and
//                  get answers / draft notices from dashboard data.
//
//  Uses Google's Gemini (the free-of-charge tier works fine here —
//  this chat does not need a paid model).
//
//  Deploy:   supabase functions deploy ask-gondar
//  Secrets:  supabase secrets set GEMINI_API_KEY=AI...
//            Get a free key at https://aistudio.google.com/apikey
//            (no credit card needed for the free tier).
//            GEMINI_MODEL is optional if Google ever renames the
//            free model (default: gemini-2.5-flash).
//            SAFETY_DESK_PHONE is optional, defaults to 991.
//  SUPABASE_URL / SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY are
//  provided by Supabase automatically.
// ============================================================
import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";
import { weatherSummary } from "../_shared/weather.ts";

const GEMINI_MODEL = Deno.env.get("GEMINI_MODEL") || "gemini-2.5-flash";
const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") ?? "";
const DAILY_LIMIT = { visitor: 50, city: 200 } as const;
const MAX_TURNS = 12;
const MAX_CHARS = 2000;
const SAFETY_DESK = Deno.env.get("SAFETY_DESK_PHONE") ?? "991";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

type Mode = "visitor" | "city";
type Turn = { role: "user" | "assistant"; content: string };

const VISITOR_RULES = `You are "Ask Gondar", the official visitor guide of the City of Gondar, Ethiopia.

Rules:
- Answer ONLY from the CITY DATA below. It is the information the City has approved.
- Only help with Gondar and the Amhara region. For any other topic, say politely that you can only help with Gondar.
- Never guess. If the answer is not in the CITY DATA, say you are not sure and give the City Safety Desk number ${SAFETY_DESK} (for emergencies the visitor should use the SOS button in the app).
- Reply in the language the visitor writes in (Amharic or English).
- Keep answers short and practical: a few sentences or a short list. Mention times, places and prices exactly as the data gives them.
- You may use the weather forecast to suggest the best time for outdoor or indoor visits.
- Never invent hotels, guides, prices, phone numbers or opening hours.`;

const CITY_RULES = `You are "Ask the City", the assistant for the Gondar City tourism team (the Mayor's office and Bureau staff).

Rules:
- Answer questions about the team's own numbers using ONLY the DASHBOARD DATA below. Say exactly which numbers you used.
- If the data does not contain the answer, say so plainly — do not estimate.
- When asked to draft a public notice, write it in both Amharic and English, short and clear, ready to publish.
- Reply in the language the team member writes in.`;

function clip(s: unknown, n = 600): string {
  const t = String(s ?? "").trim();
  return t.length > n ? t.slice(0, n) + "…" : t;
}

async function rows(
  db: SupabaseClient,
  table: string,
  columns: string,
  opts: { published?: boolean; limit?: number; order?: string } = {},
): Promise<Record<string, unknown>[]> {
  let q = db.from(table).select(columns);
  if (opts.published) q = q.or("publish_status.eq.published,publish_status.is.null");
  if (opts.order) q = q.order(opts.order, { ascending: false });
  q = q.limit(opts.limit ?? 50);
  const { data, error } = await q;
  if (error) return []; // a missing table never breaks the chat
  return (data ?? []) as unknown as Record<string, unknown>[];
}

async function visitorContext(db: SupabaseClient): Promise<string> {
  const [knowledge, sites, events, posts, notices, zones, hotels, guides, weather] =
    await Promise.all([
      rows(db, "ai_knowledge", "title,title_am,body,body_am,category", { published: true, limit: 200 }),
      rows(db, "sites", "name_en,name_am,description,info,location", { published: true }),
      rows(db, "events", "name,date,description,category", { published: true }),
      rows(db, "posts", "title,title_am,body,created_at", { published: true, limit: 10, order: "created_at" }),
      rows(db, "notifications", "title,message,body,type,created_at", { limit: 10, order: "created_at" }),
      rows(db, "danger_zones", "name,description,severity,is_active"),
      rows(db, "hotels", "name_en,location,price,star_ranking,contact", { published: true }),
      rows(db, "guides", "name,specialty,languages,price,license_status", { published: true }),
      weatherSummary(),
    ]);

  const section = (title: string, items: string[]) =>
    items.length ? `## ${title}\n${items.join("\n")}` : "";

  return [
    section("City-approved answers", knowledge.map((k) =>
      `- ${k.title}${k.title_am ? ` / ${k.title_am}` : ""}: ${clip(k.body, 1500)}${k.body_am ? `\n  (አማርኛ) ${clip(k.body_am, 1500)}` : ""}`)),
    section("Historic sites", sites.map((s) =>
      `- ${s.name_en}${s.name_am ? ` / ${s.name_am}` : ""} (${clip(s.location, 80)}): ${clip(s.description)} ${clip(s.info, 300)}`)),
    section("Events", events.map((e) =>
      `- ${e.name} — ${e.date ?? "date TBA"}: ${clip(e.description, 400)}`)),
    section("Official news", posts.map((p) =>
      `- ${clip(p.created_at, 10)} ${p.title}: ${clip(p.body, 400)}`)),
    section("Safety notices", notices.map((n) =>
      `- ${clip(n.created_at, 10)} ${n.title}: ${clip(n.message ?? n.body, 300)}`)),
    section("Areas to avoid (active)", zones.filter((z) => z.is_active !== false).map((z) =>
      `- ${z.name} (${z.severity ?? "caution"}): ${clip(z.description, 200)}`)),
    section("City-verified hotels (posted prices)", hotels.map((h) =>
      `- ${h.name_en}, ${h.star_ranking ?? "?"}★, from $${h.price ?? "?"}/night, ${clip(h.location, 80)}`)),
    section("City-verified guides (posted prices)", guides.map((g) =>
      `- ${g.name}: ${clip(g.specialty, 80)}, languages ${clip(g.languages, 80)}, $${g.price ?? "?"}/day, licence ${g.license_status ?? "unknown"}`)),
    section("Weather forecast (Gondar)", weather ? [weather] : []),
  ].filter(Boolean).join("\n\n");
}

async function cityContext(db: SupabaseClient): Promise<string> {
  const since = new Date(Date.now() - 30 * 86400_000).toISOString();
  type Query = ReturnType<ReturnType<SupabaseClient["from"]>["select"]>;
  const count = async (table: string, f?: (q: Query) => Query) => {
    let q = db.from(table).select("*", { count: "exact", head: true });
    if (f) q = f(q);
    const { count, error } = await q;
    return error ? null : count;
  };

  const [bookings, users, premium, sosOpen, sosTotal, checkins, questions, weather] =
    await Promise.all([
      rows(db, "bookings", "created_at,status,item_type,item_name,total_price",
        { limit: 2000, order: "created_at" }),
      count("users"),
      count("user_tiers", (q) => q.eq("tier", "premium")),
      count("emergency_requests", (q) => q.neq("status", "resolved")),
      count("emergency_requests"),
      rows(db, "passport_checkins", "checked_in_at,checkpoint_id", { limit: 5000, order: "checked_in_at" }),
      count("ai_questions", (q) => q.gte("created_at", since)),
      weatherSummary(),
    ]);

  const recent = bookings.filter((b) => String(b.created_at) >= since);
  const perDay = new Map<string, number>();
  const perStatus = new Map<string, number>();
  const perItem = new Map<string, number>();
  for (const b of recent) {
    const day = String(b.created_at).slice(0, 10);
    perDay.set(day, (perDay.get(day) ?? 0) + 1);
    perStatus.set(String(b.status), (perStatus.get(String(b.status)) ?? 0) + 1);
    const item = `${b.item_name ?? "?"} (${b.item_type ?? "?"})`;
    perItem.set(item, (perItem.get(item) ?? 0) + 1);
  }
  const checkinDays = new Map<string, number>();
  for (const c of checkins) {
    const day = String(c.checked_in_at).slice(0, 10);
    if (day >= since.slice(0, 10)) checkinDays.set(day, (checkinDays.get(day) ?? 0) + 1);
  }
  const list = (m: Map<string, number>) =>
    [...m.entries()].sort().map(([k, v]) => `- ${k}: ${v}`).join("\n") || "- none";
  const top = [...perItem.entries()].sort((a, b) => b[1] - a[1]).slice(0, 10)
    .map(([k, v]) => `- ${k}: ${v}`).join("\n") || "- none";

  return `Today is ${new Date().toISOString().slice(0, 10)}. Data covers the last 30 days unless stated.

## Totals (all time)
- Registered users: ${users ?? "unknown"}
- Premium visitors: ${premium ?? "unknown"}
- SOS requests: ${sosTotal ?? "unknown"} (${sosOpen ?? "unknown"} not resolved)
- Bookings (all time, up to 2000 latest): ${bookings.length}
- Ask Gondar questions (30 days): ${questions ?? "unknown"}

## Bookings per day
${list(perDay)}

## Bookings by status
${list(perStatus)}

## Most booked
${top}

## Passport check-ins per day (visits to sites)
${list(checkinDays)}

## Weather forecast (Gondar)
${weather || "unavailable"}`;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const url = Deno.env.get("SUPABASE_URL")!;
  const authHeader = req.headers.get("Authorization") ?? "";
  const asUser = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: authHeader } },
  });
  const service = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  const { data: { user } } = await asUser.auth.getUser();
  if (!user) return json({ error: "sign_in_required" }, 401);

  let body: { messages?: Turn[]; mode?: Mode; lang?: string };
  try {
    body = await req.json();
  } catch {
    return json({ error: "bad_request" }, 400);
  }
  const mode: Mode = body.mode === "city" ? "city" : "visitor";
  const turns = (body.messages ?? [])
    .filter((m) => (m.role === "user" || m.role === "assistant") && typeof m.content === "string" && m.content.trim())
    .slice(-MAX_TURNS)
    .map((m) => ({ role: m.role, content: m.content.slice(0, MAX_CHARS) }));
  // The conversation must start with the visitor and end with a new question.
  while (turns.length && turns[0].role !== "user") turns.shift();
  if (!turns.length || turns[turns.length - 1].role !== "user") {
    return json({ error: "bad_request" }, 400);
  }

  // Access: Ask Gondar is Premium; Ask the City is for the team.
  const gate = await asUser.rpc(mode === "city" ? "is_editor" : "is_premium");
  if (gate.error || gate.data !== true) {
    return json({ error: mode === "city" ? "team_only" : "premium_required" }, 403);
  }

  // Fair-use limit per 24 hours.
  const { count: used } = await service
    .from("ai_questions")
    .select("*", { count: "exact", head: true })
    .eq("user_id", user.id)
    .gte("created_at", new Date(Date.now() - 86400_000).toISOString());
  if ((used ?? 0) >= DAILY_LIMIT[mode]) return json({ error: "daily_limit" }, 429);

  const data = mode === "city" ? await cityContext(service) : await visitorContext(service);
  const today = new Date().toLocaleDateString("en-GB", {
    timeZone: "Africa/Addis_Ababa", weekday: "long", year: "numeric", month: "long", day: "numeric",
  });

  if (!GEMINI_API_KEY) {
    console.error("ask-gondar: GEMINI_API_KEY secret is not set");
    return json({ error: "ai_unavailable" }, 502);
  }

  const systemText = `${mode === "city" ? CITY_RULES : VISITOR_RULES}\n\n` +
    `Today in Gondar: ${today}.\n\n# ${mode === "city" ? "DASHBOARD DATA" : "CITY DATA"}\n\n` +
    `${data || "(no data published yet)"}`;

  let answer: string;
  try {
    const geminiRes = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json", "x-goog-api-key": GEMINI_API_KEY },
        body: JSON.stringify({
          system_instruction: { parts: [{ text: systemText }] },
          contents: turns.map((t) => ({
            role: t.role === "assistant" ? "model" : "user",
            parts: [{ text: t.content }],
          })),
          generationConfig: { maxOutputTokens: 2000, temperature: 0.4 },
        }),
      },
    );
    if (!geminiRes.ok) {
      console.error("ask-gondar: Gemini request failed", geminiRes.status, await geminiRes.text());
      return json({ error: "ai_unavailable" }, 502);
    }
    const payload = await geminiRes.json();
    const blockReason = payload?.promptFeedback?.blockReason;
    const finishReason = payload?.candidates?.[0]?.finishReason;
    if (blockReason || finishReason === "SAFETY" || finishReason === "RECITATION") {
      answer = mode === "city"
        ? "Sorry, I can't help with that request."
        : `Sorry, I can't help with that. For help, call the City Safety Desk: ${SAFETY_DESK}.`;
    } else {
      answer = (payload?.candidates?.[0]?.content?.parts ?? [])
        .map((p: { text?: string }) => p.text ?? "")
        .join("\n")
        .trim();
    }
  } catch (err) {
    console.error("ask-gondar: Gemini request failed", err);
    return json({ error: "ai_unavailable" }, 502);
  }

  await service.from("ai_questions").insert({
    user_id: user.id,
    mode,
    lang: body.lang ?? null,
    question: turns[turns.length - 1].content,
    answer,
  });

  return json({ answer, source: mode === "city" ? "Dashboard data" : "City of Gondar" });
});
