"""Collider local server. Made by Claude.

Serves the built app, the model API and the theme catalog. Every provider, key and address comes from
data\\collider_config.json, which the launch window shows and saves (collider_config.py); keys never
leave this computer and the app only talks to this server.
Run:  python tools/collider_server.py   (asks nothing; uses the saved host number, or a free one)
"""
import json, mimetypes, os, re, sys, threading, time, uuid, urllib.request, urllib.error, webbrowser
import concurrent.futures as cf
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import collider_files as cfiles
import collider_config as ccfg

# Set by setup(): the launch window passes the folder, the built app, the data folder and the host number.
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WEB = os.path.join(ROOT, "build", "web")
DATA = os.path.join(ROOT, "data")
PORT = 0
FILES = None
HIST = ""
CONFIG = {"providers": []}
_turn = {}
_turn_lock = threading.Lock()


def setup(root, web, data, port, config):
    """Points the server at its folders, host number and configuration. Called once before serving."""
    global ROOT, WEB, DATA, PORT, FILES, HIST, CONFIG
    ROOT, WEB, DATA, PORT, CONFIG = root, web, data, int(port), config
    os.makedirs(DATA, exist_ok=True)
    FILES = cfiles.Files(DATA)
    HIST = os.path.join(DATA, "history.json")
    _extend_roster()


def rows(name=None, search=None):
    """Provider rows from the configuration that have a key, optionally only one provider's or only search."""
    out = []
    for r in CONFIG.get("providers", []):
        if not (r.get("key") or "").strip():
            continue
        if search is not None and ccfg.is_search(r) != search:
            continue
        if name is not None and (r.get("name") or "").strip().lower() != name.lower():
            continue
        out.append(r)
    return out


def next_row(name=None, search=None):
    """Round-robin over the keys of one provider, so several keys share the load."""
    rs = rows(name, search)
    if not rs:
        return None
    k = (name or "").lower() + ("/s" if search else "")
    with _turn_lock:
        _turn[k] = (_turn.get(k, -1) + 1) % len(rs)
        return rs[_turn[k]]


# Every NVIDIA chat model that answered on this account.
ROSTER = [
    {"id": "nvidia/nemotron-3-super-120b-a12b", "label": "Nemotron 3 Super", "short": "NS3", "provider": "NVIDIA", "via": "NVIDIA", "color": "#76B900"},
    {"id": "nvidia/nemotron-3-ultra-550b-a55b", "label": "Nemotron 3 Ultra", "short": "NU3", "provider": "NVIDIA", "via": "NVIDIA", "color": "#A3E635"},
    {"id": "nvidia/nemotron-3.5-lightning-30b-a3b", "label": "Nemotron 3.5 Lightning", "short": "NL35", "provider": "NVIDIA", "via": "NVIDIA", "color": "#4ADE80"},
    {"id": "z-ai/glm-5.3", "label": "GLM 5.3", "short": "GLM", "provider": "Z.ai", "via": "NVIDIA", "color": "#60A5FA"},
    {"id": "z-ai/glm-5.3-flash", "label": "GLM 5.3 Flash", "short": "GLMF", "provider": "Z.ai", "via": "NVIDIA", "color": "#93C5FD"},
    {"id": "google/gemma-4-31b-it", "label": "Gemma 4 31B", "short": "G4", "provider": "Google", "via": "NVIDIA", "color": "#FBBF24"},
    {"id": "mistralai/mistral-nemotron", "label": "Mistral Nemotron", "short": "MN", "provider": "Mistral", "via": "NVIDIA", "color": "#FB923C"},
    {"id": "openai/gpt-oss-20b", "label": "GPT OSS 20B", "short": "OSS", "provider": "OpenAI", "via": "NVIDIA", "color": "#34D399"},
    {"id": "meta/muse-glimmer-30b", "label": "Muse Glimmer 30B", "short": "MG", "provider": "Meta", "via": "NVIDIA", "color": "#818CF8"},
    {"id": "deepseek-ai/deepseek-v4.1-flash", "label": "DeepSeek V4.1 Flash", "short": "DS4", "provider": "DeepSeek", "via": "NVIDIA", "color": "#38BDF8"},
    {"id": "meta/llama-3.2-90b-vision-instruct", "label": "Llama 3.2 90B Vision", "short": "L90", "provider": "Meta", "via": "NVIDIA", "color": "#A78BFA"},
    {"id": "meta/llama-3.2-11b-vision-instruct", "label": "Llama 3.2 11B Vision", "short": "L11", "provider": "Meta", "via": "NVIDIA", "color": "#C4B5FD"},
    # Listed last: on this account it currently returns repeated characters instead of answers.
    {"id": "moonshotai/kimi-k3", "label": "Kimi K3", "short": "K3", "provider": "Moonshot", "via": "NVIDIA", "color": "#F472B6"},
]
CONSENSUS_AGENT = "google/gemma-4-31b-it"
LABEL = {m["id"]: m["label"] for m in ROSTER}
_BUILT_IN = len(ROSTER)
_COLORS = ["#F59E0B", "#EC4899", "#14B8A6", "#8B5CF6", "#EF4444", "#22D3EE", "#84CC16", "#F97316"]


