"""Collider local server. Made by Claude. Signed: Claude (2026-10-20). Restored by DeepSeek V4.1 Flash (2026-10-23).

Serves the built app, the model API and the theme catalog. Every provider, key and address comes from
data\\collider_config.json, which the launch window shows and saves (collider_config.py); keys never
leave this computer and the app only talks to this server.
Run:  python tools/collider_server.py   (asks nothing; uses the saved host number, or a free one)
"""
import base64, json, mimetypes, os, re, sys, threading, time, uuid, urllib.request, urllib.error, webbrowser
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
SMARTGEN_FILE = ""
CONFIG = {"providers": []}
_turn = {}
_turn_lock = threading.Lock()
_history_mem = None
_smartgen_mem = None


def setup(root, web, data, port, config):
    """Points the server at its folders, host number and configuration. Called once before serving."""
    global ROOT, WEB, DATA, PORT, FILES, HIST, SMARTGEN_FILE, CONFIG, _history_mem, _smartgen_mem
    ROOT, WEB, DATA, PORT, CONFIG = root, web, data, int(port), config
    os.makedirs(DATA, exist_ok=True)
    FILES = cfiles.Files(DATA)
    HIST = os.path.join(DATA, "history.json")
    SMARTGEN_FILE = os.path.join(DATA, "smartgen_cards.json")
    if apply_settings(CONFIG):
        try:
            ccfg.save(DATA, CONFIG)  # the file then shows every line
        except Exception as e:
            print("config save failed", e)
    _extend_roster()
    _init_caches()


def _init_caches():
    """Preload themes_cache.json, history.json (sanitizing any legacy reasoning leaks), and smartgen_cards.json into RAM."""
    global _history_mem, _smartgen_mem
    cache_path = os.path.join(DATA, "themes_cache.json")
    if os.path.isfile(cache_path):
        try:
            with _themes_lock:
                _themes_cache["data"] = json.load(open(cache_path, encoding="utf-8"))
                _themes_cache["at"] = time.time()
        except Exception:
            pass
    threading.Thread(target=_refresh_themes_bg, daemon=True).start()

    try:
        raw_hist = json.load(open(HIST, encoding="utf-8")) if os.path.isfile(HIST) else []
    except Exception:
        raw_hist = []
    dirty = False
    for sess in raw_hist:
        n = line_budget(sess.get("line_chars") or LINE_DEFAULT)
        prompt = sess.get("prompt") or ""
        cons = sess.get("consensus") or {}
        cons_summary = (cons.get("summary") or "").strip()
        res = sess.get("results") or {}
        for mid, r in res.items():
            txt = r.get("text") or ""
            cleaned = sanitize_model_output(txt)
            if txt and not cleaned and cons_summary:
                cleaned = cons_summary
            if cleaned != txt:
                r["text"] = cleaned
                r["essence"] = self_essence_fallback(cleaned) if cleaned else ""
                r["line"] = fit_words(r["essence"], n) if r["essence"] else ""
                r.pop("error", None)
                if r.get("messages") and len(r["messages"]) >= 2:
                    r["messages"][-1]["content"] = cleaned
                dirty = True
            if r.get("line") and ("thinking process" in r["line"].lower() or len(r["line"]) > n):
                r["line"] = fit_words(r.get("essence") or r.get("text") or cons_summary, n)
                dirty = True
            if not r.get("messages") and r.get("status") == "done" and r.get("text"):
                r["messages"] = [
                    {"role": "user", "content": prompt},
                    {"role": "assistant", "content": r["text"]},
                ]
                dirty = True
        if cons.get("essences"):
            for mid, e in list(cons["essences"].items()):
                ce = sanitize_model_output(e)
                if "internal monologue" in ce.lower() or "incomplete" in ce.lower():
                    ce = cons_summary or ce
                if ce != e:
                    cons["essences"][mid] = plain(ce)
                    dirty = True
        if cons.get("dissent"):
            new_dissent = [
                plain(sanitize_model_output(d))
                for d in cons["dissent"]
                if "internal monologue" not in d.lower() and "incomplete" not in d.lower()
            ]
            if new_dissent != cons["dissent"]:
                cons["dissent"] = new_dissent
                dirty = True
        if session_id := sess.get("id"):
            JOBS[session_id] = {**sess, "status": "done", "stage": "done"}
    _history_mem = raw_hist
    if dirty:
        try:
            json.dump(_history_mem[:TUNING["history_kept"]], open(HIST, "w", encoding="utf-8"), ensure_ascii=False)
        except Exception:
            pass

    try:
        _smartgen_mem = json.load(open(SMARTGEN_FILE, encoding="utf-8")) if os.path.isfile(SMARTGEN_FILE) else []
    except Exception:
        _smartgen_mem = []
    if not _smartgen_mem and _history_mem:
        for sess in reversed(_history_mem[:TUNING["smartgen_backfill"]]):
            _extract_smartgen_card(sess, save=False)
        _save_smartgen()
    elif _smartgen_mem:
        buckets = ("High", "Medium", "Low")
        sg_dirty = False
        for idx, c in enumerate(_smartgen_mem):
            if not c.get("list"):
                c["list"] = buckets[idx % len(buckets)]
                sg_dirty = True
        if sg_dirty:
            _save_smartgen()


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
    {"id": "openai/gpt-oss-20b", "label": "GPT OSS 20B", "short": "OSS", "provider": "OpenAI", "via": "NVIDIA", "color": "#34D399"},
    {"id": "meta/muse-glimmer-30b", "label": "Muse Glimmer 30B", "short": "MG", "provider": "Meta", "via": "NVIDIA", "color": "#818CF8"},
    {"id": "deepseek-ai/deepseek-v4.1-flash", "label": "DeepSeek V4.1 Flash", "short": "DS4", "provider": "DeepSeek", "via": "NVIDIA", "color": "#38BDF8"},
    {"id": "meta/llama-3.2-90b-vision-instruct", "label": "Llama 3.2 90B Vision", "short": "L90", "provider": "Meta", "via": "NVIDIA", "color": "#A78BFA"},
    {"id": "meta/llama-3.2-11b-vision-instruct", "label": "Llama 3.2 11B Vision", "short": "L11", "provider": "Meta", "via": "NVIDIA", "color": "#C4B5FD"},
    # Mistral Nemotron and Kimi K3 were removed on 2026-10-19: NVIDIA answers both with HTTP 410 Gone (retired).
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
        if ccfg.is_speech(r):
            continue
        for mid in ccfg.models_of(r):
            if mid in known:
                continue
            known.add(mid)
            label = mid.split("/")[-1]
            ROSTER.append({"id": mid, "label": label, "short": label[:4].upper(), "provider": r["name"], "via": r["name"],
                           "color": _COLORS[len(ROSTER) % len(_COLORS)]})
            LABEL[mid] = label


