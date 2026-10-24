import os
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

APP = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WEB = os.path.join(APP, "web")
PORT = int(os.environ.get("PORT") or 8475)

class DirectorHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=WEB, **kwargs)

    def do_GET(self):
        if self.path in ("/", "/index.html") or self.path.startswith("/?"):
            self.path = "/antigravity_vision_8475.html"
        return super().do_GET()

    def log_message(self, format, *args):
        pass

server = ThreadingHTTPServer(("0.0.0.0", PORT), DirectorHandler)
print(f"Antigravity Director's Cut 8475 online on http://127.0.0.1:{PORT}/", flush=True)
server.serve_forever()
