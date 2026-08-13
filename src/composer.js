// Turns a phrase into one densely-sampled polyline the tracer can walk along.

// Cursive centerline data, authored with `tool/glyph_editor.py`. Coord system:
// x in 0..advanceWidth (left to right); y grows downward with baseline = 70 and
// x-height top = 30. Each glyph is a list of strokes; a stroke is a list of
// cubic beziers; a bezier is four [x, y] control points. Stroke 0 is the
// joinable main stroke — later strokes (i/j dots, t crossbar) are pen lifts.
// `joinFromSecondStroke` moves the join one stroke along: K is drawn spine
// first, and it is the arms that carry on into the next letter.
import glyphs from './glyphs.json' with { type: 'json' };

// Join tuning, shared with the glyph editor so its pair preview matches.
import join from './join.json' with { type: 'json' };

// Hand-tuned joins for specific letter pairs. A pair says where to cut the
// tail of the first letter, where to cut the head of the second, and the
// bezier that runs between those two cuts. Pairs compose into words because
// the two joins around a letter touch opposite ends of it: in "cap", c-a cuts
// a's head and a-p cuts a's tail, so they never disagree.
import pairs from './pairs.json' with { type: 'json' };

/** Spacing between path points, in scaled world units. Must stay well under
 *  the tracer's advance threshold of `8 * GLYPH_SCALE` or the pen can stall
 *  in the gap between two points. */
const POINT_SPACING = 2;

/** Working resolution for measuring a curve before it is respaced. */
const FINE_SAMPLES = 400;

/** Unit-coord glyph size. Big enough to feel expressive, small enough that
 *  ascenders and descenders still fit the viewport. */
export const GLYPH_SCALE = 2.2;

/** Gap between words, in unit coords. */
const SPACE_WIDTH = 30;

/**
 * Every letter hands over to the next at one fixed height, and the connecting
 * stroke is drawn once: each letter's opening rise from the baseline is
 * trimmed, each letter's closing rise is cut at its own `leadOut`, and the
 * bridge draws what is left. Both halves used to be kept, which is why a join
 * doubled back to the baseline and needed tuning per pair. Letters marked
 * `liftAfter` opt out of all of it — see `appendWord`.
 *
 * 51 was measured two ways. Across 56 hand-tuned pairs the second letter's cut
 * landed at y = 50.0..52.2 for 24 of the 26 letters — a spread of one to two
 * point spacings, the resolution the data can express. And Sacramento, which
 * has no OpenType joining features and joins by a fixed convention baked into
 * its outlines, hands over at 46% of its x-height, which is y = 51.6 here.
 *
 * Glyphs are not laid out by `advanceWidth`; the join sets the spacing.
 */
const HANDOVER_Y = 51;

/**
 * Compose a phrase into a `ComposedPath`:
 *
 *   points        dense polyline, in scaled world coords
 *   strokeStart   index into `points` where each stroke begins
 *   letterStart   index into `points` where each letter begins
 *   letterEnd     index into `points` where each letter ends (inclusive)
 *   letterCenterX world-space horizontal center of each letter
 *
 * `points` jumps in absolute coords at every stroke boundary — renderers must
 * `moveTo` there rather than `lineTo`.
 *
 * Throws if any character has no glyph.
 */
export function composePhrase(phrase, scale = GLYPH_SCALE) {
  const path = {
    points: [],
    strokeStart: [],
    letterStart: [],
    letterEnd: [],
    letterCenterX: [],
  };
  let cursorX = 0;   // world coords, like everything else past this point
  for (const word of phrase.split(' ').filter(Boolean)) {
    if (path.strokeStart.length) cursorX += SPACE_WIDTH * scale;
    path.strokeStart.push(path.points.length);
    cursorX = appendWord(word, scale, cursorX, path);
  }
  return path;
}

/** Whether `composePhrase` can draw every character of `text`: any glyph in
 *  the dataset, or the space between words. */
export const canCompose = (text) => [...text].every((c) => c === ' ' || c in glyphs);

