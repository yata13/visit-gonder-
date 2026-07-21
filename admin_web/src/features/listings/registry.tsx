import { z } from "zod";
import { formatDate } from "@/lib/utils";
import { PublishBadge } from "@/components/publish-badge";
import type { Column } from "@/components/data-table";

/**
 * The listings module is config-driven: one page + one form component
 * serve six content tables. Rows are handled as AnyRow at this layer;
 * the strict Database types still guard the API boundary in api.ts.
 */
export type AnyRow = Record<string, any>;

export type ListingType =
  | "hotels"
  | "guides"
  | "sites"
  | "places"
  | "events"
  | "posts";

export type FieldDef =
  | { kind: "text"; name: string; label: string; hint?: string }
  | { kind: "number"; name: string; label: string; step?: string }
  | { kind: "textarea"; name: string; label: string }
  | {
      kind: "bilingual";
      nameEn: string;
      nameAm: string;
      label: string;
      textarea?: boolean;
    }
  | {
      kind: "select";
      name: string;
      label: string;
      options: { value: string; label: string }[];
    }
  | { kind: "checkbox"; name: string; label: string }
  | { kind: "list"; name: string; label: string; hint?: string }
  | { kind: "latlng" };

export interface ListingConfig {
  table: ListingType;
  title: string;
  singular: string;
  searchColumn: string;
  /** Zod schema over the raw form values (strings/booleans). */
  schema: z.ZodType<any>;
  fields: FieldDef[];
  /** Row from the DB → form values (all strings/booleans). */
  fromRow: (row: AnyRow | undefined) => Record<string, any>;
  /** Validated form values → insert/update payload. */
  toPayload: (values: Record<string, any>) => Record<string, unknown>;
  columns: Column<AnyRow>[];
}

const optionalNumber = (label: string) =>
  z
    .string()
    .refine((v) => v.trim() === "" || !Number.isNaN(Number(v)), {
      message: `${label} must be a number`,
    });

const publishEnum = z.enum(["draft", "pending", "published"]);

const num = (v: string): number | null => (v.trim() === "" ? null : Number(v));
const txt = (v: string): string | null => (v.trim() === "" ? null : v.trim());
const lines = (v: string): string[] | null => {
  const arr = v
    .split("\n")
    .map((s) => s.trim())
    .filter(Boolean);
  return arr.length ? arr : null;
};
const joinLines = (v: unknown): string => (Array.isArray(v) ? v.join("\n") : "");
const s = (v: unknown): string => (v === null || v === undefined ? "" : String(v));

const publishField: FieldDef = {
  kind: "select",
  name: "publish_status",
  label: "Publish status",
  options: [
    { value: "draft", label: "Draft (hidden from the app)" },
    { value: "pending", label: "Pending review" },
    { value: "published", label: "Published (visible to tourists)" },
  ],
};

function nameCell(en: unknown, am: unknown) {
  return (
    <div className="min-w-[160px]">
      <div className="font-medium">{s(en) || "—"}</div>
      {s(am) && <div className="text-xs text-muted-foreground">{s(am)}</div>}
    </div>
  );
}

const statusColumn: Column<AnyRow> = {
  key: "publish_status",
  header: "Status",
  render: (r) => <PublishBadge status={r.publish_status} />,
};

const createdColumn: Column<AnyRow> = {
  key: "created_at",
  header: "Created",
  className: "whitespace-nowrap",
  render: (r) => formatDate(r.created_at),
};

/* ────────────────────────── configs ────────────────────────── */

