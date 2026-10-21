"""Collider. Made by Claude.
Every path is taken from where this file (or Collider.exe) sits, so the folder can be renamed or moved.

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
    import collider_server as cs
    cs.apply_settings(cfg)  # every setting line, filled with its starting value where the file has none yet
    return {"host": random_host(), "providers": cfg["providers"], "themes": cfg.get("themes") or ccfg.THEMES,
            "bypass": bool(cfg.get("store_bypass", True)), "uses": uses,
            "settings": {k: cfg[k] for k in cs.SETTINGS}}


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
            cfg = ccfg.load(DATA)  # lines the form does not show are kept
            cfg.update({"host": port,
                        "providers": [r for r in form.get("providers", []) if any((r.get(k) or "").strip() for k in ("name", "endpoint", "key"))],
                        "themes": (form.get("themes") or "").strip() or ccfg.THEMES,
                        "store_bypass": bool(form.get("bypass", True))})
            cfg.update(form.get("settings") or {})
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
        # A phone's shape, never cut to fit: iPhone 16 Pro's screen (402 x 874 points) under the window's title bar,
        # made smaller as a whole when the screen is shorter (Claude, 2026-10-21).
        bar = 32
        inner = min(874, int(area_h / scale) - bar - 24)
        width, height = round(inner * 402 / 874), inner + bar
        w.resize(width, height)
        w.move(int((left + (area_w - width * scale) / 2) / scale), int((top + (area_h - height * scale) / 2) / scale))
    except Exception as e:
        _log("resize:", repr(e))
    w.set_title("Collider")
    w.load_url(url)


FORM = r"""<!doctype html><html><head><meta charset="utf-8"><title>Collider</title>
<style>
/* The launch window, redone by Claude (2026-10-21) in Apple's grouped-settings layout (iOS Settings; seen in Mobbin on
   Wispr Flow and GroupMe): grey page, white rounded groups, small grey headings above them, plain readable type.
   David: "This cyber tech look is hard to read and annoying." Light, and dark when Windows is set to dark. */