/**
 * Append one word, returning the world-space x where its ink ended.
 *
 * Two passes, matching how cursive is actually written: first the word body
 * (each letter's main stroke, joined into one continuous stroke), then back
 * over it to dot the i's and cross the t's — each of those a separate stroke
 * the user must tap to begin.
 *
 * A letter marked `joinFromSecondStroke` puts one more stroke in the body pass.
 * Capital K is drawn spine first, lifted from, and then carried on from the
 * arms; only strokes after the joining one are deferred to the second pass.
 *
 * A letter marked `liftAfter` breaks the body pass in two. Those letters — the
 * capitals whose stroke ends somewhere the next letter cannot be reached from,
 * `D F I P T V W Y` — do not hand over: nothing is cut on either side of them,
 * no bridge is drawn, and the next letter starts a stroke of its own, which is
 * how they are written by hand. The next letter is then placed against the
 * capital's rightmost ink rather than against its exit point, because for these
 * letters those are not the same place: F exits at x = -25.8 having already
 * reached x = 40, so placing by the exit drops the next letter on top of it.
 */
function appendWord(word, scale, startX, path) {
  const characters = [...word];
  for (const character of characters) {
    if (!glyphs[character]) throw new Error(`No cursive glyph for character: "${character}"`);
  }
  // Resolve every join up front: a hand-tuned pair cuts the tail of the letter
  // *before* it, which has to be known before that letter is placed. A letter
  // marked `liftAfter` hands over to nothing, so the pair it opens is not a
  // join at all and any tuning stored for it is ignored.
  const joins = characters.slice(1).map((c, i) =>
    (glyphs[characters[i]].liftAfter ? null : pairs[characters[i] + c] ?? null));

  const deferred = [];
  let exit = null;      // last point of the previous letter's ink
  let exitDir = null;   // and the direction it was travelling in
  let lifted = false;   // the letter before this one lifted the pen after itself
  let prevRight = 0;    // and how far right its ink reached

  for (let i = 0; i < characters.length; i++) {
    const glyph = glyphs[characters[i]];
    const joining = glyph.joinFromSecondStroke ? 1 : 0;
    const into = i > 0 ? joins[i - 1] : null;      // the join arriving here
    const outOf = joins[i] ?? null;                // the join leaving here

    // Cut both ends against the untrimmed stroke, so the two cuts cannot
    // shift each other, then take the surviving middle. The letter opens with
    // whatever it draws first and hands over from its joining stroke; for most
    // letters those are the same stroke.
    const full = samplePoints(glyph.strokes[joining], scale);
    let lead = joining ? samplePoints(glyph.strokes[0], scale) : null;
    const opener = lead ?? full;
    const liftsAfter = glyph.liftAfter ?? false;
    const head = into ? cutIndex(opener, into.to)
      : exit && !lifted ? leadInLength(opener, scale) : 0;
    const tail = outOf ? cutIndex(full, outOf.from)
      : i < characters.length - 1 && !liftsAfter
        ? cutIndex(full, glyph.leadOut ?? 1)
        : full.length - 1;
    let points = lead ? full.slice(0, tail + 1)
      : full.slice(head, Math.max(tail, head + 1) + 1);
    if (lead) lead = lead.slice(head);

    // Place the letter so its opening cut lands where the join wants it — or,
    // after a lift, where its own ink clears the previous letter's, since
    // nothing was cut and those letters' exits are not their rightmost ink.
    const ink = lead ? [...lead, ...points] : points;
    const offset = !exit ? startX
      : lifted ? prevRight + join.gap * scale - Math.min(...ink.map((p) => p.x))
        : exit.x + (into ? into.dx : join.gap) * scale - ink[0].x;
    const place = (from) => from.map((point) => ({ x: point.x + offset, y: point.y }));
    points = place(points);
    if (lead) lead = place(lead);
    const opening = lead ?? points;

    path.letterStart.push(path.points.length);
    if (exit && lifted) path.strokeStart.push(path.points.length);
    else if (exit) appendBridge(exit, opening[0], into, exitDir, direction(opening[0], opening[1]), scale, path.points);
    if (lead) {
      path.points.push(...lead);
      path.strokeStart.push(path.points.length);   // the pen lift inside the letter
    }
    path.points.push(...points);
    path.letterEnd.push(path.points.length - 1);
    path.letterCenterX.push((opening[0].x + points.at(-1).x) / 2);

    for (const stroke of glyph.strokes.slice(joining + 1)) deferred.push([offset, stroke]);
    exit = points.at(-1);
    exitDir = direction(points.at(-2), exit);
    lifted = liftsAfter;
    prevRight = Math.max(...(lead ? [...lead, ...points] : points).map((p) => p.x));
  }

  for (const [x, stroke] of deferred) {
    path.strokeStart.push(path.points.length);
    const points = samplePoints(stroke, scale);
    for (const point of points) point.x += x;
    path.points.push(...points);
  }
  return exit.x;
}

