import * as React from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import { ImagePlus, Info, Languages, Loader2, MapPin, Phone, Star, Trash2, X } from "lucide-react";
import { supabase } from "@/lib/supabase";
import { cn, errorMessage, usd } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Badge } from "@/components/ui/badge";
import { Field } from "@/components/form-fields";
import { useCurrentBusiness, type Business } from "@/features/business/BusinessProvider";

const MAX_MB = 5;

/** Uploads a photo into this business's own folder (migration 0021). */
async function uploadPhoto(b: Business, file: File): Promise<string> {
  if (!file.type.startsWith("image/")) throw new Error("Choose a picture (JPG or PNG).");
  if (file.size > MAX_MB * 1024 * 1024) throw new Error(`Pictures must be under ${MAX_MB} MB.`);
  const bucket = b.type === "hotel" ? "hotel-images" : "guide-images";
  const ext = (file.name.split(".").pop() || "jpg").toLowerCase().replace(/[^a-z0-9]/g, "");
  const path = `partners/${b.id}/${Date.now()}-${Math.random().toString(36).slice(2, 8)}.${ext}`;
  const { error } = await supabase.storage.from(bucket).upload(path, file, {
    contentType: file.type,
    upsert: false,
  });
  if (error) throw error;
  return supabase.storage.from(bucket).getPublicUrl(path).data.publicUrl;
}

export default function ListingPage() {
  const business = useCurrentBusiness();
  return business.type === "hotel" ? (
    <HotelForm key={business.id} business={business} />
  ) : (
    <GuideForm key={business.id} business={business} />
  );
}

function OfficeNote({ business }: { business: Business }) {
  return (
    <div className="flex items-start gap-3 rounded-xl border bg-secondary/60 p-4 text-sm">
      <Info className="mt-0.5 h-4 w-4 shrink-0 text-primary" />
      <div>
        <p>
          <b>{business.name}</b> ·{" "}
          {business.published ? "visible in the Visit Gondar app" : "hidden until the office publishes it"}
        </p>
        <p className="mt-1 text-muted-foreground">
          To change the name{business.type === "hotel" ? ", stars" : ", licence"} or to publish, contact the
          Visit Gondar office. Everything else you can change here — the app shows it at once.
        </p>
      </div>
    </div>
  );
}

function PhotoPicker({
  business,
  photos,
  onChange,
  single = false,
}: {
  business: Business;
  photos: string[];
  onChange: (next: string[]) => void;
  single?: boolean;
}) {
  const input = React.useRef<HTMLInputElement>(null);
  const [busy, setBusy] = React.useState(false);

  async function onFiles(files: FileList | null) {
    if (!files?.length) return;
    setBusy(true);
    try {
      const urls: string[] = [];
      for (const f of Array.from(files).slice(0, single ? 1 : 8)) urls.push(await uploadPhoto(business, f));
      onChange(single ? urls.slice(0, 1) : [...photos, ...urls]);
      toast.success(urls.length === 1 ? "Photo added — press Save to show it in the app." : `${urls.length} photos added — press Save.`);
    } catch (err) {
      toast.error(errorMessage(err));
    } finally {
      setBusy(false);
      if (input.current) input.current.value = "";
    }
  }

  return (
    <div className="space-y-2">
      <div className={cn("grid gap-2", single ? "grid-cols-2 sm:grid-cols-3" : "grid-cols-3 sm:grid-cols-4")}>
        {photos.map((url, i) => (
          <div key={url} className="group relative aspect-[4/3] overflow-hidden rounded-lg border bg-muted">
            <img src={url} alt="" className="h-full w-full object-cover" loading="lazy" />
            {i === 0 && !single && (
              <span className="absolute left-1.5 top-1.5 rounded bg-black/60 px-1.5 py-0.5 text-[10px] font-semibold text-white">
                Cover
              </span>
            )}
            <button
              type="button"
              aria-label="Remove photo"
              onClick={() => onChange(photos.filter((p) => p !== url))}
              className="absolute right-1.5 top-1.5 rounded-full bg-black/60 p-1 text-white opacity-90 hover:bg-destructive"
            >
              <Trash2 className="h-3.5 w-3.5" />
            </button>
          </div>
        ))}
        {(!single || photos.length === 0) && (
          <button
            type="button"
            onClick={() => input.current?.click()}
            disabled={busy}
            className="flex aspect-[4/3] flex-col items-center justify-center gap-1 rounded-lg border-2 border-dashed text-sm font-medium text-muted-foreground hover:border-gold hover:text-primary"
          >
            {busy ? <Loader2 className="h-5 w-5 animate-spin" /> : <ImagePlus className="h-5 w-5" />}
            {busy ? "Uploading…" : "Add photo"}
          </button>
        )}
      </div>
      <input
        ref={input}
        type="file"
        accept="image/*"
        multiple={!single}
        className="hidden"
        onChange={(e) => void onFiles(e.target.files)}
      />
      <p className="text-xs text-muted-foreground">
        JPG or PNG, up to {MAX_MB} MB each.{!single && " The first photo is the cover in the app."}
      </p>
    </div>
  );
}