def _extend_roster():
    """Models listed against a provider in the configuration join the roster, answered through that provider."""
    del ROSTER[_BUILT_IN:]
    known = {m["id"] for m in ROSTER}
    for r in rows(search=False):
        for mid in ccfg.models_of(r):
            if mid in known:
                continue
            known.add(mid)
            label = mid.split("/")[-1]
            ROSTER.append({"id": mid, "label": label, "short": label[:4].upper(), "provider": r["name"], "via": r["name"],
                           "color": _COLORS[len(ROSTER) % len(_COLORS)]})
            LABEL[mid] = label


def uses(row):
    """Where in the app a provider row is read, for the launch window."""
    if ccfg.is_search(row):
        return "Web sources for Internet, Research and Deep Research (/api/ask); search answers in the browser (/api/page)"
    name = (row.get("name") or "").strip()
    ms = [m["label"] for m in ROSTER if m.get("via", "").lower() == name.lower()]
    ms += [m.split("/")[-1] for m in ccfg.models_of(row) if m.split("/")[-1] not in ms]
    if not ms:
        return "Nothing yet: list model names in Models"
    parts = [f"{len(ms)} models' answers (/api/ask) and replies (/api/reply)"]
    agent = next((m for m in ROSTER if m["id"] == CONSENSUS_AGENT), None)
    if agent and agent.get("via", "").lower() == name.lower():
        parts.append("the consensus and one-line summaries (/api/lines)")
    return "; ".join(parts) + ": " + ", ".join(ms)

DEPTH = {
    "chat": "Answer directly and concisely. Plain language, no jargon.",
    "internet": "Answer directly using the web sources provided. Cite sources inline as [n]. Plain language, no jargon.",
    "research": ("Write a research report: a one-paragraph answer first, then short sections with headings covering the evidence, "
                 "the trade-offs and a clear recommendation. Cite sources inline as [n] and end with a numbered source list. "
                 "Plain language, no jargon."),
    "deep": ("Write an annotated research paper: an abstract that states the answer, then numbered sections in which every claim "
             "carries its source [n] and a short note on why it matters or how strong the evidence is, a section on where the "
             "sources disagree, and a conclusion with practical next steps. More insight, no jargon: explain anything technical "
             "in everyday words. End with a numbered source list."),
}
SEARCH = {"internet": ("basic", 5), "research": ("advanced", 8), "deep": ("advanced", 12)}
MAX_TOKENS = {"chat": 900, "internet": 1200, "research": 2400, "deep": 4000}


def post_json(url, payload, headers, timeout):
    req = urllib.request.Request(url, data=json.dumps(payload).encode(), headers={"Content-Type": "application/json", **headers})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.load(r)


def search_results(query, n=10):
    """Plain web results for the in-app browser."""
    try:
        row = next_row(search=True)
        r = post_json(row["endpoint"], {"api_key": row["key"].strip(), "query": query, "search_depth": "basic", "max_results": n}, {}, 30)
        return [{"title": x.get("title", ""), "url": x.get("url", ""), "content": x.get("content") or ""} for x in r.get("results", [])]
    except Exception:
        return []


def web_search(query, mode):
    row = next_row(search=True)
    if mode not in SEARCH or not row:
        return []
    depth, n = SEARCH[mode]
    try:
        r = post_json(row["endpoint"], {"api_key": row["key"].strip(), "query": query, "search_depth": depth, "max_results": n}, {}, 40)
        return [{"title": x.get("title", ""), "url": x.get("url", ""), "content": (x.get("content") or "")[:1200]}
                for x in r.get("results", [])]
    except Exception as e:
        print("search error", e)
        return []


