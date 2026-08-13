// Screens, routing and storage. Everything stays on this device: waves live
// in localStorage and nothing is ever sent anywhere.

import { TracingCanvas } from './canvas.js';
import { canCompose } from './composer.js';
import { phrases, randomPhrase } from './phrases.js';

const $ = (selector, root = document) => root.querySelector(selector);
const $$ = (selector, root = document) => [...root.querySelectorAll(selector)];

const STORAGE_KEY = 'urge-surfer.waves';
const readWaves = () => JSON.parse(localStorage.getItem(STORAGE_KEY) ?? '[]');

function logWave(wave) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify([...readWaves(), wave]));
}

// --- tracing panel, shared by the ritual and "just write" ---

let tracer = null;

/** Mount a fresh tracing panel into `host`. The host must already be visible
 *  so the canvas can measure itself. */
function mountTracer(host, phrase, onComplete) {
  unmountTracer();
  host.replaceChildren($('#tracer-template').content.cloneNode(true));
  $('.phrase', host).textContent = phrase;
  tracer = new TracingCanvas($('canvas', host), phrase, onComplete);
  $('.lag input', host).addEventListener('change', (e) => tracer.setLag(e.target.checked));
}

function unmountTracer() {
  tracer?.destroy();
  tracer = null;
}

// --- ledger ---

function showLedger() {
  const count = readWaves().length;
  $('#wave-count').textContent = count;
  $('#wave-label').textContent = count === 1 ? 'wave surfed' : 'waves surfed';
}

// --- ritual: name the urge, rate it, trace a phrase, rate it again ---

const steps = $$('#ritual .step');
let phrase = '';

function showStep(index) {
  unmountTracer();
  steps.forEach((step, i) => (step.hidden = i !== index));
  if (index === 2) {
    mountTracer($('.tracer-host', steps[2]), phrase, () => showStep(3));
  }
}

function startRitual() {
  phrase = randomPhrase();
  $('#urge-text').value = '';
  for (const slider of $$('#ritual input[type=range]')) {
    slider.value = 5;
    slider.dispatchEvent(new Event('input'));
  }
  showStep(0);
}

$('#urge-next').addEventListener('click', () => {
  if ($('#urge-text').value.trim()) showStep(1);
});

$('.primary', steps[1]).addEventListener('click', () => showStep(2));

$('.primary', steps[3]).addEventListener('click', () => {
  logWave({
    urge: $('#urge-text').value.trim(),
    before: Number($('#urge-before').value),
    after: Number($('#urge-after').value),
    phrase,
    at: new Date().toISOString(),
  });
  location.hash = '#/';
});

for (const slider of $$('#ritual input[type=range]')) {
  const output = slider.previousElementSibling;
  slider.addEventListener('input', () => (output.textContent = slider.value));
}

// --- just write: pick a phrase or type one, trace it, nothing recorded ---

const writeHost = $('#write .tracer-host');
const phraseList = $('#phrase-list');
const custom = $('#custom-phrase');
const customText = $('#custom-text');
const customError = $('#custom-error');

function startWriting(text) {
  phraseList.hidden = true;
  custom.hidden = true;
  writeHost.hidden = false;
  mountTracer(writeHost, text, showPhraseList);
}

phraseList.replaceChildren(...phrases.map((text) => {
  const button = document.createElement('button');
  button.className = 'link';
  button.textContent = text;
  button.addEventListener('click', () => startWriting(text));
  const item = document.createElement('li');
  item.append(button);
  return item;
}));

/** Trace whatever the user typed. It is never stored — leaving the screen
 *  loses it, which is the point. */
function writeTyped() {
  const text = customText.value.trim();
  if (!text) return;
  customError.hidden = canCompose(text);
  if (customError.hidden) startWriting(text);
}

$('#custom-go').addEventListener('click', writeTyped);
customText.addEventListener('keydown', (event) => {
  if (event.key === 'Enter') writeTyped();
});

function showPhraseList() {
  unmountTracer();
  writeHost.hidden = true;
  phraseList.hidden = false;
  custom.hidden = false;
  customError.hidden = true;
}

// --- routing ---

const ROUTES = {
  '#/': ['ledger', showLedger],
  '#/ritual': ['ritual', startRitual],
  '#/write': ['write', showPhraseList],
};

function route() {
  const [name, enter] = ROUTES[location.hash] ?? ROUTES['#/'];
  unmountTracer();
  for (const [id] of Object.values(ROUTES)) $('#' + id).hidden = id !== name;
  enter();
}

for (const element of $$('[data-go]')) {
  element.addEventListener('click', () => (location.hash = element.dataset.go));
}

window.addEventListener('hashchange', route);
route();
