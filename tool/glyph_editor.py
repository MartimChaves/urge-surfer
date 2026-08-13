#!/usr/bin/env python3
"""Desktop editor for the cursive letterforms in `src/glyphs.json`.

Run:
    python3 tool/glyph_editor.py

One letter at a time. To edit how two letters connect, use the separate
`python3 tool/join_editor.py`.

Needs tkinter from the standard library; the optional Sacramento overlay also
needs Pillow. On Debian/Ubuntu:

    sudo apt install python3-tk python3-pil

    * Letter picker + drag anchors (red) / handles (blue).
    * Optional Sacramento reference overlay, aligned to the baseline and x-height,
      with adjustable opacity.
    * Click an anchor to see its coords; click a handle to see its angle and
      length relative to its parent anchor.
    * Linked anchors (P3 of bezier i is at P0 of bezier i+1) move together.
    * Pan with right-click drag, zoom with the mouse wheel (anchored on cursor).
    * Move-letter toggle: drag on empty canvas to translate ALL of the current
      letter's points.
    * `+ Add`: enter add-anchor mode, then click on any curve to insert a new
      anchor at that point (De Casteljau split, curve shape preserved).
    * `- Delete` (or Delete key): with an anchor selected, merge the adjacent
      beziers (or drop the bezier if at a stroke boundary).
    * `Disconnect`: with a shared anchor selected, split the stroke at that
      anchor into two strokes.
    * `+ Stroke`: append a new stroke. Stroke 1 is the one that joins to its
      neighbours; every stroke after it is a second pass — a pen lift the user
      taps to begin, like a t crossbar or an i dot.
    * `Make main`: promote the selected stroke to stroke 1. Needed when a glyph
      was drawn with its crossbar first, as capital T was.
    * Snap-on-release: drag an anchor within snap radius of another anchor and
      it snaps to that position. If both are stroke endpoints in different
      strokes, the strokes are merged into one continuous stroke (with one
      automatically reversed if needed).

Save writes the whole file back, one bezier per line so edits stay readable in
a diff.
"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from tool.glyphdata import (  # noqa: E402
    ANCHOR_EPS, DEFAULT_MARGIN_X, DEFAULT_MARGIN_Y, DEFAULT_SCALE, GLYPHS_FILE,
    HIT_R, REFERENCE_LINES, SACRAMENTO_FONT, SAMPLES_PER_CURVE, SNAP_RADIUS,
    ZOOM_FACTOR, _sample_stroke, cubic_at, cut_index, dump_glyphs, join_stroke,
    load_glyphs, load_sacramento_reference, reverse_bezier_list, sample_cubic,
    split_cubic,
)

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
    from PIL import Image
    _HAS_PIL = True
except ImportError:
    Image = None  # type: ignore
    _HAS_PIL = False

import base64
import io

# Rendering / interaction
ANCHOR_R = 7
HANDLE_R = 5
CUT_R = 9
SELECTED_R_BONUS = 3
ADD_HIT_R = 20

MODE_SELECT = "select"
MODE_ADD_ANCHOR = "add_anchor"


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
        master.geometry("1320x800")

        glyphs = load_glyphs()
        self.glyphs_on_disk = self._deep_copy(glyphs)
        self.glyphs_working = self._deep_copy(glyphs)

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
        self._sync_flags()
        self._redraw()
        self._update_status()

    @staticmethod
    def _deep_copy_glyph(glyph):
        adv, strokes, lead_out, lift_after = glyph
        return [adv, [[[p[:] for p in bez] for bez in beziers] for beziers in strokes],
                lead_out, lift_after]

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
        self.picker.pack(side="left", padx=(4, 12))

        tk.Button(
            toolbar, text="+ Add", command=self._enter_add_mode
        ).pack(side="left", padx=2)
        tk.Button(
            toolbar, text="- Delete", command=self._delete_selected
        ).pack(side="left", padx=2)
        tk.Button(
            toolbar, text="Disconnect", command=self._disconnect_selected
        ).pack(side="left", padx=2)
        tk.Button(
            toolbar, text="+ Stroke", command=self._add_stroke
        ).pack(side="left", padx=(12, 2))
        tk.Button(
            toolbar, text="Make main", command=self._make_main_stroke
        ).pack(side="left", padx=2)

        self.lift_after_var = tk.BooleanVar(value=False)
        tk.Checkbutton(
            toolbar, text="Lift after",
            variable=self.lift_after_var,
            command=self._on_lift_after_toggle,
        ).pack(side="left", padx=(12, 2))
        self.handover_stroke_var = tk.BooleanVar(value=False)
        tk.Checkbutton(
            toolbar, text="Hand over from stroke 2",
            variable=self.handover_stroke_var,
            command=self._on_handover_stroke_toggle,
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
        self._sync_flags()
        self._redraw()
        self._update_status()

    def _sync_flags(self):
        """Point the two handover checkboxes at the letter now being edited."""
        glyph = self.glyphs_working[self.current_key]
        self.lift_after_var.set(bool(glyph[3]))
        self.handover_stroke_var.set(bool(glyph[4]))

    def _on_lift_after_toggle(self):
        glyph = self.glyphs_working[self.current_key]
        glyph[3] = self.lift_after_var.get()
        self._redraw()
        self._status(
            f"'{self.current_key}' lifts the pen after itself: the next letter is "
            f"drawn whole, as a stroke of its own."
            if glyph[3] else
            f"'{self.current_key}' joins to the next letter again."
        )

    def _on_handover_stroke_toggle(self):
        """Which stroke carries on into the next letter. Capital K is one case:
        the spine is drawn first, and it is the arms that carry on."""
        glyph = self.glyphs_working[self.current_key]
        if self.handover_stroke_var.get() and len(glyph[1]) < 2:
            self.handover_stroke_var.set(False)
            self._status(f"'{self.current_key}' only has one stroke to hand over from.")
            return
        glyph[4] = self.handover_stroke_var.get()
        self._redraw()
        self._status(
            f"'{self.current_key}' hands over from stroke 2; stroke 1 is drawn "
            f"first and lifted from."
            if glyph[4] else
            f"'{self.current_key}' hands over from stroke 1 again."
        )

    def _add_stroke(self):
        """Append a new stroke. Anything after the first is a second pass —
        the user lifts the pen and taps to start it, like a t crossbar."""
        strokes = self.glyphs_working[self.current_key][1]
        strokes.append([[[0.0, 30.0], [8.0, 30.0], [16.0, 30.0], [24.0, 30.0]]])
        self.selected = (len(strokes) - 1, 0, 0)
        self._redraw()
        self._status(
            f"Added stroke {len(strokes)} as a second pass. Drag it into place; "
            f"use Make main if it should be the joinable stroke instead."
        )

    def _make_main_stroke(self):
        """Move the selected stroke to the front. Stroke 1 is the one that
        joins to its neighbours; every other stroke is a second pass."""
        if self.selected is None:
            self._status("Select a point on the stroke you want as the main one.")
            return
        s, b, p = self.selected
        strokes = self.glyphs_working[self.current_key][1]
        if s == 0:
            self._status("That is already the main stroke.")
            return
        strokes.insert(0, strokes.pop(s))
        self.selected = (0, b, p)
        self._redraw()
        self._status(f"Stroke {s + 1} is now the main stroke.")

    # --- Tuning the join between two letters ---

    def _reset_current(self):
        self.glyphs_working[self.current_key] = self._deep_copy_glyph(
            self.glyphs_on_disk[self.current_key]
        )
        self.selected = None
        self._sync_flags()
        self._redraw()
        self._status(f"Reset '{self.current_key}' to last-saved version.")

    def _reset_view(self):
        self.pan_x = 0.0
        self.pan_y = 0.0
        self.zoom = 1.0
        self._redraw()

    def _save(self):
        try:
            GLYPHS_FILE.write_text(dump_glyphs(self.glyphs_working))
            self.glyphs_on_disk = self._deep_copy(self.glyphs_working)
            self._status(
                f"Saved {len(self.glyphs_working)} glyphs to {GLYPHS_FILE.name}."
            )
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
        if self.drag_state and self.drag_state.get("type") == "lead_out":
            lead_out = self.glyphs_working[self.current_key][2]
            points = self._lead_out_points()
            x, y = points[cut_index(points, lead_out)]
            self._status(
                f"Lead-out {lead_out:.4f} at ({x:.2f}, {y:.2f}) — "
                f"grey is drawn by the run-up to the next letter, not by this one."
            )
            return
        if self.selected is None:
            self._status(
                "Click anchor (red) for coords, handle (blue) for angle, "
                "orange for the lead-out. + Add, - Delete, Disconnect."
            )
            return
        s, b, p = self.selected
        all_strokes = self.glyphs_working[self.current_key][1]
        beziers = all_strokes[s]
        pt = beziers[b][p]
        pname = ["P0", "P1", "P2", "P3"][p]
        joining = join_stroke(self.glyphs_working[self.current_key])
        pass_note = ("joins" if s == joining
                     else "drawn first" if s < joining else "2nd pass")
        if p in (0, 3):
            self._status(
                f"{pname}  bezier {b + 1}, stroke {s + 1}/{len(all_strokes)} "
                f"({pass_note})    ({pt[0]:.2f}, {pt[1]:.2f})"
            )
        else:
            parent = beziers[b][0 if p == 1 else 3]
            dx = pt[0] - parent[0]
            dy = pt[1] - parent[1]
            angle = math.degrees(math.atan2(-dy, dx))
            length = math.hypot(dx, dy)
            self._status(
                f"{pname}  bezier {b + 1}, stroke {s + 1}/{len(all_strokes)} "
                f"({pass_note})    angle {angle:+.1f}°, length {length:.2f}"
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
        for s_idx, beziers in enumerate(strokes):
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
        beziers = self.glyphs_working[self.current_key][1][s]
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
        for s_idx, beziers in enumerate(strokes):
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
        if self._hit_test_lead_out(event):
            self.selected = None
            self.drag_state = {"type": "lead_out"}
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
                strokes[s][b][p] = [gx, gy]
            self._update_status()
            self._redraw()
        elif ds["type"] == "translate":
            lx, ly = ds["last"]
            gx0, gy0 = self._to_glyph(lx, ly)
            gx1, gy1 = self._to_glyph(event.x, event.y)
            dx = gx1 - gx0
            dy = gy1 - gy0
            strokes = self.glyphs_working[self.current_key][1]
            for beziers in strokes:
                for bez in beziers:
                    for pt in bez:
                        pt[0] += dx
                        pt[1] += dy
            ds["last"] = (event.x, event.y)
            self._redraw()
        elif ds["type"] == "lead_out":
            self._drag_lead_out(event)
            self._update_status()
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
        elif ds["type"] == "lead_out":
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
        beziers = self.glyphs_working[self.current_key][1][s]
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
        beziers = strokes[s]
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
        beziers = strokes[s]
        if p == 3 and b < len(beziers) - 1:
            split_after = b
        elif p == 0 and b > 0:
            split_after = b - 1
        else:
            self._status("Cannot disconnect at a stroke endpoint.")
            return
        left = beziers[:split_after + 1]
        right = beziers[split_after + 1:]
        strokes[s] = left
        strokes.insert(s + 1, right)
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
        pt = strokes[s][b][p]
        dragged_set = set(dragged_targets)
        snap = None  # (s', b', p', dist)
        for s2, beziers2 in enumerate(strokes):
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
        other = strokes[s2][b2][p2]
        for ts, tb, tp in dragged_targets:
            strokes[ts][tb][tp] = [other[0], other[1]]
        if s == s2:
            self.selected = (s2, b2, p2)
            self._status("Snapped to nearby anchor (same stroke).")
            return
        # Different strokes — merge if both ends are stroke endpoints
        bez_a = strokes[s]
        bez_b = strokes[s2]
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
        merged_beziers = bez_a + bez_b
        # Replace the lower-indexed stroke with the merge, remove the other.
        lo, hi = sorted([s, s2])
        new_strokes = list(strokes)
        new_strokes[lo] = merged_beziers
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

    def _polyline(self, points, **options):
        if len(points) < 2:
            return
        flat = [c for pt in points for c in self._to_canvas(pt[0], pt[1])]
        self.canvas.create_line(*flat, capstyle="round", joinstyle="round", **options)

    def _stroke_points(self, beziers, offset=0.0):
        points = []
        for bez in beziers:
            samples = sample_cubic(*bez)
            points.extend(samples if not points else samples[1:])
        return [(x + offset, y) for x, y in points]

    def _redraw(self):
        self.canvas.delete("all")
        adv, strokes, _lead_out, _lift_after = self.glyphs_working[self.current_key]
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

        for s_idx, beziers in enumerate(strokes):
            self._polyline(
                self._stroke_points(beziers),
                fill="#5e35b1" if s_idx == 0 else "#c2185b", width=3,
            )
            if beziers:
                cx, cy = self._to_canvas(*beziers[0][0])
                self.canvas.create_oval(
                    cx - 5, cy - 5, cx + 5, cy + 5,
                    fill="#7e57c2" if s_idx == 0 else "#c2185b", outline="",
                )
                self.canvas.create_text(
                    cx + 10, cy - 8,
                    text=f"{s_idx + 1}" if s_idx == 0 else f"{s_idx + 1} (2nd pass)",
                    fill="#5e35b1" if s_idx == 0 else "#c2185b",
                    font=("TkDefaultFont", 10),
                )

        self._draw_lead_out()

        for s_idx, beziers in enumerate(strokes):
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


    # --- Lead-out ---
    #
    # Where this letter's tail stops when another letter follows it. Everything
    # past the marker is the run-up to the next letter, which the app draws once
    # rather than once per letter; grey shows what is given up.

    def _lead_out_points(self):
        """The joining stroke, sampled the way the app samples it — the cut
        belongs to whichever stroke carries on into the next letter."""
        glyph = self.glyphs_working[self.current_key]
        s = join_stroke(glyph)
        strokes = glyph[1]
        return _sample_stroke(strokes[s]) if len(strokes) > s and strokes[s] else []

    def _draw_lead_out(self):
        points = self._lead_out_points()
        if len(points) < 2:
            return
        cut = cut_index(points, self.glyphs_working[self.current_key][2])
        if cut < len(points) - 1:
            self._polyline(points[cut:], fill="#9e9e9e", width=3, dash=(4, 3))
        cx, cy = self._to_canvas(*points[cut])
        r = CUT_R + (SELECTED_R_BONUS if self.drag_state
                     and self.drag_state.get("type") == "lead_out" else 0)
        self.canvas.create_oval(cx - r, cy - r, cx + r, cy + r,
                                fill="#ff9800", outline="black", width=1)

    def _hit_test_lead_out(self, event):
        points = self._lead_out_points()
        if len(points) < 2:
            return False
        cut = cut_index(points, self.glyphs_working[self.current_key][2])
        cx, cy = self._to_canvas(*points[cut])
        return (cx - event.x) ** 2 + (cy - event.y) ** 2 <= HIT_R ** 2

    def _drag_lead_out(self, event):
        """Move the cut along the stroke, searched near where it already is.
        Searching the whole stroke would let it jump wherever the path loops
        back over itself, as p and o do."""
        points = self._lead_out_points()
        last = len(points) - 1
        gx, gy = self._to_glyph(event.x, event.y)
        near = int(self.glyphs_working[self.current_key][2] * last)
        span = max(2, int(0.12 * last))
        window = range(max(0, near - span), min(last, near + span) + 1)
        best = min(window, key=lambda i: (points[i][0] - gx) ** 2 + (points[i][1] - gy) ** 2)
        self.glyphs_working[self.current_key][2] = round(best / max(1, last), 4)


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