def call_model(model, messages, max_tokens, timeout=150):
    via = next((m.get("via") for m in ROSTER if m["id"] == model), "NVIDIA")
    last = None
    for attempt in range(2):
        row = next_row(via, search=False)
        if not row:
            raise RuntimeError(f"no key for {via}")
        try:
            r = post_json(row["endpoint"], {"model": model, "messages": messages, "max_tokens": max_tokens, "temperature": 0.4},
                          {"Authorization": "Bearer " + row["key"].strip()}, timeout)
            msg = r["choices"][0]["message"]
            text = (msg.get("content") or "").strip()
            if not text:
                text = (msg.get("reasoning_content") or "").strip()
            text = re.sub(r"<think>.*?</think>", "", text, flags=re.S).strip()
            if text:
                return text
            last = "empty reply"
        except urllib.error.HTTPError as e:
            last = f"HTTP {e.code}"
        except Exception as e:
            last = str(e)[:80]
            if "timed out" in last:
                break  # a slow model is not retried; the others carry on
        time.sleep(1.5)
    raise RuntimeError(last or "no reply")


def sources_block(sources):
    if not sources:
        return ""
    lines = [f"[{i + 1}] {s['title']} — {s['url']}\n{s['content']}" for i, s in enumerate(sources)]
    return "Web sources:\n\n" + "\n\n".join(lines)


# ---------------- Consensus agent (Consensus Map v3: a headcount of essences) ----------------
# Primary agent answers in plain JSON; the reasoning models are backups with room to think.
AGENT_CHAIN = [CONSENSUS_AGENT, "nvidia/nemotron-3-super-120b-a12b", "z-ai/glm-5.3"]
AGENT_PROMPT = """detailed thinking off
You are the Collider consensus agent. Consensus is a headcount: how many responses say essentially the same thing.
Steps:
1. Read the question and derive the need behind it.
2. Reduce each response to its essence: what it says, as one standalone sentence (occasionally two) in service of that need.
   Not a description of the response. Never mention which model produced it.
3. Group responses whose essences say the same thing. The largest group is the consensus.
4. The summary IS the winning group's essence, copied verbatim. Do not rewrite or blend.
5. Every other group's essence is a dissenting view, verbatim.
6. score = size of the largest group / number of responses.
On a tie you may choose, and state the logical basis in one line as tie_basis.
7. Separately, count the logical chains in each RAW response (not the essence): every explicit connective
   (because, so, therefore, thus, hence, as a result) and every instance of implied logic (a definition used to support
   a claim, a clarification that adds meaning, a preemptive challenge to a presumption).
8. For each response also write its line: the complete answer in at most {n} characters, spaces included.
   The conclusion itself, stated outright in plain words. Never a teaser, never "it depends", never cut off.
   No full stop at the end. Responses in the same group share the same line, word for word.
   Different groups get different lines that show how they differ.
Return ONLY JSON:
{"need": "...", "essences": {"R1": "...", "R2": "..."}, "lines": {"R1": "...", "R2": "..."}, "chains": {"R1": 4, "R2": 2}, "groups": [["R1","R3"],["R2"]], "summary": "...", "score": "2/3", "dissent": ["..."], "tie_basis": ""}"""


def parse_json(text):
    text = re.sub(r"```(?:json)?", "", text)
    starts = [i for i, ch in enumerate(text) if ch == "{"]
    for s in starts:  # first balanced object that parses
        depth = 0
        for j in range(s, len(text)):
            if text[j] == "{":
                depth += 1
            elif text[j] == "}":
                depth -= 1
                if depth == 0:
                    try:
                        obj = json.loads(text[s:j + 1])
                        if isinstance(obj, dict) and "essences" in obj:
                            return obj
                    except Exception:
                        pass
                    break
    raise ValueError("no json")


def run_consensus(prompt, answers, n=28):
    """answers: {model_id: text}. Returns dict with essences keyed by model id."""
    ids = list(answers.keys())
    tags = {f"R{i + 1}": mid for i, mid in enumerate(ids)}
    body = "\n\n".join(f"{t}:\n{answers[mid][:2200]}" for t, mid in tags.items())
    msgs = [{"role": "system", "content": AGENT_PROMPT.replace("{n}", str(n))},
            {"role": "user", "content": f"Question:\n{prompt}\n\nResponses:\n\n{body}"}]
    for agent in AGENT_CHAIN:
        try:
            out = parse_json(call_model(agent, msgs, 2500 if agent == CONSENSUS_AGENT else 9000, timeout=110))
            ess = {tags[t]: e for t, e in (out.get("essences") or {}).items() if t in tags}
            if not ess:
                raise ValueError("no essences")
            groups = [[tags[t] for t in g if t in tags] for g in out.get("groups") or []]
            chains = {tags[t]: int(n) for t, n in (out.get("chains") or {}).items() if t in tags and str(n).isdigit()}
            lines = {tags[t]: e for t, e in (out.get("lines") or {}).items() if t in tags}
            return {"status": "done", "agent": agent, "need": out.get("need", ""), "essences": ess, "chains": chains, "lines": lines,
                    "groups": groups, "summary": out.get("summary", ""), "score": out.get("score", ""),
                    "dissent": out.get("dissent") or [], "tie_basis": out.get("tie_basis", "")}
        except Exception as e:
            print("consensus agent failed", agent, e)
    return None


