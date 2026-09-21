pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import qs.Config

/**
 * Current conditions from Open-Meteo (no API key required).
 *
 * If no location is configured, the city is resolved once from the public IP.
 * Both lookups are plain HTTPS GETs via curl; nothing is sent anywhere else.
 */
Singleton {
    id: root

    property string location: ""
    property real temperature: 0
    property real humidity: 0
    property real windSpeed: 0
    property int code: -1
    property bool isDay: true
    property string sunrise: ""
    property string sunset: ""
    property bool loaded: false

    readonly property bool metric: Settings.data.weatherMetric
    readonly property string unit: root.metric ? "C" : "F"
    readonly property string windUnit: root.metric ? "km/h" : "mph"

    property real _lat: NaN
    property real _lon: NaN

    /// WMO weather interpretation codes -> label + glyph.
    function describe(c: int): string {
        if (c === 0) return "Clear Sky";
        if (c <= 2) return "Partly Cloudy";
        if (c === 3) return "Overcast";
        if (c === 45 || c === 48) return "Fog";
        if (c >= 51 && c <= 57) return "Drizzle";
        if (c >= 61 && c <= 67) return "Rain";
        if (c >= 71 && c <= 77) return "Snow";
        if (c >= 80 && c <= 82) return "Showers";
        if (c >= 85 && c <= 86) return "Snow Showers";
        if (c >= 95) return "Thunderstorm";
        return "Unknown";
    }

    readonly property string description: root.describe(root.code)

    readonly property string icon: {
        const c = root.code;
        if (c === 0 || c === 1) return root.isDay ? Icons.sun : Icons.moon;
        if (c <= 3) return Icons.cloud;
        if (c === 45 || c === 48) return Icons.fog;
        if (c >= 51 && c <= 67) return Icons.rain;
        if (c >= 71 && c <= 77) return Icons.snow;
        if (c >= 80 && c <= 86) return Icons.rain;
        if (c >= 95) return Icons.storm;
        return Icons.cloud;
    }

    readonly property string temperatureText:
        `${Math.round(root.temperature)}°${root.unit}`

    function refresh(): void {
        if (isNaN(root._lat)) {
            if (Settings.data.weatherLocation.trim() !== "") geocode.running = true;
            else locate.running = true;
        } else {
            forecast.running = true;
        }
    }

    // ── Resolve a configured place name to coordinates ─────────────────────
    Process {
        id: geocode
        command: ["sh", "-c",
            `curl -sf --max-time 10 "https://geocoding-api.open-meteo.com/v1/search?name=$(printf %s ` +
            `'${Settings.data.weatherLocation}' | sed 's/ /+/g')&count=1&format=json"`]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text)?.results?.[0];
                    if (!r) return;
                    root._lat = r.latitude;
                    root._lon = r.longitude;
                    root.location = r.name;
                    forecast.running = true;
                } catch (e) {
                    console.warn("Weather: geocode failed:", e);
                }
            }
        }
    }

    // ── Fall back to IP-based location ─────────────────────────────────────
    Process {
        id: locate
        // Two providers, because free IP-geolocation endpoints rate-limit and
        // then answer with HTML rather than JSON.
        command: ["sh", "-c",
            `curl -sf --max-time 8 "https://ipapi.co/json/" ` +
            `|| curl -sf --max-time 8 "http://ip-api.com/json/?fields=status,city,lat,lon"`]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text);
                    // ipapi.co uses latitude/longitude; ip-api.com uses lat/lon.
                    const lat = r?.latitude ?? r?.lat;
                    const lon = r?.longitude ?? r?.lon;
                    if (lat === undefined || lon === undefined) {
                        console.warn("Weather: no coordinates in IP lookup response");
                        return;
                    }
                    root._lat = lat;
                    root._lon = lon;
                    root.location = r.city ?? "";
                    forecast.running = true;
                } catch (e) {
                    console.warn("Weather: IP lookup failed:", e);
                }
            }
        }
    }

    // ── Current conditions ─────────────────────────────────────────────────
    Process {
        id: forecast
        command: ["sh", "-c",
            `curl -sf --max-time 10 "https://api.open-meteo.com/v1/forecast` +
            `?latitude=${root._lat}&longitude=${root._lon}` +
            `&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m,is_day` +
            `&daily=sunrise,sunset` +
            `&temperature_unit=${root.metric ? "celsius" : "fahrenheit"}` +
            `&wind_speed_unit=${root.metric ? "kmh" : "mph"}&timezone=auto"`]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text);
                    const c = parsed?.current;
                    const d = parsed?.daily;
                    if (!c) return;
                    root.temperature = c.temperature_2m ?? 0;
                    root.humidity = c.relative_humidity_2m ?? 0;
                    root.windSpeed = c.wind_speed_10m ?? 0;
                    root.code = c.weather_code ?? -1;
                    root.isDay = (c.is_day ?? 1) === 1;
                    if (d && d.sunrise && d.sunrise.length > 0) root.sunrise = d.sunrise[0];
                    if (d && d.sunset && d.sunset.length > 0) root.sunset = d.sunset[0];
                    root.loaded = true;
                } catch (e) {
                    console.warn("Weather: forecast failed:", e);
                }
            }
        }
    }

    // Re-resolve coordinates whenever the configured location changes.
    Connections {
        target: Settings.data
        function onWeatherLocationChanged(): void {
            root._lat = NaN;
            root._lon = NaN;
            root.refresh();
        }
    }

    Timer {
        interval: 900000   // 15 minutes
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
