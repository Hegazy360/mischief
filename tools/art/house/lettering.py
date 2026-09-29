"""lettering - letters and digits as SVG path SHAPES (STYLE.md §1: never <text>) from the project's OFL
font Lilita One (game/ui/theme/fonts/LilitaOne-Regular.ttf), converted with fontTools.

    pb, w = word("MISCHIEF", x=100, baseline=300, cap_h=180)            # left-aligned at x
    pb, w = word("NEXT DOOR", cx=750, baseline=520, cap_h=120, track=6) # centred on cx

The result is a svgk.PB (absolute coords, y down) holding every glyph contour; TrueType outer contours
run clockwise and counters counter-clockwise, so the default nonzero fill punches the holes (O, D, R, 9).
"""
import os

from fontTools.pens.basePen import BasePen
from fontTools.ttLib import TTFont

from svgk import PB

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
FONT = os.path.join(REPO, "game", "ui", "theme", "fonts", "LilitaOne-Regular.ttf")

_font = None


def _load():
    global _font
    if _font is None:
        f = TTFont(FONT)
        _font = (f, f.getGlyphSet(), f.getBestCmap(), float(f["OS/2"].sCapHeight or 700))
    return _font


class _Pen(BasePen):
    """fontTools pen -> svgk PB, mapping font units (y up) to canvas px (y down)."""

    def __init__(self, glyphset, pb, x, base, s):
        super().__init__(glyphset)
        self.pb, self.x, self.base, self.s = pb, x, base, s

    def _t(self, p):
        return self.x + p[0] * self.s, self.base - p[1] * self.s

    def _moveTo(self, p):
        self.pb.M(*self._t(p))

    def _lineTo(self, p):
        self.pb.L(*self._t(p))

    def _curveToOne(self, p1, p2, p3):
        a, b, c = self._t(p1), self._t(p2), self._t(p3)
        self.pb.C(a[0], a[1], b[0], b[1], c[0], c[1])

    def _qCurveToOne(self, p1, p2):
        a, b = self._t(p1), self._t(p2)
        self.pb.Q(a[0], a[1], b[0], b[1])

    def _closePath(self):
        self.pb.Z()

    def _endPath(self):
        pass


def advance(text, cap_h, track=0.0):
    """Width in px of `text` set at cap height `cap_h` with `track` px extra between letters."""
    f, gs, cmap, cap = _load()
    s = cap_h / cap
    w = 0.0
    for i, ch in enumerate(text):
        g = cmap.get(ord(ch))
        w += gs[g].width * s if g else cap_h * 0.3
        if i < len(text) - 1:
            w += track
    return w


def word(text, baseline, cap_h, x=None, cx=None, track=0.0, pb=None):
    """Glyph outlines of `text` (baseline y, cap height px) left-aligned at `x` or centred on `cx`.
    Returns (PB, width). Spaces advance without drawing."""
    f, gs, cmap, cap = _load()
    s = cap_h / cap
    w = advance(text, cap_h, track)
    x0 = x if x is not None else (cx - w / 2.0)
    pb = pb or PB()
    cur = x0
    for ch in text:
        g = cmap.get(ord(ch))
        if g is None:
            cur += cap_h * 0.3 + track
            continue
        if ch != " ":
            gs[g].draw(_Pen(gs, pb, cur, baseline, s))
        cur += gs[g].width * s + track
    return pb, w


def glyph_bbox(text, baseline, cap_h, x=None, cx=None, track=0.0):
    """(x0, y0, x1, y1) of the set text (for layout)."""
    from svgk import path
    pb, _ = word(text, baseline, cap_h, x=x, cx=cx, track=track)
    return path(pb, fill="#000000").bbox()
