// The tracing surface: composes a phrase, runs the pen simulation on every
// animation frame, and scrolls sideways to keep the active letter in view.

import { composePhrase } from './composer.js';
import { PEN_SPEED, Tracer } from './tracer.js';

/** Time constant (seconds) of the low-pass filter the camera pans with. */
const PAN_TIME_CONSTANT = 0.25;

/** World-space radius within which a touch is accepted as the start of the
 *  next stroke. Touches further away are ignored. */
const NEXT_STROKE_GATE = 100;

/** Half-window (in path points) and minimum turn angle used to split a
 *  stroke into segments. One direction chevron is drawn per segment. */
const CORNER_WINDOW = 5;
const CORNER_ANGLE = Math.PI / 2;

/** How long the newly-active chevron stays engorged before easing back. */
const CHEVRON_FLASH = 0.6;

const LINE_WIDTH = 16;

export class TracingCanvas {
  constructor(canvas, phrase, onComplete) {
    this.canvas = canvas;
    this.style = getComputedStyle(canvas);
    this.ctx = canvas.getContext('2d');
    this.onComplete = onComplete;

    this.path = composePhrase(phrase);
    this.tracer = new Tracer(this.path);
    this.segments = detectSegments(this.path);
    this.strokeStarts = new Set(this.path.strokeStart);

    this.finger = null;
    this.flash = 1;
    this.activeSegment = -1;
    this.lastTime = null;
    this.fired = false;
    this.panX = null;
    this.panY = 0;

    this.observer = new ResizeObserver(() => this.resize());
    this.observer.observe(canvas);
    this.resize();

    canvas.addEventListener('pointerdown', this);
    canvas.addEventListener('pointermove', this);
    canvas.addEventListener('pointerup', this);
    canvas.addEventListener('pointercancel', this);

    this.frame = this.frame.bind(this);
    this.raf = requestAnimationFrame(this.frame);
  }

  setLag(enabled) {
    this.tracer.penSpeed = enabled ? PEN_SPEED : Infinity;
  }

  destroy() {
    cancelAnimationFrame(this.raf);
    this.observer.disconnect();
    for (const type of ['pointerdown', 'pointermove', 'pointerup', 'pointercancel']) {
      this.canvas.removeEventListener(type, this);
    }
  }

  // --- layout ---

  resize() {
    const dpr = window.devicePixelRatio || 1;
    this.width = this.canvas.clientWidth;
    this.height = this.canvas.clientHeight;
    this.canvas.width = Math.round(this.width * dpr);
    this.canvas.height = Math.round(this.height * dpr);

    // Centre the phrase vertically; there is no vertical scrolling.
    const ys = this.path.points.map((p) => p.y);
    this.panY = this.height / 2 - (Math.min(...ys) + Math.max(...ys)) / 2;
    if (this.panX === null) this.panX = this.width / 2 - this.cameraTargetX();
  }

  /** Where the camera wants to be. Normally the leading edge of progress, so
   *  the canvas only moves while the user is actually advancing. Between
   *  strokes it hops ahead to the next word, so you can see where to tap. */
  cameraTargetX() {
    const { strokeComplete, hasNextStroke, stroke, index } = this.tracer;
    if (strokeComplete && hasNextStroke) {
      const nextStart = this.path.strokeStart[stroke + 1];
      const letter = this.path.letterStart.indexOf(nextStart);
      return letter >= 0
        ? this.path.letterCenterX[letter]
        : this.path.points[nextStart].x;
    }
    return this.path.points[index].x;
  }

  toWorld(event) {
    const rect = this.canvas.getBoundingClientRect();
    return {
      x: event.clientX - rect.left - this.panX,
      y: event.clientY - rect.top - this.panY,
    };
  }

  // --- input ---

  handleEvent(event) {
    event.preventDefault();
    if (event.type === 'pointerdown') return this.onDown(event);
    if (event.type === 'pointermove') {
      this.tracer.setFinger(this.toWorld(event));
      if (this.tracer.isDown) this.finger = this.tracer.finger;
      return;
    }
    this.tracer.isDown = false;
    this.finger = null;
  }

  onDown(event) {
    const world = this.toWorld(event);
    const { tracer } = this;
    if (tracer.strokeComplete && tracer.hasNextStroke) {
      const target = tracer.nextStrokePoint;
      if (Math.hypot(world.x - target.x, world.y - target.y) > NEXT_STROKE_GATE) return;
      tracer.advanceStroke();
    }
    this.canvas.setPointerCapture(event.pointerId);
    tracer.isDown = true;
    tracer.setFinger(world);
    this.finger = world;
  }

  // --- frame loop ---

  frame(now) {
    const dt = this.lastTime === null ? 0 : (now - this.lastTime) / 1000;
    this.lastTime = now;

    this.tracer.tick(dt);

    const segment = this.currentSegment();
    if (segment !== this.activeSegment) {
      this.activeSegment = segment;
      this.flash = 0;
    }
    this.flash = Math.min(1, this.flash + dt / CHEVRON_FLASH);

    const target = this.width / 2 - this.cameraTargetX();
    this.panX += (target - this.panX) * (1 - Math.exp(-dt / PAN_TIME_CONSTANT));

    this.draw();

    if (this.tracer.complete && !this.fired) {
      this.fired = true;
      this.onComplete();
    }
    this.raf = requestAnimationFrame(this.frame);
  }

  /** Index of the segment holding the pen, within the current stroke. */
  currentSegment() {
    const { ends } = this.segments[this.tracer.stroke];
    return ends.findIndex((end) => this.tracer.index <= end);
  }

