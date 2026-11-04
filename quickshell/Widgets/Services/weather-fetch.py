#!/usr/bin/env python3
"""weather-fetch.py — location + Open-Meteo forecast for the Weather card.

Prints ONE JSON object on stdout:
  {"location": {"lat", "lon", "name", "source"}, "forecast": <open-meteo json>, "fetched": <epoch>, "stale": bool}
or  {"error": "<reason>", "location": {...}}  when nothing (not even the cache) is available.

Location order (BRIEF §0):
  1. ~/.config/overworld/config.json → weather.lat / weather.lon (/ weather.name)
  2. IP geolocation: https://ipapi.co/json/  then  http://ip-api.com/json/
     The geolocated time-zone must match the machine's time-zone (/etc/localtime); when it does not
     (VPN exit node abroad) the result is discarded and the fallback is used, so the card shows the
     weather where the user physically is instead of where the VPN leaves the internet.
  3. Kowloon, Hong Kong 22.3167, 114.1833.

Cache: ~/.cache/overworld/weather.json (served with "stale": true when the network is down).
Summary for other modules (fx-world): ~/.cache/overworld/weather-now.json, rewritten after every successful or cached
read: {"kind": "clear|cloudy|fog|rain|thunder|snow", "code": <WMO>, "is_day": bool, "temp": °C, "precip_mm": mm,
"wind": km/h, "city": str, "stale": bool, "updated": epoch}.
"""
import json
import os
import sys
import time
import urllib.request

HOME = os.path.expanduser("~")
CONFIG = os.path.join(HOME, ".config", "overworld", "config.json")
CACHE_DIR = os.path.join(HOME, ".cache", "overworld")
CACHE = os.path.join(CACHE_DIR, "weather.json")
NOW = os.path.join(CACHE_DIR, "weather-now.json")
FALLBACK = {"lat": 22.3167, "lon": 114.1833, "name": "Kowloon", "source": "fallback"}
OPEN_METEO = (
    "https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}"
    "&current=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,wind_speed_10m,is_day"
    "&hourly=temperature_2m,precipitation_probability,weather_code&timezone=auto&forecast_days=2"
)


def get_json(url, timeout=6):
    req = urllib.request.Request(url, headers={"User-Agent": "overworld-hyprland/1.0 (quickshell widget)"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode("utf-8", "replace"))


def system_timezone():
    try:
        target = os.path.realpath("/etc/localtime")
        if "/zoneinfo/" in target:
            return target.split("/zoneinfo/", 1)[1]
    except OSError:
        pass
    return os.environ.get("TZ") or ""


def from_config():
    try:
        with open(CONFIG, encoding="utf-8") as f:
            cfg = json.load(f)
        w = cfg.get("weather") or {}
        lat, lon = w.get("lat"), w.get("lon")
        if isinstance(lat, (int, float)) and isinstance(lon, (int, float)):
            return {"lat": float(lat), "lon": float(lon), "name": str(w.get("name") or "Configured"), "source": "config"}
    except (OSError, ValueError, AttributeError):
        pass
    return None


def from_ip():
    tz = system_timezone()
    candidates = []
    try:
        d = get_json("https://ipapi.co/json/")
        if not d.get("error") and d.get("latitude") is not None:
            candidates.append({"lat": float(d["latitude"]), "lon": float(d["longitude"]),
                               "name": d.get("city") or "Here", "tz": d.get("timezone") or "", "source": "ipapi.co"})
    except Exception:
        pass
    if not candidates:
        try:
            d = get_json("http://ip-api.com/json/?fields=status,lat,lon,city,timezone")
            if d.get("status") == "success":
                candidates.append({"lat": float(d["lat"]), "lon": float(d["lon"]),
                                   "name": d.get("city") or "Here", "tz": d.get("timezone") or "", "source": "ip-api.com"})
        except Exception:
            pass
    for c in candidates:
        if tz and c["tz"] and c["tz"] != tz:
            # VPN / proxy exit node in another time-zone: not where the user is.
            return {"rejected": c, "reason": "timezone mismatch %s != %s" % (c["tz"], tz)}
        c.pop("tz", None)
        return c
    return None


def kind_of(code):
    """WMO weather_code -> the five world-effect kinds (+ fog)."""
    if code in (95, 96, 99):
        return "thunder"
    if code in (71, 73, 75, 77, 85, 86):
        return "snow"
    if code in (51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82):
        return "rain"
    if code in (45, 48):
        return "fog"
    if code in (2, 3):
        return "cloudy"
    return "clear"


def write_now(out):
    try:
        cur = out["forecast"]["current"]
        code = int(cur.get("weather_code", 0))
        now = {"kind": kind_of(code), "code": code, "is_day": cur.get("is_day", 1) != 0,
               "temp": cur.get("temperature_2m"), "precip_mm": cur.get("precipitation"),
               "wind": cur.get("wind_speed_10m"), "city": (out.get("location") or {}).get("name", ""),
               "stale": bool(out.get("stale")), "updated": int(time.time())}
        os.makedirs(CACHE_DIR, exist_ok=True)
        tmp = NOW + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(now, f)
        os.replace(tmp, NOW)
    except (OSError, KeyError, TypeError, ValueError):
        pass


def read_cache():
    try:
        with open(CACHE, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return None


def main():
    loc = from_config()
    note = ""
    if loc is None:
        ip = from_ip()
        if ip and "rejected" in ip:
            note = ip["reason"]
            loc = dict(FALLBACK, source="fallback (" + note + ")")
        elif ip:
            loc = ip
        else:
            loc = dict(FALLBACK, source="fallback (no geolocation)")

    try:
        forecast = get_json(OPEN_METEO.format(lat=loc["lat"], lon=loc["lon"]), timeout=10)
        out = {"location": loc, "forecast": forecast, "fetched": int(time.time()), "stale": False}
        try:
            os.makedirs(CACHE_DIR, exist_ok=True)
            tmp = CACHE + ".tmp"
            with open(tmp, "w", encoding="utf-8") as f:
                json.dump(out, f)
            os.replace(tmp, CACHE)
        except OSError:
            pass
        write_now(out)
        print(json.dumps(out))
        return 0
    except Exception as e:  # offline / API down → cache
        cached = read_cache()
        if cached and cached.get("forecast"):
            cached["stale"] = True
            cached["error"] = str(e)
            write_now(cached)
            print(json.dumps(cached))
            return 0
        print(json.dumps({"error": str(e), "location": loc}))
        return 1


if __name__ == "__main__":
    sys.exit(main())
