# Made by Claude (2026-10-23). Collider online, on a Hugging Face Space.
# David, 23 Oct: "we arent going to run anything off my pc ... host online" and "make sure that the app is always
# accessible". This starts the same server Collider.exe runs, reachable from anywhere at one address:
#  - its data (configuration with the providers and keys, history, Files, made pictures) lives in a private Hugging Face
#    dataset, ZellJr/collider-data: read at start, and written back within a minute of any change, so a restart of the
#    Space loses nothing;
#  - the unchanging phone link (collider-phone Worker) is pointed here at start.
import json, os, sys, threading, time, urllib.request
from http.server import ThreadingHTTPServer

APP = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(APP, "data")
WEB = os.path.join(APP, "build", "web")
REPO = os.environ.get("COLLIDER_DATA_REPO", "ZellJr/collider-data")
WEB_REPO = os.environ.get("COLLIDER_WEB_REPO", "ZellJr/collider-web")
TOKEN = os.environ.get("HF_TOKEN", "")
PORT = int(os.environ.get("PORT") or 7860)
SKIP = ("window", "window-browser", "collider_app.log")

from huggingface_hub import snapshot_download, upload_folder  # noqa: E402

os.makedirs(DATA, exist_ok=True)
for repo, folder, what in ((REPO, DATA, "data"), (WEB_REPO, WEB, "app")):
    try:
        snapshot_download(repo, repo_type="dataset", local_dir=folder, token=TOKEN)
        print(what, "restored from", repo, flush=True)
    except Exception as e:
        print(what, "not restored:", str(e)[:200], flush=True)

sys.path.insert(0, os.path.join(APP, "tools"))
import collider_config as ccfg  # noqa: E402
import collider_server as cs  # noqa: E402

cfg = ccfg.load(DATA)
cs.setup(APP, WEB, DATA, PORT, cfg)
server = ThreadingHTTPServer(("0.0.0.0", PORT), cs.Handler)


def announce():
    """Points the phone link at this Space."""
    here = os.environ.get("RENDER_EXTERNAL_URL") or ("https://" + os.environ["SPACE_HOST"] if os.environ.get("SPACE_HOST") else "")
    relay = next((r for r in cs.rows() if ccfg.is_phone(r)), None)
    if not here or not relay:
        return
    for _ in range(10):
        try:
            req = urllib.request.Request(relay["endpoint"].rstrip("/") + "/set", data=json.dumps({"url": here.rstrip("/")}).encode(),
                                         headers={"Content-Type": "application/json", "Authorization": "Key " + relay["key"].strip(),
                                                  "User-Agent": "Collider/1.0"})
            print("phone link:", urllib.request.urlopen(req, timeout=20).read()[:80], flush=True)
            return
        except Exception as e:
            print("phone link not set yet:", str(e)[:120], flush=True)
            time.sleep(10)


def state():
    out = []
    for d, dirs, files in os.walk(DATA):
        dirs[:] = [x for x in dirs if x not in SKIP and not x.startswith(".")]
        for f in files:
            if f in SKIP:
                continue
            p = os.path.join(d, f)
            try:
                st = os.stat(p)
                out.append((p, st.st_size, int(st.st_mtime)))
            except OSError:
                pass
    return sorted(out)


def keep():
    """Writes the data back to the dataset within a minute of any change."""
    last = state()
    while True:
        time.sleep(60)
        now = state()
        if now == last:
            continue
        try:
            upload_folder(folder_path=DATA, repo_id=REPO, repo_type="dataset", token=TOKEN, commit_message="Collider data",
                          ignore_patterns=["window/**", "window-browser/**", "*.log", ".cache/**"])
            last = now
            print("data kept", flush=True)
        except Exception as e:
            print("data not kept yet:", str(e)[:200], flush=True)


threading.Thread(target=announce, daemon=True).start()
threading.Thread(target=keep, daemon=True).start()
print("Collider online on", PORT, flush=True)
server.serve_forever()
