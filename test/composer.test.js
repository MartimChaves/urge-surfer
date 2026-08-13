import assert from 'node:assert/strict';
import { test } from 'node:test';

import glyphs from '../src/glyphs.json' with { type: 'json' };
import { GLYPH_SCALE, composePhrase } from '../src/composer.js';
import pairs from '../src/pairs.json' with { type: 'json' };
import { phrases } from '../src/phrases.js';

const ALPHABET = 'abcdefghijklmnopqrstuvwxyz';
const LIFTERS = Object.keys(glyphs).filter((key) => glyphs[key].liftAfter);
const ADVANCE_THRESHOLD = 8 * GLYPH_SCALE;
const POINT_SPACING = 2;
const gap = (a, b) => Math.hypot(b.x - a.x, b.y - a.y);
const heading = (points, from, to) =>
  (Math.atan2(points[to].y - points[from].y, points[to].x - points[from].x) * 180) / Math.PI;

test('a one-word phrase of single-stroke letters is one stroke', () => {
  const path = composePhrase('can');
  assert.deepEqual(path.strokeStart, [0]);
  assert.equal(path.letterStart.length, 3);
  assert.equal(path.letterEnd.at(-1), path.points.length - 1);
});

test('multi-stroke letters defer their extra strokes to the end of the word', () => {
  // 't' carries a crossbar, so "at" is the word body plus one deferred stroke.
  assert.equal(composePhrase('at').strokeStart.length, 2);
  // One stroke per word, plus a deferred stroke per i and t: it, is, time.
  assert.equal(composePhrase('it is time').strokeStart.length, 3 + 5);
});

test('letters hand over to each other as one continuous stroke', () => {
  for (const word of ['gentle', 'many', 'ease', 'whole', 'breath', 'again', 'safe']) {
    const path = composePhrase(word);
    const boundaries = new Set(path.strokeStart);
    for (let i = 1; i < path.letterStart.length; i++) {
      const join = path.letterStart[i];
      if (boundaries.has(join)) continue;         // a deferred stroke, not a join
      const from = path.points[join - 1];
      const to = path.points[join];

      // The handover happens at one height, so the pen never dives back to
      // the baseline and climbs out again between letters.
      assert.ok(
        Math.abs(to.y - from.y) < ADVANCE_THRESHOLD,
        `${word}: join ${i} steps ${(to.y - from.y).toFixed(1)} vertically`,
      );
      // And it carries on forwards rather than doubling back to pick the
      // next letter up. A hair of backtrack is fine — `s` exits leaning left.
      let leftmost = Infinity;
      for (let k = join; k < join + 15 && k < path.points.length; k++) {
        leftmost = Math.min(leftmost, path.points[k].x);
      }
      assert.ok(
        from.x - leftmost < POINT_SPACING,
        `${word}: join ${i} backtracks ${(from.x - leftmost).toFixed(1)}`,
      );

      // Compare the direction going into the join with the one coming out.
      const turn = Math.abs(
        ((heading(path.points, join + 1, join + 6)
          - heading(path.points, join - 6, join - 1) + 540) % 360) - 180,
      );
      assert.ok(turn < 90, `${word}: join ${i} turns ${turn.toFixed(0)} degrees`);
    }
  }
});

test('trimming a lead-in never eats the letter', () => {
  // Every glyph must keep enough of itself to still be a traceable path once
  // its lead-in is dropped; composePhrase would throw or produce junk if not.
  for (const character of ALPHABET) {
    const alone = composePhrase(character).points.length;
    const joined = composePhrase(`o${character}`);
    const kept = joined.letterEnd[1] - joined.letterStart[1];
    assert.ok(kept > alone * 0.5, `"${character}" lost over half its path to trimming`);
  }
});

test('a letter marked liftAfter neither cuts nor is cut', () => {
  const length = (path, i) => path.letterEnd[i] - path.letterStart[i] + 1;
  for (const key of LIFTERS) {
    const pair = composePhrase(`${key}a`);
    assert.equal(length(pair, 0), length(composePhrase(key), 0), `${key} lost its tail`);
    assert.equal(length(pair, 1), length(composePhrase('a'), 0), `a lost its lead-in after ${key}`);
    // A stroke boundary exactly at the second letter is the whole of the join:
    // no bridge was drawn, so nothing sits between the two letters. (Later
    // entries are the deferred crossbars of F and T, which come after both.)
    assert.ok(pair.strokeStart.includes(pair.letterStart[1]), `${key} bridged anyway`);
  }
});

