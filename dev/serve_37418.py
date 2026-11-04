import os, sys
from http.server import ThreadingHTTPServer

APP = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(APP, "data")
WEB = os.path.join(APP, "build", "web")
PORT = 37418

os.makedirs(DATA, exist_ok=True)
os.makedirs(WEB, exist_ok=True)

sys.path.insert(0, os.path.join(APP, "tools"))
import collider_config as ccfg
import collider_server as cs

cfg = ccfg.load(DATA)
cs.setup(APP, WEB, DATA, PORT, cfg)
server = ThreadingHTTPServer(("0.0.0.0", PORT), cs.Handler)
print(f"Collider ARGON 37418 online on http://127.0.0.1:{PORT}/", flush=True)
server.serve_forever()