def plain(s):
    """A summary sentence without markdown marks."""
    return re.sub(r"^\s*(#+|[-*>])\s+", "", re.sub(r"\*\*|__|`", "", str(s or ""))).strip()


def self_essence(model, prompt, answer):
    msgs = [{"role": "system", "content": "Reduce the answer below to its essence: one standalone sentence stating what it says, "
                                          "in service of the question's need. Never mention who wrote it. Reply with the sentence only."},
            {"role": "user", "content": f"Question: {prompt}\n\nAnswer:\n{answer[:3500]}"}]
    try:
        return call_model(model, msgs, 200, timeout=60).split("\n")[0].strip()
    except Exception:
        first = re.split(r"(?<=[.!?])\s", answer.strip(), maxsplit=1)[0]
        return first[:240]


# ---------------- One line ----------------
# Every ticker row and the consensus preview shows ONE line: the complete answer, never cut, fitting its box.
# The app measures its box and sends the length. The consensus agent writes the line for every row (primary);
# each model also writes its own at the top of its answer (backup, shown while the agent is still working).
# The length is checked here: a line that is over is never shown.
LINE_DEFAULT = 28
LINE_RULE = ("Begin your reply with one line of at most {n} characters, spaces included, that is the complete answer itself: "
             "the conclusion, stated outright in plain words, with no full stop. Then an empty line. Then the full answer.")
LINES_PROMPT = """detailed thinking off
For each response below, write its line: the complete answer to the question in at most {n} characters, spaces included.
The conclusion itself, stated outright in plain words. Never a teaser, never "it depends", never cut off.
No full stop at the end. Responses listed together under Groups agree: they share one line, word for word.
Responses in different groups disagree: their lines must show how they differ.
Return ONLY JSON: {"lines": {"R1": "...", "R2": "..."}}"""


def line_budget(v):
    try:
        return max(18, min(72, int(v)))
    except Exception:
        return LINE_DEFAULT


def clean_line(t):
    t = plain(str(t or "").strip().split("\n")[0]).strip(" \"'")
    return t.replace("\u2026", "").replace("...", "").rstrip(". ").strip()


def fit_words(t, n):
    """Last resort when nobody wrote a line that fits: whole words that fit, nothing left dangling."""
    t = clean_line(t)
    if len(t) <= n:
        return t
    cut = t[:n + 1]
    cut = cut[:cut.rfind(" ")] if " " in cut else t[:n]
    while True:
        new = re.sub(r"(?i)[\s,;:(\-\u2013\u2014]+$|\s+(and|or|the|a|an|to|of|for|with|in|on|at|by|is|are|that|which)$", "", cut)
        if new == cut:
            return cut
        cut = new


def split_line(text, n):
    """A model's reply -> (its own line, the full answer). The line is taken only when it fits."""
    rows = str(text or "").strip().split("\n")
    first = clean_line(rows[0])
    rest = "\n".join(rows[1:]).strip()
    if first and len(first) <= n:
        return first, (rest or first)
    sentence = re.split(r"(?<=[.!?])\s", plain(rows[0]).strip(), maxsplit=1)[0]
    return fit_words(sentence, n), str(text or "").strip()


def agent_lines(prompt, answers, n, groups=None):
    """One pass of the consensus agent over saved answers -> {model_id: line}. Only lines that fit are returned."""
    ids = list(answers.keys())
    tags = {f"R{i + 1}": mid for i, mid in enumerate(ids)}
    back = {mid: t for t, mid in tags.items()}
    grouped = [[back[m] for m in g if m in back] for g in (groups or [])]
    grouped = [g for g in grouped if g]
    seen = {t for g in grouped for t in g}
    grouped += [[t] for t in tags if t not in seen]
    body = "\n\n".join(f"{t}:\n{answers[mid][:2200]}" for t, mid in tags.items())
    msgs = [{"role": "system", "content": LINES_PROMPT.replace("{n}", str(n))},
            {"role": "user", "content": f"Question:\n{prompt}\n\nGroups: {json.dumps(grouped)}\n\nResponses:\n\n{body}"}]
    for agent in AGENT_CHAIN:
        try:
            raw = call_model(agent, msgs, 900 if agent == CONSENSUS_AGENT else 6000, timeout=90)
            m = re.search(r"\{.*\}", re.sub(r"```(?:json)?", "", raw), flags=re.S)
            out = json.loads(m.group(0)).get("lines") or {}
            got = {tags[t]: clean_line(v) for t, v in out.items() if t in tags}
            got = {k: v for k, v in got.items() if v and len(v) <= n}
            if got:
                return got
        except Exception as e:
            print("agent lines failed", agent, e)
    return {}


