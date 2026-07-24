#!/usr/bin/env python3
"""Desktop glyph editor for urge-surfer's cursive lowercase glyphs.

Loads `lib/domain/drawing/glyphs/lowercase_glyphs.dart`, lets you drag bezier
control points to refine each letter, and writes edits back to the file.

Run:
    python3 tool/glyph_editor.py

The editor itself uses tkinter from the standard library. The optional
Sacramento overlay also needs Pillow. On Debian/Ubuntu:

    sudo apt install python3-tk python3-pil

Features:
    * Letter picker + drag anchors (red) / handles (blue).
    * Optional Sacramento reference overlay, aligned to the baseline and x-height,
      with adjustable opacity.
    * Click an anchor to see its coords; click a handle to see its angle and
      length relative to its parent anchor.
    * Linked anchors (P3 of bezier i ≈ P0 of bezier i+1) move together.
    * Pan with right-click drag, zoom with the mouse wheel (anchored on cursor).
    * Move-letter toggle: drag on empty canvas to translate ALL of the current
      letter's points.
    * `+ Add`: enter add-anchor mode, then click on any curve to insert a new
      anchor at that point (De Casteljau split, curve shape preserved).
    * `- Delete` (or Delete key): with an anchor selected, merge the adjacent
      beziers (or drop the bezier if at a stroke boundary).
    * `Disconnect`: with a shared anchor selected, split the stroke at that
      anchor into two strokes.
    * Snap-on-release: drag an anchor within snap radius of another anchor and
      it snaps to that position. If both are stroke endpoints in different
      strokes, the strokes are merged into one continuous stroke (with one
      automatically reversed if needed).

Edits all three glyph data files (lowercase, uppercase, punctuation). The
picker lists every glyph; on save each glyph's edits are written back to its
original source file. File-level header comments round-trip; inline `// ...`
comments WITHIN a bezier list are dropped on save.
"""
import base64
import io
import math
import re
from pathlib import Path

# tkinter is optional at import time so this module can be loaded on a
# headless host for testing parse/serialize without a display. main() refuses
# to launch if it's not present.
try:
    import tkinter as tk
    from tkinter import messagebox, ttk
    _HAS_TK = True
except ImportError:
    tk = None  # type: ignore
    ttk = None  # type: ignore
    messagebox = None  # type: ignore
    _HAS_TK = False

try:
    from PIL import Image, ImageDraw, ImageFont
    _HAS_PIL = True
except ImportError:
    Image = None  # type: ignore
    ImageDraw = None  # type: ignore
    ImageFont = None  # type: ignore
    _HAS_PIL = False

REPO = Path(__file__).resolve().parent.parent
GLYPHS_DIR = REPO / "lib" / "domain" / "drawing" / "glyphs"
SACRAMENTO_FONT = REPO / "vendor" / "sacramento" / "Sacramento-Regular.ttf"

# Sacramento metrics: x-height 627 units in a 2048-unit em. The overlay is
# normalized onto the editor baseline (y=70) and x-height guide (y=30).
SACRAMENTO_UNITS_PER_EM = 2048
SACRAMENTO_X_HEIGHT = 627
SACRAMENTO_RENDER_SIZE = 1024

# Source files the editor manages. The header (everything from the first line
# up to and including `const Map<...> XxxGlyphs = {`) is captured from disk
# at startup and emitted verbatim on save — so file comments and the map name
# round-trip without being hardcoded in this script.
#
# Number format: "fixed2" emits every coord with two decimals (matches the
# letterpaths-generator output for lowercase); "smart" emits clean integers
# when the value is whole, two decimals otherwise (matches the hand-authored
# style used in uppercase / punctuation).
#
# Caveat: inline `// ...` comments WITHIN a glyph's bezier list are dropped
# on save (file-level comments above the map declaration ARE preserved).
SOURCES = [
    ("lowercase", GLYPHS_DIR / "lowercase_glyphs.dart", "fixed2"),
    ("uppercase", GLYPHS_DIR / "uppercase_glyphs.dart", "smart"),
    ("punctuation", GLYPHS_DIR / "punctuation_glyphs.dart", "smart"),
]

