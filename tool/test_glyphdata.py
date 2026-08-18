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
    HANDOVER_Y,
    REPO,
    _sample_stroke,
    compose_run,
    cut_index,
    dump_glyphs,
    load_glyphs,
    load_join,
    load_pairs,
    load_sacramento_reference,
    suggest_lead_out,
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
        for key, (advance, strokes, lead_out, _lift, _second) in load_glyphs().items():
            self.assertGreater(advance, 0, key)
            self.assertTrue(strokes, key)
            self.assertTrue(0 < lead_out <= 1, f"{key} leadOut {lead_out}")
            for bezier in strokes[0]:
                self.assertEqual(len(bezier), 4, key)


class LeadOutTest(unittest.TestCase):
    """`leadOut` replaced per-pair `from` tuning: one number per letter saying
    where its tail stops when something follows it."""

    def test_a_letter_only_gives_up_its_tail_when_something_follows(self):
        # You do finish the last letter of a word.
        glyphs, gap = load_glyphs(), load_join()["gap"]
        alone = compose_run(glyphs, ["a"], gap)[0]
        followed = compose_run(glyphs, ["a", "n"], gap)[0]

        self.assertEqual(alone["tail"], alone["sample_count"] - 1)
        self.assertLess(followed["tail"], alone["tail"])

    def test_the_cut_never_consumes_a_letter(self):
        # Both ends are cut against the same untrimmed stroke, so a letter
        # trimmed at the head and cut at the tail has to keep a middle.
        glyphs, gap = load_glyphs(), load_join()["gap"]
        for key in glyphs:
            run = compose_run(glyphs, ["n", key, "n"], gap)
            self.assertGreaterEqual(len(run[1]["points"]), 2, key)

    def test_letters_that_do_not_exit_at_the_handover_keep_their_tail(self):
        # Most capitals end in letterform, not in a run-up to the next letter;
        # cutting those back to the baseline takes the letter with it.
        glyphs = load_glyphs()
        for key in ("D", "T", "V", "W"):
            points = _sample_stroke(glyphs[key][1][0])
            self.assertEqual(suggest_lead_out(points), 1.0, key)

    def test_the_cut_does_not_put_surviving_ink_on_the_next_letter(self):
        # A horizontal projection is not enough to prove an overlap: capital C
        # reaches slightly past the next letter in x, but does so at a very
        # different height. When their x ranges cross, measure the actual 2-D
        # clearance between the two densely sampled centrelines instead.
        glyphs, gap = load_glyphs(), load_join()["gap"]
        stroke_width = APP_LINE_WIDTH / APP_GLYPH_SCALE
        for key in glyphs:
            run = compose_run(glyphs, [key, "n"], gap)
            if len(run) < 2:
                continue
            left, right = run[0]["points"], run[1]["points"]
            overlap = max(x for x, _ in left) - min(x for x, _ in right)
            if overlap >= 1.2:
                clearance = min(math.hypot(ax - bx, ay - by)
                                for ax, ay in left for bx, by in right)
                self.assertGreater(clearance, stroke_width,
                                   f"{key} touches the next letter")

    def test_every_lowercase_lead_out_ends_near_the_baseline(self):
        # The tail that gets cut is the rise from the baseline to the handover
        # height. `o v w` exit high enough that there is little or none. `s`
        # belongs here despite its last bezier overshooting its own end point —
        # that one sample used to stop the walk-back dead and leave it at 1.0.
        glyphs = load_glyphs()
        for key in "abcdefghijklmnpqrstuxyz":
            points = _sample_stroke(glyphs[key][1][0])
            cut = points[cut_index(points, glyphs[key][2])]
            self.assertGreater(cut[1], 55, f"{key} cuts at y={cut[1]:.1f}")


