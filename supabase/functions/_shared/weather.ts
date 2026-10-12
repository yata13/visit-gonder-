// Live Gondar weather from Open-Meteo (free, no API key).
// Same source the tourist app and the admin dashboard use.

export const GONDAR = { lat: 12.6030, lng: 37.4521 };

const URL =
  `https://api.open-meteo.com/v1/forecast?latitude=${GONDAR.lat}` +
  `&longitude=${GONDAR.lng}` +
  "&current=temperature_2m,weather_code" +
  "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max" +
  "&timezone=Africa%2FAddis_Ababa&forecast_days=7";

// WMO weather codes → plain words.
export function describeWeather(code: number): string {
  if (code === 0) return "clear";
  if (code <= 2) return "partly cloudy";
  if (code === 3) return "cloudy";
  if (code <= 48) return "fog";
  if (code <= 57) return "drizzle";
  if (code <= 67) return "rain";
  if (code <= 77) return "snow";
  if (code <= 82) return "rain showers";
  return "thunderstorm";
}

/** 7-day forecast as short text lines for the AI, or "" if unavailable. */
export async function weatherSummary(): Promise<string> {
  try {
    const res = await fetch(URL, { signal: AbortSignal.timeout(5000) });
    if (!res.ok) return "";
    const w = await res.json();
    const d = w.daily;
    const lines = [
      `Now: ${Math.round(w.current.temperature_2m)}°C, ${describeWeather(w.current.weather_code)}.`,
    ];
    for (let i = 0; i < d.time.length; i++) {
      lines.push(
        `${d.time[i]}: ${describeWeather(d.weather_code[i])}, ` +
          `${Math.round(d.temperature_2m_min[i])}–${Math.round(d.temperature_2m_max[i])}°C, ` +
          `rain chance ${d.precipitation_probability_max[i] ?? 0}%`,
      );
    }
    return lines.join("\n");
  } catch {
    return "";
  }
}
