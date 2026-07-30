// Drives the "pen" along a composed path while the user's finger (or mouse)
// is on the canvas. The pen chases the finger at a fixed speed, so moving
// faster than the pen just leaves it trailing behind — that lag is the whole
// point of the exercise.

import { GLYPH_SCALE } from './composer.js';

/** Pixels per second the pen travels toward the finger. */
export const PEN_SPEED = 100;

/** How close the pen must come to the next path point to count as reaching
 *  it. Scaled alongside the glyphs so progress feels the same at any size. */
const ADVANCE_THRESHOLD = 8 * GLYPH_SCALE;

export class Tracer {
  /**
   * @param {{points: {x:number,y:number}[], strokeStart: number[]}} path
   */
  constructor(path) {
    this.points = path.points;
    this.strokeStart = path.strokeStart;
    this.penSpeed = PEN_SPEED;

    this.pen = this.points[0];
    this.finger = this.points[0];
    this.index = 0;
    this.stroke = 0;
    this.isDown = false;
  }

  /** Last point index of stroke `s`. */
  strokeEnd(s) {
    return s + 1 < this.strokeStart.length
      ? this.strokeStart[s + 1] - 1
      : this.points.length - 1;
  }

  get strokeComplete() {
    return this.index >= this.strokeEnd(this.stroke);
  }

  get hasNextStroke() {
    return this.stroke + 1 < this.strokeStart.length;
  }

  get nextStrokePoint() {
    return this.hasNextStroke
      ? this.points[this.strokeStart[this.stroke + 1]]
      : this.points.at(-1);
  }

  /** True once the last point of the last stroke has been reached. */
  get complete() {
    return !this.hasNextStroke && this.index >= this.points.length - 1;
  }

  /** Jump to the next stroke, teleporting the pen to its first point. The
   *  caller gates this on a touch landing near `nextStrokePoint`. */
  advanceStroke() {
    if (!this.hasNextStroke) return;
    this.stroke++;
    this.index = this.strokeStart[this.stroke];
    this.pen = this.finger = this.points[this.index];
  }

  setFinger(p) {
    if (this.isDown) this.finger = p;
  }

  /** Advance the simulation by `dt` seconds. A no-op while the pen is up —
   *  lifting your finger freezes both the pen and the progress index. */
  tick(dt) {
    if (!this.isDown || dt <= 0) return;

    const dx = this.finger.x - this.pen.x;
    const dy = this.finger.y - this.pen.y;
    const dist = Math.hypot(dx, dy);
    const step = this.penSpeed * dt;
    this.pen = dist <= step
      ? this.finger
      : { x: this.pen.x + (dx / dist) * step, y: this.pen.y + (dy / dist) * step };

    // Progress never runs backwards, and never crosses a stroke boundary.
    const end = this.strokeEnd(this.stroke);
    while (this.index < end && this.near(this.points[this.index + 1])) this.index++;
  }

  near(p) {
    return Math.hypot(p.x - this.pen.x, p.y - this.pen.y) < ADVANCE_THRESHOLD;
  }
}
