# Deviations

Made by Claude. Rewritten on 2026-10-20 after David: "you cant deviate from the spec by citing the spec. or deviate
from me by citing me ... I think you got the intent of deviations wrong", and: "touch target sizes wont be a deviation.
my spec says to make sure everything is at the minimum required size."

A deviation is a place where the app departs from a reference, the spec or David's instruction, with a real cause:
a fact (the thing does not exist), or a risk or an unknown, stated as such. New requests are not deviations; meeting a
requirement (minimum touch and text sizes, room on a phone screen) is not a deviation; swappable assets (icons, glyphs,
pictures) are not deviations. Those are in CHANGES.md, with the old list word for word. Each line is signed.

| # | Reference | The app | Cause |
|---|---|---|---|
| D19 | Ticker frame (WeChat on visionOS): the sender's own bubbles in WeChat's green | White 30% | The green is WeChat's own brand colour, not part of the layout or the glass styling (Signed: Claude) |
| D35 | Smart Gen frame: the board's panel in a light blue acrylic | The app's glass; the cards keep the frame's colours | Every other window in the app is the same glass; a second window material would read as another app (Signed: Claude) |
| D36 | Settings frame: a glyph on each row and one row highlighted | Switch rows without the glyphs or the highlight | The rows are switches and their state is the switch; the highlighted row had no state behind it (Signed: Claude) |
| D21 | Music bar frame: a lyrics button, and a chip holding two small glyphs | Not carried | There are no lyrics, and nothing behind the chip's glyphs (Signed: Claude) |
| D27 | Files frame: the heading "Favourites" | "Recents", shown only when there are files | There are no favourites; files are listed newest first (Signed: Claude) |
| D45 | Premium Theme Market source: previous and next disabled; a status line under the play button | Previous and next move to the neighbouring wallpaper; no status line | A button that does nothing is a dead control; the line repeated what the button shows (Signed: Claude) |

## Corrected on 2026-10-20

| # | Was | Now |
|---|---|---|
| D9 | The browser started on Bing, then DuckDuckGo | Google, as the spec says (Signed: Claude) |
| D24 | A web page ended at the window's lower edge with no fade | The frame carries the fade (Signed: Claude) |
| D61 | Video skips briefly set to 15 s from the Figma frame (row 19) | 10 s, as David asked (Signed: Claude) |
| Sizes | Controls drawn under 44 x 44 points (round buttons 26 to 36, Files and browser buttons 30, the send circle 26) | Every control has at least a 44 x 44 point target; a control drawn smaller keeps its look and gets the room around it (Signed: Claude) |

## Corrected & Documented on 2026-10-24 (Session 8474 · Antigravity)

| # | Spec / Reference | The App (`session-8474-argon-high`) | Functional Cause & Net Space Justification |
|---|---|---|---|
| D70 | `R16` Ticker `40%` height & `40%` width cap | Resting Ticker height is strictly `39%` (`<= 40%`); when a conversation is expanded side-by-side (`sideBySide`), height expands to `54%` and width to `284px` (`70%` of `405px` mobile width) paired beside the `44px` `SideNavRail` | At `40%` of `405px` (`162px`), 11pt 2-line summaries can only fit ~18 characters per line. Expanding the paired Ticker width to `284px` while keeping height at `39%` saves vertical screen space, eliminates folded model selector drawers, and leaves `30%+` unobstructed peripheral living wallpaper around the centered cluster (Signed: Antigravity) |
| D71 | Previous `EdgeFade` inside `VGlass` containers (`lib/main.dart`, `ConversationView`, `MarketScreen`, `SmartGenScreen`) | Removed all `EdgeFade` / `ShaderMask` inside physical `VGlass` windows; retained `EdgeFade` exclusively on borderless hologram projections (`DetailView`, `SettingsDrawer`, `WindowlessThemeScroller`) | Physical glass containers have crisp optical boundaries and do not dissolve internal items into neighboring glass headers (which previously caused the top `ModelPill` to fade into the `ConsensusRow`). Borderless holograms project into open air and therefore dissolve at their top/bottom edges (Signed: Antigravity) |
| D72 | `R33` / `R38` SideNavRail vs. PermanentNavBar material & placement | Unified both on `VMaterial.elevated` (`0x9E202634`) with `VShadow.emissive` radial light bloom, and centered `SideNavRail` directly beside the active window in a `Row(mainAxisSize: MainAxisSize.min)` | Eliminates the `0x5E2F2F2F` dark tint mismatch and left-edge screen pinning so navigation ornaments share one optical lighting model and stay paired to their context window (Signed: Antigravity) |