def consensus_line(sess, n):
    """The consensus preview is the winning group's line, verbatim, so it matches a card word for word."""
    cons, results = sess.get("consensus") or {}, sess.get("results") or {}
    has = lambda m: bool((results.get(m) or {}).get("line")) and len(results[m]["line"]) <= n
    for m, e in (cons.get("essences") or {}).items():
        if plain(e) == plain(cons.get("summary")) and has(m):
            return results[m]["line"]
    groups = sorted(cons.get("groups") or [], key=len, reverse=True)
    for m in (groups[0] if groups else []):
        if has(m):
            return results[m]["line"]
    return fit_words(cons.get("summary", ""), n)


# ---------------- History ----------------
_hist_lock = threading.Lock()


def load_history():
    try:
        return json.load(open(HIST, encoding="utf-8"))
    except Exception:
        return []


def save_session(job):
    with _hist_lock:
        h = load_history()
        h = [s for s in h if s.get("id") != job["id"]]
        h.insert(0, {k: job.get(k) for k in ("id", "prompt", "mode", "created", "models", "results", "consensus", "sources", "line_chars")})
        json.dump(h[:200], open(HIST, "w", encoding="utf-8"), ensure_ascii=False)


def ensure_lines(body):
    """Fills in the one-line form where a session has none, or has one made for a wider box. Answers stay as they are."""
    n, sid = line_budget(body.get("line")), body.get("id")
    job = JOBS.get(sid)
    sess = job or next((x for x in load_history() if x.get("id") == sid), None)
    if not sess:
        return {"error": "not found"}
    res = sess.get("results") or {}
    done = {m: r["text"] for m, r in res.items() if r.get("status") == "done" and r.get("text")}
    todo = [m for m in done if not (res[m].get("line") and len(res[m]["line"]) <= n)]
    if todo:
        got = agent_lines(sess.get("prompt", ""), done, n, (sess.get("consensus") or {}).get("groups"))
        for m in todo:
            res[m]["line"] = got.get(m) or fit_words(res[m].get("essence") or done[m], n)
    cons = sess.get("consensus") or {}
    if cons.get("status") == "done" and (todo or not (cons.get("line") and len(cons["line"]) <= n)):
        cons["line"] = consensus_line(sess, n)
    sess["line_chars"] = n
    with _hist_lock:
        h = load_history()
        if any(x.get("id") == sid for x in h):
            keep = ("id", "prompt", "mode", "created", "models", "results", "consensus", "sources", "line_chars")
            h = [({k: sess.get(k) for k in keep} if x.get("id") == sid else x) for x in h]
            json.dump(h[:200], open(HIST, "w", encoding="utf-8"), ensure_ascii=False)
    return {**{k: sess.get(k) for k in ("id", "prompt", "mode", "created", "results", "consensus", "sources")}, "status": "done"}


# ---------------- Jobs ----------------
JOBS = {}
POOL = cf.ThreadPoolExecutor(32)