const hotels: ListingConfig = {
  table: "hotels",
  title: "Hotels",
  singular: "hotel",
  searchColumn: "name_en",
  schema: z.object({
    name_en: z.string().min(1, "English name is required"),
    name_am: z.string(),
    description: z.string(),
    location: z.string(),
    contact: z.string(),
    price: optionalNumber("Price"),
    star_ranking: optionalNumber("Star ranking"),
    lat: optionalNumber("Latitude"),
    lng: optionalNumber("Longitude"),
    photos: z.string(),
    publish_status: publishEnum,
  }),
  fields: [
    { kind: "bilingual", nameEn: "name_en", nameAm: "name_am", label: "Name" },
    { kind: "textarea", name: "description", label: "Description" },
    { kind: "text", name: "location", label: "Location" },
    { kind: "text", name: "contact", label: "Contact (phone)" },
    { kind: "number", name: "price", label: "Price per night (USD)" },
    { kind: "number", name: "star_ranking", label: "Star ranking (1–5)" },
    { kind: "latlng" },
    {
      kind: "list",
      name: "photos",
      label: "Photo URLs",
      hint: "One image URL per line",
    },
    publishField,
  ],
  fromRow: (r) => ({
    name_en: s(r?.name_en),
    name_am: s(r?.name_am),
    description: s(r?.description),
    location: s(r?.location),
    contact: s(r?.contact),
    price: s(r?.price),
    star_ranking: s(r?.star_ranking),
    lat: s(r?.lat),
    lng: s(r?.lng),
    photos: joinLines(r?.photos),
    publish_status: r?.publish_status ?? "draft",
  }),
  toPayload: (v) => ({
    name_en: txt(v.name_en),
    name_am: txt(v.name_am),
    description: txt(v.description),
    location: txt(v.location),
    contact: txt(v.contact),
    price: num(v.price),
    star_ranking: num(v.star_ranking),
    lat: num(v.lat),
    lng: num(v.lng),
    photos: lines(v.photos),
    publish_status: v.publish_status,
  }),
  columns: [
    { key: "name", header: "Name", render: (r) => nameCell(r.name_en, r.name_am) },
    {
      key: "price",
      header: "Price",
      render: (r) => (r.price === null || r.price === undefined ? "—" : `$${r.price}`),
    },
    {
      key: "stars",
      header: "Stars",
      render: (r) => (r.star_ranking ? "★".repeat(Math.min(5, r.star_ranking)) : "—"),
    },
    statusColumn,
    createdColumn,
  ],
};

const guides: ListingConfig = {
  table: "guides",
  title: "Guides",
  singular: "guide",
  searchColumn: "name",
  schema: z.object({
    name: z.string().min(1, "Name is required"),
    specialty: z.string(),
    contact: z.string(),
    price: optionalNumber("Price"),
    license_status: z.string(),
    photo: z.string(),
    languages: z.string(),
    publish_status: publishEnum,
  }),
  fields: [
    { kind: "text", name: "name", label: "Name" },
    { kind: "text", name: "specialty", label: "Specialty" },
    { kind: "text", name: "contact", label: "Contact (phone / WhatsApp)" },
    { kind: "number", name: "price", label: "Price per day (USD)" },
    {
      kind: "text",
      name: "license_status",
      label: "License status",
      hint: "e.g. licensed",
    },
    { kind: "text", name: "photo", label: "Photo URL" },
    {
      kind: "list",
      name: "languages",
      label: "Languages",
      hint: "One language per line, e.g. Amharic (Native)",
    },
    publishField,
  ],
  fromRow: (r) => ({
    name: s(r?.name),
    specialty: s(r?.specialty),
    contact: s(r?.contact),
    price: s(r?.price),
    license_status: s(r?.license_status) || "licensed",
    photo: s(r?.photo),
    languages: joinLines(r?.languages),
    publish_status: r?.publish_status ?? "draft",
  }),
  toPayload: (v) => ({
    name: txt(v.name),
    specialty: txt(v.specialty),
    contact: txt(v.contact),
    price: num(v.price),
    license_status: txt(v.license_status),
    photo: txt(v.photo),
    languages: lines(v.languages),
    publish_status: v.publish_status,
  }),
  columns: [
    { key: "name", header: "Name", render: (r) => nameCell(r.name, null) },
    { key: "specialty", header: "Specialty", render: (r) => s(r.specialty) || "—" },
    {
      key: "price",
      header: "Price/day",
      render: (r) => (r.price === null || r.price === undefined ? "—" : `$${r.price}`),
    },
    { key: "license", header: "License", render: (r) => s(r.license_status) || "—" },
    statusColumn,
    createdColumn,
  ],
};

