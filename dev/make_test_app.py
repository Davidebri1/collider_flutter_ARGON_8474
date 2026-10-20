# Made by Claude (2026-10-20). A throwaway copy of the app in dev\test_app with sample files, so Files can be checked
# without putting anything into David's own Files. Never used by Collider.exe.
import json, os, shutil
here = os.path.dirname(os.path.abspath(__file__))
src = os.path.dirname(here)
dst = os.path.join(here, "test_app")
shutil.rmtree(dst, ignore_errors=True)
shutil.copytree(os.path.join(src, "tools"), os.path.join(dst, "tools"), ignore=shutil.ignore_patterns("__pycache__"))
shutil.copytree(os.path.join(src, "build", "web"), os.path.join(dst, "build", "web"))
os.makedirs(os.path.join(dst, "data"), exist_ok=True)
shutil.copy(os.path.join(src, "data", "collider_config.json"), os.path.join(dst, "data"))
f = os.path.join(dst, "data", "files")
for s in ("uploaded", "generated", "downloaded"):
    os.makedirs(os.path.join(f, s), exist_ok=True)
gen = {
    "GLM 5.3 - launch plan.md": "# Launch plan\n",
    "Research - lantern history - Gemma 4 31B.md": "# Lanterns\n",
    "Nemotron 3 Ultra - pricing notes.md": "# Pricing\n",
    "Quarterly plan.docx": None,
}
for n, t in gen.items():
    p = os.path.join(f, "generated", n)
    if t is None:
        shutil.copy(os.path.join(here, "editor", "test_out", next(x for x in os.listdir(os.path.join(here, "editor", "test_out")) if x.endswith(".docx"))), p)
    else:
        open(p, "w", encoding="utf-8").write(t)
json.dump({"Quarterly plan.docx": "Documents"}, open(os.path.join(f, ".models.json"), "w"))
up = os.path.join(f, "uploaded")
open(os.path.join(up, "budget.csv"), "w").write("a,b\n1,2\n")
open(os.path.join(up, "settings.json"), "w").write("{}")
open(os.path.join(up, "script.py"), "w").write("print(1)\n")
shutil.copy(os.path.join(src, "assets", "icons", "apps", "claude_app_discover.png"), os.path.join(up, "picture.png"))
pdf = next((x for x in os.listdir(os.path.join(here, "editor", "test_out")) if x.endswith(".pdf")), None)
if pdf:
    shutil.copy(os.path.join(here, "editor", "test_out", pdf), os.path.join(up, "report.pdf"))
open(os.path.join(f, "downloaded", "archive.zip"), "wb").write(b"PK\x05\x06" + bytes(18))
open(os.path.join(f, "downloaded", "deck.pptx"), "wb").write(b"PK")
print("ok", dst)
