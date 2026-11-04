# E.D. — Collider — Signed: Gemini 4 Argon (2026-10-24)
"""Collider Desktop Launcher & Configurator Window.
Every path is taken from where this file (or Collider.exe) sits, so the folder can be renamed or moved.

A Launch Configurator window comes up first:
  - Localhost Port Number at the top, a free random one each time, typed over to choose another;
  - API Providers & Keys with a sorted, filterable selector loaded directly from API KEYS.txt;
  - Ticker Response Models with dropdown selectors, route selectors, color pickers, and temperature selectors;
  - Consensus & Smart Gen Judge Models and Instructions;
  - Prompt Modes (Chat, Internet, Research, Deep Research) with explicit dropdown selectors;
  - Model Execution, Stream, Browser, Discover Market Image Gen, and Theme Store settings.
Enter saves it all to data\\collider_config.json and opens the app at that localhost port in the same window.
"""
import json
import os
import random
import socket
import subprocess
import sys
import threading
import time
import webbrowser

FROZEN = getattr(sys, "frozen", False)
HERE = os.path.dirname(sys.executable) if FROZEN else os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUNDLE = getattr(sys, "_MEIPASS", HERE)
DATA = os.path.join(HERE, "data")
os.makedirs(DATA, exist_ok=True)
if os.path.isdir(os.path.join(HERE, "tools")):
    sys.path.insert(0, os.path.join(HERE, "tools"))
elif not FROZEN:
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import collider_config as ccfg  # noqa: E402


def _web_folder():
    a = sys.argv[1:]
    if "--web" in a and a.index("--web") + 1 < len(a):
        return os.path.abspath(a[a.index("--web") + 1])
    for p in (os.path.join(HERE, "build", "web"), os.path.join(BUNDLE, "web")):
        if os.path.isfile(os.path.join(p, "index.html")):
            return p
    return os.path.join(BUNDLE, "web")


def _log(*a):
    try:
        with open(os.path.join(DATA, "collider_app.log"), "a", encoding="utf-8") as f:
            f.write(time.strftime("%Y-%m-%d %H:%M:%S ") + " ".join(str(x) for x in a) + "\n")
    except Exception:
        pass


def free(port):
    s = socket.socket()
    try:
        s.bind(("127.0.0.1", int(port)))
        return True
    except (OSError, ValueError, OverflowError):
        return False
    finally:
        s.close()


def random_host():
    for _ in range(200):
        p = random.randint(20000, 60999)
        if free(p):
            return p
    s = socket.socket()
    s.bind(("127.0.0.1", 0))
    p = s.getsockname()[1]
    s.close()
    return p


def start_server(port, cfg):
    import collider_server as cs
    from http.server import ThreadingHTTPServer
    cs.setup(HERE, _web_folder(), DATA, port, cfg)
    srv = ThreadingHTTPServer(("127.0.0.1", int(port)), cs.Handler)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    _log("serving", cs.WEB, "on", port)
    return f"http://127.0.0.1:{port}/"


_WIN = None


def initial():
    """Everything the Launch Configurator form shows, filled in from data\\collider_config.json and API KEYS.txt."""
    import collider_server as cs
    cfg = ccfg.load(DATA)
    cs.CONFIG = cfg
    return cs.build_form_initial(random_host())


class Api:
    """What the launch window's page can ask of Python. Methods only."""

    def launch(self, form):
        try:
            try:
                port = int(str(form.get("host", "")).strip())
            except ValueError:
                return {"error": "host"}
            if not (1024 <= port <= 65535) or not free(port):
                return {"error": "host"}
            import collider_server as cs
            cfg = ccfg.load(DATA)
            raw_provs = form.get("providers") if "providers" in form else form.get("api_providers_and_keys", [])
            cfg["localhost_port"] = port
            cfg["api_providers_and_keys"] = [
                ccfg.normalize_provider_row(r)
                for r in raw_provs
                if any((r.get(k) or "").strip() for k in ("provider_name", "api_endpoint_url", "api_key", "name", "endpoint", "key"))
            ]
            cfg.update(form.get("settings") or {})
            cs.apply_settings(cfg)
            ccfg.save(DATA, cfg)
            url = start_server(port, cfg)
            threading.Thread(target=_open, args=(url,), daemon=True).start()
            return {"url": url}
        except Exception as e:
            _log("launch:", repr(e))
            return {"error": "launch"}


def _open(url):
    time.sleep(0.2)
    w = _WIN
    try:
        left, top, area_w, area_h, scale = _screen()
        bar = 32
        inner = min(874, int(area_h / scale) - bar - 24)
        width, height = round(inner * 402 / 874), inner + bar
        w.resize(width, height)
        w.move(int((left + (area_w - width * scale) / 2) / scale), int((top + (area_h - height * scale) / 2) / scale))
    except Exception as e:
        _log("resize:", repr(e))
    w.set_title("Collider")
    w.load_url(url)


from collider_form import FORM  # noqa: E402


def _screen():
    try:
        import ctypes
        from ctypes import wintypes
        try:
            ctypes.windll.shcore.SetProcessDpiAwareness(2)
        except Exception:
            pass
        u = ctypes.windll.user32
        r = wintypes.RECT()
        u.SystemParametersInfoW(0x0030, 0, ctypes.byref(r), 0)
        return r.left, r.top, r.right - r.left, r.bottom - r.top, u.GetDpiForSystem() / 96.0
    except Exception:
        return 0, 0, 1280, 720, 1.0


def _launch_window():
    try:
        import webview
        global _WIN
        html = FORM.replace("WHERE", json.dumps(ccfg.path(DATA))).replace("INITIAL", json.dumps(initial()))
        left, top, area_w, area_h, scale = _screen()
        width, height = min(880, int(area_w / scale)), min(900, int(area_h / scale))
        x = int((left + (area_w - width * scale) / 2) / scale)
        y = int((top + (area_h - height * scale) / 2) / scale)
        _WIN = webview.create_window("Collider — Launch Configurator", html=html, js_api=Api(), width=width, height=height, x=x, y=y,
                                     min_size=(400, 520), background_color="#0B0D12")
        debug = False
        try:
            webview.settings["OPEN_DEVTOOLS_IN_DEBUG"] = False
            debug = True
        except Exception:
            pass
        webview.start(private_mode=False, storage_path=os.path.join(DATA, "window"), debug=debug)
        return True
    except Exception as e:
        _log("window:", repr(e))
        return False


def _browser_window(url):
    for exe in (r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
                r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
                r"C:\Program Files\Google\Chrome\Application\chrome.exe",
                r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"):
        if os.path.exists(exe):
            subprocess.Popen([exe, f"--app={url}", "--window-size=440,940", "--no-first-run",
                              f"--user-data-dir={os.path.join(DATA, 'window-browser')}"]).wait()
            return True
    return False


def main():
    args = sys.argv[1:]
    if "--go" in args:
        cfg = ccfg.load(DATA)
        saved_p = cfg.get("localhost_port") or cfg.get("host") or 0
        port = int(args[args.index("--host") + 1]) if "--host" in args else (saved_p if free(saved_p) else random_host())
        url = start_server(port, cfg)
        print(url, flush=True)
        if "--server-only" in args or _browser_window(url):
            threading.Event().wait()
        return
    if _launch_window():
        return
    cfg = ccfg.load(DATA)
    url = start_server(random_host(), cfg)
    if not _browser_window(url):
        webbrowser.open(url)
    threading.Event().wait()


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        _log("fatal:", repr(e))
        raise