function useSave<T>(fn: () => Promise<T>) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: fn,
    onSuccess: () => {
      toast.success("Saved — the Visit Gondar app shows the changes now.");
      void queryClient.invalidateQueries({ queryKey: ["my-businesses"] });
    },
    onError: (err) => toast.error(errorMessage(err)),
  });
}

function priceError(v: string): string | undefined {
  const n = Number(v);
  return v.trim() === "" || !Number.isFinite(n) || n <= 0 ? "Enter a price above 0" : undefined;
}

function HotelForm({ business }: { business: Business }) {
  const h = business.hotel!;
  const [description, setDescription] = React.useState(h.description ?? "");
  const [contact, setContact] = React.useState(h.contact ?? "");
  const [location, setLocation] = React.useState(h.location ?? "");
  const [price, setPrice] = React.useState(h.price != null ? String(h.price) : "");
  const [photos, setPhotos] = React.useState<string[]>(h.photos ?? []);
  const [tried, setTried] = React.useState(false);

  const save = useSave(async () => {
    const { error } = await supabase.rpc("partner_update_hotel", {
      p_hotel_id: h.id,
      p_description: description,
      p_contact: contact,
      p_location: location,
      p_price: Number(price),
      p_photos: photos,
    });
    if (error) throw error;
  });
  const err = tried ? priceError(price) : undefined;

  return (
    <div className="grid gap-6 lg:grid-cols-[1fr_340px]">
      <form
        className="space-y-5"
        noValidate
        onSubmit={(e) => {
          e.preventDefault();
          setTried(true);
          if (!priceError(price)) save.mutate();
        }}
      >
        <OfficeNote business={business} />
        <section className="space-y-4 rounded-xl border bg-card p-5">
          <h2 className="font-bold">Photos</h2>
          <PhotoPicker business={business} photos={photos} onChange={setPhotos} />
        </section>
        <section className="space-y-4 rounded-xl border bg-card p-5">
          <h2 className="font-bold">About your hotel</h2>
          <Field label="Description" hint="What makes your hotel special — rooms, view, breakfast, Wi-Fi…">
            <Textarea rows={5} value={description} onChange={(e) => setDescription(e.target.value)} />
          </Field>
          <div className="grid gap-4 sm:grid-cols-2">
            <Field label="Price per night (USD)" error={err}>
              <Input inputMode="decimal" value={price} onChange={(e) => setPrice(e.target.value.replace(/[^\d.]/g, ""))} />
            </Field>
            <Field label="Phone or email for guests">
              <Input value={contact} onChange={(e) => setContact(e.target.value)} placeholder="+251 58 …" />
            </Field>
          </div>
          <Field label="Location" hint="Neighbourhood or landmark, e.g. Near Piassa">
            <Input value={location} onChange={(e) => setLocation(e.target.value)} />
          </Field>
        </section>
        <div className="sticky bottom-0 -mx-1 flex justify-end bg-gradient-to-t from-background via-background to-transparent px-1 pb-1 pt-4">
          <Button type="submit" className="h-10 px-8" disabled={save.isPending}>
            {save.isPending ? "Saving…" : "Save changes"}
          </Button>
        </div>
      </form>

      <aside className="space-y-2 lg:sticky lg:top-20 lg:self-start">
        <p className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">How visitors see it</p>
        <div className="overflow-hidden rounded-2xl border bg-card shadow-sm">
          <div className="aspect-[16/10] bg-muted">
            {photos[0] ? (
              <img src={photos[0]} alt="" className="h-full w-full object-cover" />
            ) : (
              <div className="flex h-full items-center justify-center text-sm text-muted-foreground">No photo yet</div>
            )}
          </div>
          <div className="space-y-2 p-4">
            <div className="flex items-start gap-2">
              <h3 className="flex-1 text-lg font-extrabold leading-tight">{business.name}</h3>
              <span className="flex shrink-0 text-gold">
                {Array.from({ length: h.star_ranking ?? 0 }).map((_, i) => (
                  <Star key={i} className="h-3.5 w-3.5 fill-current" />
                ))}
              </span>
            </div>
            {location && (
              <p className="flex items-center gap-1 text-sm text-muted-foreground">
                <MapPin className="h-3.5 w-3.5" /> {location}
              </p>
            )}
            <p className="line-clamp-3 text-sm text-muted-foreground">{description || "Add a description…"}</p>
            <div className="flex items-baseline justify-between pt-1">
              <span>
                <span className="text-xl font-extrabold text-primary">{price ? usd(Number(price)) : "—"}</span>
                <span className="text-sm text-muted-foreground"> /night</span>
              </span>
              {contact && (
                <span className="flex items-center gap-1 text-xs text-muted-foreground">
                  <Phone className="h-3 w-3" /> {contact}
                </span>
              )}
            </div>
          </div>
        </div>
      </aside>
    </div>
  );
}

