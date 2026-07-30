import json
import math
import re
import shutil
import subprocess
import unittest

from tool.glyphdata import (
    APP_GLYPH_SCALE,
    APP_LINE_WIDTH,
    GLYPHS_FILE,
    REPO,
    compose_run,
    dump_glyphs,
    load_glyphs,
    load_join,
    load_pairs,
    load_sacramento_reference,
)

def _modern_node():
    """A node that understands JSON import attributes, or None."""
    node = shutil.which("node")
    if not node:
        return None
    version = subprocess.run([node, "--version"], capture_output=True, text=True)
    major = int(version.stdout.strip().lstrip("v").split(".")[0] or 0)
    return node if major >= 20 else None


class GlyphFileTest(unittest.TestCase):
    def test_saving_untouched_glyphs_leaves_the_file_unchanged(self):
        # Anything else means opening and saving the editor churns the diff.
        self.assertEqual(dump_glyphs(load_glyphs()), GLYPHS_FILE.read_text())

    def test_every_glyph_has_an_advance_width_and_strokes(self):
        for key, (advance, strokes) in load_glyphs().items():
            self.assertGreater(advance, 0, key)
            self.assertTrue(strokes, key)
            for bezier in strokes[0]:
                self.assertEqual(len(bezier), 4, key)


class JoinMatchesTheAppTest(unittest.TestCase):
    """The join editor previews pairs with this module's copy of the join, so
    it has to agree with `src/composer.js` or it shows the wrong thing."""

    # Where each letter's ink ends, in glyph units. `letterStart` points at the
    # bridge rather than the letter, so the end is the directly comparable one —
    # and because every letter is placed relative to the one before it, matching
    # ends all the way along a word covers the trim, the offset and the gap.
    SCRIPT = """
    import { composePhrase, GLYPH_SCALE } from './src/composer.js';
    // Under --eval there is no script slot in argv, so the words start at 1.
    console.log(JSON.stringify(process.argv.slice(1).map((word) => {
      const path = composePhrase(word);
      return path.letterEnd.map((i) => {
        const p = path.points[i];
        return [p.x / GLYPH_SCALE, p.y / GLYPH_SCALE];
      });
    })));
    """

    def test_editor_join_agrees_with_composer(self):
        node = _modern_node()
        if not node:
            self.skipTest("needs node 20+ on PATH")
        words = ["gentle", "many", "ease", "whole", "is", "Begin",
                 "cabbage", "balance", "accept"]   # exercise the tuned pairs
        result = subprocess.run(
            [node, "--input-type=module", "--eval", self.SCRIPT, "--", *words],
            cwd=REPO, capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        from_app = json.loads(result.stdout)

        # Hand-tuned pairs must go to both sides, or this only agrees while
        # pairs.json happens to be empty.
        glyphs, gap, pairs = load_glyphs(), load_join()["gap"], load_pairs()
        for word, ends in zip(words, from_app):
            run = compose_run(glyphs, list(word), gap, pairs)
            self.assertEqual(len(run), len(ends), word)
            for i, (item, end) in enumerate(zip(run, ends)):
                mine = item["points"][-1]
                self.assertAlmostEqual(mine[0], end[0], delta=1.0, msg=f"{word}[{i}] x")
                self.assertAlmostEqual(mine[1], end[1], delta=1.0, msg=f"{word}[{i}] y")


class SacramentoReferenceTest(unittest.TestCase):
    def test_lowercase_reference_has_visible_ink(self):
        mask, bounds = load_sacramento_reference("a")

        self.assertIsNotNone(mask.getbbox())
        left, top, right, bottom = bounds
        self.assertLess(left, right)
        self.assertLess(top, bottom)
        self.assertLess(top, 70)
        self.assertGreater(bottom, 70)

    def test_descender_extends_below_baseline(self):
        _, (_, _, _, bottom) = load_sacramento_reference("g")

        self.assertGreater(bottom, 100)

    def test_capital_can_extend_left_of_font_origin(self):
        _, (left, _, _, _) = load_sacramento_reference("A")

        self.assertLess(left, 0)


if __name__ == "__main__":
    unittest.main()


class EditorsTest(unittest.TestCase):
    """Both editors are tkinter apps, so this only covers what can be checked
    without a display: that they import, and that the join editor's work list
    and pair maths line up with the data."""

    def test_the_two_editors_import_and_stay_separate(self):
        from tool import glyph_editor, join_editor

        self.assertFalse(
            [n for n in dir(glyph_editor.GlyphEditor) if "join" in n or "pair" in n],
            "glyph editor should not know about joins or pairs",
        )
        self.assertFalse(
            [n for n in dir(join_editor.JoinEditor) if "anchor" in n or "bezier" in n],
            "join editor should not edit letterforms",
        )

    def test_pair_sequence_covers_every_tunable_combination(self):
        from tool.join_editor import pair_sequence

        sequence = pair_sequence()
        self.assertEqual(len(sequence), 52 * 26)
        self.assertEqual(len(set(sequence)), len(sequence))
        glyphs = load_glyphs()
        for pair in sequence:
            self.assertIn(pair[0], glyphs)
            self.assertIn(pair[1], glyphs)


class AppRenderingConstantsTest(unittest.TestCase):
    """The join editor's "As drawn" preview copies three numbers out of the
    app. If the app changes them, the preview quietly starts lying."""

    def _constant(self, filename, pattern):
        source = (REPO / "src" / filename).read_text()
        match = re.search(pattern, source)
        self.assertIsNotNone(match, f"{pattern} not found in {filename}")
        return float(match.group(1))

    def test_preview_matches_what_the_app_draws(self):
        self.assertEqual(
            APP_GLYPH_SCALE,
            self._constant("composer.js", r"GLYPH_SCALE\s*=\s*([\d.]+)"),
        )
        self.assertEqual(
            APP_LINE_WIDTH,
            self._constant("canvas.js", r"LINE_WIDTH\s*=\s*([\d.]+)"),
        )
