// Public aggregator for the cursive glyph map. Combines the generated
// lowercase set with hand-authored uppercase and punctuation. Callers should
// import this file to access [cursiveGlyphs] and the [CursiveGlyph] /
// [CursiveStroke] types.

import 'cursive_glyph_types.dart';
import 'lowercase_glyphs.dart';
import 'punctuation_glyphs.dart';
import 'uppercase_glyphs.dart';

export 'cursive_glyph_types.dart';

final Map<String, CursiveGlyph> cursiveGlyphs = {
  ...lowercaseGlyphs,
  ...uppercaseGlyphs,
  ...punctuationGlyphs,
};
