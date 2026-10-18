"""Collider. Made by Claude.
Folder: C:\\Users\\D\\Documents\\collider_flutter__CLAUDE_live-models-consensus_20260927

The one thing to open. A launch window comes up first (rebuilt 2026-10-17 on David's request):
  - the host number at the top, a free random one each time, typed over to choose another;
  - every provider with its address, key and models, each showing where in the app it is read;
  - where the themes come from;
  - whether purchases are bypassed (on: a Buy completes at once, for development).
The fields arrive filled in, written into the page before it opens (2026-10-17: they had been fetched after
the page loaded, which left them blank).
Enter saves it all to data\\collider_config.json and opens the app at that host in the same window.
The last configuration comes back next time, so usually Enter is all it takes.

  Collider.exe                      launch window, then the app
  Collider.exe --host 30111 --go    no window questions: that host, the saved configuration
  Collider.exe --web <folder>       the same, serving another Collider build's web output (e.g. a newer revision)
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
# The folder Collider.exe sits in (run from source: the project folder).
HERE = os.path.dirname(sys.executable) if FROZEN else os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUNDLE = getattr(sys, "_MEIPASS", HERE)
DATA = os.path.join(HERE, "data")
os.makedirs(DATA, exist_ok=True)
if not FROZEN:
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import collider_config as ccfg  # noqa: E402


def _web_folder():
    # --web <folder>: serve another Collider build's web output (any revision built against this server)
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


def describe(providers):
    """For each provider row: where the app reads it."""
    import collider_server as cs
    cs.CONFIG = {"providers": providers}
    cs._extend_roster()
    return [cs.uses(r) if (r.get("key") or "").strip() else "Not read: no key" for r in providers]


_WIN = None  # the launch window. Kept off the Api object: pywebview walks every public attribute of js_api,
             # and walking the window from there is what crashed the form on a click (2026-10-17).


def initial():
    """Everything the form shows, filled in: a free random host, then the saved (or first-run) configuration."""
    cfg = ccfg.load(DATA)
    try:
        uses = describe(cfg["providers"])
    except Exception as e:
        _log("uses:", repr(e))
        uses = ["" for _ in cfg["providers"]]
    return {"host": random_host(), "providers": cfg["providers"], "themes": cfg.get("themes") or ccfg.THEMES,
            "bypass": bool(cfg.get("store_bypass", True)), "uses": uses}


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
            cfg = {"host": port,
                   "providers": [r for r in form.get("providers", []) if any((r.get(k) or "").strip() for k in ("name", "endpoint", "key"))],
                   "themes": (form.get("themes") or "").strip() or ccfg.THEMES,
                   "store_bypass": bool(form.get("bypass", True))}
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
        width, height = min(440, int(area_w / scale)), min(940, int(area_h / scale))
        w.resize(width, height)
        w.move(int((left + (area_w - width * scale) / 2) / scale), int((top + (area_h - height * scale) / 2) / scale))
    except Exception as e:
        _log("resize:", repr(e))
    w.set_title("Collider")
    w.load_url(url)


FORM = r"""<!doctype html><html><head><meta charset="utf-8"><title>Collider</title>
<style>
:root{color-scheme:dark}
*{box-sizing:border-box}
html,body{height:100%}
body{margin:0;background:#0B0D12;color:#E9EBF0;font:13px/1.4 "Segoe UI",system-ui,sans-serif;user-select:none}
form{padding:18px 18px 14px}
.host{display:flex;align-items:baseline;gap:10px;margin-bottom:14px}
.host label{color:#8B90A0;font-size:12px}
.host input{font-size:26px;font-weight:600;width:130px;background:transparent;border:0;border-bottom:1px solid #2A2F3A;color:#fff;padding:2px 0;outline:none}
.host input.bad{border-bottom-color:#FF453A}
h2{font-size:11px;font-weight:600;color:#8B90A0;letter-spacing:.04em;text-transform:uppercase;margin:16px 0 6px}
.row{background:#141822;border:1px solid #1F2430;border-radius:10px;padding:8px;margin-bottom:6px}
.grid{display:grid;grid-template-columns:96px 1fr 22px;gap:6px}
.grid2{display:grid;grid-template-columns:1fr 1fr;gap:6px;margin-top:6px}
input.f{width:100%;background:#0E1118;border:1px solid #232836;border-radius:6px;color:#E9EBF0;padding:5px 7px;font:12px "Cascadia Mono",Consolas,monospace;outline:none;user-select:text}
input.f:focus{border-color:#3B82F6}
.uses{color:#7D8394;font-size:11px;margin-top:5px}
.x{background:none;border:0;color:#7D8394;cursor:pointer;font-size:15px;line-height:1}
.add{background:none;border:0;color:#5E6474;width:100%;padding:2px;cursor:pointer;font-size:15px}
.sw{display:flex;align-items:center;justify-content:space-between}
.sw input{width:34px;height:20px;accent-color:#0A84FF}
.go{margin-top:14px;width:100%;padding:9px;border:0;border-radius:9px;background:#0A84FF;color:#fff;font-weight:600;cursor:pointer}
.where{color:#5E6474;font-size:11px;margin-top:8px;word-break:break-all}
</style></head><body>
<form id="f" autocomplete="off">
  <div class="host"><label for="host">Host</label><input id="host" inputmode="numeric" autofocus></div>
  <h2>Providers</h2>
  <div id="rows"></div>
  <button type="button" class="add" id="add" title="Add provider">+</button>
  <h2>Themes</h2>
  <div class="row"><input class="f" id="themes"></div>
  <h2>Purchases</h2>
  <div class="row sw"><label for="bypass">Bypass</label><input type="checkbox" id="bypass"></div>
  <button class="go" type="submit">Launch</button>
  <div class="where" id="where"></div>
</form>
<script>
const C=INITIAL;let rows=C.providers.map(r=>Object.assign({name:'',endpoint:'',key:'',models:''},r));
const R=document.getElementById('rows'),H=document.getElementById('host');
function draw(){R.innerHTML='';rows.forEach((r,i)=>{const d=document.createElement('div');d.className='row';
d.innerHTML=`<div class="grid"><input class="f" data-k="name" placeholder="Name"><input class="f" data-k="key" placeholder="Key"><button type="button" class="x" title="Remove">×</button></div>
<div class="grid2"><input class="f" data-k="endpoint" placeholder="Address"><input class="f" data-k="models" placeholder="Models"></div><div class="uses"></div>`;
d.querySelectorAll('input').forEach(inp=>{inp.value=r[inp.dataset.k]||'';inp.addEventListener('input',()=>{r[inp.dataset.k]=inp.value;});});
d.querySelector('.x').onclick=()=>{rows.splice(i,1);C.uses.splice(i,1);draw();};
if(/tavily/i.test((r.endpoint||'')+(r.name||'')))d.querySelector('[data-k=models]').style.visibility='hidden';
d.querySelector('.uses').textContent=C.uses[i]||'';R.appendChild(d);});}
document.getElementById('add').onclick=()=>{rows.push({name:'',endpoint:'',key:'',models:''});C.uses.push('');draw();};
H.value=C.host;document.getElementById('themes').value=C.themes;document.getElementById('bypass').checked=C.bypass;
document.getElementById('where').textContent='Saved to '+WHERE;draw();H.focus();H.select();
H.addEventListener('input',()=>H.classList.remove('bad'));
let busy=false;
document.getElementById('f').onsubmit=async e=>{e.preventDefault();if(busy||!window.pywebview)return;busy=true;
try{const r=await pywebview.api.launch({host:H.value,providers:rows,themes:document.getElementById('themes').value,bypass:document.getElementById('bypass').checked});
if(r&&r.error){H.classList.add('bad');H.focus();H.select();}}finally{busy=false;}};
</script></body></html>"""


def _screen():
    """The usable screen (without the taskbar) in screen pixels: left, top, width, height; and the display scale."""
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
    """The launch window; after Enter the same window becomes the app. True once it has been shown and closed."""
    try:
        import webview
        global _WIN
        html = FORM.replace("WHERE", json.dumps(ccfg.path(DATA))).replace("INITIAL", json.dumps(initial()))
        left, top, area_w, area_h, scale = _screen()
        width, height = 520, min(720, int(area_h / scale))
        x = int((left + (area_w - width * scale) / 2) / scale)
        y = int((top + (area_h - height * scale) / 2) / scale)
        _WIN = webview.create_window("Collider", html=html, js_api=Api(), width=width, height=height, x=x, y=y,
                                           min_size=(360, 480), background_color="#0B0D12")
        webview.start(private_mode=False, storage_path=os.path.join(DATA, "window"))
        return True
    except Exception as e:
        _log("window:", repr(e))
        return False


def _browser_window(url):
    """Fallback when the window library is missing: the app as a borderless window in Edge or Chrome."""
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
        port = int(args[args.index("--host") + 1]) if "--host" in args else (cfg.get("host") if free(cfg.get("host") or 0) else random_host())
        url = start_server(port, cfg)
        print(url, flush=True)
        if "--server-only" in args or _browser_window(url):
            threading.Event().wait()
        return
    if _launch_window():
        return
    # No window library: the saved configuration, a random host, the browser.
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
