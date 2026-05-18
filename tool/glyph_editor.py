#!/usr/bin/env python3
"""Desktop glyph editor for urge-surfer's cursive lowercase glyphs.

Loads `lib/domain/drawing/glyphs/lowercase_glyphs.dart`, lets you drag bezier
control points to refine each letter, and writes edits back to the file.

Run:
    python3 tool/glyph_editor.py

No third-party deps — uses tkinter from the standard library. On Debian/Ubuntu
that needs `sudo apt install python3-tk` if not already installed.

Workflow:
    1. Pick a letter from the dropdown.
    2. Drag anchor points (red) or handles (blue) to reshape the bezier.
       Anchors at the same coord (typical: P3 of bezier i = P0 of bezier i+1)
       move together so the path stays continuous.
    3. Click Save to overwrite lowercase_glyphs.dart with your edits.
    4. Hot-reload the Flutter app to see the change in the ritual.

Only the lowercase a-z map is editable from this tool. Uppercase and
punctuation files are smaller and can be hand-edited in your text editor.
"""
import re
from pathlib import Path

# tkinter is optional at import time so this module can be loaded on a
# headless host for testing parse/serialize without a display. main() will
# refuse to launch if it's not present.
try:
    import tkinter as tk
    from tkinter import messagebox, ttk
    _HAS_TK = True
except ImportError:
    tk = None  # type: ignore
    ttk = None  # type: ignore
    messagebox = None  # type: ignore
    _HAS_TK = False

REPO = Path(__file__).resolve().parent.parent
LOWERCASE_FILE = REPO / "lib" / "domain" / "drawing" / "glyphs" / "lowercase_glyphs.dart"

# Rendering
SCALE = 8.0       # canvas pixels per glyph unit
MARGIN_X = 80
MARGIN_Y = 40
ANCHOR_R = 7
HANDLE_R = 5
HIT_R = 14
ANCHOR_EPS = 0.5  # glyph-unit proximity for "linked" anchors
SAMPLES_PER_CURVE = 30

REFERENCE_LINES = [
    (0, "ascender"),
    (30, "x-height"),
    (70, "baseline"),
    (100, "descender"),
]

FILE_HEADER = (
    "// GENERATED FILE — initial seed from letterpaths. Hand-editable.\n"
    "// Regenerate via: python3 tool/letterpaths_to_dart.py\n"
    "//   (Re-running OVERWRITES this file. Back up tweaks if you've hand-tuned.)\n"
    "//\n"
    "// Lowercase a-z glyphs are initially derived from the letterpaths cursive\n"
    "// dataset (MIT-licensed, github.com/RobinL/letterpaths). License preserved\n"
    "// in vendor/letterpaths/LICENSE.\n"
    "//\n"
    "// Coord system (same as uppercase / punctuation):\n"
    "//   x in 0..advanceWidth (left to right)\n"
    "//   y: baseline = 70, x-height top = 30, y grows downward\n"
    "//   ascender region (y < 30) and descender region (y > 70) are open-ended\n"
    "\n"
    "import 'dart:ui' show Offset;\n"
    "\n"
    "import 'cursive_glyph_types.dart';\n"
    "\n"
    "const Map<String, CursiveGlyph> lowercaseGlyphs = {"
)


def parse_glyphs(path):
    """Read lowercase_glyphs.dart, return {key: [advance_width, strokes]}.

    `strokes` is a list of `[phase, beziers]` pairs; `beziers` is a list of
    beziers; each bezier is a list of 4 `[x, y]` (mutable for in-place edit).
    `phase` is the trailing comment on the `CursiveStroke(beziers: [` line
    (typically "main" or "deferred"); preserved verbatim on save.
    """
    text = path.read_text()
    glyphs = {}
    lines = text.split("\n")
    i = 0
    while i < len(lines):
        m = re.match(r"^  '(.+)':\s*CursiveGlyph\($", lines[i])
        if not m:
            i += 1
            continue
        key = m.group(1)
        i += 1
        m2 = re.match(r"^    advanceWidth:\s*([-\d.]+),", lines[i])
        adv = float(m2.group(1))
        i += 1  # 'strokes: ['
        i += 1
        strokes = []
        while not re.match(r"^    \],", lines[i]):
            sm = re.match(
                r"^      CursiveStroke\(beziers:\s*\[(.*)$", lines[i]
            )
            if sm:
                # Capture trailing phase comment if present, e.g. "  // main"
                tail = sm.group(1).strip()
                phase_match = re.match(r"//\s*(.*)$", tail)
                phase = phase_match.group(1).strip() if phase_match else None
                i += 1
                beziers = []
                while not re.match(r"^      \]\),", lines[i]):
                    nums = re.findall(
                        r"Offset\(([-\d.]+),\s*([-\d.]+)\)", lines[i]
                    )
                    if len(nums) == 4:
                        beziers.append([[float(x), float(y)] for x, y in nums])
                    i += 1
                strokes.append([phase, beziers])
                i += 1  # past ']),'
            else:
                i += 1
        i += 1  # past '],'
        i += 1  # past '),'
        glyphs[key] = [adv, strokes]
    return glyphs


