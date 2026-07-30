import assert from 'node:assert/strict';
import { test } from 'node:test';

import { PEN_SPEED, Tracer } from '../src/tracer.js';

/** A straight horizontal path, one point every 10px, split into two strokes. */
function makePath(count = 21, strokeStart = [0]) {
  return {
    points: Array.from({ length: count }, (_, i) => ({ x: i * 10, y: 0 })),
    strokeStart,
  };
}

/** Run `seconds` of simulation in 60Hz frames. */
function run(tracer, seconds, finger) {
  for (let i = 0; i < Math.round(seconds * 60); i++) {
    tracer.setFinger(finger);
    tracer.tick(1 / 60);
  }
}

test('starts pen-up at the first point', () => {
  const tracer = new Tracer(makePath());
  assert.equal(tracer.index, 0);
  assert.equal(tracer.isDown, false);
  assert.equal(tracer.complete, false);
});

test('a lifted pen ignores the finger entirely', () => {
  const tracer = new Tracer(makePath());
  run(tracer, 5, { x: 200, y: 0 });
  assert.deepEqual(tracer.pen, { x: 0, y: 0 });
  assert.equal(tracer.index, 0);
});

test('the pen trails the finger instead of jumping to it', () => {
  const tracer = new Tracer(makePath());
  tracer.isDown = true;
  run(tracer, 0.5, { x: 200, y: 0 });
  assert.ok(tracer.pen.x > 0, 'pen should have moved');
  assert.ok(tracer.pen.x < PEN_SPEED, 'pen should still be well behind');
});

test('frame rate does not change how far the pen gets', () => {
  const fast = new Tracer(makePath());
  const slow = new Tracer(makePath());
  fast.isDown = slow.isDown = true;
  for (let i = 0; i < 120; i++) {
    fast.setFinger({ x: 200, y: 0 });
    fast.tick(1 / 120);
  }
  run(slow, 1, { x: 200, y: 0 });
  assert.ok(Math.abs(fast.pen.x - slow.pen.x) < 0.001);
});

test('progress never runs backwards', () => {
  const tracer = new Tracer(makePath());
  tracer.isDown = true;
  run(tracer, 3, { x: 200, y: 0 });
  const reached = tracer.index;
  assert.ok(reached > 0);
  run(tracer, 3, { x: 0, y: 0 });
  assert.equal(tracer.index, reached);
});

test('progress stops at the end of a stroke until it is advanced', () => {
  const tracer = new Tracer(makePath(21, [0, 10]));
  tracer.isDown = true;
  run(tracer, 20, { x: 200, y: 0 });
  assert.equal(tracer.index, 9, 'should hold at the last point of stroke 0');
  assert.equal(tracer.strokeComplete, true);
  assert.equal(tracer.complete, false);

  tracer.advanceStroke();
  assert.equal(tracer.index, 10);
  assert.deepEqual(tracer.pen, { x: 100, y: 0 });

  run(tracer, 20, { x: 200, y: 0 });
  assert.equal(tracer.complete, true);
});

test('lag can be switched off', () => {
  const drag = (tracer) => {
    tracer.isDown = true;
    for (let i = 0; i <= 20; i++) {
      tracer.setFinger({ x: i * 10, y: 0 });
      tracer.tick(1 / 60);
    }
  };
  const unlagged = new Tracer(makePath());
  unlagged.penSpeed = Infinity;
  drag(unlagged);
  assert.equal(unlagged.complete, true);

  // The same drag, at the same speed, leaves a lagged pen far behind.
  const lagged = new Tracer(makePath());
  drag(lagged);
  assert.equal(lagged.complete, false);
});
