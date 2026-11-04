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
        print(json.dumps(out))
        return 0
    except Exception as e:  # offline / API down → cache
        cached = read_cache()
        if cached and cached.get("forecast"):
            cached["stale"] = True
            cached["error"] = str(e)
            print(json.dumps(cached))
            return 0
        print(json.dumps({"error": str(e), "location": loc}))
        return 1


if __name__ == "__main__":
    sys.exit(main())