def serialize_glyphs(glyphs):
    out = [FILE_HEADER]
    for key in sorted(glyphs):
        adv, strokes = glyphs[key]
        out.append(f"  '{key}': CursiveGlyph(")
        out.append(f"    advanceWidth: {adv:.2f},")
        out.append("    strokes: [")
        for phase, beziers in strokes:
            phase_tag = f"  // {phase}" if phase else ""
            out.append(f"      CursiveStroke(beziers: [{phase_tag}")
            for bez in beziers:
                pts = ", ".join(f"Offset({p[0]:.2f}, {p[1]:.2f})" for p in bez)
                out.append(f"        [{pts}],")
            out.append("      ]),")
        out.append("    ],")
        out.append("  ),")
    out.append("};")
    out.append("")  # trailing newline
    return "\n".join(out)


def cubic_at(t, p0, p1, p2, p3):
    u = 1 - t
    return (
        u * u * u * p0[0] + 3 * u * u * t * p1[0]
        + 3 * u * t * t * p2[0] + t * t * t * p3[0],
        u * u * u * p0[1] + 3 * u * u * t * p1[1]
        + 3 * u * t * t * p2[1] + t * t * t * p3[1],
    )


def sample_cubic(p0, p1, p2, p3, n=SAMPLES_PER_CURVE):
    return [cubic_at(i / (n - 1), p0, p1, p2, p3) for i in range(n)]