:root{color-scheme:light dark;--bg:#F2F2F7;--card:#FFFFFF;--text:#000000;--sub:#6C6C70;--sep:rgba(60,60,67,.16);--field:#F2F2F7;--accent:#007AFF;--red:#FF3B30}
@media (prefers-color-scheme:dark){:root{--bg:#000000;--card:#1C1C1E;--text:#FFFFFF;--sub:#8E8E93;--sep:rgba(84,84,88,.55);--field:#2C2C2E;--accent:#0A84FF;--red:#FF453A}}
*{box-sizing:border-box}
html,body{height:100%}
body{margin:0;background:var(--bg);color:var(--text);font:15px/1.4 "Segoe UI Variable Text","Segoe UI",system-ui,sans-serif;user-select:none;-webkit-font-smoothing:antialiased}
form{padding:22px 18px 26px;max-width:760px;margin:0 auto}
.host{display:flex;align-items:baseline;gap:12px;margin:0 4px 6px}
.host label{color:var(--sub);font-size:15px}
.host input{font:600 30px/1.1 "Segoe UI Variable Display","Segoe UI",system-ui,sans-serif;width:150px;background:transparent;border:0;border-bottom:1px solid var(--sep);color:var(--text);padding:2px 0;outline:none}
.host input:focus{border-bottom-color:var(--accent)}
.host input.bad{border-bottom-color:var(--red);color:var(--red)}
h2{font-size:13px;font-weight:400;color:var(--sub);text-transform:uppercase;letter-spacing:.02em;margin:24px 16px 7px}
.row{background:var(--card);border-radius:12px;padding:12px 14px;margin-bottom:10px}
.grid{display:grid;grid-template-columns:120px 1fr 28px;gap:8px;align-items:center}
.grid2{display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-top:8px}
input.f,textarea.f{width:100%;background:var(--field);border:0;border-radius:8px;color:var(--text);padding:8px 10px;font:14px/1.45 "Segoe UI Variable Text","Segoe UI",system-ui,sans-serif;outline:none;user-select:text}
input.f:focus,textarea.f:focus{box-shadow:0 0 0 2px var(--accent)}
textarea.f{min-height:72px;resize:vertical}
input.f::placeholder,textarea.f::placeholder{color:var(--sub)}
.uses{color:var(--sub);font-size:12.5px;margin-top:8px}
.x{background:none;border:0;color:var(--sub);cursor:pointer;font-size:20px;line-height:1;width:28px;height:28px;border-radius:14px}
.x:hover{background:var(--field)}
.add{background:var(--card);border:0;border-radius:12px;color:var(--accent);width:100%;padding:10px;cursor:pointer;font-size:22px;line-height:1}
.sw{display:flex;align-items:center;justify-content:space-between;font-size:15px}
.sw input{width:42px;height:24px;accent-color:#34C759}
.go{margin-top:20px;width:100%;padding:13px;border:0;border-radius:12px;background:var(--accent);color:#fff;font:600 17px "Segoe UI Variable Text","Segoe UI",system-ui,sans-serif;cursor:pointer}
.go:active{opacity:.85}
.where{color:var(--sub);font-size:12px;margin:12px 4px 0;word-break:break-all}
.kv{display:grid;grid-template-columns:190px 1fr;gap:10px;align-items:center;padding:7px 0;border-bottom:1px solid var(--sep)}
.kv:last-child{border-bottom:0}
.kv span{color:var(--text);font-size:14px}
.m{display:grid;grid-template-columns:1fr 1fr 1fr 28px;gap:8px;margin-bottom:8px;align-items:center}
.m>:first-child{grid-column:1/4;grid-row:1}
.m>button.x{grid-column:4;grid-row:1}
.mw{padding-bottom:12px;margin-bottom:12px;border-bottom:1px solid var(--sep)}
.mw:last-of-type{border-bottom:0}
.mw textarea.f{min-height:34px}
</style></head><body>
<form id="f" autocomplete="off">
  <div class="host"><label for="host">Host</label><input id="host" inputmode="numeric" autofocus></div>
  <div id="agents"></div>
  <h2>Providers</h2>
  <div id="rows"></div>
  <button type="button" class="add" id="add" title="Add provider">+</button>
  <div id="answers"></div>
  <h2>Themes</h2>
  <div class="row"><input class="f" id="themes"></div>
  <h2>Purchases</h2>
  <div id="buy"></div>
  <div class="row sw"><label for="bypass">Bypass</label><input type="checkbox" id="bypass"></div>
  <button class="go" type="submit">Launch</button>
  <div class="where" id="where"></div>
</form>
<script>
const C=INITIAL;let rows=C.providers.map(r=>Object.assign({name:'',endpoint:'',key:'',models:''},r));
const R=document.getElementById('rows'),H=document.getElementById('host');
const S=JSON.parse(JSON.stringify(C.settings));
const N={consensus_agent:'Consensus agent',agent_chain:'Agent chain',agent_prompt:'Consensus agent instruction',lines_prompt:'One-line agent instruction',essence_prompt:'Essence instruction',plan_prompt:'Search planning instruction',models:'Models',depth:'Answer instruction by mode',line_rule:'One-line rule',line_length:'Line length',search:'Search',plan_queries:'Planned searches',source_chars:'Source length',max_tokens:'Max tokens',deadline:'Deadline',silence:'Silence',tuning:'Tuning',pack_price:'Pack price',tracks_per_pack:'Tracks per pack',imagine:'Discover Market'};
function inp(v,set){const long=typeof v==='string'&&(v.length>70||v.includes('\n'));const e=document.createElement(long?'textarea':'input');e.className='f';e.value=Array.isArray(v)?v.join(', '):v;if(long)e.rows=Math.min(14,v.split('\n').length+1);e.addEventListener('input',()=>set(e.value));return e;}
function typed(old,s){if(typeof old==='number'){const n=Number(s);return isNaN(n)?old:n;}if(Array.isArray(old))return s.split(',').map(x=>x.trim()).filter(Boolean).map((x,i)=>typeof old[i]==='number'?Number(x):x);return s;}
const MF=['id','label','short','provider','via','color','temperature'];
function drawModels(box){box.innerHTML='';S.models.forEach((m,i)=>{const w=document.createElement('div');w.className='mw';const r=document.createElement('div');r.className='m';MF.forEach(f=>{const e=inp(m[f]===undefined||m[f]===null?'':String(m[f]),s=>{m[f]=f==='temperature'&&s.trim()!==''&&!isNaN(Number(s))?Number(s):s;});e.placeholder=f;r.appendChild(e);});
const x=document.createElement('button');x.type='button';x.className='x';x.textContent='×';x.onclick=()=>{S.models.splice(i,1);drawModels(box);};r.appendChild(x);w.appendChild(r);
const sy=document.createElement('textarea');sy.className='f';sy.placeholder='system';sy.rows=Math.max(1,Math.min(8,(m.system||'').split('\n').length));sy.value=m.system||'';sy.addEventListener('input',()=>{m.system=sy.value;});w.appendChild(sy);box.appendChild(w);});
const a=document.createElement('button');a.type='button';a.className='add';a.textContent='+';a.onclick=()=>{S.models.push({id:'',label:'',short:'',provider:'',via:'NVIDIA',color:'#8B90A0',temperature:'',system:''});drawModels(box);};box.appendChild(a);}
function section(k,host){const h=document.createElement('h2');h.textContent=N[k];host.appendChild(h);const box=document.createElement('div');box.className='row';const v=S[k];
if(k==='models')drawModels(box);
else if(v&&typeof v==='object'&&!Array.isArray(v))Object.keys(v).forEach(sk=>{const r=document.createElement('div');r.className='kv';const l=document.createElement('span');l.textContent=sk;r.appendChild(l);r.appendChild(inp(v[sk],s=>{v[sk]=typed(C.settings[k][sk],s);}));box.appendChild(r);});
else box.appendChild(inp(v,s=>{S[k]=typed(C.settings[k],s);}));
host.appendChild(box);}
['consensus_agent','agent_chain','agent_prompt','lines_prompt','essence_prompt','plan_prompt','models'].forEach(k=>section(k,document.getElementById('agents')));
['depth','line_rule','line_length','search','plan_queries','source_chars','max_tokens','deadline','silence','tuning'].forEach(k=>section(k,document.getElementById('answers')));
['pack_price','tracks_per_pack'].forEach(k=>section(k,document.getElementById('buy')));
['imagine'].forEach(k=>section(k,document.getElementById('answers')));
function draw(){R.innerHTML='';rows.forEach((r,i)=>{const d=document.createElement('div');d.className='row';
d.innerHTML=`<div class="grid"><input class="f" data-k="name" placeholder="Name"><input class="f" data-k="key" placeholder="Key"><button type="button" class="x" title="Remove">×</button></div>
<div class="grid2"><input class="f" data-k="endpoint" placeholder="Address"><input class="f" data-k="models" placeholder="Models"></div><div class="uses"></div>`;
d.querySelectorAll('input').forEach(inp=>{inp.value=r[inp.dataset.k]||'';inp.addEventListener('input',()=>{r[inp.dataset.k]=inp.value;});});
d.querySelector('.x').onclick=()=>{rows.splice(i,1);C.uses.splice(i,1);draw();};
if(/tavily|fal\.run/i.test((r.endpoint||'')+(r.name||'')))d.querySelector('[data-k=models]').style.visibility='hidden';
d.querySelector('.uses').textContent=C.uses[i]||'';R.appendChild(d);});}
document.getElementById('add').onclick=()=>{rows.push({name:'',endpoint:'',key:'',models:''});C.uses.push('');draw();};
H.value=C.host;document.getElementById('themes').value=C.themes;document.getElementById('bypass').checked=C.bypass;
document.getElementById('where').textContent='Saved to '+WHERE;draw();H.focus();H.select();
H.addEventListener('input',()=>H.classList.remove('bad'));
let busy=false;
document.getElementById('f').onsubmit=async e=>{e.preventDefault();if(busy||!window.pywebview)return;busy=true;
try{const r=await pywebview.api.launch({host:H.value,providers:rows,themes:document.getElementById('themes').value,bypass:document.getElementById('bypass').checked,settings:S});
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
        width, height = min(760, int(area_w / scale)), min(860, int(area_h / scale))
        x = int((left + (area_w - width * scale) / 2) / scale)
        y = int((top + (area_h - height * scale) / 2) / scale)
        _WIN = webview.create_window("Collider", html=html, js_api=Api(), width=width, height=height, x=x, y=y,
                                           min_size=(360, 480), background_color="#0B0D12")
        # The right-click menu is on so a misspelt word in Documents shows its suggestions (Claude, 2026-10-20);
        # the developer tools stay closed.
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
