# Collider (Flutter) — Claude's build

Made by Claude for David Ebri. Source folder on David's computer:
`C:\Users\D\Documents\collider_flutter__CLAUDE_live-models-consensus_20260927`

## Run

- `Collider.exe` (built by `_ds_work/build_exe.ps1`), or `python tools/collider_app.py`.
- A launch window comes up first: the host number at the top (a free random one each time), then every
  provider with its address, key and models, each showing where the app reads it, then where the themes come from.
  Enter saves `data/collider_config.json` and opens the app at that host. The last configuration comes back next time.
- `python tools/collider_app.py --go --host 30111 --server-only` runs the server on that host with the saved configuration.

Keys live only in `data/collider_config.json` on the computer running it; `data/` is not in this repository.

## Where things are

- `lib/` the Flutter app (web build served by the local server).
- `tools/collider_server.py` the local server: models, consensus, files, browser pages, `/api/themes`.
- `tools/collider_config.py` the configuration the launch window edits.
- `tools/collider_app.py` the launch window and the app window.
- Live wallpapers: David's Cloudflare R2 bucket `collider-themes`, listed by its Worker; see `themes()` in the server.
- `docs/INTENT.md` David's words; `docs/DEVIATIONS.md` every departure from his frames, with the reason.