/** Where along a stroke a hand-tuned cut falls. `at` runs 0 (the stroke's
 *  start) to 1 (its end); points are evenly spaced, so this is a position
 *  along the drawn line rather than along the underlying bezier parameter. */
function cutIndex(points, at) {
  return Math.min(points.length - 1, Math.max(0, Math.round(at * (points.length - 1))));
}

/** Sample one stroke into world-scaled points, still in glyph-local x. */
function samplePoints(stroke, scale) {
  const points = [];
  for (const bezier of stroke) {
    const sampled = sampleCubic(bezier.map(([x, y]) => ({ x: x * scale, y: y * scale })));
    points.push(...(points.length ? sampled.slice(1) : sampled));
  }
  return points;
}

/**
 * How many leading points are lead-in — the opening stroke rising from the
 * baseline to the handover height, which the bridge draws instead. 0 when the
 * glyph already starts at or above that height, as most of the capitals and
 * the period do.
 */
function leadInLength(points, scale) {
  return Math.max(0, points.findIndex((point) => point.y <= HANDOVER_Y * scale));
}

/**
 * The stroke connecting two letters. A hand-tuned pair supplies its control
 * handles outright; otherwise they are derived from the directions the two
 * letters are already travelling in, which keeps the join smooth by default.
 */
function appendBridge(start, end, tuned, exitDir, entryDir, scale, points) {
  const chord = Math.hypot(end.x - start.x, end.y - start.y);
  if (chord < 0.001) return;
  const h = chord / 3;
  const control = tuned
    ? [
      { x: start.x + tuned.h1[0] * scale, y: start.y + tuned.h1[1] * scale },
      { x: end.x + tuned.h2[0] * scale, y: end.y + tuned.h2[1] * scale },
    ]
    : [
      { x: start.x + exitDir.x * h, y: start.y + exitDir.y * h },
      { x: end.x - entryDir.x * h, y: end.y - entryDir.y * h },
    ];
  points.push(...sampleCubic([start, ...control, end]).slice(1));
}

/** Unit vector from one point to the next. */
function direction(from, to) {
  const dx = to.x - from.x;
  const dy = to.y - from.y;
  const len = Math.hypot(dx, dy);
  return len < 0.001 ? { x: 1, y: 0 } : { x: dx / len, y: dy / len };
}

/** Sample a cubic into points spaced evenly *along the curve*. Sampling at
 *  even steps of `t` instead would bunch points up wherever the control
 *  points make the curve accelerate, leaving gaps the pen cannot cross. */
function sampleCubic([p0, p1, p2, p3]) {
  const fine = Array.from({ length: FINE_SAMPLES }, (_, i) => {
    const t = i / (FINE_SAMPLES - 1);
    const u = 1 - t;
    const a = u * u * u;
    const b = 3 * u * u * t;
    const c = 3 * u * t * t;
    const d = t * t * t;
    return {
      x: a * p0.x + b * p1.x + c * p2.x + d * p3.x,
      y: a * p0.y + b * p1.y + c * p2.y + d * p3.y,
    };
  });
  return respace(fine, POINT_SPACING);
}

/** Walk a polyline and emit a point every `spacing` units of length, always
 *  keeping both endpoints so consecutive curves still meet exactly. */
function respace(fine, spacing) {
  const out = [fine[0]];
  let travelled = 0;
  let next = spacing;
  for (let i = 1; i < fine.length; i++) {
    const [from, to] = [fine[i - 1], fine[i]];
    const length = Math.hypot(to.x - from.x, to.y - from.y);
    if (length <= 0) continue;
    while (travelled + length >= next) {
      const t = (next - travelled) / length;
      out.push({ x: from.x + (to.x - from.x) * t, y: from.y + (to.y - from.y) * t });
      next += spacing;
    }
    travelled += length;
  }
  out.push(fine.at(-1));
  return out;
}