def run_job(job):
    prompt, mode = job["prompt"], job["mode"]
    if mode in SEARCH:
        job["stage"] = "searching"
        job["sources"] = web_search(prompt, mode)
    job["stage"] = "answering"
    n = job["line_chars"]
    system = DEPTH.get(mode, DEPTH["chat"]) + "\n\n" + LINE_RULE.replace("{n}", str(n))
    src = sources_block(job["sources"])
    attached = FILES.attachment_text(job.get("attachments"))
    asked = prompt + ("\n\n" + attached if attached else "")

    def one(mid):
        t0 = time.time()
        msgs = [{"role": "system", "content": system + ("\n\n" + src if src else "")}, {"role": "user", "content": asked}]
        try:
            line, text = split_line(call_model(mid, msgs, MAX_TOKENS.get(mode, 1200)), n)
            job["results"][mid].update(status="done", text=text, line=line, ms=int((time.time() - t0) * 1000))
        except Exception as e:
            job["results"][mid].update(status="error", text="", error=str(e), ms=int((time.time() - t0) * 1000))

    # Every model gets the same deadline; one slow model never holds the others back.
    deadline = {"chat": 100, "internet": 120, "research": 180, "deep": 240}.get(mode, 120)
    futs = [POOL.submit(one, m) for m in job["models"]]
    cf.wait(futs, timeout=deadline)
    for m, r in job["results"].items():
        if r["status"] == "pending":
            r.update(status="error", error="no answer in time")
    answers = {m: r["text"] for m, r in job["results"].items() if r["status"] == "done" and r["text"]}
    job["stage"] = "consensus"
    cons = run_consensus(prompt, answers, n) if answers else None
    if cons:
        for mid, e in cons["essences"].items():
            job["results"][mid]["essence"] = plain(e)
        for mid, e in (cons.pop("lines", None) or {}).items():
            e = clean_line(e)
            if e and len(e) <= n and mid in job["results"]:
                job["results"][mid]["line"] = e
        cons["summary"] = plain(cons.get("summary"))
        cons["line"] = consensus_line({"consensus": cons, "results": job["results"]}, n)
        job["consensus"] = cons
    missing = [m for m in answers if not job["results"][m].get("essence")]
    for mid, e in zip(missing, POOL.map(lambda m: self_essence(m, prompt, answers[m]), missing)):
        job["results"][mid]["essence"] = plain(e)
    if not cons:
        job["consensus"] = {"status": "unavailable", "summary": "", "score": f"{len(answers)} answered", "dissent": []}
    job["stage"] = "done"
    job["status"] = "done"
    if job.get("save") and not job.get("incognito"):
        save_session(job)


def new_job(body):
    models = [m for m in body.get("models", []) if m in LABEL] or [ROSTER[0]["id"]]
    job = {"id": uuid.uuid4().hex[:12], "prompt": body.get("prompt", "").strip(), "mode": body.get("mode", "chat"),
           "created": time.time(), "models": models, "status": "running", "stage": "queued", "sources": [],
           "results": {m: {"status": "pending", "text": "", "essence": "", "line": ""} for m in models},
           "line_chars": line_budget(body.get("line")),
           "consensus": {"status": "pending"}, "save": body.get("autosave", True), "incognito": body.get("incognito", False),
           "attachments": [str(a) for a in body.get("attachments", [])][:12]}
    JOBS[job["id"]] = job
    threading.Thread(target=run_job, args=(job,), daemon=True).start()
    return job


def reply(body):
    mid = body.get("model")
    n = line_budget(body.get("line"))
    msgs = [{"role": "system", "content": DEPTH.get(body.get("mode", "chat"), DEPTH["chat"]) + "\n\n" + LINE_RULE.replace("{n}", str(n))}] + body.get("messages", [])
    attached = FILES.attachment_text(body.get("attachments"))
    if attached and msgs[-1].get("role") == "user":
        msgs[-1] = {"role": "user", "content": msgs[-1]["content"] + "\n\n" + attached}
    line, text = split_line(call_model(mid, msgs, 1400), n)
    return {"text": text, "essence": line, "line": line}


# ---------------- Themes ----------------
# The live wallpapers live in David's Cloudflare R2 bucket "collider-themes"; its Worker lists every object (name, kind,
# public URL, tags). Each wallpaper is numbered and titled in the bucket itself (Claude, 2026-10-17):
#   "007 Late Night on the Phone.mp4"   the wallpaper
#   "007 Late Night on the Phone.jpg"   its poster, beside it so the bucket shows it
#   "007 Late Night on the Phone.m4a"   its song, when it has one
# The number keeps the three together and sets the order; the app shows the title only.
_themes_cache = {"at": 0, "data": []}
_themes_lock = threading.Lock()
_NUMBERED = re.compile(r"^(\d{3}) (.+)\.([A-Za-z0-9]+)$")


def _get_json(url, timeout=25):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 Collider"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.load(r)


PACK_PRICE = "$4.99"      # shown until the store returns its own, local price
TRACKS_PER_PACK = 5


