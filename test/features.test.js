import assert from 'node:assert/strict';
import { test } from 'node:test';

import * as development from '../src/features.js';
import * as production from '../config/production.js';

test('development exposes writing and pen-lag controls', () => {
  assert.equal(development.JUST_WRITE, true);
  assert.equal(development.PEN_LAG_CONTROL, true);
});

test('production disables development-only controls', () => {
  assert.equal(production.JUST_WRITE, false);
  assert.equal(production.PEN_LAG_CONTROL, false);
});
