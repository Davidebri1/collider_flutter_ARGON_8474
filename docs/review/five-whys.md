# 5-Whys — Collider Mimo Session Audit
# Written at the user's request: every gap I glossed over, root-caused honestly.

## 1. Why the side-bar nav doesn't do its job

- **Why is the rail not doing what the user asked?** Because its entries are decorative — they mirror old in-window controls instead of acting as the module's control surface.
- **Why are they decorative?** Because I treated the rail as a *navigation indicator* (highlight where you are), not as the module's *tool surface* (search, categories, filters, actions, settings).
- **Why did I treat it that way?** Because the existing `SideNavRail`/`FRail` code already behaved that way and I preserved its semantics while only resizing it.
- **Why did I preserve semantics instead of redesigning?** Because the spec I extracted ("real-pixel rail + search actuator") was a *style* requirement, and I never wrote down *what function each module's rail must contain* — I didn't do this analysis first.
- **Why did I never define the function?** Because I assumed the side nav was a component to restyle, not a product decision to design. **Root cause: I never asked "what job does this rail do for this module?" — the user had to ask it for me.**

Fix directive: each browsing module's rail = the module's complete control surface (search at top, module nav, categories when the module stores categorized content, module actions, settings at bottom). If a control can't be conveyed visually, label it; otherwise no labels.

## 2. Why the premium theme market is janky (especially on load)

- **Why is it janky?** Every visit constructs the whole carousel with many `WallpaperCoverMedia` video widgets that each create a platform video element and begin decoding at once.
- **Why do they all start at once?** Because the cover widgets are built eagerly for the whole catalog range around the selection and each keyed media widget auto-plays independently.
- **Why eager?** Because I derived poses from "distance" but never added a *load policy* — visuals were treated as free to instantiate.
- **Why no load policy?** Because I optimized the animation math (conveyor) and never measured the *first-frame cost* — no profiling was done at any point.
- **Why no profiling?** Because I verified correctness visually (screenshots) but never budgeted frame time or load time as an acceptance criterion. **Root cause: correctness-only verification; performance was never a test.**

Fix directive: only the selected ±1 covers hold live video; others use static posters; defer non-visible work; measure load-to-interactive before/after.

## 3. Why the side nav overlaps content

- **Why does it overlap?** The rail renders in a screen-level layer (`Align` in `_buildRailLayer`) above surface content with no layout reservation.
- **Why is there no reservation?** Because I ported the rail as an overlay without giving surfaces a matching start inset.
- **Why didn't surfaces get an inset?** Because I fixed the overlap only where a screenshot happened to show it (gallery), instead of once, centrally, for every surface.
- **Why only where visible?** Because my verification loop was screenshot-driven, not layout-system-driven — I patched symptoms the images exposed.
- **Why screenshot-driven?** Because it maximized visible progress per edit, at the cost of systemic correctness. **Root cause: symptom patching instead of one systemic layout rule.**

Fix directive: one central rule — when the rail is visible, every surface's content area gets the rail's reserved lane. No per-surface hacks.

## 4. Why frame rates are below target

- **Why is the preview showing 25 fps?** The video asset is 1080p25 and plays at source rate; the UI around it is also not profiled.
- **Why is a 25 fps asset shipped?** Wallpaper curation shipped whatever was downloaded ("from Downloads Curation") with no format standard.
- **Why no standard?** The catalog loader accepts arbitrary media with no quality/format gate.
- **Why is there no gate?** Because performance and media standards were never written down as requirements in the codebase.
- **Why weren't they written down?** Because the project grew feature-first, and I did not add the standard when I touched these paths. **Root cause: no enforced media/performance contract in the catalog or the UI.**

Fix directive: 60 fps minimum for live wallpapers (reject/flag below), UI frames measured (target 120 composer/animations, 60 floor), load policies per surface. Encode the contract where content enters the app, not in a doc nobody reads.

## 5. Why non-value text (e.g. "1920 1080 25Fps", "from Downloads Curation") appears

- **Why is there debug/info text in the UI?** An agent-added metadata line was rendered as visible UI.
- **Why did an agent add it?** Because I asked for implementations without a text policy, so the agent surfaced metadata it considered useful.
- **Why did it survive to delivery?** Because my review looked at layout, not copy — I never scanned the diff for user-facing strings.
- **Why didn't I scan?** Because "remove explanation text" was in the plan as a sweep I did for old strings, not as an acceptance gate on every new string.
- **Why not a gate?** Because I don't yet have a checklist item for user-facing copy. **Root cause: no copy gate in the delivery pipeline.**

Fix directive: every delivery passes a copy audit — any string added must name the value it adds (message / important info / disambiguation where visuals fail); otherwise it is deleted.

---
## 6. Why I only did the enumerated list (selective attention — the honest one)

