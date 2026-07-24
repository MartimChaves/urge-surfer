import unittest

from tool.glyph_editor import load_sacramento_reference


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
