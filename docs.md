# Urge Surfer — Technical Notes

Living technical doc. Each commit that changes structure or dependencies should update this file in the same commit.

The product/design source of truth is `~/.claude/plans/the-goal-of-this-snappy-dolphin.md`. This doc covers the **how**, not the **what**.

---

## Project layout

A static web app. No build step, no bundler, no runtime dependencies.

```
Dockerfile            static Caddy image; no application runtime
compose.yaml          one-command local or public deployment
config/production.js  production feature switches copied into the image
index.html            every screen's markup, toggled with `hidden`
styles.css            one fluid layout, light and dark
src/
  main.js             screens, hash routing, localStorage
  canvas.js           the tracing surface: frame loop, pointers, camera, painting
  tracer.js           the pen simulation
  composer.js         phrase -> traceable polyline
  glyphs.json         cursive centerline data
  join.json           global join tuning — shared with the join editor
  pairs.json          hand-tuned joins for specific letter pairs
  features.js          development feature switches; defaults on locally
  phrases.js          the phrase list, and the deck that walks it
server/
  Caddyfile           TLS and static file serving
test/                 node:test suites for composer.js, tracer.js and phrases.js
tool/glyphdata.py     glyph loading/saving + the join maths, shared, no UI
tool/glyph_editor.py  desktop editor for the letterforms
tool/join_editor.py   desktop editor for how pairs of letters connect
vendor/               letterpaths dataset (provenance) + Sacramento font (glyph editor overlay)
assets/phrases/       JSON phrase library — reviewed content, read by src/phrases.js
```

`package.json` exists only to mark `src/` and `test/` as ES modules so `node --test` can run them. There are no dependencies and nothing to install.

Was previously a Flutter phone app (Riverpod, drift/SQLCipher, go_router). The drawing model and the glyph data carried over; everything else was replaced by the platform's own equivalents — DOM instead of widgets, `localStorage` instead of an encrypted database, hash routing instead of go_router.

## Running and testing

```sh
python3 -m http.server 8000     # then open http://localhost:8000
node --test test/               # needs Node 20+ for JSON import attributes
python3 -m unittest tool.test_glyphdata
bash tool/check_no_network.sh
```

A server is required: browsers refuse ES modules over `file://`, and the JSON data files are loaded with import attributes, which need an `application/json` content type.

## Browser requirements

Chrome 123+, Safari 17.2+, Firefox 132+, or newer. The floor is set by JSON import attributes (`import … with { type: 'json' }`). Also assumed: ES modules, `ResizeObserver`, Pointer Events, `dvh` units, `:has`-free CSS.

## The drawing model

Three pure-ish layers, each testable on its own.

### `composer.js` — phrase to polyline

Glyphs are authored in unit coordinates: `x ∈ [0, advanceWidth]` left to right, `y ∈ [0, 100]` top to bottom, baseline at `y = 70`, x-height top at `y = 30`, ascender top at `y = 10`, descender bottom at `y = 95`.

`composePhrase(phrase)` returns a `ComposedPath`:

- `points` — one dense polyline in scaled world coords.
- `strokeStart` — index where each stroke begins. The points list **jumps** in absolute coords at these indices; renderers must `moveTo`, not `lineTo`.
- `letterStart` / `letterEnd` — inclusive point range per letter.
- `letterCenterX` — world-space horizontal centre of each letter, midway between its first and last point. Used only to aim the camera.

Composition is two passes per word, matching how cursive is actually written. Pass one walks the letters, sampling each glyph's `strokes[0]` and joining consecutive letters — this is the word body, one continuous stroke unless a `liftAfter` letter breaks it. Pass two emits every `strokes[1..]` (i/j dots, t and T crossbars) as separate strokes afterwards, so the user goes back to dot and cross. There are no bridging samples between words.

Constants: `GLYPH_SCALE = 2.2`, `SPACE_WIDTH = 30` (unit coords). How letters connect is tunable and lives in `src/join.json`.

#### Joining letters

Every glyph in the dataset **enters at the baseline** (`y ≈ 70`, heading up at roughly -75°) and **exits at mid height** (`y ≈ 51`, heading up-right at roughly -63°). Drawing both as-is means each letter's lead-out and the next letter's lead-in are *the same connecting stroke drawn twice*: the pen climbs to mid height, about-faces 135–214° to dive back to the baseline, then about-faces again to climb out. Two cusps and a retrace at every join.

