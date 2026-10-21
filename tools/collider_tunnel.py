"""The phone link. Made by Claude (2026-10-21).

David, 21 Oct: "So if I'm on my phone, I can't test this app? I can't run exe on iPhone can I? I'm in safari".
Collider is a web app served by this computer. Cloudflare's tunnel program (bin\\cloudflared.exe beside Collider.exe,
from Cloudflare's own releases) gives it a private https address that works from a phone anywhere, microphone included.
The address carries a key made fresh at each start; without it the server answers nothing that comes through the
tunnel, so nobody else can use the keys on this computer. The tunnel ends when Collider closes.
"""
import base64, io, json, os, re, secrets, shutil, subprocess, threading, urllib.request


class Tunnel:
    def __init__(self, root, port, relay=None):
        """relay: the configuration's Phone row (collider-phone Worker): its key is the link's key, kept across starts."""
        self.root = root
        self.port = int(port)
        self.relay = relay or {}
        self.key = (self.relay.get("key") or "").strip() or secrets.token_urlsafe(18)
        self.url = ""  # https://....trycloudflare.com once Cloudflare has given it
        self._proc = None

    def program(self):
        for p in (os.path.join(self.root, "bin", "cloudflared.exe"), shutil.which("cloudflared")):
            if p and os.path.isfile(p):
                return p
        return None

    def start(self):
        if not self.program():
            return False
        self._spawn()
        threading.Thread(target=self._watch, daemon=True).start()
        return True

    def _spawn(self):
        flags = 0x08000000 if os.name == "nt" else 0  # no console window
        self.url = ""
        self._proc = subprocess.Popen([self.program(), "tunnel", "--no-autoupdate", "--url", f"http://127.0.0.1:{self.port}"],
                                      stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE,
                                      creationflags=flags)
        threading.Thread(target=self._read, args=(self._proc,), daemon=True).start()

    def _read(self, proc):
        for raw in iter(proc.stderr.readline, b""):
            m = re.search(rb"https://[a-z0-9-]+\.trycloudflare\.com", raw)
            if m and m.group(0).decode() != self.url:
                self.url = m.group(0).decode()
                threading.Thread(target=self._announce, daemon=True).start()

    def _alive(self):
        """The tunnel's own address still answers (a quick tunnel can be dropped by Cloudflare while the program runs)."""
        if not self.url:
            return False
        try:
            urllib.request.urlopen(urllib.request.Request(self.url + "/", method="HEAD", headers={"User-Agent": "Collider/1.0"}),
                                   timeout=20)
            return True
        except urllib.error.HTTPError:
            return True  # it answered (the key gate says no to a bare request): the tunnel is up
        except Exception:
            return False

    def _watch(self):
        """Keeps the phone link working for as long as Collider runs (Claude, 2026-10-21; David, 21 Oct: "Link doesn't
        work"): every minute, if the tunnel program has ended or its address has stopped answering twice running, a new
        tunnel is opened and the unchanging link is pointed at it."""
        import time
        misses = 0
        time.sleep(60)
        while (p := self._proc) is not None:
            ended = p.poll() is not None
            misses = 0 if (not ended and self._alive()) else misses + 1
            if self._proc is None:
                break
            if ended or misses >= 2:
                if not ended:
                    p.terminate()
                self._spawn()
                misses = 0
                time.sleep(30)
            time.sleep(60)

    def _announce(self):
        """Tells the Worker where Collider is now, so the unchanging link leads here."""
        ep = (self.relay.get("endpoint") or "").rstrip("/")
        if not ep:
            return
        for _ in range(5):
            try:
                req = urllib.request.Request(ep + "/set", data=json.dumps({"url": self.url}).encode(), headers={
                    "Content-Type": "application/json", "Authorization": "Key " + self.key, "User-Agent": "Collider/1.0"})
                urllib.request.urlopen(req, timeout=20).read()
                return
            except Exception as e:
                print("phone link not recorded yet", str(e)[:80])
                import time
                time.sleep(5)

    def link(self):
        if not self.url:
            return ""
        ep = (self.relay.get("endpoint") or "").rstrip("/")
        return f"{ep}/{self.key}" if ep else f"{self.url}/?k={self.key}"

    def qr(self):
        """The link as a QR picture (PNG, data URL) for the phone's camera."""
        link = self.link()
        if not link:
            return ""
        import segno
        buf = io.BytesIO()
        segno.make(link, error="m").save(buf, kind="png", scale=8, border=2, dark="#000000", light="#FFFFFF")
        return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()

    def stop(self):
        p, self._proc = self._proc, None  # ends the watch too
        if p and p.poll() is None:
            p.terminate()