const sites: ListingConfig = {
  table: "sites",
  title: "Sites",
  singular: "site",
  searchColumn: "name_en",
  schema: z.object({
    name_en: z.string().min(1, "English name is required"),
    name_am: z.string(),
    description: z.string(),
    info: z.string(),
    location: z.string(),
    photo: z.string(),
    lat: optionalNumber("Latitude"),
    lng: optionalNumber("Longitude"),
    publish_status: publishEnum,
  }),
  fields: [
    { kind: "bilingual", nameEn: "name_en", nameAm: "name_am", label: "Name" },
    { kind: "textarea", name: "description", label: "Description" },
    {
      kind: "text",
      name: "info",
      label: "Short info line",
      hint: "e.g. UNESCO World Heritage · Entry 200 ETB",
    },
    { kind: "text", name: "location", label: "Location" },
    { kind: "text", name: "photo", label: "Photo URL" },
    { kind: "latlng" },
    publishField,
  ],
  fromRow: (r) => ({
    name_en: s(r?.name_en),
    name_am: s(r?.name_am),
    description: s(r?.description),
    info: s(r?.info),
    location: s(r?.location),
    photo: s(r?.photo),
    lat: s(r?.lat),
    lng: s(r?.lng),
    publish_status: r?.publish_status ?? "draft",
  }),
  toPayload: (v) => ({
    name_en: txt(v.name_en),
    name_am: txt(v.name_am),
    description: txt(v.description),
    info: txt(v.info),
    location: txt(v.location),
    photo: txt(v.photo),
    lat: num(v.lat),
    lng: num(v.lng),
    publish_status: v.publish_status,
  }),
  columns: [
    { key: "name", header: "Name", render: (r) => nameCell(r.name_en, r.name_am) },
    { key: "location", header: "Location", render: (r) => s(r.location) || "—" },
    statusColumn,
    createdColumn,
  ],
};

const PLACE_CATEGORIES = [
  "hotel",
  "castle",
  "church",
  "museum",
  "store",
  "club",
  "restaurant",
  "other",
];

const places: ListingConfig = {
  table: "places",
  title: "Map Manager",
  singular: "place",
  searchColumn: "name_en",
  schema: z.object({
    name_en: z.string().min(1, "English name is required"),
    name_am: z.string(),
    category: z.string().min(1, "Category is required"),
    photo: z.string(),
    info: z.string(),
    description: z.string(),
    lat: optionalNumber("Latitude"),
    lng: optionalNumber("Longitude"),
    publish_status: publishEnum,
  }),
  fields: [
    { kind: "bilingual", nameEn: "name_en", nameAm: "name_am", label: "Name" },
    {
      kind: "select",
      name: "category",
      label: "Category",
      options: PLACE_CATEGORIES.map((c) => ({ value: c, label: c })),
    },
    { kind: "text", name: "photo", label: "Photo URL" },
    { kind: "text", name: "info", label: "Short info line" },
    { kind: "textarea", name: "description", label: "Description" },
    { kind: "latlng" },
    publishField,
  ],
  fromRow: (r) => ({
    name_en: s(r?.name_en),
    name_am: s(r?.name_am),
    category: s(r?.category) || "other",
    photo: s(r?.photo),
    info: s(r?.info),
    description: s(r?.description),
    lat: s(r?.lat),
    lng: s(r?.lng),
    publish_status: r?.publish_status ?? "draft",
  }),
  toPayload: (v) => ({
    name_en: txt(v.name_en) ?? "",
    name_am: txt(v.name_am),
    category: v.category,
    photo: txt(v.photo),
    info: txt(v.info),
    description: txt(v.description),
    lat: num(v.lat),
    lng: num(v.lng),
    publish_status: v.publish_status,
  }),
  columns: [
    { key: "name", header: "Name", render: (r) => nameCell(r.name_en, r.name_am) },
    { key: "category", header: "Category", render: (r) => s(r.category) || "—" },
    {
      key: "coords",
      header: "Map pin",
      render: (r) =>
        r.lat !== null && r.lat !== undefined && r.lng !== null && r.lng !== undefined
          ? `${Number(r.lat).toFixed(4)}, ${Number(r.lng).toFixed(4)}`
          : "—",
    },
    statusColumn,
    createdColumn,
  ],
};

