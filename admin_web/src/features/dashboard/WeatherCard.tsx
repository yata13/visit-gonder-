import { useQuery } from "@tanstack/react-query";
import {
  Cloud,
  CloudDrizzle,
  CloudFog,
  CloudLightning,
  CloudRain,
  CloudSun,
  Snowflake,
  Sun,
  type LucideIcon,
} from "lucide-react";
import { Skeleton } from "@/components/ui/skeleton";

/* Live Gondar weather — today and the next 7 days (proposal page 6:
   "Plan with the weather"). Open-Meteo: free, no API key. The tourist
   app and the Ask Gondar AI use the same forecast. */

const URL =
  "https://api.open-meteo.com/v1/forecast?latitude=12.6030&longitude=37.4521" +
  "&current=temperature_2m,weather_code" +
  "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max" +
  "&timezone=Africa%2FAddis_Ababa&forecast_days=7";

interface Forecast {
  current: { temperature_2m: number; weather_code: number };
  daily: {
    time: string[];
    weather_code: number[];
    temperature_2m_max: number[];
    temperature_2m_min: number[];
    precipitation_probability_max: (number | null)[];
  };
}

function describe(code: number): { label: string; Icon: LucideIcon } {
  if (code === 0) return { label: "Sunny", Icon: Sun };
  if (code <= 2) return { label: "Partly cloudy", Icon: CloudSun };
  if (code === 3) return { label: "Cloudy", Icon: Cloud };
  if (code <= 48) return { label: "Fog", Icon: CloudFog };
  if (code <= 57) return { label: "Drizzle", Icon: CloudDrizzle };
  if (code <= 67 || (code >= 80 && code <= 82)) return { label: "Rain", Icon: CloudRain };
  if (code <= 77) return { label: "Snow", Icon: Snowflake };
  return { label: "Storm", Icon: CloudLightning };
}

async function fetchForecast(): Promise<Forecast> {
  const res = await fetch(URL);
  if (!res.ok) throw new Error(`Weather unavailable (${res.status})`);
  return res.json();
}

export function WeatherCard() {
  const { data, isPending, isError } = useQuery({
    queryKey: ["weather", "gondar"],
    queryFn: fetchForecast,
    staleTime: 30 * 60 * 1000,
  });

  return (
    <div className="rounded-xl border bg-card p-4">
      <h3 className="mb-3 text-sm font-bold">Gondar weather · today + 7 days</h3>
      {isPending && <Skeleton className="h-24 w-full" />}
      {isError && (
        <p className="text-sm text-muted-foreground">Weather is unavailable right now.</p>
      )}
      {data && (
        <>
          {(() => {
            const { label, Icon } = describe(data.current.weather_code);
            return (
              <div className="mb-4 flex items-center gap-3">
                <Icon className="h-9 w-9 text-primary" />
                <div>
                  <div className="text-2xl font-semibold leading-tight">
                    {Math.round(data.current.temperature_2m)}°C
                  </div>
                  <div className="text-sm text-muted-foreground">{label} now</div>
                </div>
              </div>
            );
          })()}
          <div className="grid grid-cols-7 gap-1 text-center">
            {data.daily.time.map((day, i) => {
              const { label, Icon } = describe(data.daily.weather_code[i]);
              const rain = data.daily.precipitation_probability_max[i] ?? 0;
              const name =
                i === 0
                  ? "Today"
                  : new Date(`${day}T12:00:00`).toLocaleDateString("en-GB", {
                      weekday: "short",
                    });
              return (
                <div key={day} className="flex flex-col items-center gap-1" title={label}>
                  <span className={i === 0 ? "text-xs font-bold" : "text-xs text-muted-foreground"}>
                    {name}
                  </span>
                  <Icon className="h-5 w-5 text-primary" />
                  <span className="text-xs font-semibold">
                    {Math.round(data.daily.temperature_2m_max[i])}°
                    <span className="font-normal text-muted-foreground">
                      /{Math.round(data.daily.temperature_2m_min[i])}°
                    </span>
                  </span>
                  {rain >= 30 && <span className="text-[10px] text-[#3D6DA8]">{rain}%</span>}
                </div>
              );
            })}
          </div>
        </>
      )}
    </div>
  );
}
