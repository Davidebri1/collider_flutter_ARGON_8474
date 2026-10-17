"""Collider's configuration. Made by Claude (2026-10-17).

One file, data\\collider_config.json beside Collider.exe, holds everything the app needs before it can work:
the host number it last ran on, every provider with its address and key, and where the themes come from.
The launch window (collider_app.py) shows it and saves it; the server (collider_server.py) reads only this.
No environment variables, nothing hidden in code.

The first time, when there is no file yet, the keys are taken from David's keys file so nothing has to be typed.
"""
import json
import os
import re

KEYS_FILE = r"C:\Users\D\Documents\00_Config_and_Secrets\API KEYS.txt"
NVIDIA_CHAT = "https://integrate.api.nvidia.com/v1/chat/completions"
TAVILY_SEARCH = "https://api.tavily.com/search"
THEMES = "https://collider-themes.ebridavid.workers.dev/"
THEME_NAMES = "https://davidebri1.github.io/collider-media/themes.json"


def path(data_dir):
    return os.path.join(data_dir, "collider_config.json")


def _first_run():
    text = ""
    if os.path.exists(KEYS_FILE):
        text = open(KEYS_FILE, encoding="utf-8", errors="ignore").read()
    rows = [{"name": "NVIDIA", "endpoint": NVIDIA_CHAT, "key": k, "models": ""}
            for k in dict.fromkeys(re.findall(r"nvapi-[A-Za-z0-9_\-]+", text))]
    for k in dict.fromkeys(re.findall(r"tvly-[A-Za-z0-9_\-]+", text)):
        rows.append({"name": "Tavily", "endpoint": TAVILY_SEARCH, "key": k, "models": ""})
    if not rows:
        rows.append({"name": "NVIDIA", "endpoint": NVIDIA_CHAT, "key": "", "models": ""})
    return {"host": None, "providers": rows, "themes": THEMES, "theme_names": THEME_NAMES}


def load(data_dir):
    p = path(data_dir)
    if os.path.exists(p):
        try:
            cfg = json.load(open(p, encoding="utf-8"))
            cfg.setdefault("providers", [])
            cfg.setdefault("themes", THEMES)
            cfg.setdefault("theme_names", THEME_NAMES)
            return cfg
        except Exception:
            pass
    return _first_run()


def save(data_dir, cfg):
    os.makedirs(data_dir, exist_ok=True)
    p = path(data_dir)
    tmp = p + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(cfg, f, indent=2)
    os.replace(tmp, p)


def is_search(row):
    return "tavily" in (row.get("endpoint") or "").lower() or (row.get("name") or "").lower() == "tavily"


def models_of(row):
    return [m.strip() for m in (row.get("models") or "").split(",") if m.strip()]
