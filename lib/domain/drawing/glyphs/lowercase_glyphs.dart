// GENERATED FILE — initial seed from letterpaths. Hand-editable.
// Regenerate via: python3 tool/letterpaths_to_dart.py
//   (Re-running OVERWRITES this file. Back up tweaks if you've hand-tuned.)
//
// Lowercase a-z glyphs are initially derived from the letterpaths cursive
// dataset (MIT-licensed, github.com/RobinL/letterpaths). License preserved
// in vendor/letterpaths/LICENSE.
//
// Coord system (same as uppercase / punctuation):
//   x in 0..advanceWidth (left to right)
//   y: baseline = 70, x-height top = 30, y grows downward
//   ascender region (y < 30) and descender region (y > 70) are open-ended

import 'dart:ui' show Offset;

import 'cursive_glyph_types.dart';

const Map<String, CursiveGlyph> lowercaseGlyphs = {
  'a': CursiveGlyph(
    advanceWidth: 36.61,
    strokes: [
      CursiveStroke(beziers: [  // main
        [Offset(-1.75, 69.52), Offset(-0.88, 46.38), Offset(12.50, 37.00), Offset(26.50, 43.62)],
        [Offset(26.50, 43.62), Offset(-12.12, 29.12), Offset(5.12, 102.75), Offset(26.88, 47.75)],
        [Offset(26.88, 47.75), Offset(20.62, 56.38), Offset(28.38, 89.38), Offset(49.25, 51.88)],
      ]),
    ],
  ),
  'b': CursiveGlyph(
    advanceWidth: 36.54,
    strokes: [
      CursiveStroke(beziers: [  // main
        [Offset(-1.02, 70.00), Offset(19.20, 25.91), Offset(29.21, -16.58), Offset(13.91, -21.24)],
        [Offset(13.91, -21.24), Offset(-3.40, -10.43), Offset(1.26, 74.43), Offset(17.07, 71.26)],
        [Offset(17.07, 71.26), Offset(35.20, 73.43), Offset(36.49, 20.07), Offset(8.88, 49.00)],
        [Offset(8.88, 49.00), Offset(6.46, 48.70), Offset(44.05, 71.95), Offset(54.28, 50.76)],
      ]),
    ],
  ),
  'c': CursiveGlyph(
    advanceWidth: 33.96,
    strokes: [
      CursiveStroke(beziers: [  // main
        [Offset(-0.77, 69.03), Offset(0.93, 52.80), Offset(9.21, 25.43), Offset(23.06, 47.97)],
        [Offset(23.06, 47.97), Offset(3.61, 17.14), Offset(-8.48, 84.25), Offset(26.75, 68.54)],
        [Offset(26.75, 68.54), Offset(40.15, 58.07), Offset(36.01, 57.34), Offset(41.86, 51.96)],
      ]),
    ],
  ),
  'd': CursiveGlyph(
    advanceWidth: 39.82,
    strokes: [
      CursiveStroke(beziers: [  // main
        [Offset(-0.29, 69.76), Offset(-0.90, 57.12), Offset(17.35, 18.00), Offset(23.89, 50.47)],
        [Offset(23.89, 50.47), Offset(14.74, 13.86), Offset(-4.06, 67.10), Offset(7.42, 67.77)],
        [Offset(7.42, 67.77), Offset(28.38, 74.92), Offset(45.35, -21.41), Offset(31.38, -13.09)],
        [Offset(31.38, -13.09), Offset(10.75, -8.93), Offset(21.23, 114.02), Offset(52.51, 50.63)],
      ]),
    ],
  ),
  'e': CursiveGlyph(
    advanceWidth: 29.52,
    strokes: [
      CursiveStroke(beziers: [  // main
        [Offset(-1.07, 68.77), Offset(8.25, 62.95), Offset(31.71, 46.31), Offset(11.74, 40.48)],
        [Offset(11.74, 40.48), Offset(-2.56, 46.14), Offset(8.08, 64.78), Offset(10.75, 66.94)],
        [Offset(10.75, 66.94), Offset(20.06, 72.93), Offset(28.00, 69.25), Offset(37.53, 51.80)],
      ]),
    ],
  ),
  'f': CursiveGlyph(
    advanceWidth: 45.98,
    strokes: [
      CursiveStroke(beziers: [  // main
        [Offset(-1.51, 68.54), Offset(29.19, 8.62), Offset(24.56, -24.27), Offset(13.60, -20.61)],
        [Offset(13.60, -20.61), Offset(-2.72, -16.71), Offset(-0.04, 136.99), Offset(11.65, 128.95)],
        [Offset(11.65, 128.95), Offset(28.21, 136.02), Offset(20.42, 69.27), Offset(2.39, 78.29)],
        [Offset(2.39, 78.29), Offset(25.78, 66.11), Offset(31.38, 57.58), Offset(32.84, 50.76)],
      ]),
    ],
  ),
  'g': CursiveGlyph(
    advanceWidth: 38.28,
    strokes: [
      CursiveStroke(beziers: [  // main
        [Offset(-1.75, 69.03), Offset(-0.77, 33.71), Offset(22.37, 38.58), Offset(25.29, 45.89)],
        [Offset(25.29, 45.89), Offset(-5.40, 19.34), Offset(1.42, 102.40), Offset(23.83, 52.71)],
        [Offset(23.83, 52.71), Offset(24.07, 87.30), Offset(26.26, 141.86), Offset(10.19, 137.48)],
        [Offset(10.19, 137.48), Offset(-7.35, 130.17), Offset(9.46, 93.14), Offset(44.05, 52.95)],
      ]),
    ],
  ),
  'h': CursiveGlyph(
    advanceWidth: 32.68,
    strokes: [
      CursiveStroke(beziers: [  // main
        [Offset(-6.62, 69.03), Offset(15.06, 41.26), Offset(32.35, -14.28), Offset(15.55, -20.86)],
        [Offset(15.55, -20.86), Offset(2.39, -25.97), Offset(2.15, 47.84), Offset(5.07, 69.03)],
        [Offset(5.07, 69.03), Offset(30.65, 27.62), Offset(29.92, 41.99), Offset(30.16, 56.85)],
        [Offset(30.16, 56.85), Offset(30.16, 72.93), Offset(42.10, 75.36), Offset(53.55, 50.52)],
      ]),
    ],
  ),
  'i': CursiveGlyph(
    advanceWidth: 10.80,
    strokes: [
      CursiveStroke(beziers: [  // main
        [Offset(0.25, 69.62), Offset(3.75, 67.25), Offset(4.62, 76.25), Offset(6.05, 38.58)],
        [Offset(6.05, 38.58), Offset(4.58, 70.00), Offset(4.88, 44.88), Offset(4.83, 60.75)],
        [Offset(4.83, 60.75), Offset(4.94, 71.01), Offset(22.37, 79.26), Offset(31.87, 51.00)],
      ]),
      CursiveStroke(beziers: [  // deferred
        [Offset(6.53, 20.07), Offset(6.53, 20.07), Offset(6.53, 20.07), Offset(6.53, 20.07)],
      ]),
    ],
  ),
  'j': CursiveGlyph(
    advanceWidth: 22.20,
    strokes: [
      CursiveStroke(beziers: [  // main
        [Offset(-1.02, 69.76), Offset(8.97, 67.32), Offset(2.64, 47.11), Offset(6.53, 38.82)],
        [Offset(6.53, 38.82), Offset(-0.04, 98.26), Offset(13.35, 131.63), Offset(-10.03, 131.14)],
        [Offset(-10.03, 131.14), Offset(-22.94, 118.72), Offset(-6.62, 86.32), Offset(26.51, 51.98)],
      ]),
      CursiveStroke(beziers: [  // deferred
        [Offset(7.51, 19.82), Offset(7.51, 19.58), Offset(7.02, 19.82), Offset(7.51, 19.82)],
      ]),
    ],
  ),
  'k': CursiveGlyph(
    advanceWidth: 25.70,
    strokes: [
      CursiveStroke(beziers: [  // main
        [Offset(-1.02, 68.54), Offset(2.86, 15.75), Offset(16.28, -10.14), Offset(8.48, -16.96)],
        [Offset(8.48, -16.96), Offset(0.20, -22.56), Offset(2.58, 45.93), Offset(5.07, 69.76)],
        [Offset(5.07, 69.76), Offset(2.35, 57.87), Offset(13.11, 19.82), Offset(26.99, 23.23)],
        [Offset(26.99, 23.23), Offset(34.79, 33.22), Offset(3.73, 49.38), Offset(3.61, 46.62)],
        [Offset(3.61, 46.62), Offset(7.16, 55.16), Offset(30.89, 93.88), Offset(50.14, 50.03)],
      ]),
    ],
  ),
  'l': CursiveGlyph(
    advanceWidth: 15.39,
    strokes: [
      CursiveStroke(beziers: [  // main
        [Offset(-0.53, 69.76), Offset(17.25, 29.08), Offset(32.60, -15.50), Offset(17.49, -21.10)],
        [Offset(17.49, -21.10), Offset(3.85, -21.10), Offset(4.34, 12.52), Offset(4.83, 33.71)],
        [Offset(4.83, 33.71), Offset(4.58, 58.31), Offset(17.98, 90.47), Offset(35.76, 51.49)],
      ]),
    ],
  ),
  'm': CursiveGlyph(
    advanceWidth: 53.25,
    strokes: [
      CursiveStroke(beziers: [  // main
        [Offset(-0.04, 68.54), Offset(2.39, 39.07), Offset(19.20, 26.40), Offset(15.55, 54.17)],
        [Offset(15.55, 54.17), Offset(14.82, 57.82), Offset(12.87, 81.21), Offset(24.32, 55.14)],
        [Offset(24.32, 55.14), Offset(22.85, 53.20), Offset(41.37, 27.38), Offset(38.69, 54.90)],
        [Offset(38.69, 54.90), Offset(37.71, 61.97), Offset(38.93, 80.72), Offset(46.48, 58.31)],
        [Offset(46.48, 58.31), Offset(56.71, 36.14), Offset(68.89, 39.80), Offset(64.26, 55.39)],
        [Offset(64.26, 55.39), Offset(60.85, 70.25), Offset(77.42, 77.07), Offset(88.38, 50.27)],
      ]),
    ],
  ),
  'n': CursiveGlyph(
    advanceWidth: 32.81,
    strokes: [
      CursiveStroke(beziers: [  // main
        [Offset(-0.53, 69.03), Offset(6.53, 22.75), Offset(21.64, 39.80), Offset(14.82, 54.66)],
        [Offset(14.82, 54.66), Offset(9.94, 63.91), Offset(15.55, 79.75), Offset(25.05, 53.20)],
        [Offset(25.05, 53.20), Offset(30.16, 38.58), Offset(43.80, 36.14), Offset(39.66, 56.85)],
        [Offset(39.66, 56.85), Offset(35.52, 70.98), Offset(53.06, 75.61), Offset(63.05, 50.52)],
      ]),
    ],
  ),
  'o': CursiveGlyph(
    advanceWidth: 36.35,
    strokes: [
      CursiveStroke(beziers: [  // main
        [Offset(-1.02, 71.47), Offset(2.06, 44.88), Offset(3.85, 38.58), Offset(19.44, 37.36)],
        [Offset(19.44, 37.36), Offset(2.97, 36.24), Offset(-7.70, 59.38), Offset(10.34, 68.16)],
        [Offset(10.34, 68.16), Offset(20.17, 74.39), Offset(41.12, 56.85), Offset(22.37, 39.07)],
        [Offset(22.37, 39.07), Offset(7.02, 37.61), Offset(28.21, 79.02), Offset(45.51, 51.98)],
      ]),
    ],
  ),
  'p': CursiveGlyph(
    advanceWidth: 35.23,
    strokes: [
      CursiveStroke(beziers: [  // main
        [Offset(-4.92, 70.49), Offset(6.78, 60.26), Offset(10.43, 70.49), Offset(9.70, 32.25)],
        [Offset(9.70, 32.25), Offset(5.32, 51.73), Offset(13.35, 132.61), Offset(-5.16, 132.36)],
        [Offset(-5.16, 132.36), Offset(-13.20, 120.43), Offset(15.30, 30.30), Offset(27.73, 41.50)],
        [Offset(27.73, 41.50), Offset(33.77, 45.54), Offset(36.74, 68.79), Offset(9.70, 62.94)],
        [Offset(9.70, 62.94), Offset(32.60, 78.77), Offset(44.53, 66.11), Offset(52.33, 50.76)],
      ]),
    ],
  ),
  'q': CursiveGlyph(
    advanceWidth: 36.13,
    strokes: [
      CursiveStroke(beziers: [  // main
        [Offset(-0.53, 68.79), Offset(4.34, 33.71), Offset(19.93, 41.99), Offset(26.02, 43.70)],
        [Offset(26.02, 43.70), Offset(2.39, 30.54), Offset(-4.08, 70.82), Offset(12.72, 69.51)],
        [Offset(12.72, 69.51), Offset(17.49, 69.03), Offset(24.07, 58.80), Offset(25.53, 48.81)],
        [Offset(25.53, 48.81), Offset(17.98, 99.23), Offset(20.91, 138.45), Offset(30.65, 136.50)],
        [Offset(30.65, 136.50), Offset(43.07, 132.61), Offset(40.64, 109.95), Offset(22.12, 82.91)],
        [Offset(22.12, 82.91), Offset(34.06, 67.81), Offset(37.47, 61.72), Offset(45.26, 50.03)],
      ]),
    ],
  ),
  'r': CursiveGlyph(
    advanceWidth: 27.07,
    strokes: [
      CursiveStroke(beziers: [  // main
        [Offset(-0.77, 70.49), Offset(15.30, 13.49), Offset(-0.77, 34.93), Offset(2.64, 30.79)],
        [Offset(2.64, 30.79), Offset(-1.02, 42.72), Offset(-7.35, 41.75), Offset(13.11, 41.02)],
        [Offset(13.11, 41.02), Offset(21.88, 41.02), Offset(18.23, 49.30), Offset(17.25, 60.99)],
        [Offset(17.25, 60.99), Offset(17.74, 67.57), Offset(30.41, 79.02), Offset(45.02, 50.27)],
      ]),
    ],
  ),
  's': CursiveGlyph(
    advanceWidth: 29.98,
    strokes: [
      CursiveStroke(beziers: [  // main
        [Offset(-10.27, 70.73), Offset(-6.13, 65.52), Offset(-1.75, 65.86), Offset(3.61, 50.52)],
        [Offset(3.61, 50.52), Offset(9.94, 36.39), Offset(9.21, 43.21), Offset(19.44, 31.76)],
        [Offset(19.44, 31.76), Offset(-7.11, 31.52), Offset(41.61, 74.63), Offset(3.12, 67.57)],
        [Offset(3.12, 67.57), Offset(14.08, 73.66), Offset(19.93, 71.95), Offset(25.29, 67.57)],
        [Offset(25.29, 67.57), Offset(34.55, 62.45), Offset(39.88, 48.22), Offset(38.44, 51.25)],
      ]),
    ],
  ),
  't': CursiveGlyph(
    advanceWidth: 19.50,
    strokes: [
      CursiveStroke(beziers: [  // main
        [Offset(-0.53, 69.76), Offset(11.16, 32.73), Offset(17.01, -1.86), Offset(11.89, -6.24)],
        [Offset(11.89, -6.24), Offset(-10.27, 101.91), Offset(31.38, 67.57), Offset(34.30, 50.76)],
      ]),
      CursiveStroke(beziers: [  // deferred
        [Offset(-20.99, 5.21), Offset(44.53, 5.94), Offset(-13.68, 5.70), Offset(51.84, 5.70)],
      ]),
    ],
  ),
  'u': CursiveGlyph(
    advanceWidth: 31.86,
    strokes: [
      CursiveStroke(beziers: [  // main
        [Offset(-1.51, 69.52), Offset(2.88, 61.23), Offset(7.02, 45.64), Offset(9.46, 41.26)],
        [Offset(9.46, 41.26), Offset(2.39, 53.68), Offset(2.64, 71.22), Offset(13.11, 69.03)],
        [Offset(13.11, 69.03), Offset(18.71, 68.30), Offset(26.51, 54.41), Offset(24.80, 43.21)],
        [Offset(24.80, 43.21), Offset(23.83, 70.73), Offset(31.82, 69.44), Offset(32.35, 69.03)],
        [Offset(32.35, 69.03), Offset(47.46, 64.89), Offset(43.32, 58.56), Offset(51.11, 49.30)],
      ]),
    ],
  ),
  'v': CursiveGlyph(
    advanceWidth: 30.85,
    strokes: [
      CursiveStroke(beziers: [  // main
        [Offset(-1.26, 70.73), Offset(2.64, 57.82), Offset(-0.29, 33.47), Offset(6.53, 41.02)],
        [Offset(6.53, 41.02), Offset(13.60, 49.06), Offset(11.51, 65.20), Offset(14.35, 69.55)],
        [Offset(14.35, 69.55), Offset(12.14, 63.18), Offset(37.23, 36.39), Offset(25.78, 38.34)],
        [Offset(25.78, 38.34), Offset(23.10, 47.84), Offset(43.07, 64.16), Offset(47.94, 51.73)],
      ]),
    ],
  ),
  'w': CursiveGlyph(
    advanceWidth: 55.69,
    strokes: [
      CursiveStroke(beziers: [  // main
        [Offset(-0.29, 69.52), Offset(-0.29, 58.56), Offset(3.12, 49.30), Offset(9.21, 40.04)],
        [Offset(9.21, 40.04), Offset(3.98, 42.73), Offset(-1.51, 71.22), Offset(13.11, 68.06)],
        [Offset(13.11, 68.06), Offset(26.99, 60.26), Offset(25.29, 44.18), Offset(25.78, 42.72)],
        [Offset(25.78, 42.72), Offset(21.15, 67.08), Offset(29.92, 69.76), Offset(35.76, 68.79)],
        [Offset(35.76, 68.79), Offset(45.26, 67.32), Offset(45.75, 48.32), Offset(44.29, 39.56)],
        [Offset(44.29, 39.56), Offset(48.92, 45.40), Offset(52.33, 65.13), Offset(66.21, 51.49)],
      ]),
    ],
  ),
  'x': CursiveGlyph(
    advanceWidth: 38.18,
    strokes: [
      CursiveStroke(beziers: [  // main
        [Offset(0.44, 69.03), Offset(7.75, -6.00), Offset(36.01, 60.75), Offset(11.65, 69.52)],
        [Offset(11.65, 69.52), Offset(6.78, 50.03), Offset(46.48, 41.75), Offset(37.96, 33.47)],
        [Offset(37.96, 33.47), Offset(3.61, 44.67), Offset(27.73, 98.26), Offset(52.33, 51.73)],
      ]),
    ],
  ),
  'y': CursiveGlyph(
    advanceWidth: 34.08,
    strokes: [
      CursiveStroke(beziers: [  // main
        [Offset(-0.77, 69.27), Offset(1.17, 52.71), Offset(3.85, 51.73), Offset(9.21, 41.02)],
        [Offset(9.21, 41.02), Offset(2.39, 48.32), Offset(0.93, 66.35), Offset(9.21, 68.54)],
        [Offset(9.21, 68.54), Offset(17.25, 70.98), Offset(21.39, 62.70), Offset(26.26, 44.67)],
        [Offset(26.26, 44.67), Offset(18.47, 51.25), Offset(34.06, 126.76), Offset(10.92, 127.98)],
        [Offset(10.92, 127.98), Offset(-5.65, 119.21), Offset(18.47, 76.58), Offset(45.26, 51.98)],
      ]),
    ],
  ),
  'z': CursiveGlyph(
    advanceWidth: 33.63,
    strokes: [
      CursiveStroke(beziers: [  // main
        [Offset(-0.77, 69.03), Offset(17.74, -2.59), Offset(50.87, 56.85), Offset(11.65, 67.08)],
        [Offset(11.65, 67.08), Offset(38.20, 29.32), Offset(36.49, 120.67), Offset(17.01, 124.81)],
        [Offset(17.01, 124.81), Offset(8.97, 120.18), Offset(3.85, 107.76), Offset(52.57, 51.00)],
      ]),
    ],
  ),
};