# Rendering / interaction
DEFAULT_SCALE = 8.0
DEFAULT_MARGIN_X = 80
DEFAULT_MARGIN_Y = 40
ANCHOR_R = 7
HANDLE_R = 5
SELECTED_R_BONUS = 3
HIT_R = 14
ADD_HIT_R = 20
ANCHOR_EPS = 0.5         # glyph-unit proximity for "linked" anchors
SNAP_RADIUS = 6.0        # glyph-unit snap radius for connect-on-release
ZOOM_FACTOR = 1.1
SAMPLES_PER_CURVE = 30

# Modes
MODE_SELECT = "select"
MODE_ADD_ANCHOR = "add_anchor"

REFERENCE_LINES = [
    (0, "ascender"),
    (30, "x-height"),
    (70, "baseline"),
    (100, "descender"),
]

# --- Parsing / serializing ---


def parse_glyphs_file(path):
    """Read a glyph data file. Returns (header, glyphs).

    `header` is the file's prefix verbatim: everything before the first
    `'X': CursiveGlyph(` line, including the `const Map<...> XxxGlyphs = {`
    line. Re-emitted unchanged on save so file-level comments and the map
    name (lowercaseGlyphs / uppercaseGlyphs / punctuationGlyphs) round-trip.

    `glyphs` is a dict `{key: [advance_width, strokes]}`. `strokes` is a list
    of `[phase, beziers]`; `beziers` is a list of beziers; each bezier is a
    list of 4 `[x, y]` (mutable for in-place edit). `phase` is the trailing
    `// main` / `// deferred` comment on the `CursiveStroke(beziers: [` line
    (or None if absent); preserved verbatim.
    """
    text = path.read_text()
    lines = text.split("\n")
    glyph_entry_re = re.compile(r"^  '(.+)':\s*CursiveGlyph\($")
    header_end = len(lines)
    for i, line in enumerate(lines):
        if glyph_entry_re.match(line):
            header_end = i
            break
    header = "\n".join(lines[:header_end])

    glyphs = {}
    i = header_end
    while i < len(lines):
        m = glyph_entry_re.match(lines[i])
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
    return header, glyphs


def _fmt_num(v, style):
    """Format a coordinate per the source file's style. `"fixed2"` always
    emits two decimals (matches the letterpaths generator). `"smart"` emits
    a clean integer for whole-number values, two decimals otherwise."""
    if style == "smart" and v == int(v):
        return str(int(v))
    return f"{v:.2f}"


def serialize_glyphs_file(header, glyphs, num_format="fixed2"):
    """Render a glyph data file: file header + glyph entries + closing brace."""
    out = [header]
    for key in sorted(glyphs):
        adv, strokes = glyphs[key]
        out.append(f"  '{key}': CursiveGlyph(")
        out.append(f"    advanceWidth: {_fmt_num(adv, num_format)},")
        out.append("    strokes: [")
        for phase, beziers in strokes:
            phase_tag = f"  // {phase}" if phase else ""
            out.append(f"      CursiveStroke(beziers: [{phase_tag}")
            for bez in beziers:
                pts = ", ".join(
                    f"Offset({_fmt_num(p[0], num_format)}, "
                    f"{_fmt_num(p[1], num_format)})"
                    for p in bez
                )
                out.append(f"        [{pts}],")
            out.append("      ]),")
        out.append("    ],")
        out.append("  ),")
    out.append("};")
    out.append("")
    return "\n".join(out)


# --- Bezier helpers ---


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