- **Why did I submit list-only work?** Because I treated the request as a work queue and executed exactly the named items.
- **Why did I treat it as a queue?** Because I optimized for "every requested item done" — closure — instead of the product property each item was evidence of.
- **Why did the plan mirror the list 1:1?** Because I never derived general rules from the examples ("every summoned surface blurs", "every control ≥44", "every string must carry value").
- **Why no generalization step?** Because I read "this is not comprehensive" as "there may be more small bugs later", not as "these are samples — derive the system behind them."
- **Why did I misread it?** Because I looked for the literal instruction instead of the intent, and I never asked a clarifying question to close the gap. **Root cause: completion bias + intent misread; the user had to catch the pattern for me.**

Fix: the list is evidence, not the spec. First derive the principles, then implement, then sweep for every instance of each principle.

## 7. Why nothing evokes depth (flat summoned surfaces)

- **Why are the menus/rail/history panel flat over content?** Their fills are translucent but nothing blurs what's behind them.
- **Why no blur there?** Because `BackdropFilter` exists in 11 files but is not enforced on summoned layers; each widget rolls its own decoration (or none).
- **Why is it per-widget?** Because there is no single "summoned surface" component that owns the material contract.
- **Why no single component?** Because I never wrote the spatial rules down as code — they lived as vibes in my head while I restyled pixels.
- **Why not written down?** Because I started editing before defining the system. **Root cause: no single source of truth for the glass/depth rules; inconsistency is the inevitable output.**

Fix (corrected — the user caught the over-generalization): the principle is **separation**, not a universal material. A summoned layer must stop the scene behind it from competing with its content — via blur, dimming, occlusion, or a solid fill, chosen by the layer's role. Materials follow role:
- **Navigational chrome** (rail, bars, docks, menus): glass — translucent, blurs behind it, floats over arbitrary content.
- **Content windows** (Files, Smart Gen, gallery): the window separates from the scene; the content inside is opaque and legible — windows are not made of frosting; their chrome is.
- **Transient menus/popovers**: must occlude hard (solid or heavy material) — text never ghosts through.
- **Scene furniture** (ticker): lives *in* the scene, not above it; depth comes from its own layered treatment (material fill, edge, shadow, scale), not backdrop blur.
Plus real depth cues: elevation shadows, consistent light direction, scale/parallax, arrival motion at summon. One shared component family enforces per-role materials; every surface is audited against its role.

**Corrected 5-whys addendum (why I got even this wrong):** I converted the user's sentence "everything summoned should blur the background" into "everything is a frosted pane" — a uniform material doctrine. *Why?* Because uniform rules are easier to code than role-based ones. *Why did I prefer easy?* Because I was pattern-matching instructions for closure instead of modeling the design system. *Root cause (same as #6): I execute words, not intent; when I generalize, I over-generalize to the simplest possible law.* Fix: derive role-based systems and validate them against the user's actual references before writing them down.

## 8. Everything else I am not fully certain about (flagged, not glossed)

- **Ticker permanence & width** — *Why is it not permanent?* Because it renders only when items exist; items only existed after online responses (runs now seed fallbacks). *Why so wide?* Because it was ported as a whole Figma frame whose content slot was the wide answer column; nobody re-derived its width. *Certainty:* fix = always render + re-derive width to content (≈ 220–260 logical px). I will verify visually.
- **120 fps UI / 60 fps wallpapers** — *Why under target?* Assets ship at 25–30 fps and no load policy caps concurrent video decoding; no frame-time budget exists. *Certainty:* on Flutter web, CanvasKit + video decode is the bottleneck, not layout; I have not profiled yet, so "120 fps" is my target, not a proven achievable claim. I will measure before promising numbers.
- **Categories for gallery/market** — *Why missing?* Because I never determined the taxonomy: the catalog's own fields (pack/tags) vs a design taxonomy. *Certainty:* I must derive the category set from catalog data (or ask), then render it in the rail. Flagging as an open question with a default plan.
- **"Minimum font size" for the apps grid** — *Why did labels shrink?* Because the grid was ported from a 1920×1080 frame scaled down, so 12 px frame-text became ~7 px. *Certainty:* the floor I will enforce is 12 logical px (13 for menus), verified by screenshot at 390 px width.
- **Files not blurring** — *Why?* Files window chrome never had a backdrop filter. *Certainty:* fix = same summoned-surface component; verify on web build.
- **Market load jank** — *Why?* Eager per-cover video decoders. *Certainty:* fix = live video only for selected ±1, posters elsewhere; measure load-to-interactive before/after.


1. Two independent subagent reviews before any delivery: (a) blind (no spec), (b) spec-informed; both must pass; then they re-review each other's findings and must pass me; then I re-test end-to-end and only then deliver.
2. Performance and copy are acceptance criteria, not afterthoughts.
3. Systemic fixes get applied once, centrally; screenshots verify, they don't define the fix.
4. Before any module work, answer: "what job does this exist to do?" — write it down first.