The fix is to drop the duplicate — **both halves of it**. Every letter hands over to the next at one fixed height, `HANDOVER_Y = 51`, and the connecting stroke is drawn exactly once. For every letter in a word:

1. **Trim the lead-in**, unless it starts the word — you do start a word from the baseline. Discard leading points until the path first rises to the handover height. That is 3–29% of a lowercase glyph (median 9%): the rise from the baseline and nothing else. Glyphs that already start at or above that height, which is most capitals and the period, lose nothing.
2. **Cut the lead-out**, unless it ends the word — you do finish the last letter. The tail is cut at the glyph's own `leadOut`, dropping the closing rise back up to the handover height. That is 9–31 units of a lowercase glyph; `o`, `v` and `w` exit high enough that there is little or nothing to drop.
3. **Place by the cut, not by `advanceWidth`.** The letter is offset so its trimmed start sits `join.gap` to the right of the previous letter's cut. The connecting stroke sets the spacing, the way it does by hand, and letters can no longer collide — several glyphs' exits (`m` reaches `x = 88` against an advance of 53) used to overshoot well into the next letter's slot.
4. **Bridge with one cubic**, leaving along the previous letter's final direction and arriving along the trimmed letter's opening direction, both measured from the sampled points rather than the bezier control points so the cuts are accounted for.

Steps 1 and 2 are mirror images, and between them the run-up between two letters belongs to neither letter: the bridge draws all of it.

#### Capitals that hand over to nothing

Nine capitals — `B D F I P T V W Y` — carry `liftAfter: true` and opt out of all four steps. Their main stroke ends somewhere the next letter cannot be reached from, so there is no handover to share: nothing is cut on either side of them, no bridge is drawn, and the next letter begins a stroke of its own, which is how they are written by hand. Any pair tuned for them in `pairs.json` is ignored, and the join editor does not offer those pairs at all.

The flag has to sit on the **first** letter. It is not a property of the second one — `a` after `c` still wants its lead-in cut — and it cannot be derived from `leadOut: 1`: thirteen capitals keep their whole tail, but `G O Q U` exit far enough right and low enough that the automatic join still reads, so they keep it.

**The test for needing this is the shape, not the letter.** A stroke that ends left of ink it has already laid down cannot hand over, because the next letter is placed against the exit and would land on top of that ink. `B` was redrawn and joined the family: it sweeps right to `x = 46.4` and loops back to exit at `14.2`, dropping the next letter 18.1 units inside itself. Cutting the tail cannot help — `suggest_lead_out` walks forward looking for a cut that is the rightmost surviving point, finds none, and returns `1.0`. Lifting the pen is the fix, and it is how a capital `B` is written by hand anyway.

`liftAfter` also changes how the next letter is **placed**. Everywhere else a letter is offset from the previous letter's cut, but there is no cut here, and for these letters the exit is not the rightmost ink: `F` exits at `x = -25.8` having already reached `x = 40`, and `D` exits at `x = 31` with ink out to `44`. Placing by the exit dropped the next letter inside the capital. After a lift the offset is measured from the previous letter's rightmost ink instead, and by `join.liftGap` rather than `join.gap`. The two are different distances: `gap` is the room a connecting stroke needs, and a lift draws no connecting stroke, so spending the full 13.24 there left a hole in the middle of the word. `liftGap = 6` puts the next letter 0.55 units of visible daylight away — the stroke is 5.45 units wide, so anything under that overlaps the ink rather than closing the gap.

#### Letters that hand over from a later stroke

`joinFromSecondStroke` moves the handover one stroke along, and only capital `K` carries it. `K` is drawn spine first, the pen lifts, and it is the arms that carry on into the next letter — so the stroke that joins is `strokes[1]`, while `strokes[0]` is drawn before it rather than deferred to the second pass. Everything after the joining stroke is still deferred.

Without the flag `K` hands over from its spine, which ends at `x = -6.8` having already reached `19.7`, and the arms then reach `44.2` — so the next letter was drawn straight through them, overlapping by 50 units. The flag was plumbed through `composer.js`, `glyphdata.py` and both editors before it was set on any glyph, which is exactly how that went unnoticed: the machinery was all in place and dormant.