function GuideForm({ business }: { business: Business }) {
  const g = business.guide!;
  const [specialty, setSpecialty] = React.useState(g.specialty ?? "");
  const [contact, setContact] = React.useState(g.contact ?? "");
  const [price, setPrice] = React.useState(g.price != null ? String(g.price) : "");
  const [languages, setLanguages] = React.useState<string[]>(g.languages ?? []);
  const [lang, setLang] = React.useState("");
  const [photo, setPhoto] = React.useState<string[]>(g.photo ? [g.photo] : []);
  const [tried, setTried] = React.useState(false);

  const save = useSave(async () => {
    const { error } = await supabase.rpc("partner_update_guide", {
      p_guide_id: g.id,
      p_specialty: specialty,
      p_contact: contact,
      p_price: Number(price),
      p_languages: languages,
      p_photo: photo[0] ?? null,
    });
    if (error) throw error;
  });
  const err = tried ? priceError(price) : undefined;

  function addLang() {
    const v = lang.trim();
    if (v && !languages.some((l) => l.toLowerCase() === v.toLowerCase())) setLanguages([...languages, v]);
    setLang("");
  }

  return (
    <div className="grid gap-6 lg:grid-cols-[1fr_340px]">
      <form
        className="space-y-5"
        noValidate
        onSubmit={(e) => {
          e.preventDefault();
          setTried(true);
          if (!priceError(price)) save.mutate();
        }}
      >
        <OfficeNote business={business} />
        <section className="space-y-4 rounded-xl border bg-card p-5">
          <h2 className="font-bold">Your photo</h2>
          <PhotoPicker business={business} photos={photo} onChange={setPhoto} single />
        </section>
        <section className="space-y-4 rounded-xl border bg-card p-5">
          <h2 className="font-bold">About your tours</h2>
          <Field label="Specialty" hint="e.g. Royal Enclosure & churches, Simien day trips">
            <Input value={specialty} onChange={(e) => setSpecialty(e.target.value)} />
          </Field>
          <div className="grid gap-4 sm:grid-cols-2">
            <Field label="Price per day (USD)" error={err}>
              <Input inputMode="decimal" value={price} onChange={(e) => setPrice(e.target.value.replace(/[^\d.]/g, ""))} />
            </Field>
            <Field label="Phone or email for guests">
              <Input value={contact} onChange={(e) => setContact(e.target.value)} placeholder="+251 9…" />
            </Field>
          </div>
          <Field label="Languages you guide in" hint="Type one and press Enter">
            <div className="flex flex-wrap items-center gap-2 rounded-md border bg-card p-2">
              {languages.map((l) => (
                <Badge key={l} variant="secondary" className="gap-1 py-1">
                  {l}
                  <button type="button" aria-label={`Remove ${l}`} onClick={() => setLanguages(languages.filter((x) => x !== l))}>
                    <X className="h-3 w-3" />
                  </button>
                </Badge>
              ))}
              <input
                value={lang}
                onChange={(e) => setLang(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === "Enter" || e.key === ",") {
                    e.preventDefault();
                    addLang();
                  }
                }}
                onBlur={addLang}
                placeholder={languages.length ? "Add another…" : "English, Amharic…"}
                className="min-w-[8rem] flex-1 bg-transparent text-sm outline-none"
              />
            </div>
          </Field>
        </section>
        <div className="sticky bottom-0 -mx-1 flex justify-end bg-gradient-to-t from-background via-background to-transparent px-1 pb-1 pt-4">
          <Button type="submit" className="h-10 px-8" disabled={save.isPending}>
            {save.isPending ? "Saving…" : "Save changes"}
          </Button>
        </div>
      </form>

      <aside className="space-y-2 lg:sticky lg:top-20 lg:self-start">
        <p className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">How visitors see it</p>
        <div className="rounded-2xl border bg-card p-5 text-center shadow-sm">
          <div className="mx-auto h-24 w-24 overflow-hidden rounded-full border-4 border-secondary bg-muted">
            {photo[0] ? (
              <img src={photo[0]} alt="" className="h-full w-full object-cover" />
            ) : (
              <div className="flex h-full items-center justify-center text-2xl font-extrabold text-primary">
                {g.initials || business.name.charAt(0)}
              </div>
            )}
          </div>
          <h3 className="mt-3 text-lg font-extrabold">{business.name}</h3>
          <p className="text-sm text-muted-foreground">{specialty || "Add your specialty…"}</p>
          {languages.length > 0 && (
            <p className="mt-2 flex items-center justify-center gap-1 text-xs text-muted-foreground">
              <Languages className="h-3.5 w-3.5" /> {languages.join(" · ")}
            </p>
          )}
          <p className="mt-3">
            <span className="text-xl font-extrabold text-primary">{price ? usd(Number(price)) : "—"}</span>
            <span className="text-sm text-muted-foreground"> /day</span>
          </p>
        </div>
      </aside>
    </div>
  );
}
