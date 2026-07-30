// Turns a phrase into one densely-sampled polyline the tracer can walk along.

// Cursive centerline data, authored with `tool/glyph_editor.py`. Coord system:
// x in 0..advanceWidth (left to right); y grows downward with baseline = 70 and
// x-height top = 30. Each glyph is a list of strokes; a stroke is a list of
// cubic beziers; a bezier is four [x, y] control points. Stroke 0 is the
// joinable main stroke — later strokes (i/j dots, t crossbar) are pen lifts.
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
 * A letter hands over to the next at whatever height the previous one exited,
 * so long as that lands in the band between the x-height and the baseline —
 * where cursive connections belong. Clamping matters for the capitals, whose
 * exits range from y = 5 to y = 72; without it, a letter following a capital
 * that exits up near the ascender would have its whole opening stroke trimmed
 * away. Glyphs are not laid out by `advanceWidth`; the join sets the spacing.
 */
const BASELINE_Y = 70;
const X_HEIGHT_Y = 30;

/**
 * Compose a phrase into a `ComposedPath`:
 *
 *   points        dense polyline, in scaled world coords
 *   strokeStart   index into `points` where each stroke begins
 *   letterStart   index into `points` where each letter begins
 *   letterEnd     index into `points` where each letter ends (inclusive)
 *   letterCenterX world-space horizontal center of each letter
 *
 * Each word is one stroke, so `points` jumps in absolute coords at every
 * stroke boundary — renderers must `moveTo` there rather than `lineTo`.
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

/**
 * Append one word, returning the world-space x where its ink ended.
 *
 * Two passes, matching how cursive is actually written: first the word body
 * (each letter's main stroke, joined into one continuous stroke), then back
 * over it to dot the i's and cross the t's — each of those a separate stroke
 * the user must tap to begin.
 */
function appendWord(word, scale, startX, path) {
  const characters = [...word];
  for (const character of characters) {
    if (!glyphs[character]) throw new Error(`No cursive glyph for character: "${character}"`);
  }
  // Resolve every join up front: a hand-tuned pair cuts the tail of the letter
  // *before* it, which has to be known before that letter is placed.
  const joins = characters.slice(1).map((c, i) => pairs[characters[i] + c] ?? null);

  const deferred = [];
  let exit = null;      // last point of the previous letter's ink
  let exitDir = null;   // and the direction it was travelling in

  for (let i = 0; i < characters.length; i++) {
    const [main, ...rest] = glyphs[characters[i]].strokes;
    const into = i > 0 ? joins[i - 1] : null;      // the join arriving here
    const outOf = joins[i] ?? null;                // the join leaving here

    // Cut both ends against the untrimmed stroke, so the two cuts cannot
    // shift each other, then take the surviving middle.
    const full = samplePoints(main, scale);
    const head = into ? cutIndex(full, into.to)
      : exit ? leadInLength(full, exit.y, scale) : 0;
    const tail = outOf ? cutIndex(full, outOf.from) : full.length - 1;
    let points = full.slice(head, Math.max(tail, head + 1) + 1);

    // Place the letter so its opening cut lands where the join wants it.
    const offset = exit
      ? exit.x + (into ? into.dx : join.gap) * scale - points[0].x
      : startX;
    points = points.map((point) => ({ x: point.x + offset, y: point.y }));

    path.letterStart.push(path.points.length);
    if (exit) appendBridge(exit, points[0], into, exitDir, direction(points[0], points[1]), scale, path.points);
    path.points.push(...points);
    path.letterEnd.push(path.points.length - 1);
    path.letterCenterX.push((points[0].x + points.at(-1).x) / 2);

    for (const stroke of rest) deferred.push([offset, stroke]);
    exit = points.at(-1);
    exitDir = direction(points.at(-2), exit);
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
 * baseline to the height the previous letter left off at, which that letter's
 * exit has already drawn. Dropping it is what lets two letters meet as one
 * continuous line instead of doubling back to the baseline between them.
 * 0 when the glyph already starts at or above that height, as the capitals
 * and the period do.
 */
function leadInLength(points, exitY, scale) {
  const target = Math.min(BASELINE_Y * scale, Math.max(X_HEIGHT_Y * scale, exitY));
  return Math.max(0, points.findIndex((point) => point.y <= target));
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
