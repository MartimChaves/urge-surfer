import assert from 'node:assert/strict';
import { test, beforeEach } from 'node:test';

import { phrases, nextPhrase } from '../src/phrases.js';

// The deck lives in localStorage, which node does not have.
const store = new Map();
globalThis.localStorage = {
  getItem: (key) => store.get(key) ?? null,
  setItem: (key, value) => store.set(key, value),
};
const pass = () => Array.from({ length: phrases.length }, () => nextPhrase());

beforeEach(() => store.clear());

test('a pass through the deck shows every phrase exactly once', () => {
  assert.deepEqual([...new Set(pass())].sort(), [...phrases].sort());
});

test('finishing the deck reshuffles rather than repeating the same order', () => {
  const first = pass();
  const second = pass();
  assert.deepEqual([...new Set(second)].sort(), [...phrases].sort());
  assert.notDeepEqual(second, first);
});

test('two devices get different orders', () => {
  const a = pass();
  store.clear();
  assert.notDeepEqual(pass(), a);
});

test('the deck picks up where it left off across a reload', () => {
  const before = [nextPhrase(), nextPhrase(), nextPhrase()];
  const saved = store.get('urge-surfer.deck');
  const after = [nextPhrase(), nextPhrase()];
  store.set('urge-surfer.deck', saved);   // as if the page had been reloaded here
  assert.deepEqual([nextPhrase(), nextPhrase()], after);
  assert.equal(after.filter((text) => before.includes(text)).length, 0);
});

test('a cursor left over from a shorter list is discarded, not trusted', () => {
  // The list grows as phrases are reviewed in; a stale cursor must not index
  // past the end of it.
  store.set('urge-surfer.deck', JSON.stringify({ seed: 1, cursor: phrases.length + 40 }));
  assert.ok(phrases.includes(nextPhrase()));
});

test('a phrase still comes back when storage is unavailable', () => {
  const real = globalThis.localStorage;
  globalThis.localStorage = {
    getItem() { throw new Error('denied'); },
    setItem() { throw new Error('denied'); },
  };
  try {
    assert.ok(phrases.includes(nextPhrase()));
  } finally {
    globalThis.localStorage = real;
  }
});