def split_cubic(bez, t):
    """De Casteljau split. Returns (left, right) — two new beziers whose
    union exactly reproduces the original curve. Each returned bezier is a
    list of four fresh `[x, y]` mutable lists."""
    P0, P1, P2, P3 = bez

    def lerp(a, b, u):
        return [a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u]

    Q0 = lerp(P0, P1, t)
    Q1 = lerp(P1, P2, t)
    Q2 = lerp(P2, P3, t)
    R0 = lerp(Q0, Q1, t)
    R1 = lerp(Q1, Q2, t)
    S = lerp(R0, R1, t)
    return (
        [[P0[0], P0[1]], Q0, R0, S],
        [[S[0], S[1]], R1, Q2, [P3[0], P3[1]]],
    )


def reverse_bezier_list(beziers):
    """Reverse a sequence of beziers so the curve runs backwards. Returns a
    new list with each bezier's points reversed and list order reversed."""
    return [
        [list(b[3]), list(b[2]), list(b[1]), list(b[0])]
        for b in reversed(beziers)
    ]


def load_sacramento_reference(character):
    # Return a grayscale mask and bounds in editor coordinates. Keeping this
    # transform separate from Tk makes alignment testable on headless hosts.
    if not _HAS_PIL:
        raise RuntimeError("Pillow is required for the Sacramento overlay")
    if not SACRAMENTO_FONT.exists():
        raise FileNotFoundError(SACRAMENTO_FONT)

    font = ImageFont.truetype(str(SACRAMENTO_FONT), SACRAMENTO_RENDER_SIZE)
    left, top, right, bottom = font.getbbox(character, anchor="ls")
    width = max(1, right - left)
    height = max(1, bottom - top)
    mask = Image.new("L", (width, height), 0)
    draw = ImageDraw.Draw(mask)
    draw.text((-left, -top), character, font=font, fill=255, anchor="ls")

    font_units_per_pixel = SACRAMENTO_UNITS_PER_EM / SACRAMENTO_RENDER_SIZE
    glyph_units_per_pixel = 40.0 / (
        SACRAMENTO_X_HEIGHT / font_units_per_pixel
    )
    bounds = (
        left * glyph_units_per_pixel,
        70.0 + top * glyph_units_per_pixel,
        right * glyph_units_per_pixel,
        70.0 + bottom * glyph_units_per_pixel,
    )
    return mask, bounds


# --- Editor ---


def _sort_keys_for_picker(keys):
    """Sort: lowercase a-z first, then uppercase A-Z, then everything else
    (punctuation). Within each bucket, alphabetical."""
    def order(k):
        if k.islower():
            return (0, k)
        if k.isupper():
            return (1, k)
        return (2, k)
    return sorted(keys, key=order)