class GlyphEditor:
    def __init__(self, master):
        self.master = master
        master.title("Cursive glyph editor")
        master.geometry("960x720")

        self.glyphs_on_disk = parse_glyphs(LOWERCASE_FILE)
        self.glyphs_working = self._deep_copy(self.glyphs_on_disk)
        self.keys = sorted(self.glyphs_working.keys())
        self.current_key = self.keys[0]
        self.drag_targets = []

        self._build_ui()
        self._redraw()

    @staticmethod
    def _deep_copy(glyphs):
        return {
            k: [
                v[0],
                [
                    [phase, [[p[:] for p in bez] for bez in beziers]]
                    for phase, beziers in v[1]
                ],
            ]
            for k, v in glyphs.items()
        }

    def _build_ui(self):
        toolbar = tk.Frame(self.master)
        toolbar.pack(side="top", fill="x", padx=8, pady=8)
        tk.Label(toolbar, text="Letter:").pack(side="left")
        self.picker = ttk.Combobox(
            toolbar, values=self.keys, state="readonly", width=4
        )
        self.picker.set(self.current_key)
        self.picker.bind("<<ComboboxSelected>>", self._on_pick)
        self.picker.pack(side="left", padx=(4, 16))
        tk.Button(
            toolbar, text="Reset letter", command=self._reset_current
        ).pack(side="left", padx=4)
        tk.Button(
            toolbar, text="Save to file", command=self._save
        ).pack(side="right", padx=4)
        self.status = tk.Label(self.master, text="Ready.", anchor="w")
        self.status.pack(side="bottom", fill="x", padx=8, pady=4)
        self.canvas = tk.Canvas(self.master, bg="white")
        self.canvas.pack(side="top", fill="both", expand=True)
        self.canvas.bind("<ButtonPress-1>", self._on_press)
        self.canvas.bind("<B1-Motion>", self._on_drag)
        self.canvas.bind("<ButtonRelease-1>", self._on_release)

    def _on_pick(self, event):
        self.current_key = self.picker.get()
        self.drag_targets = []
        self._redraw()

    def _reset_current(self):
        adv, strokes = self.glyphs_on_disk[self.current_key]
        self.glyphs_working[self.current_key] = [
            adv,
            [
                [phase, [[p[:] for p in bez] for bez in beziers]]
                for phase, beziers in strokes
            ],
        ]
        self._redraw()
        self._status(f"Reset '{self.current_key}' to last-saved version.")

    def _save(self):
        try:
            content = serialize_glyphs(self.glyphs_working)
            LOWERCASE_FILE.write_text(content)
            self.glyphs_on_disk = self._deep_copy(self.glyphs_working)
            self._status(f"Saved {LOWERCASE_FILE.name}.")
        except Exception as e:
            messagebox.showerror("Save failed", str(e))

    def _status(self, text):
        self.status.config(text=text)

    def _to_canvas(self, gx, gy):
        return (MARGIN_X + gx * SCALE, MARGIN_Y + gy * SCALE)

    def _to_glyph(self, cx, cy):
        return ((cx - MARGIN_X) / SCALE, (cy - MARGIN_Y) / SCALE)

    def _on_press(self, event):
        strokes = self.glyphs_working[self.current_key][1]
        best = None
        best_dist = HIT_R
        for s_idx, (_, beziers) in enumerate(strokes):
            for b_idx, bez in enumerate(beziers):
                for p_idx, (px, py) in enumerate(bez):
                    cx, cy = self._to_canvas(px, py)
                    d = ((cx - event.x) ** 2 + (cy - event.y) ** 2) ** 0.5
                    if d < best_dist:
                        best_dist = d
                        best = (s_idx, b_idx, p_idx)
        if best is None:
            self.drag_targets = []
            return
        s, b, p = best
        targets = [(s, b, p)]
        if p in (0, 3):
            ref = strokes[s][1][b][p]
            for b2, bez in enumerate(strokes[s][1]):
                for p2 in (0, 3):
                    if (b2, p2) == (b, p):
                        continue
                    if (
                        abs(bez[p2][0] - ref[0]) < ANCHOR_EPS
                        and abs(bez[p2][1] - ref[1]) < ANCHOR_EPS
                    ):
                        targets.append((s, b2, p2))
        self.drag_targets = targets

    def _on_drag(self, event):
        if not self.drag_targets:
            return
        gx, gy = self._to_glyph(event.x, event.y)
        strokes = self.glyphs_working[self.current_key][1]
        for s, b, p in self.drag_targets:
            strokes[s][1][b][p] = [gx, gy]
        self._redraw()

    def _on_release(self, event):
        if self.drag_targets:
            self.drag_targets = []
            self._status(
                f"Edited '{self.current_key}'. Click Save to write to "
                f"{LOWERCASE_FILE.name}."
            )

    def _redraw(self):
        self.canvas.delete("all")
        adv, strokes = self.glyphs_working[self.current_key]
        w = self.canvas.winfo_width() or 960
        h = self.canvas.winfo_height() or 720
        for y, label in REFERENCE_LINES:
            _, cy = self._to_canvas(0, y)
            self.canvas.create_line(0, cy, w, cy, fill="#e0e0e0")
            self.canvas.create_text(
                8, cy, anchor="w", text=label,
                fill="#a0a0a0", font=("TkDefaultFont", 9),
            )
        for gx in (0, adv):
            cx, _ = self._to_canvas(gx, 0)
            self.canvas.create_line(cx, 0, cx, h, fill="#e0e0e0")
        # Strokes
        for s_idx, (_, beziers) in enumerate(strokes):
            polyline = []
            if beziers:
                first_p0 = beziers[0][0]
                polyline.append(self._to_canvas(first_p0[0], first_p0[1]))
                for bez in beziers:
                    samples = sample_cubic(*bez)
                    for pt in samples[1:]:
                        polyline.append(self._to_canvas(pt[0], pt[1]))
            if len(polyline) >= 2:
                flat = [c for pt in polyline for c in pt]
                self.canvas.create_line(
                    *flat, fill="#5e35b1", width=3,
                    capstyle="round", joinstyle="round",
                )
            if beziers:
                cx, cy = self._to_canvas(*beziers[0][0])
                self.canvas.create_oval(
                    cx - 5, cy - 5, cx + 5, cy + 5,
                    fill="#7e57c2", outline="",
                )
                self.canvas.create_text(
                    cx + 10, cy - 8, text=f"{s_idx + 1}",
                    fill="#5e35b1", font=("TkDefaultFont", 10),
                )
        # Control points
        for _, beziers in strokes:
            for bez in beziers:
                p0 = self._to_canvas(*bez[0])
                p1 = self._to_canvas(*bez[1])
                p2 = self._to_canvas(*bez[2])
                p3 = self._to_canvas(*bez[3])
                self.canvas.create_line(*p0, *p1, fill="#1e88e5", width=1)
                self.canvas.create_line(*p3, *p2, fill="#1e88e5", width=1)
                self.canvas.create_oval(
                    p1[0] - HANDLE_R, p1[1] - HANDLE_R,
                    p1[0] + HANDLE_R, p1[1] + HANDLE_R,
                    fill="#1e88e5", outline="",
                )
                self.canvas.create_oval(
                    p2[0] - HANDLE_R, p2[1] - HANDLE_R,
                    p2[0] + HANDLE_R, p2[1] + HANDLE_R,
                    fill="#1e88e5", outline="",
                )
                self.canvas.create_oval(
                    p0[0] - ANCHOR_R, p0[1] - ANCHOR_R,
                    p0[0] + ANCHOR_R, p0[1] + ANCHOR_R,
                    fill="#e53935", outline="",
                )
                self.canvas.create_oval(
                    p3[0] - ANCHOR_R, p3[1] - ANCHOR_R,
                    p3[0] + ANCHOR_R, p3[1] + ANCHOR_R,
                    fill="#e53935", outline="",
                )


def main():
    if not _HAS_TK:
        raise SystemExit(
            "tkinter is not available. On Debian/Ubuntu install it with:\n"
            "  sudo apt install python3-tk"
        )
    root = tk.Tk()
    GlyphEditor(root)
    root.mainloop()


if __name__ == "__main__":
    main()
