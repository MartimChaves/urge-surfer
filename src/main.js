// Screens, routing and storage. Everything stays on this device: waves live
// in localStorage and nothing is ever sent anywhere.

import { TracingCanvas } from './canvas.js';
import { canCompose } from './composer.js';
import { phrases, nextPhrase } from './phrases.js';
import { JUST_WRITE, PEN_LAG_CONTROL } from './features.js';

const $ = (selector, root = document) => root.querySelector(selector);
const $$ = (selector, root = document) => [...root.querySelectorAll(selector)];

const justWriteButton = document.querySelector('[data-go="#/write"]');
if (JUST_WRITE) justWriteButton.hidden = false;
else justWriteButton.remove();
const STORAGE_KEY = 'urge-surfer.waves';

function readWaveCount() {
  try {
    const saved = JSON.parse(localStorage.getItem(STORAGE_KEY) ?? '0');
    const count = Array.isArray(saved) ? saved.length : saved;
    if (!Number.isSafeInteger(count) || count < 0) return 0;
    // Older versions stored full wave records. Preserve only their count and
    // erase the urge text, ratings, phrase and timestamp on the first visit.
    if (Array.isArray(saved)) localStorage.setItem(STORAGE_KEY, String(count));
    return count;
  } catch {
    return 0;
  }
}

function logWave() {
  localStorage.setItem(STORAGE_KEY, String(readWaveCount() + 1));
}

// --- tracing panel, shared by the ritual and "just write" ---

let tracer = null;

/** Mount a fresh tracing panel into `host`. The host must already be visible
 *  so the canvas can measure itself. */
function mountTracer(host, phrase, onComplete) {
  unmountTracer();
  host.replaceChildren($("#tracer-template").content.cloneNode(true));
  $(".phrase", host).textContent = phrase;
  tracer = new TracingCanvas($("canvas", host), phrase, onComplete);
  const lagControl = $(".lag", host);
  if (PEN_LAG_CONTROL) {
    lagControl.hidden = false;
    $(".lag input", host).addEventListener("change", (e) => tracer.setLag(e.target.checked));
  } else {
    lagControl.remove();
  }
}

function unmountTracer() {
  tracer?.destroy();
  tracer = null;
}

// --- ledger ---

function showLedger() {
  const count = readWaveCount();
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
  phrase = nextPhrase();
  $("#urge-text").value = "";
  for (const slider of $$("#ritual input[type=range]")) {
    slider.value = 5;
    slider.dispatchEvent(new Event("input"));
  }
  showStep(0);
}

$("#urge-next").addEventListener("click", () => {
  if ($("#urge-text").value.trim()) showStep(1);
});

$(".primary", steps[1]).addEventListener("click", () => showStep(2));

$(".primary", steps[3]).addEventListener("click", () => {
  logWave();
  location.hash = "#/";
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

if (!JUST_WRITE) $('#write').remove();

// --- routing ---

const ROUTES = {
  '#/': ['ledger', showLedger],
  '#/ritual': ['ritual', startRitual],
  ...(JUST_WRITE ? { '#/write': ['write', showPhraseList] } : {}),
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