class GlyphEditor:
    def __init__(self, master):
        self.master = master
        master.title("Cursive glyph editor")
        master.geometry("1100x800")

        # Load all three source files. Each glyph keeps a record of which
        # file (and format style) it came from so save writes to the right
        # place with the right number format.
        self.sources_data = {}
        self.glyphs_on_disk = {}
        self.glyphs_working = {}
        self.key_source = {}
        for name, path, fmt in SOURCES:
            header, glyphs = parse_glyphs_file(path)
            self.sources_data[name] = {
                "path": path,
                "header": header,
                "format": fmt,
            }
            for key, glyph in glyphs.items():
                self.glyphs_on_disk[key] = self._deep_copy_glyph(glyph)
                self.glyphs_working[key] = self._deep_copy_glyph(glyph)
                self.key_source[key] = name

        self.keys = _sort_keys_for_picker(self.glyphs_working.keys())
        self.current_key = self.keys[0]

        # View state
        self.pan_x = 0.0
        self.pan_y = 0.0
        self.zoom = 1.0
        self._sacramento_cache = {}
        self._overlay_photo = None

        # Interaction state
        self.mode = MODE_SELECT
        self.selected = None  # (s, b, p) or None
        self.translate_mode = False
        self.drag_state = None  # dict | None

        self._build_ui()
        self._redraw()
        self._update_status()

    @staticmethod
    def _deep_copy_glyph(glyph):
        adv, strokes = glyph
        return [
            adv,
            [
                [phase, [[p[:] for p in bez] for bez in beziers]]
                for phase, beziers in strokes
            ],
        ]

    @classmethod
    def _deep_copy(cls, glyphs):
        return {k: cls._deep_copy_glyph(v) for k, v in glyphs.items()}

    # --- UI ---

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
            toolbar, text="+ Add", command=self._enter_add_mode
        ).pack(side="left", padx=2)
        tk.Button(
            toolbar, text="- Delete", command=self._delete_selected
        ).pack(side="left", padx=2)
        tk.Button(
            toolbar, text="Disconnect", command=self._disconnect_selected
        ).pack(side="left", padx=2)

        self.translate_var = tk.BooleanVar(value=False)
        tk.Checkbutton(
            toolbar, text="Move letter",
            variable=self.translate_var,
            command=self._on_translate_toggle,
        ).pack(side="left", padx=(16, 4))

        overlay_available = _HAS_PIL and SACRAMENTO_FONT.exists()
        self.overlay_var = tk.BooleanVar(value=overlay_available)
        self.overlay_toggle = tk.Checkbutton(
            toolbar, text="Sacramento overlay",
            variable=self.overlay_var,
            command=self._redraw,
            state="normal" if overlay_available else "disabled",
        )
        self.overlay_toggle.pack(side="left", padx=(12, 2))
        self.overlay_opacity_var = tk.DoubleVar(value=28.0)
        self.overlay_opacity = ttk.Scale(
            toolbar, from_=5.0, to=80.0, length=90,
            variable=self.overlay_opacity_var,
            command=lambda _value: self._redraw(),
            state="normal" if overlay_available else "disabled",
        )
        self.overlay_opacity.pack(side="left", padx=(2, 8))

        tk.Button(
            toolbar, text="Reset view", command=self._reset_view
        ).pack(side="left", padx=(16, 2))
        tk.Button(
            toolbar, text="Reset letter", command=self._reset_current
        ).pack(side="left", padx=2)
        tk.Button(
            toolbar, text="Save to file", command=self._save
        ).pack(side="right", padx=4)

        self.status = tk.Label(self.master, text="Ready.", anchor="w")
        self.status.pack(side="bottom", fill="x", padx=8, pady=4)

        self.canvas = tk.Canvas(self.master, bg="white", cursor="arrow")
        self.canvas.pack(side="top", fill="both", expand=True)
        self.canvas.bind("<ButtonPress-1>", self._on_press_1)
        self.canvas.bind("<B1-Motion>", self._on_drag_1)
        self.canvas.bind("<ButtonRelease-1>", self._on_release_1)
        self.canvas.bind("<ButtonPress-3>", self._on_press_3)
        self.canvas.bind("<B3-Motion>", self._on_drag_3)
        self.canvas.bind("<MouseWheel>", self._on_wheel)
        self.canvas.bind("<Button-4>", self._on_wheel)   # Linux scroll up
        self.canvas.bind("<Button-5>", self._on_wheel)   # Linux scroll down

        self.master.bind("<Delete>", lambda e: self._delete_selected())
        self.master.bind("<Escape>", lambda e: self._cancel_mode())

    # --- Common actions ---

    def _on_pick(self, event):
        self.current_key = self.picker.get()
        self.selected = None
        self.drag_state = None
        self._redraw()
        self._update_status()

    def _reset_current(self):
        self.glyphs_working[self.current_key] = self._deep_copy_glyph(
            self.glyphs_on_disk[self.current_key]
        )
        self.selected = None
        self._redraw()
        self._status(f"Reset '{self.current_key}' to last-saved version.")

    def _reset_view(self):
        self.pan_x = 0.0
        self.pan_y = 0.0
        self.zoom = 1.0
        self._redraw()

    def _save(self):
        try:
            written = []
            for name, data in self.sources_data.items():
                source_glyphs = {
                    k: v for k, v in self.glyphs_working.items()
                    if self.key_source[k] == name
                }
                content = serialize_glyphs_file(
                    data["header"], source_glyphs, data["format"]
                )
                data["path"].write_text(content)
                written.append(data["path"].name)
            self.glyphs_on_disk = self._deep_copy(self.glyphs_working)
            self._status(f"Saved {len(written)} files: {', '.join(written)}.")
        except Exception as e:
            messagebox.showerror("Save failed", str(e))

    # --- Mode / status ---

    def _enter_add_mode(self):
        self.mode = MODE_ADD_ANCHOR
        self.selected = None
        self.canvas.configure(cursor="crosshair")
        self._status("Click on a curve to insert a new anchor (Esc to cancel).")
        self._redraw()

    def _cancel_mode(self):
        self.mode = MODE_SELECT
        self.canvas.configure(cursor="arrow")
        self._update_status()

    def _on_translate_toggle(self):
        self.translate_mode = self.translate_var.get()
        self._update_status()

    def _status(self, text):
        self.status.config(text=text)

    def _update_status(self):
        if self.mode == MODE_ADD_ANCHOR:
            self._status("Add mode: click a curve to insert an anchor (Esc to cancel).")
            return
        if self.translate_mode:
            self._status("Move-letter mode: drag on empty canvas to translate the whole letter.")
            return
        if self.selected is None:
            self._status(
                "Click anchor (red) for coords, handle (blue) for angle. "
                "+ Add, - Delete, Disconnect."
            )
            return
        s, b, p = self.selected
        beziers = self.glyphs_working[self.current_key][1][s][1]
        pt = beziers[b][p]
        pname = ["P0", "P1", "P2", "P3"][p]
        if p in (0, 3):
            self._status(
                f"{pname}  bezier {b + 1}, stroke {s + 1}    "
                f"({pt[0]:.2f}, {pt[1]:.2f})"
            )
        else:
            parent = beziers[b][0 if p == 1 else 3]
            dx = pt[0] - parent[0]
            dy = pt[1] - parent[1]
            angle = math.degrees(math.atan2(-dy, dx))
            length = math.hypot(dx, dy)
            self._status(
                f"{pname}  bezier {b + 1}, stroke {s + 1}    "
                f"angle {angle:+.1f}°, length {length:.2f}"
            )

    # --- Coord transforms ---

    def _eff_scale(self):
        return DEFAULT_SCALE * self.zoom

    def _to_canvas(self, gx, gy):
        s = self._eff_scale()
        return (DEFAULT_MARGIN_X + self.pan_x + gx * s,
                DEFAULT_MARGIN_Y + self.pan_y + gy * s)

    def _to_glyph(self, cx, cy):
        s = self._eff_scale()
        return ((cx - DEFAULT_MARGIN_X - self.pan_x) / s,
                (cy - DEFAULT_MARGIN_Y - self.pan_y) / s)

    # --- Pick helpers ---

    def _hit_test_control_point(self, event):
        strokes = self.glyphs_working[self.current_key][1]
        best = None
        best_dist = HIT_R
        for s_idx, (_, beziers) in enumerate(strokes):
            for b_idx, bez in enumerate(beziers):
                for p_idx, (px, py) in enumerate(bez):
                    cx, cy = self._to_canvas(px, py)
                    d = math.hypot(cx - event.x, cy - event.y)
                    if d < best_dist:
                        best_dist = d
                        best = (s_idx, b_idx, p_idx)
        return best

    def _linked_anchors(self, s, b, p):
        if p not in (0, 3):
            return [(s, b, p)]
        beziers = self.glyphs_working[self.current_key][1][s][1]
        ref = beziers[b][p]
        out = [(s, b, p)]
        for b2, bez in enumerate(beziers):
            for p2 in (0, 3):
                if (b2, p2) == (b, p):
                    continue
                if (
                    abs(bez[p2][0] - ref[0]) < ANCHOR_EPS
                    and abs(bez[p2][1] - ref[1]) < ANCHOR_EPS
                ):
                    out.append((s, b2, p2))
        return out

    def _bezier_polyline_points(self):
        strokes = self.glyphs_working[self.current_key][1]
        for s_idx, (_, beziers) in enumerate(strokes):
            for b_idx, bez in enumerate(beziers):
                for i in range(SAMPLES_PER_CURVE):
                    t = i / (SAMPLES_PER_CURVE - 1)
                    x, y = cubic_at(t, *bez)
                    yield s_idx, b_idx, t, x, y

    # --- Left-click interaction ---

    def _on_press_1(self, event):
        if self.mode == MODE_ADD_ANCHOR:
            self._do_add_anchor(event)
            return
        hit = self._hit_test_control_point(event)
        if hit is not None:
            self.selected = hit
            s, b, p = hit
            if p in (0, 3):
                self.drag_state = {
                    "type": "point",
                    "targets": self._linked_anchors(s, b, p),
                }
            else:
                self.drag_state = {"type": "point", "targets": [(s, b, p)]}
            self._update_status()
            self._redraw()
            return
        if self.translate_mode:
            self.drag_state = {"type": "translate", "last": (event.x, event.y)}
            return
        # Empty click clears selection
        self.selected = None
        self.drag_state = None
        self._update_status()
        self._redraw()

    def _on_drag_1(self, event):
        ds = self.drag_state
        if ds is None:
            return
        if ds["type"] == "point":
            gx, gy = self._to_glyph(event.x, event.y)
            strokes = self.glyphs_working[self.current_key][1]
            for s, b, p in ds["targets"]:
                strokes[s][1][b][p] = [gx, gy]
            self._update_status()
            self._redraw()
        elif ds["type"] == "translate":
            lx, ly = ds["last"]
            gx0, gy0 = self._to_glyph(lx, ly)
            gx1, gy1 = self._to_glyph(event.x, event.y)
            dx = gx1 - gx0
            dy = gy1 - gy0
            strokes = self.glyphs_working[self.current_key][1]
            for _, beziers in strokes:
                for bez in beziers:
                    for pt in bez:
                        pt[0] += dx
                        pt[1] += dy
            ds["last"] = (event.x, event.y)
            self._redraw()

    def _on_release_1(self, event):
        ds = self.drag_state
        self.drag_state = None
        if ds is None:
            return
        if ds["type"] == "point":
            self._try_snap_on_release(ds["targets"])
            self._update_status()
            self._redraw()
        elif ds["type"] == "translate":
            self._status(f"Translated '{self.current_key}'. Save to persist.")

    # --- Right-click pan ---

    def _on_press_3(self, event):
        self.drag_state = {"type": "pan", "last": (event.x, event.y)}

    def _on_drag_3(self, event):
        ds = self.drag_state
        if ds is None or ds["type"] != "pan":
            return
        lx, ly = ds["last"]
        self.pan_x += event.x - lx
        self.pan_y += event.y - ly
        ds["last"] = (event.x, event.y)
        self._redraw()

    # --- Wheel zoom (anchored on cursor) ---

    def _on_wheel(self, event):
        if hasattr(event, "delta") and event.delta:
            zoom_in = event.delta > 0
        else:
            zoom_in = event.num == 4
        factor = ZOOM_FACTOR if zoom_in else 1.0 / ZOOM_FACTOR
        gx, gy = self._to_glyph(event.x, event.y)
        self.zoom *= factor
        new_scale = self._eff_scale()
        # Keep the glyph point under the cursor at the same canvas position
        self.pan_x = event.x - DEFAULT_MARGIN_X - gx * new_scale
        self.pan_y = event.y - DEFAULT_MARGIN_Y - gy * new_scale
        self._redraw()

    # --- Editing operations ---

    def _do_add_anchor(self, event):
        best = None  # (s, b, t, dist)
        for s, b, t, x, y in self._bezier_polyline_points():
            cx, cy = self._to_canvas(x, y)
            d = math.hypot(cx - event.x, cy - event.y)
            if best is None or d < best[3]:
                best = (s, b, t, d)
        if best is None or best[3] > ADD_HIT_R:
            self._status("Click closer to a curve to add an anchor.")
            return
        s, b, t, _ = best
        beziers = self.glyphs_working[self.current_key][1][s][1]
        left, right = split_cubic(beziers[b], t)
        beziers[b:b + 1] = [left, right]
        self.selected = (s, b, 3)  # the new shared anchor
        self._cancel_mode()
        self._redraw()
        self._status(f"Inserted anchor in stroke {s + 1}.")

    def _delete_selected(self):
        if self.selected is None:
            self._status("Select an anchor (red) first, then Delete.")
            return
        s, b, p = self.selected
        if p not in (0, 3):
            self._status("Select an anchor (red), not a handle.")
            return
        strokes = self.glyphs_working[self.current_key][1]
        beziers = strokes[s][1]
        if p == 0 and b == 0:
            beziers.pop(0)
        elif p == 3 and b == len(beziers) - 1:
            beziers.pop()
        elif p == 3:
            a = beziers[b]
            c = beziers[b + 1]
            merged = [list(a[0]), list(a[1]), list(c[2]), list(c[3])]
            beziers[b:b + 2] = [merged]
        else:  # p == 0, b > 0
            a = beziers[b - 1]
            c = beziers[b]
            merged = [list(a[0]), list(a[1]), list(c[2]), list(c[3])]
            beziers[b - 1:b + 1] = [merged]
        if not beziers:
            strokes.pop(s)
        self.selected = None
        self._redraw()
        self._update_status()

    def _disconnect_selected(self):
        if self.selected is None:
            self._status("Select a shared anchor (red) first, then Disconnect.")
            return
        s, b, p = self.selected
        if p not in (0, 3):
            self._status("Select an anchor (red), not a handle.")
            return
        strokes = self.glyphs_working[self.current_key][1]
        phase, beziers = strokes[s]
        if p == 3 and b < len(beziers) - 1:
            split_after = b
        elif p == 0 and b > 0:
            split_after = b - 1
        else:
            self._status("Cannot disconnect at a stroke endpoint.")
            return
        left = beziers[:split_after + 1]
        right = beziers[split_after + 1:]
        strokes[s] = [phase, left]
        strokes.insert(s + 1, [phase, right])
        self.selected = None
        self._redraw()
        self._status("Split stroke into two.")

    def _try_snap_on_release(self, dragged_targets):
        # Only single-anchor drags can snap-connect; multi-anchor (i.e.
        # already linked) drags are skipped.
        if len(dragged_targets) > 1:
            return
        s, b, p = dragged_targets[0]
        if p not in (0, 3):
            return
        strokes = self.glyphs_working[self.current_key][1]
        pt = strokes[s][1][b][p]
        dragged_set = set(dragged_targets)
        snap = None  # (s', b', p', dist)
        for s2, (_, beziers2) in enumerate(strokes):
            for b2, bez2 in enumerate(beziers2):
                for p2 in (0, 3):
                    if (s2, b2, p2) in dragged_set:
                        continue
                    other = bez2[p2]
                    d = math.hypot(other[0] - pt[0], other[1] - pt[1])
                    if d < SNAP_RADIUS and (snap is None or d < snap[3]):
                        snap = (s2, b2, p2, d)
        if snap is None:
            return
        s2, b2, p2, _ = snap
        other = strokes[s2][1][b2][p2]
        for ts, tb, tp in dragged_targets:
            strokes[ts][1][tb][tp] = [other[0], other[1]]
        if s == s2:
            self.selected = (s2, b2, p2)
            self._status("Snapped to nearby anchor (same stroke).")
            return
        # Different strokes — merge if both ends are stroke endpoints
        bez_a = strokes[s][1]
        bez_b = strokes[s2][1]
        a_is_end = (p == 3 and b == len(bez_a) - 1)
        a_is_start = (p == 0 and b == 0)
        b_is_start = (p2 == 0 and b2 == 0)
        b_is_end = (p2 == 3 and b2 == len(bez_b) - 1)
        if not (a_is_end or a_is_start) or not (b_is_start or b_is_end):
            self.selected = (s2, b2, p2)
            self._status("Snapped to nearby anchor (different stroke, no merge).")
            return
        if a_is_start:
            bez_a = reverse_bezier_list(bez_a)
        if b_is_end:
            bez_b = reverse_bezier_list(bez_b)
        merged_phase = strokes[s][0] or strokes[s2][0]
        merged_beziers = bez_a + bez_b
        # Replace the lower-indexed stroke with the merge, remove the other.
        lo, hi = sorted([s, s2])
        new_strokes = list(strokes)
        new_strokes[lo] = [merged_phase, merged_beziers]
        new_strokes.pop(hi)
        self.glyphs_working[self.current_key][1] = new_strokes
        self.selected = None
        self._status("Snapped and merged two strokes.")

    # --- Drawing ---

    def _draw_sacramento_overlay(self):
        if not self.overlay_var.get() or not _HAS_PIL:
            self._overlay_photo = None
            return
        cached = self._sacramento_cache.get(self.current_key)
        if cached is None:
            try:
                cached = load_sacramento_reference(self.current_key)
            except (OSError, RuntimeError) as error:
                self.overlay_var.set(False)
                self._overlay_photo = None
                self._status(f"Sacramento overlay unavailable: {error}")
                return
            self._sacramento_cache[self.current_key] = cached

        mask, (left, top, right, bottom) = cached
        scale = self._eff_scale()
        width = max(1, round((right - left) * scale))
        height = max(1, round((bottom - top) * scale))
        resized_mask = mask.resize(
            (width, height), Image.Resampling.LANCZOS
        )
        opacity = max(0.0, min(1.0, self.overlay_opacity_var.get() / 100.0))
        alpha = resized_mask.point(lambda value: round(value * opacity))
        overlay = Image.new("RGBA", resized_mask.size, (126, 87, 194, 0))
        overlay.putalpha(alpha)
        png = io.BytesIO()
        overlay.save(png, format="PNG")
        encoded = base64.b64encode(png.getvalue()).decode("ascii")
        self._overlay_photo = tk.PhotoImage(data=encoded)
        x, y = self._to_canvas(left, top)
        self.canvas.create_image(
            x, y, anchor="nw", image=self._overlay_photo, tags="overlay"
        )

    def _redraw(self):
        self.canvas.delete("all")
        adv, strokes = self.glyphs_working[self.current_key]
        w = self.canvas.winfo_width() or 1100
        h = self.canvas.winfo_height() or 800

        self._draw_sacramento_overlay()

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

        for s_idx, (_, beziers) in enumerate(strokes):
            for b_idx, bez in enumerate(beziers):
                p0 = self._to_canvas(*bez[0])
                p1 = self._to_canvas(*bez[1])
                p2 = self._to_canvas(*bez[2])
                p3 = self._to_canvas(*bez[3])
                self.canvas.create_line(*p0, *p1, fill="#1e88e5", width=1)
                self.canvas.create_line(*p3, *p2, fill="#1e88e5", width=1)
                for p_idx, (cx, cy) in enumerate([p0, p1, p2, p3]):
                    is_anchor = p_idx in (0, 3)
                    r = ANCHOR_R if is_anchor else HANDLE_R
                    color = "#e53935" if is_anchor else "#1e88e5"
                    if self.selected == (s_idx, b_idx, p_idx):
                        r += SELECTED_R_BONUS
                        color = "#ff9800"
                    self.canvas.create_oval(
                        cx - r, cy - r, cx + r, cy + r,
                        fill=color, outline="black", width=1,
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