def themes():
    with _themes_lock:
        if _themes_cache["data"] and time.time() - _themes_cache["at"] < 600:
            return _themes_cache["data"]
    cache = os.path.join(DATA, "themes_cache.json")
    try:
        listing = _get_json(CONFIG.get("themes") or ccfg.THEMES)
    except Exception as e:
        print("themes:", e)
        try:
            return json.load(open(cache, encoding="utf-8"))
        except Exception:
            return []
    parts = {}
    for o in listing:
        m = _NUMBERED.match(o["name"])
        if not m:
            continue
        t = parts.setdefault(m.group(1), {"title": m.group(2)})
        t.setdefault(o.get("kind"), o)
    def kind(tags):
        """The wallpaper's category tag (cozy, city, abstract...), not its resolution or file type."""
        return next((x for x in tags or [] if x not in ("live wallpaper", "mp4") and not re.match(r"^\d+p$", x)), "")

    songs = [(int(n), parts[n]["title"], parts[n]["audio"]["url"], kind((parts[n].get("video") or {}).get("tags")))
             for n in sorted(parts) if parts[n].get("audio")]
    out = []
    for num in sorted(parts):
        t = parts[num]
        v = t.get("video")
        if not v:
            continue
        k, n = kind(v.get("tags")), int(num)
        # A pack's preview tracks: its own song first, then the songs of the same kind of wallpaper, then the nearest.
        picks = sorted(songs, key=lambda s: (s[0] != n, s[3] != k, abs(s[0] - n)))[:TRACKS_PER_PACK]
        out.append({
            "id": num,
            "name": t["title"],
            "video": v["url"],
            "poster": t["image"]["url"] if t.get("image") else None,
            "tags": v.get("tags") or [],
            "price": PACK_PRICE,
            "productId": "collider.theme." + num,
            "tracks": [{"title": s[1], "url": s[2]} for s in picks],
        })
    with _themes_lock:
        _themes_cache.update(at=time.time(), data=out)
    try:
        json.dump(out, open(cache, "w", encoding="utf-8"), ensure_ascii=False)
    except Exception:
        pass
    return out


