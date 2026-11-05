"""Pull Figma reference frames (JSON + PNG) into assets/figma_ref/.

Usage: uv run --with requests python tools/figma_pull.py
PAT is read at runtime from C:\\Users\\D\\Documents\\API KEYS.txt (never hardcoded).
"""
import json
import re
import sys
import time
import urllib.request
from pathlib import Path

KEYS = Path(r"C:\Users\D\Documents\API KEYS.txt")
OUT = Path(__file__).resolve().parent.parent / "assets" / "figma_ref"
GAP = 20  # seconds between pulls — the token is rate-limited (429)

TARGETS = [
    ("premium_theme_market", "hFeAUDR2hO1arcLe4NoNgo", ["1:3"]),
    ("spatial_kit_overview", "jqsG6Hqkm7yws2iz607kim", ["0:1"]),
    ("theme_gallery", "jqsG6Hqkm7yws2iz607kim", ["69:1926"]),
    ("files_ref", "jqsG6Hqkm7yws2iz607kim", ["71:7502"]),
    ("vos_music_market", "YEuK4CL2uyECUhvGEcgCNS", ["417:1777"]),
    ("vos_premium_detail", "YEuK4CL2uyECUhvGEcgCNS", ["417:15864"]),
    ("vos_video_player", "YEuK4CL2uyECUhvGEcgCNS", ["417:8630"]),
    ("browser", "TReeWMHkw4GE5uKPhzvgMu", ["1:71"]),
    ("message_bar", "TReeWMHkw4GE5uKPhzvgMu", ["1:240"]),
    ("model_responses", "TReeWMHkw4GE5uKPhzvgMu", ["1:96"]),
    ("media_gen_ticker", "OkuRCwJ6Hgz664K8YSe1zr", ["26:1004"]),
    ("model_response_ticker", "OkuRCwJ6Hgz664K8YSe1zr", ["0:639"]),
    ("nimo_smart_gen", "gQWsPhZJQjqFPgaJQDds9p", ["2012:201531"]),
    ("vision_pro_ui_kit_stage", "BLoCtbUcCpX32i0Fh7Y0ld", ["30:75"]),
    ("inline_editing", "IZidmdk7e3KXXGqdbtUGWF", ["59:170"]),
    ("autolayout_menu", "4CLz2H5l84ILrVUyskOnAS", ["0:1"]),
]


def pat() -> str:
    m = re.search(r"figd_[A-Za-z0-9_\-]+", KEYS.read_text(encoding="utf-8", errors="ignore"))
    if not m:
        sys.exit("no figd_ token found in keys file")
    return m.group(0)


def get_json(url: str, token: str):
    last = None
    for wait in (25, 50, 90):  # retry 429s with backoff
        try:
            req = urllib.request.Request(url, headers={"X-Figma-Token": token})
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.loads(r.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            if e.code == 429:
                last = e
                print(f"    429, waiting {wait}s …")
                time.sleep(wait)
                continue
            raise
    raise last


def main() -> None:
    token = pat()
    OUT.mkdir(parents=True, exist_ok=True)
    ok = failed = 0
    for i, (name, key, nodes) in enumerate(TARGETS):
        if i > 0:
            time.sleep(GAP)
        ids = ",".join(nodes)
        try:
            meta = get_json(
                f"https://api.figma.com/v1/files/{key}/nodes?ids={ids}&depth=6", token
            )
            (OUT / f"{name}.json").write_text(
                json.dumps(meta, indent=1)[:2_000_000], encoding="utf-8"
            )
            img = get_json(
                f"https://api.figma.com/v1/images/{key}?ids={ids}&format=png&scale=2",
                token,
            )
            urls = (img.get("images") or {})
            png = next((u for n, u in urls.items() if u), None)
            if png:
                req = urllib.request.Request(png)
                with urllib.request.urlopen(req, timeout=120) as r:
                    (OUT / f"{name}.png").write_bytes(r.read())
            print(f"OK   {name}")
            ok += 1
        except Exception as e:  # noqa: BLE001 - report and continue
            print(f"FAIL {name}: {e}")
            failed += 1
    print(f"done: {ok} ok, {failed} failed -> {OUT}")


if __name__ == "__main__":
    main()
