// Preview shim for the Collider web build.
//
// The app and its API must share one origin. When the app is served by the plain preview
// file server there is no API behind it, and every panel comes up empty. This shim answers
// the read-only endpoints from the files the project already keeps on disk, so the app is a
// working preview and not an empty shell.
//
// The moment a real API answers on this origin, every request is passed straight through,
// so running the Collider server later needs no change here.
//
// Preview only: it holds no keys and answers no model request.

const DATA = '/..%2f..%2fdata%2f'; // the project's data folder, reached through the preview server

// The roster the server keeps (tools/collider_server.py, ROSTER).
const ROSTER = [
  {id: 'nvidia/nemotron-3-super-120b-a12b', label: 'Nemotron 3 Super', short: 'NS3', provider: 'NVIDIA', via: 'NVIDIA', color: '#76B900'},
  {id: 'nvidia/nemotron-3-ultra-550b-a55b', label: 'Nemotron 3 Ultra', short: 'NU3', provider: 'NVIDIA', via: 'NVIDIA', color: '#A3E635'},
  {id: 'nvidia/nemotron-3.5-lightning-30b-a3b', label: 'Nemotron 3.5 Lightning', short: 'NL35', provider: 'NVIDIA', via: 'NVIDIA', color: '#4ADE80'},
  {id: 'z-ai/glm-5.3', label: 'GLM 5.3', short: 'GLM', provider: 'Z.ai', via: 'NVIDIA', color: '#60A5FA'},
  {id: 'z-ai/glm-5.3-flash', label: 'GLM 5.3 Flash', short: 'GLMF', provider: 'Z.ai', via: 'NVIDIA', color: '#93C5FD'},
  {id: 'google/gemma-4-31b-it', label: 'Gemma 4 31B', short: 'G4', provider: 'Google', via: 'NVIDIA', color: '#FBBF24'},
  {id: 'openai/gpt-oss-20b', label: 'GPT OSS 20B', short: 'OSS', provider: 'OpenAI', via: 'NVIDIA', color: '#34D399'},
  {id: 'meta/muse-glimmer-30b', label: 'Muse Glimmer 30B', short: 'MG', provider: 'Meta', via: 'NVIDIA', color: '#818CF8'},
  {id: 'deepseek-ai/deepseek-v4.1-flash', label: 'DeepSeek V4.1 Flash', short: 'DS4', provider: 'DeepSeek', via: 'NVIDIA', color: '#38BDF8'},
  {id: 'meta/llama-3.2-90b-vision-instruct', label: 'Llama 3.2 90B Vision', short: 'L90', provider: 'Meta', via: 'NVIDIA', color: '#A78BFA'},
  {id: 'meta/llama-3.2-11b-vision-instruct', label: 'Llama 3.2 11B Vision', short: 'L11', provider: 'Meta', via: 'NVIDIA', color: '#C4B5FD'},
];
const AGENT = 'google/gemma-4-31b-it';

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));

self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);
  if (url.origin !== self.location.origin) return;
  if (!url.pathname.startsWith('/api/')) return;
  event.respondWith(answer(event.request, url));
});

async function answer(request, url) {
  try {
    const res = await fetch(request);
    const type = res.headers.get('content-type') || '';
    // A real API answers with JSON or an event stream. The preview file server answers
    // everything else with the app shell, and that is the case this shim is here for.
    if (!type.includes('text/html')) return res;
  } catch (e) {
    // No API on this origin.
  }
  const path = url.pathname;
  if (path === '/api/models') return json({models: ROSTER, agent: AGENT, search: await hasSearch(), keys: await keyCount()});
  if (path === '/api/themes') return json(await themes());
  if (path === '/api/history') return json({sessions: await readJson(DATA + 'history.json') || []});
  if (path === '/api/smartgen') return json({cards: await readJson(DATA + 'smartgen_cards.json') || []});
  if (path === '/api/files') return json({uploaded: [], generated: [], downloaded: []});
  if (path === '/api/store') return json({bypass: true});
  if (path === '/api/whoami') return json({root: 'preview', port: 0});
  if (path.startsWith('/api/job/')) return json(emptyJob(path.split('/').pop()));
  if (path.startsWith('/api/reply/')) return json({error: 'not found'}, 404);
  if (path.startsWith('/api/stream/')) return json({error: 'not found'}, 404);
  if (path === '/api/ask' || path === '/api/reply' || path === '/api/reply/start' || path === '/api/lines') {
    return json({error: 'No model is running behind this preview. Start the Collider server for live answers.'}, 503);
  }
  return json({error: 'not found'}, 404);
}

function json(value, status = 200) {
  return new Response(JSON.stringify(value), {status, headers: {'Content-Type': 'application/json'}});
}

function emptyJob(id) {
  return {
    id: id,
    prompt: '',
    mode: 'chat',
    stage: 'done',
    status: 'done',
    results: {},
    consensus: {status: 'unavailable', summary: 'No answer', score: '', dissent: [], need: ''},
    sources: [],
    created: Date.now() / 1000,
  };
}

async function readJson(path) {
  try {
    const res = await fetch(path);
    if (!res.ok) return null;
    return await res.json();
  } catch (e) {
    return null;
  }
}

// The provider rows live in the project's config file. Only counts leave this device: no key
// is read into a response, logged or sent anywhere.
async function providers() {
  const cfg = await readJson(DATA + 'collider_config.json');
  const rows = (cfg && cfg.providers) || [];
  return rows.filter((r) => (r.key || '').trim());
}

async function keyCount() {
  return (await providers()).length;
}

async function hasSearch() {
  return (await providers()).some((r) => ((r.endpoint || '') + ' ' + (r.name || '')).toLowerCase().includes('tavily'));
}

// The wallpapers, in the shape the app reads them (tools/collider_server.py, _refresh_themes_bg).
async function themes() {
  const cached = await readJson(DATA + 'themes_cache.json');
  if (cached && cached.length) return cached;
  const listing = await readJson('https://collider-themes.ebridavid.workers.dev/');
  if (!listing || !listing.length) return [];
  const parts = {};
  for (const o of listing) {
    const m = /(\d+)\s+(.*)/.exec(o.name || '');
    if (!m) continue;
    const t = parts[m[1]] || (parts[m[1]] = {title: m[2]});
    if (!t[o.kind]) t[o.kind] = o;
  }
  const kindOf = (tags) => (tags || []).find((x) => x !== 'live wallpaper' && x !== 'mp4' && !/^\d+p$/.test(x)) || '';
  const songs = Object.keys(parts)
    .filter((n) => parts[n].audio)
    .map((n) => [parseInt(n, 10), parts[n].title, parts[n].audio.url, kindOf((parts[n].video || {}).tags)]);
  const out = [];
  for (const num of Object.keys(parts).sort((a, b) => parseInt(a, 10) - parseInt(b, 10))) {
    const t = parts[num];
    const v = t.video;
    if (!v) continue;
    const k = kindOf(v.tags);
    const n = parseInt(num, 10);
    const picks = songs
      .slice()
      .sort((a, b) => (a[0] !== n) - (b[0] !== n) || (a[3] !== k) - (b[3] !== k) || Math.abs(a[0] - n) - Math.abs(b[0] - n))
      .slice(0, 5);
    out.push({
      id: num,
      name: t.title,
      video: v.url,
      poster: t.image ? t.image.url : null,
      tags: v.tags || [],
      price: '$4.99',
      productId: 'collider.theme.' + num,
      tracks: picks.map((s) => ({title: s[1], url: s[2]})),
    });
  }
  return out;
}