test('the letter after a lift clears the ink, not just the exit point', () => {
  // F exits at x = -25.8 having already reached x = 40, so placing the next
  // letter against the exit point drops it inside the F.
  const xs = (path, i) => path.points.slice(path.letterStart[i], path.letterEnd[i] + 1).map((p) => p.x);
  for (const key of LIFTERS) {
    const path = composePhrase(`${key}a`);
    assert.ok(Math.min(...xs(path, 1)) > Math.max(...xs(path, 0)), `a overlaps ${key}`);
  }
});

test('letters are laid out left to right without overlapping', () => {
  const path = composePhrase('gentle');
  for (let i = 1; i < path.letterStart.length; i++) {
    assert.ok(path.letterStart[i] > path.letterEnd[i - 1]);
    assert.ok(path.letterCenterX[i] > path.letterCenterX[i - 1]);
  }
});

test('words are separated by a gap the pen cannot cross', () => {
  const path = composePhrase('be gentle');
  const start = path.strokeStart[1];
  assert.ok(gap(path.points[start - 1], path.points[start]) > ADVANCE_THRESHOLD);
});

test('sampling within a stroke stays dense enough for the pen to advance', () => {
  for (const text of [...phrases, ALPHABET, ALPHABET.toUpperCase()]) {
    const path = composePhrase(text);
    const boundaries = new Set(path.strokeStart);
    for (let i = 1; i < path.points.length; i++) {
      if (boundaries.has(i)) continue;
      assert.ok(
        gap(path.points[i - 1], path.points[i]) < ADVANCE_THRESHOLD,
        `gap at point ${i} of "${text}" would strand the pen`,
      );
    }
  }
});

test('every letter and the period have a glyph', () => {
  for (const character of ALPHABET + ALPHABET.toUpperCase() + '.') {
    assert.ok(glyphs[character], `missing glyph for "${character}"`);
    assert.doesNotThrow(() => composePhrase(character));
  }
});

test('unsupported characters are rejected rather than silently dropped', () => {
  assert.throws(() => composePhrase('be br@ve'), /No cursive glyph/);
});

test('every glyph has non-empty, continuous beziers', () => {
  for (const [character, glyph] of Object.entries(glyphs)) {
    assert.ok(glyph.strokes.length, character);
    for (const stroke of glyph.strokes) {
      assert.ok(stroke.length, character);
      for (const bezier of stroke) assert.equal(bezier.length, 4, character);
      for (let i = 1; i < stroke.length; i++) {
        const [endX, endY] = stroke[i - 1][3];
        const [startX, startY] = stroke[i][0];
        assert.ok(
          Math.hypot(startX - endX, startY - endY) < 0.5,
          `"${character}" bezier ${i} does not continue from the previous one`,
        );
      }
    }
  }
});

test('a join looks the same whatever surrounds it, so pairs build words', () => {
  // "ca" + "ap" must give "cap". This holds because a letter's neighbours only
  // translate it: the join depends on the two letters in it and nothing else.
  const joinShape = (word, i, span = 60) => {
    const path = composePhrase(word);
    const origin = path.points[path.letterEnd[i]];
    const out = [];
    for (let k = path.letterEnd[i]; k <= path.letterEnd[i] + span && k < path.points.length; k++) {
      out.push([+(path.points[k].x - origin.x).toFixed(4), +(path.points[k].y - origin.y).toFixed(4)]);
    }
    return JSON.stringify(out);
  };
  for (const [word, i, context, j] of [
    ['ca', 0, 'cap', 0], ['ap', 0, 'cap', 1], ['ap', 0, 'scrap', 3],
    ['th', 0, 'breathe', 4], ['ea', 0, 'pleases', 2],
  ]) {
    assert.equal(joinShape(word, i), joinShape(context, j), `${word} inside ${context}`);
  }
});

test('every hand-tuned pair is usable', () => {
  for (const [key, pair] of Object.entries(pairs)) {
    if (key.length !== 2) continue;                   // the "_" doc note
    for (const field of ['from', 'to', 'dx', 'h1', 'h2']) {
      assert.ok(pair[field] !== undefined, `${key} is missing ${field}`);
    }
    assert.ok(pair.from >= 0 && pair.from <= 1, `${key}.from out of range`);
    assert.ok(pair.to >= 0 && pair.to <= 1, `${key}.to out of range`);

    // Both letters must survive being cut at both ends. The tightest case is a
    // letter with a tuned pair on each side of it.
    const [first, second] = key;
    for (const word of [key, `${first}${second}${second}`, `${first}${first}${second}`]) {
      const path = composePhrase(word);
      path.letterEnd.forEach((end, i) => {
        assert.ok(
          end - path.letterStart[i] > 10,
          `"${word}" letter ${i} is consumed by its joins (${end - path.letterStart[i]} points left)`,
        );
      });
    }
  }
});