The 180° reversals that remain in a phrase are inside letterforms: `a`, `i`, `o` and `q` reverse at the top of their bowls when composed entirely alone.

**Where 51 comes from.** Two independent measurements. Across the 56 pairs that were hand-tuned before `leadOut` existed, the second letter's cut landed at `y = 50.0..52.2` for 24 of the 26 letters — a spread of one to two point spacings, which is the resolution the data can express at all. And Sacramento, checked directly: it has **no** OpenType joining features (`GSUB` carries `aalt frac liga ordn sups`, `GPOS` only `kern` — no `calt`, no `curs`), and instead bakes a fixed convention into every outline. Each lowercase glyph overhangs its advance by exactly 110 font units and ends that overhang at 46% of the x-height, which is `y = 51.6` here. A joining script font and a hand-tuned dataset agreed to within half a unit.

`src/join.json` holds the two global tunables, `gap` and `liftGap`. Both `composer.js` and `tool/glyphdata.py` read them, so the join editor's preview and the app agree by construction. The editor's slider edits `gap`; `liftGap` is a file edit, and `glyphdata.py` reads it once at import.

Cutting the lead-out narrows words by 12–32% (median 21%) against keeping the whole tail, because each letter now starts from a cut that sits further left than its exit did. `gap ≈ 29` restores the old widths if that reads too tight; `13.24` is what the hand-tuned pairs used, and they were tuned with the tail already cut.

#### Hand-tuned pairs

`src/pairs.json` overrides the automatic join for named letter pairs. A pair stores **the connection, not the letterforms**:

| field | meaning |
|---|---|
| `from` | where the first letter's tail is cut, 0–1 along its main stroke |
| `to` | where the second letter's head is cut, 0–1 along its main stroke |
| `dx` | the second letter's cut point relative to the first's, horizontally, in glyph units |
| `h1`, `h2` | the connecting bezier's control handles, as offsets from the cut they belong to |

Vertical placement is not stored — both letters stay on the baseline, so the heights follow from where the cuts land.

**Pairs compose into words.** `ca` plus `ap` gives `cap`, exactly, with no blending. Two facts make that true:

1. A join depends only on the two letters in it. Everything before merely translates what follows, so the `a→p` join is bit-identical in `ap`, `cap` and `scrap`. `test/composer.test.js` asserts this.
2. The two joins around a letter touch opposite ends of it. In `cap`, `c→a` cuts `a`'s head and `a→p` cuts `a`'s tail; they never write the same field. This is why the per-pair data must stay connection-only — there is one `a` glyph with one path, so per-pair *letterforms* would overwrite each other.

The failure mode is a letter consumed from both sides: if `from` on one join falls before `to` on the other, nothing survives. `composer.js` clamps so at least one segment remains, and the test suite checks every stored pair against `xy`, `xyy` and `xxy` to catch it.

Any pair not listed falls back to the automatic join, so partial tuning is useful immediately — there is no need to fill in all 1118 combinations before the file does anything.

**`pairs.json` is now an exceptions file, and it should stay small.** It once held 56 pairs, tuned by hand before `leadOut` existed. Grouping them showed the tuning was per-letter, not per-pair: `to` landed at the handover height for every second letter, `dx` was left at the default in 42 of the 56, and `h2` sat a median 1.48 units from the automatic tangent. Only `from` carried real information, and it clustered by *first* letter — `a` 0.849–0.882, `b` 0.915–0.949, `c` 0.814–0.845. That is what `leadOut` stores. Recomposing each pair with and without its entry left 43 of the 56 differing by under 3 units against a 7.3-unit stroke width, so they were dropped. The 13 that remain are `a` before a round or narrow letter (`aa ac ad ae ag ai aj ak al am an ao`) plus `be` — the pairs where `dx` was pulled down to 4–6 against a `gap` of 13.24, which no per-letter number can express.

**`advanceWidth` is no longer used for layout.** It survives in `glyphs.json` and as a guide in the glyph editor, but changing it will not move anything on screen.

#### Sampling

