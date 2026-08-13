#!/usr/bin/env python3
"""Desktop editor for how two cursive letters connect, in `src/pairs.json`.

Run:
    python3 tool/join_editor.py

Letterforms are read-only here — edit those in `python3 tool/glyph_editor.py`.
This tool only decides where one letter hands over to the next.

A pair stores the connection, never the letterforms, which is what lets pairs
build words: "ca" plus "ap" gives "cap" exactly, because the two joins around a
letter cut opposite ends of it and so can never disagree.

    from   where the first letter's tail is cut, 0-1 along its main stroke
    to     where the second letter's head is cut, 0-1 along its main stroke
    dx     the second letter's cut point relative to the first's, horizontally
    h1,h2  the connecting bezier's handles, as offsets from their own cut

Controls:
    * Type a pair, or step through all 1352 of them with the arrow keys or the
      Prev/Next buttons. "Untuned only" skips the ones already done.
    * Drag the orange markers to move each cut along its letter.
    * Drag the blue handles to shape the connecting stroke.
    * Drag anywhere else to kern — it slides the second letter.
    * `Reset` drops this pair back to the automatic join; `Save` writes the file.
    * Right-drag pans, the wheel zooms, `Fit` re-frames.

Every pair starts seeded from whatever the automatic join already does, so
tuning is always an adjustment rather than a blank page.
"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from tool.glyphdata import (  # noqa: E402
    APP_GLYPH_SCALE, APP_LINE_WIDTH, BASELINE_Y, JOIN_FILE, PAIRS_FILE, REFERENCE_LINES, compose_run, dump_join, dump_pairs,
    load_glyphs, load_join, load_pairs,
)
from tool.glyphdata import _sample_stroke  # noqa: E402

try:
    import tkinter as tk
    from tkinter import messagebox, ttk
    _HAS_TK = True
except ImportError:
    tk = None  # type: ignore
    ttk = None  # type: ignore
    messagebox = None  # type: ignore
    _HAS_TK = False

LOWER = "abcdefghijklmnopqrstuvwxyz"
UPPER = LOWER.upper()

HIT_R = 16
CUT_R = 9
HANDLE_R = 7
ZOOM_FACTOR = 1.1
FIT_MARGIN = 60

# How much of the canvas height the ascender-to-descender band may take. Over
# 1.0 crops tall glyphs to keep the join legible.
VERTICAL_CROP = 1.5


def pair_sequence():
    """Every pair worth tuning: lowercase then capitals, each followed by a
    lowercase letter. Capitals only ever start a word, so nothing follows a
    lowercase letter into a capital, and a capital marked `liftAfter` opens no
    join at all — there is no connection between it and what follows to tune."""
    lifts = {key for key, glyph in load_glyphs().items() if glyph[3]}
    return [first + second
            for first in LOWER + UPPER if first not in lifts
            for second in LOWER]


class JoinEditor:
    def __init__(self, master):
        self.master = master
        master.title("Cursive join editor")
        master.geometry("1280x780")

        self.glyphs = load_glyphs()
        self.join = load_join()
        self.pairs = load_pairs()
        self.sequence = pair_sequence()
        self.index = 0
        self.draft = None
        self.drag = None
        self.scale, self.ox, self.oy = 8.0, 80.0, 120.0

        self._build_ui()
        self._load_pair(self.sequence[0])

    # --- data ---

    @property
    def key(self):
        return self.sequence[self.index]

    def _auto_join(self, key):
        run = compose_run(self.glyphs, [key[0], key[1]], self.gap_var.get())
        return dict(run[1]["join"])

    def _load_pair(self, key):
        if key not in self.sequence:
            self._status(f"'{key}' is not a tunable pair.")
            return
        self.index = self.sequence.index(key)
        stored = self.pairs.get(key)
        self.draft = dict(stored) if stored else self._auto_join(key)
        if stored:
            self.draft["h1"] = list(stored["h1"])
            self.draft["h2"] = list(stored["h2"])
        self.entry_var.set(key)
        self._fit_view()
        self._redraw()
        self._update_status()

    def _compose(self):
        pairs = dict(self.pairs)
        pairs[self.key] = self.draft
        return compose_run(self.glyphs, [self.key[0], self.key[1]], self.gap_var.get(), pairs)

    def _commit(self):
        """A pair is stored only once it differs from the automatic join, so
        the file stays a record of decisions rather than of defaults."""
        if self.draft == self._auto_join(self.key):
            self.pairs.pop(self.key, None)
        else:
            self.pairs[self.key] = dict(self.draft)

    def _tuned_count(self):
        return sum(1 for k in self.pairs if len(k) == 2)

    # --- navigation ---

    def _step(self, direction):
        untuned_only = self.untuned_var.get()
        i = self.index
        for _ in range(len(self.sequence)):
            i = (i + direction) % len(self.sequence)
            if not untuned_only or self.sequence[i] not in self.pairs:
                self._load_pair(self.sequence[i])
                return
        self._status("Every pair is tuned.")

    def _on_entry(self, _event=None):
        self._load_pair(self.entry_var.get().strip())

    def _reset_pair(self):
        self.pairs.pop(self.key, None)
        self.draft = self._auto_join(self.key)
        self._redraw()
        self._status(f"'{self.key}' is back to the automatic join.")

    def _save(self):
        try:
            self._commit()
            PAIRS_FILE.write_text(dump_pairs(self.pairs))
            gap = round(self.gap_var.get(), 2)
            self.join["gap"] = int(gap) if gap == int(gap) else gap
            JOIN_FILE.write_text(dump_join(self.join))
            self._status(
                f"Saved {self._tuned_count()} tuned joins to {PAIRS_FILE.name}, "
                f"gap {self.join['gap']:g} to {JOIN_FILE.name}."
            )
        except Exception as error:
            messagebox.showerror("Save failed", str(error))

    def _on_gap_change(self):
        self.gap_label.config(text=f"{self.gap_var.get():.0f}")
        if self.key not in self.pairs:
            self.draft = self._auto_join(self.key)
        self._redraw()

    # --- view ---

    def _to_canvas(self, gx, gy):
        return (self.ox + gx * self.scale, self.oy + gy * self.scale)

    def _to_glyph(self, cx, cy):
        return ((cx - self.ox) / self.scale, (cy - self.oy) / self.scale)

    def _ink_width(self, editing_width):
        """Stroke weight. The editor otherwise draws centrelines, which is what
        you want for placing handles and useless for judging how heavy a join
        reads — the app strokes those centrelines many times thicker."""
        if not self.as_drawn_var.get():
            return editing_width
        return max(1.0, APP_LINE_WIDTH / APP_GLYPH_SCALE * self.scale)

    def _fit_view(self):
        """Frame the pair on its join. Fitting the letters whole would let one
        descender shrink the connection down to a few pixels, which is the part
        actually being edited — so the scale comes from the horizontal span, and
        tall glyphs are allowed to run off the top and bottom."""
        run = self._compose()
        points = [p for item in run for p in item["points"] + item["trimmed"] + item["bridge"]]
        if not points:
            return
        width = self.canvas.winfo_width() or 1280
        height = self.canvas.winfo_height() or 620
        xs = [p[0] for p in points]
        span_x = max(max(xs) - min(xs), 1.0)
        self.scale = min(
            (width - 2 * FIT_MARGIN) / span_x,
            height * VERTICAL_CROP / (BASELINE_Y + 30),
        )
        self.ox = (width - span_x * self.scale) / 2 - min(xs) * self.scale
        # Centre on the join itself, not on the letters.
        join_y = (run[0]["points"][-1][1] + run[1]["points"][0][1]) / 2
        self.oy = height / 2 - join_y * self.scale

    def _on_wheel(self, event):
        step = ZOOM_FACTOR if getattr(event, "delta", 0) > 0 or event.num == 4 else 1 / ZOOM_FACTOR
        gx, gy = self._to_glyph(event.x, event.y)
        self.scale *= step
        self.ox, self.oy = event.x - gx * self.scale, event.y - gy * self.scale
        self._redraw()

    def _on_pan_press(self, event):
        self.drag = {"target": "pan", "x": event.x, "y": event.y}

    def _on_pan_drag(self, event):
        if not self.drag or self.drag["target"] != "pan":
            return
        self.ox += event.x - self.drag["x"]
        self.oy += event.y - self.drag["y"]
        self.drag.update(x=event.x, y=event.y)
        self._redraw()

    # --- editing ---

    def _handles(self, run):
        cut_a, cut_b = run[0]["points"][-1], run[1]["points"][0]
        return {
            "from": cut_a,
            "to": cut_b,
            "h1": (cut_a[0] + self.draft["h1"][0], cut_a[1] + self.draft["h1"][1]),
            "h2": (cut_b[0] + self.draft["h2"][0], cut_b[1] + self.draft["h2"][1]),
        }

    def _full_stroke(self, key, offset=0.0):
        return [(x + offset, y) for x, y in _sample_stroke(self.glyphs[key][1][0])]

    @staticmethod
    def _nearest_fraction(points, gx, gy, near, window=0.12):
        """Where along `points` the cursor is, searched near the cut's current
        position. Searching the whole stroke would let the cut jump across the
        letter wherever the path loops back over itself, as p and o do."""
        last = len(points) - 1
        span = max(2, int(window * last))
        centre = int(near * last)
        lo, hi = max(0, centre - span), min(last, centre + span)
        best, best_d = lo, None
        for i in range(lo, hi + 1):
            x, y = points[i]
            d = (x - gx) ** 2 + (y - gy) ** 2
            if best_d is None or d < best_d:
                best, best_d = i, d
        return round(best / max(1, last), 4)

    def _on_press(self, event):
        run = self._compose()
        gx, _gy = self._to_glyph(event.x, event.y)
        # Nearest wins: a cut and its handle sit close together, so picking the
        # first match would make the handle unreachable.
        target, nearest = None, HIT_R
        for name, (hx, hy) in self._handles(run).items():
            cx, cy = self._to_canvas(hx, hy)
            distance = math.hypot(event.x - cx, event.y - cy)
            if distance <= nearest:
                target, nearest = name, distance
        self.drag = {"target": target or "dx", "gx0": gx, "dx0": self.draft["dx"]}

    def _on_drag(self, event):
        if not self.drag or self.drag["target"] == "pan":
            return
        run = self._compose()
        gx, gy = self._to_glyph(event.x, event.y)
        target = self.drag["target"]
        if target == "from":
            self.draft["from"] = self._nearest_fraction(
                self._full_stroke(self.key[0]), gx, gy, self.draft["from"])
        elif target == "to":
            self.draft["to"] = self._nearest_fraction(
                self._full_stroke(self.key[1], run[1]["offset"]), gx, gy, self.draft["to"])
        elif target in ("h1", "h2"):
            anchor = self._handles(run)["from" if target == "h1" else "to"]
            self.draft[target] = [round(gx - anchor[0], 2), round(gy - anchor[1], 2)]
        else:
            self.draft["dx"] = round(self.drag["dx0"] + (gx - self.drag["gx0"]), 2)
        self._commit()
        self._redraw()
        self._update_status()

    def _on_release(self, _event):
        self.drag = None

    # --- drawing ---

    def _polyline(self, points, **options):
        if len(points) < 2:
            return
        flat = [c for p in points for c in self._to_canvas(p[0], p[1])]
        self.canvas.create_line(*flat, capstyle="round", joinstyle="round", **options)

    def _redraw(self):
        self.canvas.delete("all")
        run = self._compose()
        width = self.canvas.winfo_width() or 1280

        for y, label in REFERENCE_LINES:
            _, cy = self._to_canvas(0, y)
            self.canvas.create_line(0, cy, width, cy, fill="#e8e8e8")
            self.canvas.create_text(8, cy, anchor="w", text=label,
                                    fill="#b0b0b0", font=("TkDefaultFont", 9))

        # What each letter gives up to the join.
        first_full = self._full_stroke(self.key[0])
        self._polyline(first_full[run[0]["tail"]:], fill="#dcdcdc", width=4, dash=(5, 4))
        self._polyline(run[1]["trimmed"], fill="#dcdcdc", width=4, dash=(5, 4))
        # Deferred strokes ride along with their letter.
        for key, item in ((self.key[0], run[0]), (self.key[1], run[1])):
            for beziers in self.glyphs[key][1][1:]:
                points = []
                for bez in beziers:
                    samples = _sample_stroke([bez])
                    points.extend(samples if not points else samples[1:])
                self._polyline([(x + item["offset"], y) for x, y in points],
                               fill="#cfc6e6", width=self._ink_width(4))

        self._polyline(run[0]["points"], fill="#5e35b1", width=self._ink_width(5))
        self._polyline(run[1]["points"], fill="#9575cd", width=self._ink_width(5))
        self._polyline(run[1]["bridge"], fill="#00897b", width=self._ink_width(5))

        handles = self._handles(run)
        for cut, handle in (("from", "h1"), ("to", "h2")):
            self.canvas.create_line(*self._to_canvas(*handles[cut]),
                                    *self._to_canvas(*handles[handle]),
                                    fill="#1e88e5", width=1)
        for name, (gx, gy) in handles.items():
            cx, cy = self._to_canvas(gx, gy)
            is_cut = name in ("from", "to")
            r = CUT_R if is_cut else HANDLE_R
            self.canvas.create_oval(cx - r, cy - r, cx + r, cy + r,
                                    fill="#ff9800" if is_cut else "#1e88e5",
                                    outline="black", width=1)
            self.canvas.create_text(cx, cy - r - 9, text=name, fill="#777",
                                    font=("TkDefaultFont", 8))

    # --- ui ---

    def _status(self, text):
        self.status.config(text=text)

    def _update_status(self):
        d = self.draft
        tuned = "tuned" if self.key in self.pairs else "automatic"
        self._status(
            f"{self.key}   {self.index + 1} of {len(self.sequence)}   "
            f"{self._tuned_count()} tuned   [{tuned}]      "
            f"from {d['from']:.3f}   to {d['to']:.3f}   dx {d['dx']:.1f}   "
            f"h1 {d['h1'][0]:.1f},{d['h1'][1]:.1f}   h2 {d['h2'][0]:.1f},{d['h2'][1]:.1f}"
        )

    def _build_ui(self):
        bar = tk.Frame(self.master)
        bar.pack(side="top", fill="x", padx=8, pady=8)

        tk.Label(bar, text="Pair:").pack(side="left")
        self.entry_var = tk.StringVar()
        entry = tk.Entry(bar, textvariable=self.entry_var, width=5)
        entry.bind("<Return>", self._on_entry)
        entry.pack(side="left", padx=(4, 8))

        tk.Button(bar, text="← Prev", command=lambda: self._step(-1)).pack(side="left", padx=2)
        tk.Button(bar, text="Next →", command=lambda: self._step(1)).pack(side="left", padx=2)
        self.untuned_var = tk.BooleanVar(value=False)
        tk.Checkbutton(bar, text="Untuned only", variable=self.untuned_var).pack(side="left", padx=(12, 4))
        self.as_drawn_var = tk.BooleanVar(value=False)
        tk.Checkbutton(bar, text="Real weight", variable=self.as_drawn_var,
                       command=self._redraw).pack(side="left", padx=(12, 4))

        tk.Button(bar, text="Reset", command=self._reset_pair).pack(side="left", padx=(16, 2))
        tk.Button(bar, text="Fit", command=lambda: (self._fit_view(), self._redraw())).pack(side="left", padx=2)

        tk.Label(bar, text="Join gap:").pack(side="left", padx=(16, 2))
        self.gap_var = tk.DoubleVar(value=self.join["gap"])
        ttk.Scale(bar, from_=0.0, to=30.0, length=100, variable=self.gap_var,
                  command=lambda _v: self._on_gap_change()).pack(side="left", padx=2)
        self.gap_label = tk.Label(bar, text=f"{self.join['gap']:.0f}", width=3)
        self.gap_label.pack(side="left")

        tk.Button(bar, text="Save to file", command=self._save).pack(side="right", padx=4)

        self.status = tk.Label(self.master, text="Ready.", anchor="w")
        self.status.pack(side="bottom", fill="x", padx=8, pady=4)

        self.canvas = tk.Canvas(self.master, bg="white", cursor="arrow")
        self.canvas.pack(side="top", fill="both", expand=True)
        self.canvas.bind("<ButtonPress-1>", self._on_press)
        self.canvas.bind("<B1-Motion>", self._on_drag)
        self.canvas.bind("<ButtonRelease-1>", self._on_release)
        self.canvas.bind("<ButtonPress-3>", self._on_pan_press)
        self.canvas.bind("<B3-Motion>", self._on_pan_drag)
        self.canvas.bind("<ButtonRelease-3>", self._on_release)
        self.canvas.bind("<MouseWheel>", self._on_wheel)
        self.canvas.bind("<Button-4>", self._on_wheel)
        self.canvas.bind("<Button-5>", self._on_wheel)

        self.master.bind("<Right>", lambda e: self._step(1))
        self.master.bind("<Left>", lambda e: self._step(-1))
        self.master.bind("<Control-s>", lambda e: self._save())


def main():
    if not _HAS_TK:
        raise SystemExit(
            "tkinter is not available. On Debian/Ubuntu install it with:\n"
            "  sudo apt install python3-tk"
        )
    root = tk.Tk()
    JoinEditor(root)
    root.mainloop()


if __name__ == "__main__":
    main()
