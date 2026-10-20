# Deviations

Made by Claude. Rewritten on 2026-10-20 after David: "you cant deviate from the spec by citing the spec. or deviate
from me by citing me ... I think you got the intent of deviations wrong."

A deviation here is a place where the app does not do what a reference, the spec or David's instruction shows,
with the cause. A cause is a function the reference would break (a target too small to hit, text too small to read,
something that does not fit the screen), a fact (no such feature exists), or a risk or an unknown, stated as such.
Changes David asked for, and swappable assets (icons, glyphs, pictures), are not deviations: they are in CHANGES.md,
with the old list word for word. Each line is signed.

## Departures with a cause

| # | Reference | The app | Cause |
|---|---|---|---|
| D2 | Theme Gallery round controls 50 across (23 at a phone's scale) | 36 across | A finger has to hit them (Signed: Claude) |
| D3 | Theme Gallery thumbnails 86 tall (39 at a phone's scale) | 56 tall, the frame's 50 : 86 kept | A finger has to hit them (Signed: Claude) |
| D4 | Theme Gallery name 24 (11 at a phone's scale) | 20 | It has to be read (Signed: Claude) |
| D7 | Browser buttons 60 across, bar 80, field 64 (18, 24, 19 at a phone's scale) | Buttons 30, bar 42, field 30 | A finger has to hit them, and the bar has to leave room for the page (Signed: Claude) |
| D9 | David: "DUCKDUCKGO" | DuckDuckGo, through its HTML page (html.duckduckgo.com); an address on duckduckgo.com is sent there | DuckDuckGo's script page answers the app's page loader with a bot puzzle (seen 20 Oct); its HTML page gives the results. Before 20 Oct the browser started on Bing, with no good cause recorded for leaving DuckDuckGo out: corrected (Signed: Claude) |
| D11 | Files type at the frame's scale: tile name 7 on a phone | Type at 0.79 of the frame instead of 0.60 | At 0.60 the tile name would be 7 px; it has to be read (Signed: Claude) |
| D12 | Files buttons 42 (25 at scale) | 30 | A finger has to hit them (Signed: Claude) |
| D13 | Files search field in the title bar | On a phone, under the title bar's first row | A phone's title bar has no room for it beside the title and the buttons (Signed: Claude) |
| D14 | Files: eight tiles, each with a "..." menu; share and more buttons | Four tiles (Uploaded, Generated, Purchased, Downloaded); no per-tile menu; upload and close | Files come from four places; a place has nothing to offer in a menu; upload and close are what the window does (Signed: Claude) |
| D15 | Files window centred with wide margins | On a phone, 8 from the left (with the side menu) and 10 from the right | A phone has no room for the frame's margins (Signed: Claude) |
| D17 | Ticker rows and the opened conversation side by side | On a phone the conversation takes the rows' place | 402 across cannot hold two columns (Signed: Claude) |
| D19 | The sender's own bubbles in WeChat's green | White 30% | The green is WeChat's own colour (Signed: Claude) |
| D21 | Music bar: a lyrics button and a chip with two small glyphs | Not carried | There are no lyrics; the chip's glyphs have nothing behind them (Signed: Claude) |
| D27 | Files heading "Favourites" | "Recents", shown only when there are files | There are no favourites; the files are listed newest first (Signed: Claude) |
| D35 | Smart Gen panel in the frame's light blue acrylic | The app's glass; only the cards carry the frame's colours | Every other window is the same glass (Signed: Claude) |
| D36 | Settings rows with the frame's glyphs and a highlighted row | Switches without the glyphs or the highlight | The rows are switches; their state is the switch (Signed: Claude) |
| D43 | Premium Theme Market source: iTunes and AudioDB services, three cover hooks, AlbumCoverAdmin, BackgroundVideo, the 50-song list | Not carried | Nothing called them, or they served only the music the market no longer has (Signed: Claude) |
| D44 | Premium Theme Market source builds every cover at once | Builds the covers that can be on screen; looks the same | Speed (Signed: Claude) |
| D45 | Premium Theme Market source: previous and next disabled; a status line under the button | Previous and next move to the neighbouring wallpaper; no status line | A button that does nothing is a dead control; the line repeated what the button shows (Signed: Claude) |
| D75 | Files grid cells 68 x 48 (the frame) | Square cells, 88 across | Each file now shows its own picture (a page, a photo, a model); at 68 x 48 a page was too small to recognise (Signed: Claude) |
| D76 | Apple, HIG Color: "prefer a monochromatic appearance for toolbars"; visionOS draws most glyphs white | Icons that name a thing are in colour across the app; plain controls stay white | David: "the rest of the icons need to be in color too. visionOS isnt meant to be stale" (Signed: Claude) |

## Corrected on 2026-10-20 (no good cause)

| # | Was | Now |
|---|---|---|
| D9 | The browser started on Bing | DuckDuckGo (above) (Signed: Claude) |
| D24 | A web page ended at the window's lower edge without a fade, "because the app cannot fade inside a web frame" | The frame carries a mask: the page recedes over an eased ramp at its lower edge (Signed: Claude) |
| D61 | Video skips of 10 s, "Material has no 15 s glyph" | 15 s, as the reference: the circular arrow with 15 set in it, mirrored for forward (Signed: Claude) |

## Open

| # | Instruction | Where it stands |
|---|---|---|
| O1 | David, 20 Oct: "implement your smart gen find and the discover market find where you see fit" (the two Vercel templates Claude named when asked which templates would help: Tersa, an AI workflow canvas, and an AI image generator) | Tersa: not put in. Smart Gen is a board of cards; a canvas that chains models is a different tool, and nothing in the app has a use for it yet. Image generator: waiting on one answer, below (Signed: Claude) |
| O2 | Image generator in Discover Market | Discover Market shows the live wallpapers and takes no typing (CHANGES D58: "NO PROMPT anthing in this app"). Grok's Imagine, which it follows, has a bar to make pictures. Which holds is David's call; nothing is built until then (Signed: Claude) |
