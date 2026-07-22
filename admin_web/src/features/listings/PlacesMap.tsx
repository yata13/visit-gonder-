import { useQuery } from "@tanstack/react-query";
import L from "leaflet";
import { MapContainer, Marker, TileLayer, Tooltip } from "react-leaflet";
import "leaflet/dist/leaflet.css";
import { supabase } from "@/lib/supabase";
import { Skeleton } from "@/components/ui/skeleton";
import { normalizePublishStatus } from "@/components/publish-badge";

const GONDAR: [number, number] = [12.603, 37.4521];

interface MapPlace {
  id: string;
  name_en: string;
  name_am: string | null;
  category: string | null;
  lat: number | null;
  lng: number | null;
  publish_status: string | null;
}

function pinIcon(published: boolean): L.DivIcon {
  const color = published ? "#FF6D29" : "#B0AAA4";
  return L.divIcon({
    className: "",
    iconSize: [26, 26],
    iconAnchor: [13, 13],
    html: `<div style="width:26px;height:26px;border-radius:50%;background:${color};border:2px solid white;box-shadow:0 1px 6px ${color}99;display:flex;align-items:center;justify-content:center;color:white;font-size:13px;line-height:1">📍</div>`,
  });
}

/** The map above the Map Manager table — every place with coordinates. */
export function PlacesMap() {
  const query = useQuery({
    queryKey: ["listings", "places", "map"],
    queryFn: async (): Promise<MapPlace[]> => {
      const { data, error } = await supabase
        .from("places")
        .select("id, name_en, name_am, category, lat, lng, publish_status")
        .limit(500);
      if (error) throw error;
      return (data ?? []) as MapPlace[];
    },
  });

  if (query.isPending) {
    return <Skeleton className="h-[380px] w-full rounded-xl" />;
  }

  const places = query.data ?? [];
  const withPin = places.filter((p) => p.lat !== null && p.lng !== null);

  return (
    <div className="space-y-1.5">
      <div className="h-[380px] overflow-hidden rounded-xl border">
        <MapContainer center={GONDAR} zoom={13} scrollWheelZoom>
          <TileLayer
            url="https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png"
            attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> &copy; <a href="https://carto.com/">CARTO</a>'
            subdomains={["a", "b", "c", "d"]}
          />
          {withPin.map((p) => {
            const published = normalizePublishStatus(p.publish_status) === "published";
            return (
              <Marker
                key={p.id}
                position={[p.lat!, p.lng!]}
                icon={pinIcon(published)}
              >
                <Tooltip direction="top" offset={[0, -12]}>
                  <b>{p.name_en}</b>
                  {p.name_am ? <> · {p.name_am}</> : null}
                  <br />
                  {p.category ?? "other"}
                  {!published && " · NOT published"}
                </Tooltip>
              </Marker>
            );
          })}
        </MapContainer>
      </div>
      <p className="text-xs text-muted-foreground">
        {withPin.length} of {places.length} places have a map pin (grey pins are
        not published). Add or fix coordinates by editing a place below.
      </p>
    </div>
  );
}
