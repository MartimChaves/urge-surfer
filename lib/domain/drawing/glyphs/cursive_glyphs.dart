// GENERATED FILE — do not edit by hand.
// Regenerate via: python3 tool/letterpaths_to_dart.py > lib/domain/drawing/glyphs/cursive_glyphs.dart
//
// Lowercase a-z glyphs are derived from the letterpaths cursive dataset
// (MIT-licensed, github.com/RobinL/letterpaths). License preserved in
// vendor/letterpaths/LICENSE.
//
// Each letter is normalized into our coord system:
//   x in 0..advanceWidth (left to right)
//   y baseline = 70, x-height top = 30, y grows downward
//   ascender region (y < 30) and descender region (y > 70) are open-ended
//
// 'I' and '.' are hand-authored in the same coord system.

import 'dart:ui' show Offset;

class CursiveGlyph {
  final List<CursiveStroke> strokes;
  final double advanceWidth;
  const CursiveGlyph({required this.strokes, required this.advanceWidth});
}

class CursiveStroke {
  final List<List<Offset>> beziers;
  const CursiveStroke({required this.beziers});
}

const Map<String, CursiveGlyph> cursiveGlyphs = {
  'a': CursiveGlyph(
    advanceWidth: 36.61,
    strokes: [
      CursiveStroke(beziers: [  // main
        [Offset(0.53, 44.88), Offset(8.46, 27.93), Offset(23.25, 26.66), Offset(35.62, 33.68)],
        [Offset(35.62, 33.68), Offset(23.24, 26.82), Offset(12.42, 30.10), Offset(7.16, 35.68)],
        [Offset(7.16, 35.68), Offset(1.90, 41.25), Offset(-0.78, 45.35), Offset(0.30, 54.77)],
        [Offset(0.30, 54.77), Offset(2.61, 70.48), Offset(25.73, 76.68), Offset(35.19, 59.06)],
        [Offset(35.19, 59.06), Offset(35.87, 49.06), Offset(35.42, 40.00), Offset(36.10, 30.00)],
        [Offset(36.10, 30.00), Offset(35.96, 42.30), Offset(32.21, 69.64), Offset(41.51, 69.79)],
      ]),
    ],
  ),
  'b': CursiveGlyph(
    advanceWidth: 36.54,
    strokes: [
      CursiveStroke(beziers: [  // main
        [Offset(2.49, 19.18), Offset(2.64, 13.20), Offset(2.38, 11.02), Offset(2.58, 0.23)],
        [Offset(2.58, 0.23), Offset(2.36, 13.10), Offset(2.54, 23.59), Offset(2.47, 29.58)],
        [Offset(2.47, 29.58), Offset(2.41, 35.58), Offset(0.34, 46.78), Offset(0.11, 70.03)],
        [Offset(0.11, 70.03), Offset(0.46, 62.47), Offset(1.00, 52.97), Offset(2.09, 40.68)],
        [Offset(2.09, 40.68), Offset(4.72, 28.51), Offset(37.44, 22.65), Offset(36.02, 50.68)],
        [Offset(36.02, 50.68), Offset(33.66, 78.76), Offset(6.63, 67.63), Offset(0.63, 65.24)],
        [Offset(0.63, 65.24), Offset(7.55, 67.39), Offset(14.38, 69.96), Offset(22.73, 69.88)],
      ]),
    ],
  ),
  'c': CursiveGlyph(
    advanceWidth: 33.96,
    strokes: [
      CursiveStroke(beziers: [  // main
        [Offset(3.25, 40.58), Offset(13.37, 21.79), Offset(32.45, 34.36), Offset(33.77, 35.38)],
        [Offset(33.77, 35.38), Offset(5.01, 15.77), Offset(-10.14, 57.89), Offset(7.96, 67.36)],
        [Offset(7.96, 67.36), Offset(14.39, 70.73), Offset(27.88, 69.94), Offset(33.90, 68.22)],
        [Offset(33.90, 68.22), Offset(34.02, 68.20), Offset(34.08, 68.18), Offset(34.18, 68.16)],
      ]),
    ],
  ),
  'd': CursiveGlyph(
    advanceWidth: 39.82,
    strokes: [
      CursiveStroke(beziers: [  // main
        [Offset(0.53, 43.57), Offset(9.18, 24.12), Offset(30.48, 29.59), Offset(36.99, 36.59)],
        [Offset(36.99, 36.59), Offset(22.59, 24.08), Offset(-0.02, 31.81), Offset(0.18, 47.82)],
        [Offset(0.18, 47.82), Offset(-0.15, 73.56), Offset(24.67, 73.04), Offset(36.30, 63.92)],
        [Offset(36.30, 63.92), Offset(37.40, 49.22), Offset(37.45, 36.45), Offset(37.26, -0.62)],
        [Offset(37.26, -0.62), Offset(36.31, 12.47), Offset(37.76, 26.97), Offset(37.03, 40.08)],
        [Offset(37.03, 40.08), Offset(35.63, 65.14), Offset(37.17, 66.91), Offset(37.87, 68.04)],
        [Offset(37.87, 68.04), Offset(38.57, 69.18), Offset(40.81, 69.95), Offset(42.78, 69.87)],
      ]),
    ],
  ),
  'e': CursiveGlyph(
    advanceWidth: 29.52,
    strokes: [
      CursiveStroke(beziers: [  // main
        [Offset(7.10, 63.00), Offset(10.56, 60.60), Offset(29.14, 50.14), Offset(29.31, 41.48)],
        [Offset(29.31, 41.48), Offset(29.47, 32.83), Offset(22.05, 28.62), Offset(11.44, 31.36)],
        [Offset(11.44, 31.36), Offset(0.83, 34.11), Offset(-0.46, 44.16), Offset(0.58, 49.50)],
        [Offset(0.58, 49.50), Offset(1.63, 54.85), Offset(6.44, 67.56), Offset(21.33, 69.23)],
        [Offset(21.33, 69.23), Offset(25.37, 69.88), Offset(28.52, 69.88), Offset(29.59, 69.82)],
      ]),
    ],
  ),
  'f': CursiveGlyph(
    advanceWidth: 45.98,
    strokes: [
      CursiveStroke(beziers: [  // main
        [Offset(25.25, 23.53), Offset(28.32, 7.44), Offset(37.99, 6.20), Offset(45.87, 6.42)],
        [Offset(45.87, 6.42), Offset(27.89, 6.02), Offset(25.73, 17.39), Offset(24.49, 33.48)],
        [Offset(24.49, 33.48), Offset(23.72, 43.49), Offset(22.31, 53.43), Offset(21.64, 63.44)],
        [Offset(21.64, 63.44), Offset(20.83, 75.51), Offset(23.11, 87.02), Offset(14.76, 96.99)],
        [Offset(14.76, 96.99), Offset(11.08, 101.40), Offset(0.47, 99.49), Offset(0.26, 88.85)],
        [Offset(0.26, 88.85), Offset(0.04, 78.22), Offset(14.01, 68.76), Offset(25.63, 64.12)],
      ]),
    ],
  ),
  'g': CursiveGlyph(
    advanceWidth: 38.28,
    strokes: [
      CursiveStroke(beziers: [  // main
        [Offset(0.85, 47.44), Offset(5.32, 25.33), Offset(28.38, 29.29), Offset(37.17, 35.20)],
        [Offset(37.17, 35.20), Offset(34.48, 33.95), Offset(23.23, 26.78), Offset(11.39, 32.53)],
        [Offset(11.39, 32.53), Offset(-0.46, 38.27), Offset(-4.60, 59.67), Offset(8.56, 67.17)],
        [Offset(8.56, 67.17), Offset(21.17, 74.31), Offset(29.61, 65.07), Offset(36.53, 59.68)],
        [Offset(36.53, 59.68), Offset(37.01, 59.33), Offset(36.67, 40.42), Offset(37.65, 30.31)],
        [Offset(37.65, 30.31), Offset(36.54, 57.99), Offset(36.77, 61.55), Offset(35.54, 70.65)],
        [Offset(35.54, 70.65), Offset(35.29, 73.93), Offset(34.39, 83.17), Offset(32.43, 91.03)],
        [Offset(32.43, 91.03), Offset(27.69, 109.85), Offset(9.26, 100.40), Offset(9.37, 89.50)],
        [Offset(9.37, 89.50), Offset(9.42, 85.56), Offset(16.37, 82.42), Offset(18.63, 81.09)],
      ]),
    ],
  ),
  'h': CursiveGlyph(
    advanceWidth: 32.68,
    strokes: [
      CursiveStroke(beziers: [  // main
        [Offset(2.13, 36.64), Offset(2.70, 28.29), Offset(5.11, 5.75), Offset(5.21, 1.65)],
        [Offset(5.21, 1.65), Offset(3.42, 24.08), Offset(0.53, 47.65), Offset(-0.03, 70.17)],
        [Offset(-0.03, 70.17), Offset(0.33, 57.14), Offset(-2.21, 29.86), Offset(18.06, 30.22)],
        [Offset(18.06, 30.22), Offset(37.69, 30.16), Offset(26.28, 69.60), Offset(35.06, 69.85)],
      ]),
    ],
  ),
  'i': CursiveGlyph(
    advanceWidth: 10.80,
    strokes: [
      CursiveStroke(beziers: [  // main
        [Offset(1.23, 43.41), Offset(1.66, 33.51), Offset(1.88, 33.50), Offset(2.14, 30.44)],
        [Offset(2.14, 30.44), Offset(1.41, 38.69), Offset(-0.16, 62.07), Offset(2.39, 66.54)],
        [Offset(2.39, 66.54), Offset(4.94, 71.01), Offset(10.58, 69.80), Offset(11.78, 69.82)],
      ]),
      CursiveStroke(beziers: [  // deferred
        [Offset(2.93, 19.41), Offset(2.95, 19.41), Offset(2.97, 19.41), Offset(3.00, 19.41)],
      ]),
    ],
  ),
  'j': CursiveGlyph(
    advanceWidth: 22.20,
    strokes: [
      CursiveStroke(beziers: [  // main
        [Offset(19.18, 51.12), Offset(19.47, 44.99), Offset(19.56, 37.99), Offset(19.94, 30.30)],
        [Offset(19.94, 30.30), Offset(18.18, 67.82), Offset(21.38, 99.03), Offset(-0.28, 99.59)],
        [Offset(-0.28, 99.59), Offset(-12.11, 99.86), Offset(-8.19, 85.99), Offset(0.12, 79.43)],
      ]),
      CursiveStroke(beziers: [  // deferred
        [Offset(20.70, 17.78), Offset(20.73, 17.78), Offset(20.76, 17.78), Offset(20.78, 17.78)],
      ]),
    ],
  ),
  'k': CursiveGlyph(
    advanceWidth: 25.70,
    strokes: [
      CursiveStroke(beziers: [  // main
        [Offset(2.69, 23.53), Offset(2.86, 15.75), Offset(2.97, 10.34), Offset(3.39, 2.98)],
        [Offset(3.39, 2.98), Offset(1.98, 29.00), Offset(2.58, 45.93), Offset(0.68, 69.89)],
        [Offset(0.68, 69.89), Offset(2.35, 57.87), Offset(1.02, 43.29), Offset(2.57, 34.48)],
        [Offset(2.57, 34.48), Offset(9.51, 26.72), Offset(22.38, 30.62), Offset(24.94, 37.51)],
        [Offset(24.94, 37.51), Offset(29.75, 51.49), Offset(3.73, 49.38), Offset(2.77, 50.30)],
        [Offset(2.77, 50.30), Offset(7.16, 55.16), Offset(19.86, 69.62), Offset(25.77, 69.91)],
      ]),
    ],
  ),
  'l': CursiveGlyph(
    advanceWidth: 15.39,
    strokes: [
      CursiveStroke(beziers: [  // main
        [Offset(0.71, 33.12), Offset(1.09, 10.73), Offset(1.73, 14.13), Offset(1.90, 8.87)],
        [Offset(1.90, 8.87), Offset(1.14, 24.65), Offset(-0.04, 45.36), Offset(0.36, 57.08)],
        [Offset(0.36, 57.08), Offset(0.76, 68.80), Offset(11.93, 71.29), Offset(19.33, 68.44)],
      ]),
    ],
  ),
  'm': CursiveGlyph(
    advanceWidth: 53.25,
    strokes: [
      CursiveStroke(beziers: [  // main
        [Offset(1.11, 43.24), Offset(1.44, 39.43), Offset(1.53, 35.35), Offset(2.06, 30.30)],
        [Offset(2.06, 30.30), Offset(0.90, 53.42), Offset(1.40, 40.89), Offset(0.68, 68.99)],
        [Offset(0.68, 68.99), Offset(2.14, 51.87), Offset(-1.38, 37.97), Offset(7.79, 32.81)],
        [Offset(7.79, 32.81), Offset(16.96, 27.64), Offset(27.38, 29.61), Offset(27.24, 38.94)],
        [Offset(27.24, 38.94), Offset(26.90, 48.36), Offset(26.45, 60.12), Offset(26.11, 69.54)],
        [Offset(26.11, 69.54), Offset(26.35, 56.16), Offset(25.87, 38.79), Offset(31.18, 34.28)],
        [Offset(31.18, 34.28), Offset(36.49, 29.76), Offset(47.38, 27.81), Offset(50.74, 34.75)],
        [Offset(50.74, 34.75), Offset(55.84, 45.31), Offset(49.78, 69.65), Offset(55.50, 69.86)],
      ]),
    ],
  ),
  'n': CursiveGlyph(
    advanceWidth: 32.81,
    strokes: [
      CursiveStroke(beziers: [  // main
        [Offset(0.33, 44.24), Offset(0.87, 40.24), Offset(0.51, 36.02), Offset(0.97, 30.30)],
        [Offset(0.97, 30.30), Offset(0.26, 54.41), Offset(1.14, 45.01), Offset(0.35, 69.94)],
        [Offset(0.35, 69.94), Offset(0.46, 34.93), Offset(2.87, 30.73), Offset(16.79, 30.60)],
        [Offset(16.79, 30.60), Offset(36.74, 30.91), Offset(28.01, 69.75), Offset(33.30, 69.79)],
      ]),
    ],
  ),
  'o': CursiveGlyph(
    advanceWidth: 36.35,
    strokes: [
      CursiveStroke(beziers: [  // main
        [Offset(0.33, 49.81), Offset(2.06, 44.88), Offset(6.39, 23.21), Offset(30.74, 32.74)],
        [Offset(30.74, 32.74), Offset(24.02, 29.37), Offset(17.70, 29.29), Offset(10.33, 32.77)],
        [Offset(10.33, 32.77), Offset(2.97, 36.24), Offset(-7.70, 59.38), Offset(10.34, 68.16)],
        [Offset(10.34, 68.16), Offset(19.14, 72.45), Offset(29.47, 67.03), Offset(33.63, 58.91)],
        [Offset(33.63, 58.91), Offset(35.41, 55.46), Offset(36.23, 48.72), Offset(36.15, 44.89)],
        [Offset(36.15, 44.89), Offset(36.02, 39.37), Offset(34.43, 34.63), Offset(30.61, 32.64)],
        [Offset(30.61, 32.64), Offset(32.88, 33.26), Offset(32.88, 33.33), Offset(35.11, 33.37)],
      ]),
    ],
  ),
  'p': CursiveGlyph(
    advanceWidth: 35.23,
    strokes: [
      CursiveStroke(beziers: [  // main
        [Offset(-0.26, 46.48), Offset(0.63, 41.12), Offset(0.90, 35.91), Offset(1.32, 30.04)],
        [Offset(1.32, 30.04), Offset(-0.37, 53.55), Offset(0.48, 79.47), Offset(0.10, 104.36)],
        [Offset(0.10, 104.36), Offset(0.19, 95.81), Offset(-1.59, 35.35), Offset(4.28, 32.49)],
        [Offset(4.28, 32.49), Offset(13.26, 27.69), Offset(29.48, 31.83), Offset(32.73, 36.99)],
        [Offset(32.73, 36.99), Offset(35.97, 42.15), Offset(37.39, 62.10), Offset(24.28, 68.44)],
        [Offset(24.28, 68.44), Offset(17.97, 71.49), Offset(6.57, 67.40), Offset(0.61, 65.34)],
        [Offset(0.61, 65.34), Offset(6.82, 68.09), Offset(14.85, 69.75), Offset(21.90, 69.57)],
      ]),
    ],
  ),
  'q': CursiveGlyph(
    advanceWidth: 36.13,
    strokes: [
      CursiveStroke(beziers: [  // main
        [Offset(5.07, 36.51), Offset(10.55, 28.94), Offset(29.68, 28.47), Offset(35.49, 36.14)],
        [Offset(35.49, 36.14), Offset(30.89, 32.95), Offset(25.06, 27.19), Offset(10.91, 32.26)],
        [Offset(10.91, 32.26), Offset(-3.23, 37.33), Offset(-4.08, 70.82), Offset(12.72, 69.51)],
        [Offset(12.72, 69.51), Offset(17.11, 69.19), Offset(30.69, 68.75), Offset(32.86, 58.66)],
        [Offset(32.86, 58.66), Offset(35.02, 48.56), Offset(35.21, 39.36), Offset(36.55, 29.90)],
        [Offset(36.55, 29.90), Offset(30.38, 78.92), Offset(32.28, 58.18), Offset(29.73, 97.66)],
        [Offset(29.73, 97.66), Offset(31.89, 94.00), Offset(34.46, 84.96), Offset(35.13, 83.15)],
        [Offset(35.13, 83.15), Offset(35.80, 81.33), Offset(36.34, 79.46), Offset(37.03, 78.37)],
      ]),
    ],
  ),
  'r': CursiveGlyph(
    advanceWidth: 27.07,
    strokes: [
      CursiveStroke(beziers: [  // main
        [Offset(0.88, 40.39), Offset(1.81, 35.17), Offset(1.30, 36.26), Offset(2.10, 30.00)],
        [Offset(2.10, 30.00), Offset(0.43, 43.54), Offset(-0.43, 56.19), Offset(0.03, 69.84)],
        [Offset(0.03, 69.84), Offset(0.06, 64.17), Offset(-1.13, 44.07), Offset(4.31, 38.25)],
        [Offset(4.31, 38.25), Offset(9.74, 32.44), Offset(21.55, 29.33), Offset(27.26, 32.11)],
      ]),
    ],
  ),
  's': CursiveGlyph(
    advanceWidth: 29.98,
    strokes: [
      CursiveStroke(beziers: [  // main
        [Offset(6.54, 36.56), Offset(12.08, 26.58), Offset(27.10, 29.51), Offset(29.95, 35.89)],
        [Offset(29.95, 35.89), Offset(27.26, 32.02), Offset(26.05, 30.65), Offset(20.55, 30.37)],
        [Offset(20.55, 30.37), Offset(14.81, 30.08), Offset(8.58, 30.94), Offset(6.45, 36.96)],
        [Offset(6.45, 36.96), Offset(5.67, 39.31), Offset(4.82, 42.30), Offset(6.53, 44.63)],
        [Offset(6.53, 44.63), Offset(10.68, 50.28), Offset(27.06, 47.09), Offset(29.08, 55.41)],
        [Offset(29.08, 55.41), Offset(32.96, 72.56), Offset(9.55, 71.00), Offset(0.13, 66.33)],
        [Offset(0.13, 66.33), Offset(5.71, 68.63), Offset(12.70, 69.93), Offset(19.85, 69.64)],
      ]),
    ],
  ),
  't': CursiveGlyph(
    advanceWidth: 19.50,
    strokes: [
      CursiveStroke(beziers: [  // main
        [Offset(9.03, 21.33), Offset(9.44, 17.57), Offset(11.08, 6.11), Offset(11.59, 1.54)],
        [Offset(11.59, 1.54), Offset(9.05, 16.77), Offset(3.78, 67.52), Offset(12.84, 69.75)],
        [Offset(12.84, 69.75), Offset(14.55, 69.97), Offset(14.96, 69.99), Offset(17.27, 69.85)],
      ]),
      CursiveStroke(beziers: [  // deferred
        [Offset(0.45, 30.56), Offset(6.43, 30.29), Offset(11.80, 30.21), Offset(19.38, 30.25)],
      ]),
    ],
  ),
  'u': CursiveGlyph(
    advanceWidth: 31.86,
    strokes: [
      CursiveStroke(beziers: [  // main
        [Offset(0.16, 43.41), Offset(1.06, 39.45), Offset(2.02, 34.07), Offset(2.55, 30.16)],
        [Offset(2.55, 30.16), Offset(1.54, 36.64), Offset(-0.44, 69.47), Offset(12.60, 69.62)],
        [Offset(12.60, 69.62), Offset(36.19, 69.57), Offset(30.69, 43.97), Offset(31.42, 30.23)],
        [Offset(31.42, 30.23), Offset(31.35, 44.67), Offset(30.78, 49.16), Offset(30.45, 61.31)],
        [Offset(30.45, 61.31), Offset(30.29, 67.38), Offset(31.82, 69.44), Offset(33.57, 69.46)],
        [Offset(33.57, 69.46), Offset(35.32, 69.48), Offset(33.84, 69.51), Offset(36.44, 69.29)],
      ]),
    ],
  ),
  'v': CursiveGlyph(
    advanceWidth: 30.85,
    strokes: [
      CursiveStroke(beziers: [  // main
        [Offset(-0.41, 39.43), Offset(-0.05, 36.55), Offset(0.78, 33.48), Offset(0.97, 30.11)],
        [Offset(0.97, 30.11), Offset(1.64, 34.82), Offset(11.51, 65.20), Offset(14.35, 69.55)],
        [Offset(14.35, 69.55), Offset(17.73, 65.16), Offset(29.74, 30.13), Offset(30.68, 30.18)],
        [Offset(30.68, 30.18), Offset(31.57, 30.37), Offset(31.16, 30.17), Offset(32.82, 30.76)],
      ]),
    ],
  ),
  'w': CursiveGlyph(
    advanceWidth: 55.69,
    strokes: [
      CursiveStroke(beziers: [  // main
        [Offset(-0.90, 34.91), Offset(-0.41, 32.97), Offset(-0.29, 32.46), Offset(0.60, 30.14)],
        [Offset(0.60, 30.14), Offset(3.98, 42.73), Offset(11.62, 56.96), Offset(15.00, 69.55)],
        [Offset(15.00, 69.55), Offset(20.82, 57.77), Offset(22.37, 44.35), Offset(28.18, 32.57)],
        [Offset(28.18, 32.57), Offset(30.91, 44.45), Offset(35.37, 57.51), Offset(38.10, 69.40)],
        [Offset(38.10, 69.40), Offset(44.94, 57.77), Offset(48.01, 41.90), Offset(54.86, 30.26)],
        [Offset(54.86, 30.26), Offset(55.64, 30.47), Offset(56.78, 31.22), Offset(57.97, 32.06)],
      ]),
    ],
  ),
  'x': CursiveGlyph(
    advanceWidth: 38.18,
    strokes: [
      CursiveStroke(beziers: [  // main
        [Offset(0.14, 69.82), Offset(6.52, 69.82), Offset(31.50, 36.67), Offset(37.88, 30.52)],
      ]),
      CursiveStroke(beziers: [  // main
        [Offset(0.35, 30.32), Offset(1.65, 31.91), Offset(30.26, 69.71), Offset(38.29, 69.76)],
      ]),
    ],
  ),
  'y': CursiveGlyph(
    advanceWidth: 34.08,
    strokes: [
      CursiveStroke(beziers: [  // main
        [Offset(-1.65, 45.37), Offset(-0.62, 41.02), Offset(-0.28, 35.37), Offset(0.00, 30.31)],
        [Offset(0.00, 30.31), Offset(0.14, 40.31), Offset(0.99, 69.47), Offset(13.83, 69.68)],
        [Offset(13.83, 69.68), Offset(38.02, 70.00), Offset(33.38, 40.36), Offset(33.88, 30.18)],
        [Offset(33.88, 30.18), Offset(33.70, 66.69), Offset(34.14, 87.65), Offset(23.88, 97.41)],
        [Offset(23.88, 97.41), Offset(21.53, 100.02), Offset(14.14, 104.13), Offset(7.53, 101.87)],
        [Offset(7.53, 101.87), Offset(0.92, 99.61), Offset(-7.72, 85.95), Offset(14.92, 77.18)],
      ]),
    ],
  ),
  'z': CursiveGlyph(
    advanceWidth: 33.63,
    strokes: [
      CursiveStroke(beziers: [  // main
        [Offset(1.84, 33.55), Offset(2.61, 31.65), Offset(2.74, 29.94), Offset(4.18, 29.89)],
        [Offset(4.18, 29.89), Offset(13.68, 29.97), Offset(23.18, 30.06), Offset(32.69, 30.14)],
        [Offset(32.69, 30.14), Offset(22.22, 43.14), Offset(10.58, 56.94), Offset(0.11, 69.94)],
        [Offset(0.11, 69.94), Offset(10.26, 70.11), Offset(21.27, 69.69), Offset(31.65, 69.69)],
        [Offset(31.65, 69.69), Offset(32.32, 69.69), Offset(32.98, 69.70), Offset(33.63, 69.70)],
      ]),
    ],
  ),
  'I': CursiveGlyph(
    advanceWidth: 25,
    strokes: [
      CursiveStroke(beziers: [
        [Offset(0, 65), Offset(3, 40), Offset(8, 20), Offset(12, 10)],
        [Offset(12, 10), Offset(18, 8), Offset(20, 12), Offset(15, 18)],
        [Offset(15, 18), Offset(13, 35), Offset(11, 55), Offset(8, 70)],
        [Offset(8, 70), Offset(15, 73), Offset(22, 68), Offset(25, 65)],
      ]),
    ],
  ),
  '.': CursiveGlyph(
    advanceWidth: 15,
    strokes: [
      CursiveStroke(beziers: [
        [Offset(0, 65), Offset(3, 68), Offset(5, 70), Offset(7, 70)],
        [Offset(7, 70), Offset(10, 70), Offset(12, 68), Offset(10, 65)],
        [Offset(10, 65), Offset(12, 65), Offset(13, 65), Offset(15, 65)],
      ]),
    ],
  ),
};