const events: ListingConfig = {
  table: "events",
  title: "Events",
  singular: "event",
  searchColumn: "name",
  schema: z.object({
    name: z.string().min(1, "Event name is required"),
    date: z.string(),
    description: z.string(),
    photo: z.string(),
    category: z.string(),
    includes_timket: z.boolean(),
    publish_status: publishEnum,
  }),
  fields: [
    { kind: "text", name: "name", label: "Event name" },
    {
      kind: "text",
      name: "date",
      label: "Date",
      hint: "Free text, e.g. 19 January 2027",
    },
    { kind: "textarea", name: "description", label: "Description" },
    { kind: "text", name: "photo", label: "Photo URL" },
    {
      kind: "text",
      name: "category",
      label: "Category",
      hint: "e.g. Religious Festival",
    },
    { kind: "checkbox", name: "includes_timket", label: "Part of Timket festival" },
    publishField,
  ],
  fromRow: (r) => ({
    name: s(r?.name),
    date: s(r?.date),
    description: s(r?.description),
    photo: s(r?.photo),
    category: s(r?.category) || "Religious Festival",
    includes_timket: Boolean(r?.includes_timket),
    publish_status: r?.publish_status ?? "draft",
  }),
  toPayload: (v) => ({
    name: txt(v.name),
    date: txt(v.date),
    description: txt(v.description),
    photo: txt(v.photo),
    category: txt(v.category),
    includes_timket: Boolean(v.includes_timket),
    publish_status: v.publish_status,
  }),
  columns: [
    { key: "name", header: "Name", render: (r) => nameCell(r.name, null) },
    { key: "date", header: "Date", render: (r) => s(r.date) || "—" },
    { key: "category", header: "Category", render: (r) => s(r.category) || "—" },
    {
      key: "timket",
      header: "Timket",
      render: (r) => (r.includes_timket ? "Yes" : "—"),
    },
    statusColumn,
    createdColumn,
  ],
};

const posts: ListingConfig = {
  table: "posts",
  title: "News Feed",
  singular: "post",
  searchColumn: "title",
  schema: z.object({
    title: z.string().min(1, "English title is required"),
    title_am: z.string(),
    body: z.string(),
    body_am: z.string(),
    photo: z.string(),
    category: z.string(),
    publish_status: publishEnum,
  }),
  fields: [
    { kind: "bilingual", nameEn: "title", nameAm: "title_am", label: "Title" },
    {
      kind: "bilingual",
      nameEn: "body",
      nameAm: "body_am",
      label: "Body",
      textarea: true,
    },
    { kind: "text", name: "photo", label: "Photo URL" },
    { kind: "text", name: "category", label: "Category", hint: "e.g. news" },
    publishField,
  ],
  fromRow: (r) => ({
    title: s(r?.title),
    title_am: s(r?.title_am),
    body: s(r?.body),
    body_am: s(r?.body_am),
    photo: s(r?.photo),
    category: s(r?.category) || "news",
    publish_status: r?.publish_status ?? "draft",
  }),
  toPayload: (v) => ({
    title: txt(v.title) ?? "",
    title_am: txt(v.title_am),
    body: txt(v.body),
    body_am: txt(v.body_am),
    photo: txt(v.photo),
    category: txt(v.category),
    publish_status: v.publish_status,
  }),
  columns: [
    { key: "title", header: "Title", render: (r) => nameCell(r.title, r.title_am) },
    { key: "category", header: "Category", render: (r) => s(r.category) || "—" },
    statusColumn,
    createdColumn,
  ],
};

export const LISTINGS: Record<ListingType, ListingConfig> = {
  hotels,
  guides,
  sites,
  places,
  events,
  posts,
};

export function isListingType(value: string | undefined): value is ListingType {
  return !!value && value in LISTINGS;
}
