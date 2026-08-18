// Short, present-tense phrases aligned with Kristin Neff's self-compassion
// framework. Deliberately not affirmations ("you are worthy") — those can
// backfire for people with low self-esteem.
//
// One general list, reviewed as content and licensed separately from the code.
import library from '../assets/phrases/general.json' with { type: 'json' };

export const phrases = library.phrases.map((phrase) => phrase.text);

/** Where one person is in their own shuffle of the list. */
const DECK_KEY = 'urge-surfer.deck';

/**
 * A seeded shuffle walked in order, rather than an independent random draw
 * each time. Drawing at random repeats: with 138 phrases the same one comes up
 * twice running about once every ten sessions, and that lands right when
 * someone is least able to shrug it off. Walking a shuffled deck instead means
 * no phrase comes back until every other one has been seen.
 *
 * The seed is generated on this device, so two people get different orders.
 * It never leaves localStorage.
 */
export function nextPhrase() {
  const deck = readDeck();
  const order = shuffle(phrases.length, deck.seed);
  const text = phrases[order[deck.cursor]];
  const cursor = deck.cursor + 1;
  // A finished pass earns a new shuffle, so the next lap is a different order.
  writeDeck(cursor < order.length ? { seed: deck.seed, cursor } : { seed: newSeed(), cursor: 0 });
  return text;
}

function readDeck() {
  try {
    const saved = JSON.parse(localStorage.getItem(DECK_KEY));
    // A list that has grown since the deck was saved invalidates the cursor.
    if (Number.isInteger(saved?.seed) && saved.cursor >= 0 && saved.cursor < phrases.length) {
      return saved;
    }
  } catch {
    // No storage, or something else wrote nonsense here. Start a fresh deck.
  }
  return { seed: newSeed(), cursor: 0 };
}

function writeDeck(deck) {
  try {
    localStorage.setItem(DECK_KEY, JSON.stringify(deck));
  } catch {
    // Private-mode storage refusal costs the order, not the phrase.
  }
}

const newSeed = () => crypto.getRandomValues(new Uint32Array(1))[0];

/** Fisher-Yates over `mulberry32`, so one seed always gives one order. */
function shuffle(length, seed) {
  const order = [...Array(length).keys()];
  const random = mulberry32(seed);
  for (let i = length - 1; i > 0; i--) {
    const j = Math.floor(random() * (i + 1));
    [order[i], order[j]] = [order[j], order[i]];
  }
  return order;
}

/** Small seeded PRNG. Only has to be well spread, not unguessable — nothing
 *  here is a secret, and `crypto` supplies the seed. */
function mulberry32(seed) {
  let state = seed >>> 0;
  return () => {
    state = (state + 0x6d2b79f5) >>> 0;
    let t = Math.imul(state ^ (state >>> 15), 1 | state);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