Points are spaced evenly **along the curve**, `POINT_SPACING = 2` world units apart. Each cubic is first sampled at 400 even steps of `t`, then respaced by arc length.

Sampling at even steps of `t` — what the Flutter version did — is not good enough. A cubic with distant control points (the `t` glyph's second bezier, for one) accelerates hard near one end, leaving gaps of 25 world units between consecutive samples. The tracer only credits progress for points it passes within `8 * GLYPH_SCALE = 17.6` units of, so a gap that big strands the pen. `test/composer.test.js` asserts the spacing invariant across every shipped phrase and both alphabets.

### `tracer.js` — the pen

The pen chases the finger at a constant `PEN_SPEED = 70` px/s. Moving the finger faster just leaves the pen trailing; that lag is the mechanic. `penSpeed = Infinity` turns it off (the development-only "pen lag" toggle).

Progress (`index`) advances only while the pen passes within `8 * GLYPH_SCALE` of the *next* point, one point at a time, and never decreases. Straying off the path, or racing ahead and stopping, leaves progress where the pen last actually passed — you have to go back. Progress cannot cross a stroke boundary; `advanceStroke()` teleports the pen to the next stroke's first point, and the canvas gates that on where the user touched.

Pen-up (the default, and after every pointer release) freezes everything: `setFinger` is ignored and `tick` is a no-op.

`tick(dt)` takes seconds, so 60Hz and 120Hz displays reach the same place after the same wall-clock time.

### `canvas.js` — the surface

Owns the `requestAnimationFrame` loop, pointer events, the camera, and all painting.

- **Camera.** Horizontal only; the phrase is centred vertically once per resize. `panX` tweens toward its target through a low-pass filter (`τ = 0.25 s`). The target is the leading edge of progress, so the canvas moves only while the user is advancing — except when the current stroke is complete and another remains, when it hops to the next stroke's first letter so the user can see where to tap.
- **Pointers.** Raw `pointerdown/move/up`, so a tap without a drag registers. On pointer-down, if the current stroke is complete, the touch must land within `NEXT_STROKE_GATE = 100` world units of `nextStrokePoint` or it is ignored entirely.
- **Chevrons.** Each stroke is split into segments at its sharp corners (local turn angle ≥ 90° over a ±5-point window). One chevron marks the active segment, pointing along the local tangent; it pops to double size and full opacity on becoming active, then eases down over 0.6 s.
- **Painting.** Ink colour comes from the canvas element's CSS `color`, so the light/dark theme drives it with no JS involvement. Opacity is `globalAlpha`: 0.25 for the template, 0.7 for the traced part.
- **Sizing.** The canvas is sized by CSS; a `ResizeObserver` sets the backing store to `clientWidth × devicePixelRatio` and re-centres vertically. Wide screens simply show more of the phrase — the glyph scale does not change. Height therefore has to be tall enough for the ink: the shipped phrases compose 200–350 world units high, and a word pairing the highest capital with the lowest descender (`D` and `g`) reaches 424. The CSS clamp is `280px, 60vh, 440px`; anything shorter crops tall phrases top and bottom, which is what a 340px ceiling used to do to every phrase carrying a capital and a descender.

## Screens and storage

`main.js` holds three screens, all present in `index.html` and toggled with `hidden`:

- `#/` — the ledger: wave count, "Start a wave", "Just write" in development.
- `#/ritual` — four steps: name the urge, rate it 0–10, trace a random phrase, rate it again, then log.
- `#/write` — pick any phrase, or type a sentence of your own, and trace it; nothing is recorded.

Routing is `location.hash` plus a `hashchange` listener, so the browser back button works on phones. The ritual's four steps are internal state, not routes.

The tracing panel is a `<template>` cloned into whichever screen needs it, so the ritual and "just write" share one implementation. Only one is ever mounted; `unmountTracer()` cancels the frame loop and disconnects the observer.

A typed sentence is held only in the input element: it is traced and then forgotten, never stored and never added to the phrase list. It is checked against `canCompose` first, since the dataset covers `a–z`, `A–Z`, `.` and the space between words, and `composePhrase` throws on anything else — so digits, commas and apostrophes are rejected in the UI rather than crashing the tracer.

Only the integer wave count is stored in `localStorage["urge-surfer.waves"]`. On first load after upgrading, an older array of `{urge, before, after, phrase, at}` records is replaced with its length, erasing those details while preserving the count.

## No network

The app makes no requests after the page loads. The integer wave count uses `localStorage["urge-surfer.waves"]`; the shuffled phrase deck uses `localStorage["urge-surfer.deck"]`. The urge text, ratings, phrase and timestamp are discarded rather than stored.

`tool/check_no_network.sh` checks `index.html`, `styles.css` and `src/*.js` for absolute URLs and browser networking APIs. CI runs it on every push and pull request. This is a source-level guard, not a substitute for the browser security headers in the Caddy configuration.

The Compose file has two explicit services:

- `docker compose up dev --build` runs development mode at <http://localhost>, bind-mounts the working tree for immediate edits, and enables **Just write** plus the **pen lag** checkbox.
- `docker compose up prod -d --build` builds immutable production assets, disables both development-only controls, publishes HTTP, HTTPS and HTTP/3, persists Caddy certificate/configuration data in named volumes, and restarts unless stopped.

For a public deployment, clone the repository, point the `urgesurfer.surf` DNS records at the server, and run the production command. There is no Node service, database or writable application state. Update with `git pull` followed by the same command.

For a native production installation, copy the public files to `/srv/urge-surfer/public`, replace `public/src/features.js` with `config/production.js`, set `SITE_ADDRESS` in Caddy's environment, install `server/Caddyfile`, validate it, and reload Caddy.

## Glyph data and the editors

`src/glyphs.json` holds all 53 glyphs (`a–z`, `A–Z`, `.`) as `{advanceWidth, leadOut, liftAfter?, joinFromSecondStroke?, strokes}`, where a stroke is a list of cubic beziers and a bezier is four `[x, y]` control points. Stroke 0 is the joinable main stroke; `F`, `K`, `T`, `i`, `j` and `t` have a second one. `liftAfter` and `joinFromSecondStroke` are written only when true — the first for the nine capitals that hand over to nothing, the second only for `K`. `leadOut` is where the main stroke is cut when another letter follows, 0–1 along it; `1` keeps the whole tail, which is where the period and the thirteen capitals `B D F G I O P Q T U V W Y` end up — they either do not exit at the handover height, or they sweep right and come back before exiting, so cutting the tail would put the next letter on top of ink they already laid down.

`suggest_lead_out` seeds the value, and it has to tolerate a stroke whose last bezier overshoots its own end point: `s` comes back down and to the left over its final sample, which was enough to stop the walk-back on its first step and leave `s` uncut with its marker stranded at mid-height. Up to `OVERSHOOT_SAMPLES` trailing samples are skipped before the walk begins — bounded, because `O`, `U` and the period genuinely end on a descent and would otherwise be walked back through half the letterform.

The file is written one bezier per line so hand edits show up as readable diffs. `tool/test_glyphdata.py` asserts that loading and saving an untouched file is byte-identical, so opening an editor never churns the diff.

There are **two editors, deliberately separate**. Letterforms and connections are different jobs with different data, and one tool doing both made each of them worse.

```sh
sudo apt install python3-tk python3-pil
python3 tool/glyph_editor.py     # the letterforms, one at a time
python3 tool/join_editor.py      # how two letters connect
```

Both import `tool/glyphdata.py`, which owns the file loading and saving, the bezier maths and the join algorithm, and has no UI in it so it stays testable headless.

### `glyph_editor.py` — letterforms

Drag red anchors and blue handles; add, delete, disconnect and snap-merge anchors; pan with right-drag and zoom with the wheel. The Sacramento overlay renders the vendored font beneath the paths as a visual reference — stroke order stays deliberate and hand-authored rather than inferred from a font outline.

The overlay is normalised on the baseline, and on **x-height for lowercase, cap height for capitals**. Sacramento is a script face with flamboyant capitals: cap height 1550 against an x-height of 627, a ratio of 2.47 where a text face sits near 1.4. Normalising everything on the x-height put a capital 99 units above the baseline — 39 past the ascender guide — so the reference had to be shrunk by eye before it was any use. On cap height it lands within 3 units of the ascender guide, where this dataset's own capitals already sit.

Stroke 1 is the joinable one; every stroke after it is a second pass, drawn after the word is finished and begun with a tap. `+ Stroke` appends one, `Make main` promotes the selected stroke to first. `Make main` is what capital `T` needed: its stroke 1 was the crossbar rather than the stem, which is why there appeared to be no way to add a second stroke to it.

One orange marker on stroke 1 sets the glyph's `leadOut` — drag it along the path, searched locally so it cannot jump across a letter where the path loops back over itself, as `o` and `p` do. Grey dashed shows the tail it gives up, which the bridge to the next letter draws instead.

Two checkboxes carry the other two handover decisions: **Lift after** sets `liftAfter`, and **Hand over from stroke 2** sets `joinFromSecondStroke` (refused on a single-stroke letter). All three are letterform decisions, not connection ones: each is a property of the single letter, so they live here rather than in the join editor. `test_glyphdata.py` enforces that separation by name, which is why these are named for the handover rather than for the join — a `_on_join_…` method in this file reads as the glyph editor reaching into pair data and fails the check.

### `join_editor.py` — connections

Type a pair or step through all 1118 with the arrow keys; "Untuned only" skips the ones already done. The nine `liftAfter` capitals are left out of the sequence — they open no connection to tune. Two orange markers set where each letter is cut — drag them along their letter's path, searched locally so a cut cannot jump across a letter where the path loops back over itself. Two blue handles shape the bezier between the cuts. Dragging anywhere else kerns. Grey dashed shows what each letter gives up.

The view frames each pair on its **join** rather than on the letters, letting tall glyphs crop — fitting `g` whole shrinks the connection to a few pixels, and the connection is the thing being edited.

**Real weight** strokes the preview at the width the app uses. The editor otherwise draws centrelines, which is what you want for placing handles and useless for judging how heavy a join reads: `LINE_WIDTH = 12` in `canvas.js` is 3.4% of a word's ink height, against roughly 0.5% for the editor's editing view. The two numbers it copies out of the app are mirrored in `glyphdata.py` and checked against `composer.js`/`canvas.js` by `tool/test_glyphdata.py`.

Geometry otherwise matches the app exactly. It briefly did not: `composePhrase` used to shear the whole path 10° after joining, which the editor never showed, so a join tuned to look balanced arrived on screen leaning. The shear was removed rather than mirrored — what you draw in the editor is now what ships.

#### Cut fractions are arc length, not bezier parameter

`from` and `to` index into a stroke's respaced point list, so they mean *fraction of the drawn line*. `glyphdata.py` therefore has to respace exactly as `composer.js` does. It briefly did not — it sampled at even steps of `t` — which put every cut somewhere other than where the app applied it, by a median of 6 glyph units and up to 21. The stored fractions from that period were converted in place: both samplings trace the same curve, so the arc-length fraction of the intended point is recoverable exactly, and the conversion landed every cut within 0.834 units of where it was drawn — inside the 0.909-unit point spacing, which is the resolution the format can express at all.

A pair is stored only once it differs from the automatic join, so `pairs.json` stays a record of decisions rather than of defaults, and `Reset` drops one back to automatic. The global `Join gap` lives here too, since it is the same kind of decision.

**Tune the glyphs before the pairs.** A pair is tuned against a glyph's current shape, so reshaping a letter afterwards invalidates every pair that uses it — up to 52 of them for a letter used in both cases. Set its `leadOut` first too, for the same reason and in the same tool: one number per letter decides 26 joins, so it is worth getting right before tuning any pair by hand.

Glyph work is **visual and subjective**. Expect a "longer descender on g, smoother c entry" feedback loop; `glyphs.json` is the only file that needs to change for it.

## Verification status

- `node --test test/` — 30 tests, passing.
- `python3 -m unittest tool.test_glyphdata` — 19 tests, passing (the composer cross-check needs node 20+ on `PATH`, and skips otherwise).
- `bash tool/check_no_network.sh` — passing.
- Manually driven in Chrome: full ritual flow, all four strokes of a phrase traced end to end, stroke gating, completion, camera settling, and rendering at both desktop and phone canvas widths.

## Not built yet

Onboarding, multiple modules, money tracking, the ritual timer, a breathing pacer, ledger detail beyond the count, weekly check-ins, and settings.