# ---------------- HTTP ----------------
class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *a, **k):
        super().__init__(*a, directory=WEB, **k)

    def log_message(self, *a):
        pass

    def _json(self, obj, code=200):
        data = json.dumps(obj, ensure_ascii=False).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _body(self):
        n = int(self.headers.get("Content-Length") or 0)
        return json.loads(self.rfile.read(n) or b"{}")

    def do_GET(self):
        p = self.path.split("?")[0]
        if p == "/api/whoami":
            return self._json({"root": ROOT, "port": PORT})
        if p == "/api/models":
            return self._json({"models": ROSTER, "agent": CONSENSUS_AGENT, "search": bool(rows(search=True))})
        if p == "/api/themes":
            return self._json(themes())
        if p == "/api/store":
            return self._json({"bypass": bool(CONFIG.get("store_bypass", True))})
        if p.startswith("/api/job/"):
            job = JOBS.get(p.rsplit("/", 1)[-1])
            return self._json(job or {"error": "not found"}, 200 if job else 404)
        if p == "/api/jobs":
            return self._json([{"id": j["id"], "stage": j["stage"], "status": j["status"], "save": j.get("save"),
                                "results": {m: r["status"] for m, r in j["results"].items()}} for j in JOBS.values()])
        if p == "/api/history":
            return self._json({"sessions": load_history()})
        if p == "/api/page":
            return self._page()
        if p == "/api/fetch":
            return self._fetch()
        if p == "/api/files":
            return self._json(FILES.listing())
        if p.startswith("/files/"):
            return self._file(p)
        static = self.translate_path(self.path)
        if self.headers.get("Range") and os.path.isfile(static) and self._part(static):
            return
        return super().do_GET()

    def _part(self, path):
        """Sound and video jump to a point in the file by asking for part of it."""
        m = re.match(r"bytes=(\d*)-(\d*)$", (self.headers.get("Range") or "").strip())
        if not m or (m.group(1) == "" and m.group(2) == ""):
            return False
        size = os.path.getsize(path)
        if m.group(1) == "":
            start, end = max(0, size - int(m.group(2))), size - 1
        else:
            start, end = int(m.group(1)), min(int(m.group(2)) if m.group(2) else size - 1, size - 1)
        if start > end or start >= size:
            self.send_response(416)
            self.send_header("Content-Range", f"bytes */{size}")
            self.end_headers()
            return True
        with open(path, "rb") as f:
            f.seek(start)
            data = f.read(end - start + 1)
        self.send_response(206)
        self.send_header("Content-Type", mimetypes.guess_type(path)[0] or "application/octet-stream")
        self.send_header("Accept-Ranges", "bytes")
        self.send_header("Content-Range", f"bytes {start}-{end}/{size}")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)
        return True

    def _file(self, p):
        parts = p.split("/", 3)
        path = FILES.path_for(parts[2], parts[3]) if len(parts) == 4 else None
        if not path:
            return self._json({"error": "not found"}, 404)
        if self.headers.get("Range") and self._part(path):
            return
        data = open(path, "rb").read()
        self.send_response(200)
        self.send_header("Content-Type", mimetypes.guess_type(path)[0] or "application/octet-stream")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _send(self, code, ctype, data):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _target(self):
        from urllib.parse import urlparse, parse_qs
        url = (parse_qs(urlparse(self.path).query).get("url") or [""])[0]
        return url if re.match(r"^https?://", url) else "https://" + url

    def _mobile(self):
        """The app says in a cookie when its window is phone-sized; sites are then asked for their phone pages."""
        return "collider_ua=mobile" in (self.headers.get("Cookie") or "")

    def _fetch(self, method="GET"):
        """Script requests made by a proxied page come through here so they are not blocked as cross-site."""
        body = self.rfile.read(int(self.headers.get("Content-Length") or 0)) if method != "GET" else None
        try:
            code, _, headers, data = cfiles.fetch(self._target(), method, body, self.headers.get("Content-Type"), mobile=self._mobile())
            self._send(code or 200, headers.get("Content-Type") or "application/octet-stream", data)
        except Exception as e:
            self._send(502, "text/plain; charset=utf-8", str(e)[:200].encode())

    def _page(self, method="GET"):
        """In-app browser: fetch the page here so sites that refuse framing still render, keep links, forms
        and script requests inside the app, and save anything that is a file to Files > Downloaded."""
        url = self._target()
        body = self.rfile.read(int(self.headers.get("Content-Length") or 0)) if method != "GET" else None
        try:
            code, final, headers, data = cfiles.fetch_page(url, method, body, self.headers.get("Content-Type"), mobile=self._mobile())
        except Exception as e:
            return self._send(200, "text/html; charset=utf-8", cfiles.error_page(url, str(e)).encode())
        ctype = headers.get("Content-Type") or "text/html"
        if cfiles.is_download(headers):
            name = FILES.save_download(cfiles.download_name(final, headers, data), data)
            return self._send(200, "text/html; charset=utf-8", cfiles.saved_page(name).encode())
        if "html" in ctype.lower():
            text = cfiles.decode_html(data, headers)
            if rows(search=True) and cfiles.is_search_challenge(final, text):
                # The search engine is asking for a puzzle; answer the search from the web-search key instead.
                q = cfiles.search_query(final, body)
                found = search_results(q) if q else []
                if found:
                    text = cfiles.results_page(q, found)
            html = cfiles.prepare_html(text, final.replace('"', "%22"))
            return self._send(200, "text/html; charset=utf-8", html.encode("utf-8"))
        self._send(200, ctype, data)

    def do_POST(self):
        p = self.path.split("?")[0]
        try:
            if p == "/api/ask":
                job = new_job(self._body())
                return self._json({"id": job["id"]})
            if p == "/api/reply":
                return self._json(reply(self._body()))
            if p == "/api/lines":
                return self._json(ensure_lines(self._body()))
            if p == "/api/page":
                return self._page("POST")
            if p == "/api/fetch":
                return self._fetch("POST")
            if p == "/api/files/upload":
                b = self._body()
                return self._json({"name": FILES.save_upload(b.get("name", "file"), b.get("b64", ""))})
            if p == "/api/files/generated":
                b = self._body()
                return self._json({"name": FILES.save_generated(b.get("name", "note.md"), b.get("text", ""))})
            if p == "/api/files/download":
                url = self._body().get("url", "")
                code, final, headers, data = cfiles.fetch(url)
                if code and code >= 400:
                    return self._json({"error": f"HTTP {code}"}, 502)
                return self._json({"name": FILES.save_download(cfiles.download_name(final, headers), data)})
        except Exception as e:
            return self._json({"error": str(e)}, 500)
        self._json({"error": "unknown"}, 404)


def main():
    """Run from the project folder without the launch window: the saved configuration and host number, or a free one."""
    import socket
    cfg = ccfg.load(DATA)
    s = socket.socket()
    try:
        s.bind(("127.0.0.1", int(cfg.get("host") or 0)))
    except (OSError, ValueError):
        s.close()
        s = socket.socket()
        s.bind(("127.0.0.1", 0))
    port = s.getsockname()[1]
    s.close()
    setup(ROOT, WEB, DATA, port, cfg)
    srv = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    url = f"http://127.0.0.1:{PORT}/"
    print(f"Collider running at {url}")
    if "--no-open" not in sys.argv:
        threading.Timer(1.0, lambda: webbrowser.open(url)).start()
    srv.serve_forever()


if __name__ == "__main__":
    main()
