"""Discover Market's making of pictures and videos, through fal. Made by Claude (2026-10-20).

David, 20 Oct: "discover market should be wired to Fal ... whatever functionality imagine market has, discover market
has." So, as in Grok's Imagine: words make pictures (several at once, at 2K), a picture can be set in motion (a video
from that picture), and words alone can make a video. The models are Grok Imagine's own on fal by default and are lines
in the configuration (settings > imagine), so any fal model can be put in their place without touching code.

Everything made is saved in Files > Generated (marked as made by Discover Market) and listed in data\\imagine.json,
newest first, which the app reads for Discover Market's feed and My Gallery.
"""
import json, os, re, threading, time, urllib.error, urllib.request, uuid

QUEUE = "https://queue.fal.run/"

# The lines the configuration starts with (settings > imagine). Values are the best each model offers.
DEFAULTS = {
    "image_model": "xai/grok-imagine-image/v2.0/text-to-image",
    "motion_model": "xai/grok-imagine-video/v1.5/image-to-video",
    "video_model": "xai/grok-imagine-video/v1.5/text-to-video",
    "pictures": 4,
    "image_resolution": "2k",
    "image_quality": "medium",
    "aspect_ratio": "9:16",
    "video_resolution": "1080p",
    "video_seconds": 6,
    "poll_seconds": 2,
    "deadline_seconds": 600,
}

_lock = threading.Lock()


class Imagine:
    def __init__(self, data_dir, files, rows, settings):
        """files: collider_files.Files; rows(): the configuration's fal rows (with keys); settings(): the imagine lines."""
        self.path = os.path.join(data_dir, "imagine.json")
        self.files = files
        self.rows = rows
        self.settings = settings
        self._turn = 0

    # ---------------- the list ----------------
    def _load(self):
        try:
            return json.load(open(self.path, encoding="utf-8"))
        except Exception:
            return []

    def _save(self, items):
        tmp = self.path + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(items, f, indent=1)
        os.replace(tmp, self.path)

    def _update(self, cid, **changes):
        with _lock:
            items = self._load()
            for it in items:
                if it["id"] == cid:
                    it.update(changes)
            self._save(items)

    def listing(self):
        with _lock:
            return self._load()

    # ---------------- making ----------------
    def start(self, text, kind="image", from_id=None, replace=None):
        """kind: image (pictures from words), video (a video from words), motion (a video from one of the pictures).
        replace: a making that failed, taken off the list as it is tried again."""
        if replace:
            self.remove(replace)
        text = (text or "").strip()
        source = None
        if kind == "motion":
            source = next((it for it in self.listing() if it["id"] == from_id), None)
            if not source or not source.get("media"):
                raise ValueError("no picture")
        elif not text:
            raise ValueError("no words")
        cid = uuid.uuid4().hex[:12]
        item = {"id": cid, "kind": kind, "text": text or (source or {}).get("text", ""), "status": "making",
                "created": time.time(), "from": from_id, "media": []}
        with _lock:
            items = self._load()
            items.insert(0, item)
            self._save(items)
        threading.Thread(target=self._run, args=(cid, kind, item["text"], source), daemon=True).start()
        return item

    def _key(self):
        rs = self.rows()
        if not rs:
            return None
        self._turn = (self._turn + 1) % len(rs)
        return rs[self._turn]["key"].strip()

    def _call(self, method, url, key, body=None):
        req = urllib.request.Request(url, method=method, data=json.dumps(body).encode() if body is not None else None,
                                     headers={"Authorization": "Key " + key, "Content-Type": "application/json",
                                              "Accept": "application/json", "User-Agent": "Collider/1.0"})
        with urllib.request.urlopen(req, timeout=60) as r:
            return json.loads(r.read() or b"{}")

    def _run(self, cid, kind, text, source):
        s = {**DEFAULTS, **(self.settings() or {})}
        try:
            key = self._key()
            if not key:
                raise RuntimeError("no fal key")
            if kind == "image":
                model = s["image_model"]
                body = {"prompt": text, "num_images": int(s["pictures"]), "resolution": s["image_resolution"],
                        "quality": s["image_quality"], "aspect_ratio": s["aspect_ratio"], "output_format": "png"}
            elif kind == "video":
                model = s["video_model"]
                body = {"prompt": text, "resolution": s["video_resolution"], "duration": int(s["video_seconds"]),
                        "aspect_ratio": s["aspect_ratio"]}
            else:
                model = s["motion_model"]
                body = {"prompt": text or "", "image_url": source["media"][0]["remote"],
                        "resolution": s["video_resolution"], "duration": int(s["video_seconds"])}
            job = self._call("POST", QUEUE + model, key, body)
            status_url = job.get("status_url") or f"{QUEUE}{model}/requests/{job['request_id']}/status"
            result_url = job.get("response_url") or f"{QUEUE}{model}/requests/{job['request_id']}"
            give_up = time.time() + float(s["deadline_seconds"])
            while True:
                st = self._call("GET", status_url, key)
                if st.get("status") == "COMPLETED":
                    break
                if st.get("status") in ("FAILED", "ERROR") or time.time() > give_up:
                    raise RuntimeError(st.get("status") or "timeout")
                time.sleep(float(s["poll_seconds"]))
            out = self._call("GET", result_url, key)
            found = [i for i in (out.get("images") or []) if i.get("url")]
            if out.get("video", {}).get("url"):
                found.append(out["video"])
            media = []
            stem = re.sub(r"[^\w\- ]", "", text)[:48].strip() or "Discover Market"
            for n, m in enumerate(found):
                url = m["url"]
                ext = os.path.splitext(url.split("?")[0])[1] or (".mp4" if kind != "image" else ".png")
                data = urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "Collider/1.0"}), timeout=120).read()
                name = self.files.save_media(f"{stem}{'' if n == 0 else f' {n + 1}'}{ext}", data, "Discover Market")
                media.append({"name": name, "url": f"/files/generated/{urllib.request.quote(name)}", "remote": url,
                              "kind": "video" if ext.lower() in (".mp4", ".webm", ".mov") else "image",
                              "width": m.get("width"), "height": m.get("height")})
            self._update(cid, status="done", media=media, model=model)
        except Exception as e:
            self._update(cid, status="failed", error=str(e)[:160])

    def remove(self, cid):
        """Takes a making off the list. Its files stay in Files > Generated."""
        with _lock:
            self._save([it for it in self._load() if it["id"] != cid])