  // --- drawing ---

  draw() {
    const { ctx } = this;
    const dpr = window.devicePixelRatio || 1;
    const ink = this.style.color;

    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, this.width, this.height);
    ctx.translate(this.panX, this.panY);
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    ctx.strokeStyle = ink;
    ctx.fillStyle = ink;

    this.strokePolyline(this.path.points.length - 1, LINE_WIDTH, 0.25);
    this.strokePolyline(this.tracer.index, LINE_WIDTH, 0.7);
    this.drawChevron();
    this.drawNextStrokeTarget();

    ctx.globalAlpha = 1;
    dot(ctx, this.tracer.pen, 10);
    if (this.finger) ring(ctx, this.finger, 6, 2);
  }

  /** Trace `points[0..to]`, lifting the pen at every stroke boundary. */
  strokePolyline(to, width, alpha) {
    const { ctx } = this;
    const points = this.path.points;
    if (to < 1) return;
    ctx.globalAlpha = alpha;
    ctx.lineWidth = width;
    ctx.beginPath();
    ctx.moveTo(points[0].x, points[0].y);
    for (let i = 1; i <= to; i++) {
      const { x, y } = points[i];
      if (this.strokeStarts.has(i)) ctx.moveTo(x, y);
      else ctx.lineTo(x, y);
    }
    ctx.stroke();
  }

  /** Arrowhead showing which way to go next. It pops big and bright when it
   *  becomes active, then eases down to a hint. */
  drawChevron() {
    const segment = this.activeSegment;
    if (segment < 0) return;
    const { mids, dirs } = this.segments[this.tracer.stroke];
    const tip = this.path.points[mids[segment]];
    const dir = dirs[segment];

    const size = 8 * (2 - this.flash);
    const spread = 0.45;
    const cos = Math.cos(spread);
    const sin = Math.sin(spread);
    const [bx, by] = [-dir.x, -dir.y];

    const { ctx } = this;
    ctx.globalAlpha = 1 - 0.45 * this.flash;
    ctx.lineWidth = 2 * (2 - this.flash);
    ctx.beginPath();
    ctx.moveTo(tip.x + (bx * cos - by * sin) * size, tip.y + (bx * sin + by * cos) * size);
    ctx.lineTo(tip.x, tip.y);
    ctx.lineTo(tip.x + (bx * cos + by * sin) * size, tip.y + (-bx * sin + by * cos) * size);
    ctx.stroke();
  }

  drawNextStrokeTarget() {
    const { tracer } = this;
    if (!tracer.strokeComplete || !tracer.hasNextStroke) return;
    this.ctx.globalAlpha = 0.55;
    ring(this.ctx, tracer.nextStrokePoint, 18, 3);
  }
}

function dot(ctx, p, r) {
  ctx.beginPath();
  ctx.arc(p.x, p.y, r, 0, Math.PI * 2);
  ctx.fill();
}

function ring(ctx, p, r, width) {
  ctx.lineWidth = width;
  ctx.beginPath();
  ctx.arc(p.x, p.y, r, 0, Math.PI * 2);
  ctx.stroke();
}

/**
 * Split each stroke into segments at its sharp corners, and pick a chevron
 * position and direction for each. Returns one `{ends, mids, dirs}` per
 * stroke, indexed the same as `path.strokeStart`.
 */
function detectSegments({ points, strokeStart }) {
  return strokeStart.map((start, s) => {
    const last = s + 1 < strokeStart.length ? strokeStart[s + 1] - 1 : points.length - 1;
    const ends = [...detectCorners(points, start, last), last];
    const mids = [];
    const dirs = [];
    let segStart = start;
    for (const end of ends) {
      const mid = Math.floor((segStart + end) / 2);
      mids.push(mid);
      // Local tangent rather than the segment chord — on a curved segment the
      // chord can be short or point somewhere unhelpful.
      const a = points[Math.max(mid - 2, segStart)];
      const b = points[Math.min(mid + 2, end)];
      const len = Math.hypot(b.x - a.x, b.y - a.y);
      dirs.push(len < 0.001 ? { x: 1, y: 0 } : { x: (b.x - a.x) / len, y: (b.y - a.y) / len });
      segStart = end + 1;
    }
    return { ends, mids, dirs };
  });
}

/** Indices in `points[start..end]` where the path turns more sharply than
 *  `CORNER_ANGLE`. A run of above-threshold points collapses to its peak. */
function detectCorners(points, start, end) {
  const w = CORNER_WINDOW;
  const corners = [];
  let peak = -1;
  let peakAngle = 0;

  for (let i = start + w; i + w <= end; i++) {
    const angle = turnAngle(points[i - w], points[i], points[i + w]);
    if (angle >= CORNER_ANGLE) {
      if (peak < 0 || angle > peakAngle) {
        peak = i;
        peakAngle = angle;
      }
    } else if (peak >= 0) {
      corners.push(peak);
      peak = -1;
      peakAngle = 0;
    }
  }
  if (peak >= 0) corners.push(peak);
  return corners;
}

function turnAngle(a, b, c) {
  const t1 = { x: b.x - a.x, y: b.y - a.y };
  const t2 = { x: c.x - b.x, y: c.y - b.y };
  const l1 = Math.hypot(t1.x, t1.y);
  const l2 = Math.hypot(t2.x, t2.y);
  if (l1 < 0.001 || l2 < 0.001) return 0;
  const cos = (t1.x * t2.x + t1.y * t2.y) / (l1 * l2);
  return Math.acos(Math.min(1, Math.max(-1, cos)));
}