def transcribe(audio, mime):
    """Voice chat: speech to text with the speech provider in the configuration (Claude, 2026-10-20)."""
    ok = [r for r in rows() if ccfg.is_speech(r)]
    if not ok or not audio:
        return ""
    with _turn_lock:
        _turn["speech"] = (_turn.get("speech", -1) + 1) % len(ok)
        row = ok[_turn["speech"]]
    ext = {"audio/webm": "webm", "audio/ogg": "ogg", "audio/mp4": "m4a", "audio/wav": "wav", "audio/mpeg": "mp3"}.get(mime.split(";")[0], "webm")
    bnd = "----collider" + uuid.uuid4().hex
    model = (ccfg.models_of(row) or [ccfg.SPEECH_MODEL])[0]
    body = (f"--{bnd}\r\nContent-Disposition: form-data; name=\"model\"\r\n\r\n{model}\r\n"
            f"--{bnd}\r\nContent-Disposition: form-data; name=\"response_format\"\r\n\r\njson\r\n"
            f"--{bnd}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"speech.{ext}\"\r\n"
            f"Content-Type: {mime.split(';')[0]}\r\n\r\n").encode() + audio + f"\r\n--{bnd}--\r\n".encode()
    req = urllib.request.Request(row["endpoint"], data=body, headers={
        "Authorization": "Bearer " + row["key"].strip(), "Content-Type": "multipart/form-data; boundary=" + bnd,
        "Accept": "application/json", "User-Agent": "Collider/1.0"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return (json.loads(r.read()).get("text") or "").strip()


def uses(row):
    """Where in the app a provider row is read, for the launch window."""
    if ccfg.is_speech(row):
        return "Voice chat: what is said, turned into text (/api/transcribe)"
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
# Research and Deep Research (Claude, 2026-10-20): searches planned beyond the question itself, and source length kept.
PLAN_QUERIES = {"research": 4, "deep": 8}
SOURCE_CHARS = {"internet": 1200, "research": 1200, "deep": 1200}
PLAN_PROMPT = ("detailed thinking off\nSplit the question into {k} web searches that together cover what a thorough answer "
               "needs: the facts, the evidence for and against, recent developments, and expert disagreement. Each search is "
               "a short query a search engine understands. Return ONLY JSON: {\"queries\": [\"...\"]}")

_LEAK_RE = re.compile(
    r"(?im)^(let'?s\s+count\s+characters|wait,\s+the\s+prompt|begin\s+your\s+reply\s+with\s+one\s+line|"
    r"character\s+count\s*:|let'?s\s+check\s+length|drafting\s+the\s+one-liner|the\s+user\s+wants\s+one\s+line|"
    r"here'?s\s+a\s+thinking\s+process).*$"
)


def sanitize_model_output(text):
    """Strips <think> tags and internal chain-of-thought character-counting leakage."""
    if not text:
        return ""
    s = re.sub(r"<think>.*?</think>", "", str(text), flags=re.S).strip()
    if "Let me draft:" in s:
        s = s.split("Let me draft:", 1)[1].strip()
    paras = [p.strip() for p in re.split(r"\n\s*\n", s) if p.strip()]
    clean_paras = []
    for p in paras:
        low = p.lower()
        if any(k in low for k in (
            "begin your reply with one line",
            "let's count",
            "count characters",
            "count: ",
            "let's check the length",
            "characters, spaces included",
            "wait, let's count",
            "analyze user input:",
            "identify key requirements:",
            "we need to produce answer",
            "we need first line",
            "so first line max",
            "need <=37",
            "too long.",
            "the user is asking",
            "let me think about",
            "the instruction says:",
            "format considerations:",
            "that's a good structure.",
            "that's pretty good. should i use",
            "here's a thinking process",
            "(25 chars)",
            "(26 chars)",
            "(27 chars)",
            "(28 chars)",
            "(29 chars)",
            "(30 chars)",
            "full stop at the end",
        )):
            continue
        clean_paras.append(p)
    s = "\n\n".join(clean_paras) if clean_paras else ""
    s = _LEAK_RE.sub("", s).strip()
    return s


def _sanitize_messages(messages):
    """Ensures alternating roles and non-empty content so multi-turn LLM calls never fail with HTTP 400."""
    out = []
    for m in messages or []:
        role = str(m.get("role") or "user").strip().lower()
        if role not in ("system", "user", "assistant"):
            role = "user"
        content = str(m.get("content") or "").strip()
        if not content:
            continue
        if out and out[-1]["role"] == role and role != "system":
            out[-1]["content"] = out[-1]["content"] + "\n\n" + content
        else:
            out.append({"role": role, "content": content})
    return out


def post_json(url, payload, headers, timeout):
    req = urllib.request.Request(url, data=json.dumps(payload).encode(), headers={"Content-Type": "application/json", **headers})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.load(r)


def search_results(query, n=None):
    n = n or TUNING["browser_search_results"]
    """Plain web results for the in-app browser."""
    try:
        row = next_row(search=True)
        r = post_json(row["endpoint"], {"api_key": row["key"].strip(), "query": query, "search_depth": TUNING["browser_search_depth"], "max_results": n}, {}, TUNING["browser_search_timeout"])
        return [{"title": x.get("title", ""), "url": x.get("url", ""), "content": x.get("content") or ""} for x in r.get("results", [])]
    except Exception:
        return []


def _search_once(query, depth, n, chars):
    row = next_row(search=True)
    if not row:
        return []
    try:
        r = post_json(row["endpoint"], {"api_key": row["key"].strip(), "query": query, "search_depth": depth, "max_results": n}, {}, TUNING["search_timeout"])
        return [{"title": x.get("title", ""), "url": x.get("url", ""), "content": (x.get("content") or "")[:chars]}
                for x in r.get("results", []) if x.get("url")]
    except Exception as e:
        print("search error", query[:60], e)
        return []


def plan_queries(question, k):
    """Research and Deep Research (Claude, 2026-10-20): the consensus agent splits the question into k searches that
    together cover what a thorough answer needs. Falls back to the question itself."""
    msgs = [{"role": "system", "content": PLAN_PROMPT.replace("{k}", str(k))}, {"role": "user", "content": question}]
    for agent in AGENT_CHAIN:
        try:
            raw = call_model(agent, msgs, TUNING["plan_tokens"] if agent == CONSENSUS_AGENT else TUNING["plan_backup_tokens"], timeout=TUNING["plan_timeout"])
            m = re.search(r"\{.*\}", re.sub(r"```(?:json)?", "", raw), flags=re.S)
            qs = [str(q).strip() for q in (json.loads(m.group(0)).get("queries") or []) if str(q).strip()]
            if qs:
                return qs[:k]
        except Exception as e:
            print("plan failed", agent, e)
    return []


def web_search(query, mode, job=None):
    """Internet: one search. Research and Deep Research: the question and its planned searches, run together,
    sources merged without repeats, up to the mode's number."""
    if mode not in SEARCH or not rows(search=True):
        return []
    depth, n = SEARCH[mode]
    chars = SOURCE_CHARS.get(mode, 1200)
    k = PLAN_QUERIES.get(mode, 0)
    queries = [query]
    if k:
        if job is not None:
            job["stage"] = "planning"
        queries += plan_queries(query, k)
    if job is not None:
        job["stage"] = "searching"
        job["queries"] = queries
    per = n if len(queries) == 1 else max(TUNING["search_fanout_min"],
                                         -(-n * TUNING["search_fanout_factor"] // len(queries)))
    found = list(POOL.map(lambda q: _search_once(q, depth, per, chars), queries))
    out, seen = [], set()
    for i in range(max((len(f) for f in found), default=0)):  # round-robin so every search contributes
        for f in found:
            if i < len(f) and f[i]["url"] not in seen and len(out) < n:
                seen.add(f[i]["url"])
                out.append(f[i])
    return out


def call_model(model, messages, max_tokens, timeout=None):
    timeout = timeout or TUNING["answer_timeout"]
    via = next((m.get("via") for m in ROSTER if m["id"] == model), "NVIDIA")
    clean_msgs = _sanitize_messages(messages)
    last = None
    for attempt in range(TUNING["retries"]):
        row = next_row(via, search=False)
        if not row:
            raise RuntimeError(f"no key for {via}")
        try:
            r = post_json(row["endpoint"], {"model": model, "messages": clean_msgs, "max_tokens": max_tokens, "temperature": temperature_of(model)},
                          {"Authorization": "Bearer " + row["key"].strip()}, timeout)
            msg = r["choices"][0]["message"]
            text = sanitize_model_output(msg.get("content") or "")
            if not text:
                raw_reasoning = sanitize_model_output(msg.get("reasoning_content") or "")
                if raw_reasoning and "{" in raw_reasoning and "}" in raw_reasoning:
                    text = raw_reasoning
                elif raw_reasoning:
                    paras = [p.strip() for p in raw_reasoning.split("\n\n") if p.strip()]
                    text = paras[-1] if paras else ""
            if text:
                return text
            last = "empty reply"
        except urllib.error.HTTPError as e:
            last = f"HTTP {e.code}"
        except Exception as e:
            last = str(e)[:TUNING["error_chars"]]
            if "timed out" in last:
                break  # a slow model is not retried; the others carry on
        time.sleep(TUNING["retry_wait"])
    raise RuntimeError(last or "no reply")


def draft_clean(s):
    """Text drafted so far, without thinking: a closed <think> block goes, an open one hides the rest until it closes."""
    s = re.sub(r"<think>.*?</think>", "", s or "", flags=re.S)
    i = s.find("<think>")
    return (s[:i] if i >= 0 else s).lstrip()


def draft_split(s, n):
    """Text drafted so far -> (its one line once that line is complete, the answer drafted so far)."""
    s = draft_clean(s)
    if "\n" in s:
        first, rest = s.split("\n", 1)
        first = clean_line(first)
        if first and len(first) <= n:
            return first, rest.strip()
        return "", s.strip()
    return "", (s.strip() if len(s) > n + TUNING["draft_extra_chars"] else "")


def stream_model(model, messages, max_tokens, on_text=None, timeout=None):
    """The streamed form of call_model (Claude, 2026-10-19): the OpenAI-compatible "stream": true that every chat
    template uses (Vercel AI SDK among them). on_text receives the text drafted so far as tokens arrive. Anything that
    goes wrong before the first token falls back to call_model, so an answer still comes.
    timeout: the longest silence allowed (the configuration's "silence"; measured 2026-10-19: a queued model's first
    byte comes within 30 s, a stalled one never comes)."""
    timeout = timeout or SILENCE
    via = next((m.get("via") for m in ROSTER if m["id"] == model), "NVIDIA")
    row = next_row(via, search=False)
    if not row:
        raise RuntimeError(f"no key for {via}")
    payload = {"model": model, "messages": _sanitize_messages(messages), "max_tokens": max_tokens, "temperature": temperature_of(model), "stream": True}
    req = urllib.request.Request(row["endpoint"], data=json.dumps(payload).encode(), headers={
        "Content-Type": "application/json", "Accept": "text/event-stream", "Authorization": "Bearer " + row["key"].strip()})
    parts = []
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            for raw in r:
                line = raw.decode("utf-8", "ignore").strip()
                if not line.startswith("data:"):
                    continue
                data = line[5:].strip()
                if data == "[DONE]":
                    break
                try:
                    delta = (json.loads(data)["choices"][0].get("delta") or {}).get("content")
                except Exception:
                    continue
                if delta:
                    parts.append(delta)
                    if on_text:
                        on_text("".join(parts))
    except Exception as e:
        if "timed out" in str(e) and not parts:
            raise RuntimeError("no answer in time")
        if isinstance(e, urllib.error.HTTPError) and e.code == 410:
            raise RuntimeError("retired by the provider")
        if not parts:
            print("stream failed, asking without streaming", model, str(e)[:TUNING["error_chars"]])
            return call_model(model, messages, max_tokens, timeout)
    text = sanitize_model_output("".join(parts))
    return text or call_model(model, messages, max_tokens, timeout)


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


def run_consensus(prompt, answers, n=None):
    """answers: {model_id: text}. Returns dict with essences keyed by model id."""
    n = n or LINE_DEFAULT
    ids = list(answers.keys())
    tags = {f"R{i + 1}": mid for i, mid in enumerate(ids)}
    body = "\n\n".join(f"{t}:\n{answers[mid][:TUNING['agent_answer_chars']]}" for t, mid in tags.items())
    msgs = [{"role": "system", "content": AGENT_PROMPT.replace("{n}", str(n))},
            {"role": "user", "content": f"Question:\n{prompt}\n\nResponses:\n\n{body}"}]
    for agent in AGENT_CHAIN:
        try:
            out = parse_json(call_model(agent, msgs, TUNING["agent_tokens"] if agent == CONSENSUS_AGENT else TUNING["agent_backup_tokens"], timeout=TUNING["agent_timeout"]))
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


def self_essence_fallback(answer):
    paras = [p.strip() for p in str(answer or "").strip().split("\n") if p.strip()]
    target = paras[1] if len(paras) > 1 and len(paras[0]) <= TUNING["essence_short_line"] else (paras[0] if paras else "")
    first = re.split(r"(?<=[.!?])\s", plain(target), maxsplit=1)[0]
    return first[:TUNING["essence_fallback_chars"]]


def self_essence(model, prompt, answer):
    msgs = [{"role": "system", "content": ESSENCE_PROMPT},
            {"role": "user", "content": f"Question: {prompt}\n\nAnswer:\n{answer[:TUNING['essence_answer_chars']]}"}]
    try:
        return call_model(model, msgs, TUNING["essence_tokens"], timeout=TUNING["essence_timeout"]).split("\n")[0].strip()
    except Exception:
        return self_essence_fallback(answer)


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
        return max(TUNING["line_min"], min(TUNING["line_max"], int(v)))
    except Exception:
        return LINE_DEFAULT


def clean_line(t):
    t = plain(str(t or "").strip().split("\n")[0]).strip(" \"'")
    return t.replace("\u2026", "").replace("...", "").rstrip(". ").strip()


def fit_words(t, n):
    """Clause-aware one-line fitter: prefers complete clauses before punctuation, then whole words without dangling prepositions."""
    t = clean_line(t)
    if len(t) <= n:
        return t
    window = t[:n + 1]
    for sep in ("; ", " — ", " – ", ": ", ", "):
        idx = window.rfind(sep)
        if idx >= max(10, n // 2):
            window = window[:idx]
            break
    else:
        window = window[:window.rfind(" ")] if " " in window else t[:n]
    cut = window.strip()
    while True:
        new = re.sub(
            r"(?i)[\s,;:(\-\u2013\u2014]+$|\s+(and|or|but|the|a|an|to|of|for|with|in|on|at|by|from|as|into|than|"
            r"is|are|was|were|be|been|has|have|had|will|would|can|could|should|may|might|"
            r"that|which|who|whom|whose|where|when|while|because|since|unless|although|if|not|no|so|yet)$",
            "",
            cut,
        ).strip()
        if new == cut or not new:
            return cut
        cut = new


def split_line(text, n):
    """A model's reply -> (its own line, the full answer). The line is taken only when it fits."""
    cleaned = sanitize_model_output(text)
    rows = str(cleaned or "").strip().split("\n")
    first = clean_line(rows[0])
    rest = "\n".join(rows[1:]).strip()
    if first and len(first) <= n:
        return first, (rest or first)
    sentence = re.split(r"(?<=[.!?])\s", plain(rows[0]).strip(), maxsplit=1)[0]
    return fit_words(sentence, n), str(cleaned or "").strip()


def agent_lines(prompt, answers, n, groups=None):
    """One pass of the consensus agent over saved answers -> {model_id: line}. Only lines that fit are returned."""
    ids = list(answers.keys())
    tags = {f"R{i + 1}": mid for i, mid in enumerate(ids)}
    back = {mid: t for t, mid in tags.items()}
    grouped = [[back[m] for m in g if m in back] for g in (groups or [])]
    grouped = [g for g in grouped if g]
    seen = {t for g in grouped for t in g}
    grouped += [[t] for t in tags if t not in seen]
    body = "\n\n".join(f"{t}:\n{answers[mid][:TUNING['agent_answer_chars']]}" for t, mid in tags.items())
    msgs = [{"role": "system", "content": LINES_PROMPT.replace("{n}", str(n))},
            {"role": "user", "content": f"Question:\n{prompt}\n\nGroups: {json.dumps(grouped)}\n\nResponses:\n\n{body}"}]
    for agent in AGENT_CHAIN:
        try:
            raw = call_model(agent, msgs, TUNING["lines_tokens"] if agent == CONSENSUS_AGENT else TUNING["lines_backup_tokens"], timeout=TUNING["lines_timeout"])
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


# ---------------- History & SmartGen ----------------
_hist_lock = threading.Lock()


def load_history():
    global _history_mem
    if _history_mem is not None:
        return _history_mem
    try:
        _history_mem = json.load(open(HIST, encoding="utf-8"))
        return _history_mem
    except Exception:
        _history_mem = []
        return _history_mem


def _save_smartgen():
    if _smartgen_mem is None or not SMARTGEN_FILE:
        return
    try:
        json.dump(_smartgen_mem[:TUNING["smartgen_kept"]], open(SMARTGEN_FILE, "w", encoding="utf-8"), ensure_ascii=False)
    except Exception:
        pass


def _extract_smartgen_card(job, save=True):
    """Extracts an autonomous SmartGen synthesis card from a completed consensus session."""
    global _smartgen_mem
    if _smartgen_mem is None:
        _smartgen_mem = []
    cons = job.get("consensus") or {}
    results = job.get("results") or {}
    summary = (cons.get("summary") or "").strip()
    if not summary:
        for r in results.values():
            if r.get("essence"):
                summary = r["essence"]
                break
    if not summary:
        return
    title = (cons.get("line") or "").strip() or fit_words(job.get("prompt") or "Synthesis", TUNING["smartgen_title_chars"])
    score = cons.get("score") or f"{len([r for r in results.values() if r.get('status') == 'done'])}/{len(results)}"
    dissent = cons.get("dissent") or []
    body_lines = [summary]
    if dissent:
        body_lines.append(f"Dissent: {dissent[0]}")
    buckets = ("High", "Medium", "Low")
    list_name = buckets[len(_smartgen_mem) % len(buckets)]
    card = {
        "id": f"sg_{job['id']}",
        "session_id": job["id"],
        "list": list_name,
        "title": title,
        "prompt": job.get("prompt") or "",
        "content": "\n\n".join(body_lines),
        "score": score,
        "mode": job.get("mode") or "chat",
        "created": job.get("created") or time.time(),
    }
    _smartgen_mem = [c for c in _smartgen_mem if c.get("id") != card["id"]]
    _smartgen_mem.insert(0, card)
    if save:
        _save_smartgen()


def save_session(job):
    global _history_mem
    with _hist_lock:
        h = list(load_history())
        h = [s for s in h if s.get("id") != job["id"]]
        entry = {k: job.get(k) for k in ("id", "prompt", "mode", "created", "models", "results", "consensus", "sources", "line_chars")}
        h.insert(0, entry)
        _history_mem = h[:TUNING["history_kept"]]
        try:
            json.dump(_history_mem, open(HIST, "w", encoding="utf-8"), ensure_ascii=False)
        except Exception:
            pass
    try:
        _extract_smartgen_card(job, save=True)
    except Exception:
        pass


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
    cons = sess.get("consensus") or {}
    need_cons_line = cons.get("status") == "done" and (todo or not (cons.get("line") and len(cons["line"]) <= n))
    if not todo and not need_cons_line:
        return {**{k: sess.get(k) for k in ("id", "prompt", "mode", "created", "results", "consensus", "sources")}, "status": "done"}
    if todo:
        got = agent_lines(sess.get("prompt", ""), done, n, cons.get("groups"))
        for m in todo:
            res[m]["line"] = got.get(m) or fit_words(res[m].get("essence") or done[m], n)
    if need_cons_line:
        cons["line"] = consensus_line(sess, n)
    sess["line_chars"] = n
    save_session(sess)
    return {**{k: sess.get(k) for k in ("id", "prompt", "mode", "created", "results", "consensus", "sources")}, "status": "done"}


# ---------------- Jobs ----------------
JOBS = {}
POOL = cf.ThreadPoolExecutor(32)


LOOKUP_RULE = (
    "A stored session record exists at /api/lookup/{jid}/{mid}. "
    "Do NOT assume prior turns unless needed; if and ONLY if the user's message explicitly depends on looking up "
    "an earlier turn from that stored record, reply with ONLY [LOOKUP_SESSION] to retrieve it on demand."
)


def lookup_stored_messages(job_id, mid):
    """On-demand lookup of a conversation stored at its canonical location (JOBS / data/history.json).
    Never injected by default; fetched only when explicitly looked up."""
    if not job_id:
        return []
    sess = JOBS.get(job_id) or next((x for x in load_history() if x.get("id") == job_id), None)
    if not sess:
        return []
    r = (sess.get("results") or {}).get(mid) or {}
    if r.get("messages"):
        return list(r["messages"])
    if r.get("text"):
        return [
            {"role": "user", "content": sess.get("prompt") or ""},
            {"role": "assistant", "content": r["text"]},
        ]
    return []


def run_job(job, prior_threads=None):
    prompt, mode = job["prompt"], job["mode"]
    if mode in SEARCH:
        job["stage"] = "searching"
        job["sources"] = web_search(prompt, mode, job)
    job["stage"] = "answering"
    n = job["line_chars"]
    system = DEPTH.get(mode, DEPTH["chat"]) + "\n\n" + LINE_RULE.replace("{n}", str(n))
    src = sources_block(job["sources"])
    attached = FILES.attachment_text(job.get("attachments"))
    asked = prompt + ("\n\n" + attached if attached else "")
    prior_threads = prior_threads or {}

    def one(mid):
        t0 = time.time()
        history_msgs = list(prior_threads.get(mid) or [])
        lookup_hint = ("\n\n" + LOOKUP_RULE.format(jid=job["id"], mid=mid)) if history_msgs else ""
        # Zero unconsented context stuffing: send only the system instruction and current user prompt.
        msgs = [{"role": "system", "content": own_system(mid) + system + lookup_hint + ("\n\n" + src if src else "")}, {"role": "user", "content": asked}]
        def drafted(s):
            if job["results"][mid]["status"] == "pending":
                l, t = draft_split(s, n)
                job["results"][mid].update(line=l, text=t)

        try:
            raw_out = stream_model(mid, msgs, MAX_TOKENS.get(mode, 1200), drafted)
            if "[LOOKUP_SESSION]" in raw_out and history_msgs:
                stored = lookup_stored_messages(job["id"], mid) or history_msgs
                lookup_msgs = [{"role": "system", "content": own_system(mid) + system + ("\n\n" + src if src else "")}] + stored + [{"role": "user", "content": asked}]
                raw_out = stream_model(mid, lookup_msgs, MAX_TOKENS.get(mode, 1200), drafted)
            line, text = split_line(raw_out, n)
            updated_thread = _sanitize_messages(history_msgs + [
                {"role": "user", "content": prompt},
                {"role": "assistant", "content": text},
            ])
            job["results"][mid].update(
                status="done",
                text=text,
                line=line,
                messages=updated_thread,
                ms=int((time.time() - t0) * 1000),
            )
        except Exception as e:
            fallback_thread = _sanitize_messages(history_msgs + [{"role": "user", "content": prompt}])
            job["results"][mid].update(
                status="error",
                text="",
                error=str(e),
                messages=fallback_thread,
                ms=int((time.time() - t0) * 1000),
            )

    # Every model gets the same deadline; one slow model never holds the others back.
    deadline = DEADLINE.get(mode, 120)
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
    if mode in PLAN_QUERIES and not job.get("incognito"):
        save_reports(job)
    job["stage"] = "done"
    job["status"] = "done"
    if job.get("save") and not job.get("incognito"):
        save_session(job)


def report_text(text, sources):
    """A report as a document: the model's text, then the sources it was given, numbered as it cites them."""
    listed = "\n".join(f"{i + 1}. [{s.get('title') or s['url']}]({s['url']})" for i, s in enumerate(sources or []))
    return text.strip() + ("\n\n## Sources\n\n" + listed if listed else "") + "\n"


def save_reports(job):
    """Research and Deep Research (Claude, 2026-10-20): every report is kept as a document in Files > Generated."""
    kind = "Deep Research" if job["mode"] == "deep" else "Research"
    words = " ".join(re.sub(r"[^\w\s-]", " ", job["prompt"]).split()[:TUNING["report_words"]]) or kind
    for mid, r in job["results"].items():
        if r.get("status") != "done" or not r.get("text"):
            continue
        try:
            r["file"] = FILES.save_generated(f"{kind} - {words} - {LABEL.get(mid, mid)}.md", report_text(r["text"], job.get("sources")))
        except Exception as e:
            print("report save failed", mid, e)


def new_job(body):
    models = [m for m in body.get("models", []) if m in LABEL] or [ROSTER[0]["id"]]
    session_id = (body.get("session_id") or "").strip()
    prior_sess = None
    if session_id:
        prior_sess = JOBS.get(session_id) or next((x for x in load_history() if x.get("id") == session_id), None)

    prior_threads = {}
    if prior_sess:
        prev_prompt = prior_sess.get("prompt") or ""
        for m, r in (prior_sess.get("results") or {}).items():
            if r.get("messages"):
                prior_threads[m] = list(r["messages"])
            elif r.get("text"):
                prior_threads[m] = [
                    {"role": "user", "content": prev_prompt},
                    {"role": "assistant", "content": r["text"]},
                ]

    jid = prior_sess["id"] if prior_sess else uuid.uuid4().hex[:12]
    prompt = body.get("prompt", "").strip()
    job = {
        "id": jid,
        "prompt": prompt,
        "mode": body.get("mode", "chat"),
        "created": time.time(),
        "models": models,
        "status": "running",
        "stage": "queued",
        "sources": [],
        "results": {
            m: {
                "status": "pending",
                "text": "",
                "essence": "",
                "line": "",
                "messages": _sanitize_messages(list(prior_threads.get(m) or []) + [{"role": "user", "content": prompt}]),
            }
            for m in models
        },
        "line_chars": line_budget(body.get("line")),
        "consensus": {"status": "pending"},
        "save": body.get("autosave", True),
        "incognito": body.get("incognito", False),
        "attachments": [str(a) for a in body.get("attachments", [])][:TUNING["attachments_max"]],
    }
    JOBS[job["id"]] = job
    threading.Thread(target=run_job, args=(job, prior_threads), daemon=True).start()
    return job


REPLIES = {}


def start_reply(body):
    """A reply that drafts: the app watches /api/stream/r/<id> while the model writes."""
    rid = uuid.uuid4().hex[:12]
    rec = {"id": rid, "status": "running", "text": "", "line": "", "messages": []}
    REPLIES[rid] = rec

    def work():
        try:
            out = reply(body, lambda line, text: rec.update(line=line, text=text))
            rec.update(out, status="done" if out.get("text") else "error")
        except Exception as e:
            rec.update(status="error", error=str(e)[:200])

    POOL.submit(work)
    return rec


def reply(body, on_draft=None):
    mid = body.get("model")
    n = line_budget(body.get("line"))
    job_id = (body.get("job_id") or body.get("session_id") or "").strip()
    prompt = (body.get("prompt") or "").strip()
    if not prompt:
        raw_in = _sanitize_messages(body.get("messages") or [])
        if raw_in:
            prompt = raw_in[-1].get("content") or ""
    stored_history = lookup_stored_messages(job_id, mid) if job_id else []
    attached = FILES.attachment_text(body.get("attachments"))
    asked = prompt + ("\n\n" + attached if attached else "")
    sys_base = own_system(mid) + DEPTH.get(body.get("mode", "chat"), DEPTH["chat"]) + "\n\n" + LINE_RULE.replace("{n}", str(n))
    lookup_hint = ("\n\n" + LOOKUP_RULE.format(jid=job_id, mid=mid)) if stored_history else ""
    # Zero unconsented context stuffing: send only the system instruction and current user prompt.
    msgs = [{"role": "system", "content": sys_base + lookup_hint}, {"role": "user", "content": asked}]

    attached = FILES.attachment_text(body.get("attachments"))


    drafted = (lambda s: on_draft(*draft_split(s, n))) if on_draft else None
    raw_out = stream_model(mid, msgs, TUNING["reply_tokens"], drafted)
    if "[LOOKUP_SESSION]" in raw_out and stored_history:
        lookup_msgs = [{"role": "system", "content": sys_base}] + stored_history + [{"role": "user", "content": asked}]
        raw_out = stream_model(mid, lookup_msgs, TUNING["reply_tokens"], drafted)
    line, text = split_line(raw_out, n)
    updated_thread = _sanitize_messages(stored_history + [{"role": "user", "content": prompt}, {"role": "assistant", "content": text}])


    job_id = (body.get("job_id") or body.get("session_id") or "").strip()
    target_sess = None
    if job_id:
        target_sess = JOBS.get(job_id) or next((x for x in load_history() if x.get("id") == job_id), None)
    if target_sess and mid in (target_sess.get("results") or {}):
        res_entry = target_sess["results"][mid]
        res_entry["status"] = "done"
        res_entry["text"] = text
        res_entry["line"] = line
        res_entry["essence"] = self_essence_fallback(text) or line
        res_entry["messages"] = updated_thread
        JOBS[target_sess["id"]] = target_sess
        if target_sess.get("save", True) and not target_sess.get("incognito", False):
            save_session(target_sess)

    return {"ok": True, "text": text, "essence": line, "line": line, "messages": updated_thread}


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


def _refresh_themes_bg():
    """Fetches the remote Cloudflare R2 theme manifest in the background and updates _themes_cache + disk cache."""
    cache = os.path.join(DATA, "themes_cache.json")
    try:
        listing = _get_json(CONFIG.get("themes") or ccfg.THEMES)
    except Exception:
        return
    parts = {}
    for o in listing:
        m = _NUMBERED.match(o["name"])
        if not m:
            continue
        t = parts.setdefault(m.group(1), {"title": m.group(2)})
        t.setdefault(o.get("kind"), o)

    def kind(tags):
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


def themes():
    with _themes_lock:
        if _themes_cache["data"]:
            if time.time() - _themes_cache["at"] >= TUNING["themes_refresh"]:
                _themes_cache["at"] = time.time()
                threading.Thread(target=_refresh_themes_bg, daemon=True).start()
            return _themes_cache["data"]
    cache = os.path.join(DATA, "themes_cache.json")
    if os.path.isfile(cache):
        try:
            data = json.load(open(cache, encoding="utf-8"))
            with _themes_lock:
                _themes_cache.update(at=time.time(), data=data)
            threading.Thread(target=_refresh_themes_bg, daemon=True).start()
            return data
        except Exception:
            pass
    _refresh_themes_bg()
    with _themes_lock:
        return _themes_cache["data"]


# ---------------- Settings (Claude, 2026-10-20) ----------------
# Every line that decides how the app answers lives in data\collider_config.json beside the exe, shown in the launch
# window. The values below are only what a configuration starts with; from then on the file is what is read.
DEADLINE = {"chat": 100, "internet": 120, "research": 180, "deep": 240}
SILENCE = 45
ESSENCE_PROMPT = ("Reduce the answer below to its essence: one standalone sentence stating what it says, "
                  "in service of the question's need. Never mention who wrote it. Reply with the sentence only.")
# Every other number the server works by. These are the values it has always run on.
TUNING = {
    "temperature": 0.4, "answer_timeout": 150, "retries": 2, "retry_wait": 1.5, "reply_tokens": 1400,
    "agent_answer_chars": 2200, "agent_tokens": 2500, "agent_backup_tokens": 9000, "agent_timeout": 110,
    "lines_tokens": 900, "lines_backup_tokens": 6000, "lines_timeout": 90, "line_min": 18, "line_max": 72,
    "essence_answer_chars": 3500, "essence_tokens": 200, "essence_timeout": 60,
    "plan_tokens": 400, "plan_backup_tokens": 3000, "plan_timeout": 60, "search_timeout": 40,
    "browser_search_depth": "basic", "browser_search_results": 10, "browser_search_timeout": 30,
    "attachments_max": 12, "history_kept": 200, "smartgen_kept": 100, "themes_refresh": 600,
    # read by code another session added in the old folder at 08:53 on 2026-10-20 without listing them here;
    # these are the values that code had before it was moved into the configuration
    "smartgen_backfill": 12, "search_fanout_min": 3, "search_fanout_factor": 2, "error_chars": 80,
    "draft_extra_chars": 8, "essence_short_line": 45, "essence_fallback_chars": 240, "smartgen_title_chars": 32,
    "report_words": 8,
}
SETTINGS = ("consensus_agent", "agent_chain", "agent_prompt", "lines_prompt", "essence_prompt", "plan_prompt", "models",
            "depth", "line_rule", "line_length", "search", "plan_queries", "source_chars", "max_tokens", "deadline",
            "silence", "tuning", "pack_price", "tracks_per_pack")


def own_system(mid):
    """A model's own instruction from the configuration, placed before the mode's instruction. Empty: none."""
    t = next((str(m.get("system") or "").strip() for m in ROSTER if m["id"] == mid), "")
    return t + "\n\n" if t else ""


def temperature_of(mid):
    """A model's own temperature from the configuration, or the general one."""
    v = next((m.get("temperature") for m in ROSTER if m["id"] == mid), None)
    try:
        return float(v) if v not in (None, "") else float(TUNING["temperature"])
    except (TypeError, ValueError):
        return float(TUNING["temperature"])


def settings_defaults():
    return {"consensus_agent": CONSENSUS_AGENT, "agent_chain": list(AGENT_CHAIN),
            "models": [{**m, "system": m.get("system", ""), "temperature": m.get("temperature", "")} for m in ROSTER[:_BUILT_IN]],
            "essence_prompt": ESSENCE_PROMPT, "tuning": dict(TUNING),
            "depth": dict(DEPTH), "line_rule": LINE_RULE, "line_length": LINE_DEFAULT,
            "search": {k: list(v) for k, v in SEARCH.items()}, "max_tokens": dict(MAX_TOKENS), "deadline": dict(DEADLINE),
            "silence": SILENCE, "plan_queries": dict(PLAN_QUERIES), "plan_prompt": PLAN_PROMPT,
            "source_chars": dict(SOURCE_CHARS), "agent_prompt": AGENT_PROMPT, "lines_prompt": LINES_PROMPT,
            "pack_price": PACK_PRICE, "tracks_per_pack": TRACKS_PER_PACK}


def apply_settings(cfg):
    """Fills any missing line with its starting value, then makes the file's values the ones the server runs on.
    Returns True when a line was missing (the file is then saved complete)."""
    global CONSENSUS_AGENT, AGENT_CHAIN, DEPTH, LINE_RULE, LINE_DEFAULT, SEARCH, MAX_TOKENS, DEADLINE, SILENCE
    global AGENT_PROMPT, LINES_PROMPT, PACK_PRICE, TRACKS_PER_PACK, _BUILT_IN, PLAN_QUERIES, SOURCE_CHARS, PLAN_PROMPT
    global ESSENCE_PROMPT, TUNING
    missing = False
    for k, v in settings_defaults().items():
        if k not in cfg:
            cfg[k] = v
            missing = True
    CONSENSUS_AGENT = str(cfg["consensus_agent"]).strip()
    AGENT_CHAIN = [m for m in dict.fromkeys([CONSENSUS_AGENT] + [str(x).strip() for x in cfg["agent_chain"]]) if m]
    ROSTER[:] = [dict(m) for m in cfg["models"] if m.get("id")]
    _BUILT_IN = len(ROSTER)
    LABEL.clear()
    LABEL.update({m["id"]: m.get("label") or m["id"] for m in ROSTER})
    DEPTH, LINE_RULE, LINE_DEFAULT = dict(cfg["depth"]), str(cfg["line_rule"]), int(cfg["line_length"])
    SEARCH = {k: (v[0], int(v[1])) for k, v in cfg["search"].items()}
    MAX_TOKENS = {k: int(v) for k, v in cfg["max_tokens"].items()}
    DEADLINE = {k: int(v) for k, v in cfg["deadline"].items()}
    SILENCE = int(cfg["silence"])
    PLAN_QUERIES = {k: int(v) for k, v in cfg["plan_queries"].items()}
    SOURCE_CHARS = {k: int(v) for k, v in cfg["source_chars"].items()}
    PLAN_PROMPT = str(cfg["plan_prompt"])
    ESSENCE_PROMPT = str(cfg["essence_prompt"])
    for m in cfg["models"]:  # every model row shows its own instruction and temperature, empty until set
        if "system" not in m or "temperature" not in m:
            missing = True
        m.setdefault("system", "")
        m.setdefault("temperature", "")
    missing = missing or any(k not in cfg["tuning"] for k in TUNING)
    TUNING = {**TUNING, **cfg["tuning"]}
    cfg["tuning"] = dict(TUNING)
    AGENT_PROMPT, LINES_PROMPT = str(cfg["agent_prompt"]), str(cfg["lines_prompt"])
    PACK_PRICE, TRACKS_PER_PACK = str(cfg["pack_price"]), int(cfg["tracks_per_pack"])
    return missing


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

    def _sse(self, get):
        """Server-sent events: the whole state each time it changes, until it is done (Claude, 2026-10-19)."""
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        last, until = None, time.time() + 900
        try:
            while time.time() < until:
                obj = get()
                if obj is None:
                    self.wfile.write(b"event: gone\ndata: {}\n\n")
                    self.wfile.flush()
                    return
                try:
                    s = json.dumps(obj, ensure_ascii=False)
                except RuntimeError:  # changed while being read; the next look gets it
                    time.sleep(0.03)
                    continue
                if s != last:
                    self.wfile.write(("data: " + s + "\n\n").encode("utf-8"))
                    self.wfile.flush()
                    last = s
                if obj.get("status", "done") in ("done", "error"):
                    self.wfile.write(b"event: end\ndata: {}\n\n")
                    self.wfile.flush()
                    return
                time.sleep(0.08)
        except OSError:
            pass

    def _body(self):
        n = int(self.headers.get("Content-Length") or 0)
        return json.loads(self.rfile.read(n) or b"{}")

    def do_GET(self):
        p = self.path.split("?")[0]
        if p == "/api/whoami":
            return self._json({"root": ROOT, "port": PORT})
        if p == "/api/models":
            return self._json({"models": ROSTER, "agent": CONSENSUS_AGENT, "search": bool(rows(search=True)), "keys": len(rows(search=False))})
        if p == "/api/themes":
            return self._json(themes())
        if p == "/api/store":
            return self._json({"bypass": bool(CONFIG.get("store_bypass", True))})
        if p.startswith("/api/stream/r/"):
            return self._sse(lambda: REPLIES.get(p.rsplit("/", 1)[-1]))
        if p.startswith("/api/stream/"):
            jid = p.rsplit("/", 1)[-1]
            return self._sse(lambda: JOBS.get(jid) or next((x for x in load_history() if x.get("id") == jid), None))
        if p.startswith("/api/reply/"):
            rec = REPLIES.get(p.rsplit("/", 1)[-1])
            return self._json(rec or {"error": "not found"}, 200 if rec else 404)
        if p.startswith("/api/lookup/"):
            parts = p.split("/", 4)
            jid = parts[3] if len(parts) > 3 else ""
            mid = parts[4] if len(parts) > 4 else ""
            return self._json({"job_id": jid, "model": mid, "messages": lookup_stored_messages(jid, mid)})
        if p.startswith("/api/job/"):
            jid = p.rsplit("/", 1)[-1]
            job = JOBS.get(jid) or next((x for x in load_history() if x.get("id") == jid), None)
            return self._json(job or {"error": "not found"}, 200 if job else 404)
        if p == "/api/jobs":
            return self._json([{"id": j["id"], "stage": j["stage"], "status": j["status"], "save": j.get("save"),
                                "results": {m: r["status"] for m, r in j["results"].items()}} for j in JOBS.values()])
        if p == "/api/history":
            return self._json({"sessions": load_history()})
        if p == "/api/smartgen":
            return self._json({"cards": _smartgen_mem or []})
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
            if p == "/api/reply/start":
                return self._json({"id": start_reply(self._body())["id"]})
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
            if p == "/api/transcribe":
                b = self._body()
                return self._json({"text": transcribe(base64.b64decode(b.get("b64", "")), b.get("mime", "audio/webm"))})
            if p == "/api/files/save":
                b = self._body()
                return self._json({"name": FILES.save_bytes(b.get("name", "document.docx"), b.get("b64", ""), b.get("replace", ""))})
            if p == "/api/files/pdf":
                b = self._body()
                name = FILES.print_pdf(b.get("name", "document.pdf"), b.get("html", ""), b.get("replace", ""))
                return self._json({"name": name} if name else {"error": "pdf"}, 200 if name else 500)
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