class LiftAfterTest(unittest.TestCase):
    """`liftAfter` marks the capitals that hand over to nothing: the letter
    after them is drawn whole, as a stroke of its own."""

    def test_a_lifted_letter_neither_cuts_nor_is_cut(self):
        glyphs, gap = load_glyphs(), load_join()["gap"]
        for key in [k for k, glyph in glyphs.items() if glyph[3]]:
            run = compose_run(glyphs, [key, "a"], gap)
            self.assertEqual(run[0]["tail"], run[0]["sample_count"] - 1, key)
            self.assertEqual(run[1]["head"], 0, key)
            self.assertEqual(run[1]["bridge"], [], key)
            self.assertIsNone(run[1]["join"], key)

    def test_the_next_letter_clears_the_ink_rather_than_the_exit(self):
        # F exits at x = -25.8 having already reached x = 40, so placing the
        # next letter against the exit point drops it inside the F.
        glyphs, gap = load_glyphs(), load_join()["gap"]
        for key in [k for k, glyph in glyphs.items() if glyph[3]]:
            run = compose_run(glyphs, [key, "a"], gap)
            self.assertGreater(min(x for x, _ in run[1]["points"]),
                               max(x for x, _ in run[0]["points"]), key)

    def test_tuning_is_ignored_for_a_pair_that_does_not_connect(self):
        glyphs, gap = load_glyphs(), load_join()["gap"]
        key = next(k for k, glyph in glyphs.items() if glyph[3])
        invented = {"from": 0.5, "to": 0.5, "dx": 40, "h1": [9, 9], "h2": [9, 9]}
        plain = compose_run(glyphs, [key, "a"], gap)
        tuned = compose_run(glyphs, [key, "a"], gap, {key + "a": invented})
        self.assertEqual(plain[1]["points"], tuned[1]["points"])


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
                 "cabbage", "balance", "accept",   # exercise the tuned pairs
                 "Dan", "Fun", "Pause"]            # and the letters that lift
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

    def test_capitals_are_matched_on_cap_height_not_x_height(self):
        # Sacramento's cap/x ratio is 2.47 against 1.4 for a text face, so on
        # x-height a capital lands 99 units up — 39 past the ascender guide —
        # and has to be shrunk by eye. On cap height it lands on the guide.
        for key in "ABEFMST":
            _, (_, top, _, _) = load_sacramento_reference(key)
            self.assertAlmostEqual(top, 0, delta=6, msg=f"{key} top {top:.1f}")


if __name__ == "__main__":
    unittest.main()


class EditorsTest(unittest.TestCase):
    """Both editors are tkinter apps, so this only covers what can be checked
    without a display: that they import, and that the join editor's work list
    and pair maths line up with the data."""

    def test_the_two_editors_import_and_stay_separate(self):
        # A name check, so a letterform property that affects joining has to be
        # named for the letter rather than for the connection: which stroke
        # hands over is the glyph editor's business, the same way `leadOut` is.
        from tool import glyph_editor, join_editor

        self.assertFalse(
            [n for n in dir(glyph_editor.GlyphEditor) if "join" in n or "pair" in n],
            "glyph editor should not know about joins or pairs",
        )
        self.assertFalse(
            [n for n in dir(join_editor.JoinEditor) if "anchor" in n or "bezier" in n],
            "join editor should not edit letterforms",
        )

    def test_no_editor_method_reads_a_name_that_does_not_exist(self):
        """Both editors are tkinter apps, so a method nobody can call headlessly
        can sit broken indefinitely: `_bezier_polyline_points` used
        `SAMPLES_PER_CURVE` and `cubic_at` without importing either, and add-
        anchor raised `NameError` on the first click for as long as that lasted.
        Importing the module does not catch it — the name is only resolved when
        the line runs — so check the bytecode instead."""
        import builtins
        import dis
        import types

        from tool import glyph_editor, join_editor

        def defined_here(obj, path):
            if isinstance(obj, (staticmethod, classmethod)):
                obj = obj.__func__
            if isinstance(obj, types.FunctionType) and obj.__code__.co_filename == path:
                yield obj.__qualname__, obj.__code__
            elif isinstance(obj, type):
                for value in vars(obj).values():
                    yield from defined_here(value, path)

        for module in (glyph_editor, join_editor):
            known = set(vars(module)) | set(dir(builtins))
            for value in vars(module).values():
                for qualname, code in defined_here(value, module.__file__):
                    for instruction in dis.get_instructions(code):
                        if instruction.opname != "LOAD_GLOBAL":
                            continue
                        # assertIn would dump the whole namespace on failure.
                        self.assertTrue(
                            instruction.argval in known,
                            f"{module.__name__}.{qualname} reads undefined "
                            f"'{instruction.argval}'",
                        )

    def test_pair_sequence_covers_every_tunable_combination(self):
        from tool.join_editor import pair_sequence

        glyphs = load_glyphs()
        # A letter that lifts the pen after itself opens no join to tune.
        lifts = sum(1 for glyph in glyphs.values() if glyph[3])
        sequence = pair_sequence()
        self.assertEqual(len(sequence), (52 - lifts) * 26)
        self.assertEqual(len(set(sequence)), len(sequence))
        self.assertFalse([p for p in sequence if glyphs[p[0]][3]])
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
        self.assertEqual(
            HANDOVER_Y,
            self._constant("composer.js", r"HANDOVER_Y\s*=\s*([\d.]+)"),
        )
