"""Eases for clip keys — identical to the (removed) 2D `RigEase` and TECH §4.8.

A key's `ease` is the curve INTO that key: `linear`, `hold` (keep the previous key's pose until this key's frame,
then jump: a step), `pop` (the same step — the accent pose pops in on its frame; the lint allows a > 45°/f jump
only on `lint.pop_frames`, which `Clip` fills with every pop key) and `in_ | out_ | in_out_` × `quad cubic quart
expo sine back elastic bounce`. `apply(name, t)` maps progress t in [0, 1] to eased progress (back / elastic
overshoot outside [0, 1], so a key can overshoot its target: the interpolation extrapolates).
"""
import math

FAMILIES = ("quad", "cubic", "quart", "expo", "sine", "back", "elastic", "bounce")
KINDS = ("in", "out", "in_out")


def names():
    out = ["linear", "hold", "pop"]
    for k in KINDS:
        for f in FAMILIES:
            out.append("%s_%s" % (k, f))
    return out


def is_step(name):
    return name in ("hold", "pop")


def valid(name):
    return name in names()


def _bounce_out(t):
    if t < 1.0 / 2.75:
        return 7.5625 * t * t
    if t < 2.0 / 2.75:
        a = t - 1.5 / 2.75
        return 7.5625 * a * a + 0.75
    if t < 2.5 / 2.75:
        b = t - 2.25 / 2.75
        return 7.5625 * b * b + 0.9375
    c = t - 2.625 / 2.75
    return 7.5625 * c * c + 0.984375


def _in(fam, t):
    if fam == 0:
        return t * t
    if fam == 1:
        return t * t * t
    if fam == 2:
        return t * t * t * t
    if fam == 3:
        return math.pow(2.0, 10.0 * (t - 1.0)) - 0.001
    if fam == 4:
        return -math.cos(t * math.pi * 0.5) + 1.0
    if fam == 5:
        s = 1.70158
        return t * t * ((s + 1.0) * t - s)
    if fam == 6:
        t1 = t - 1.0
        p = 0.3
        s2 = p / 4.0
        return -(math.pow(2.0, 10.0 * t1) * math.sin((t1 - s2) * math.tau / p))
    if fam == 7:
        return 1.0 - _bounce_out(1.0 - t)
    return t


def _out(fam, t):
    if fam == 0:
        return -t * (t - 2.0)
    if fam == 1:
        u = t - 1.0
        return u * u * u + 1.0
    if fam == 2:
        u = t - 1.0
        return -(u * u * u * u - 1.0)
    if fam == 3:
        return 1.001 * (1.0 - math.pow(2.0, -10.0 * t))
    if fam == 4:
        return math.sin(t * math.pi * 0.5)
    if fam == 5:
        s = 1.70158
        u = t - 1.0
        return u * u * ((s + 1.0) * u + s) + 1.0
    if fam == 6:
        p = 0.3
        s2 = p / 4.0
        return math.pow(2.0, -10.0 * t) * math.sin((t - s2) * math.tau / p) + 1.0
    if fam == 7:
        return _bounce_out(t)
    return t


def _in_out_lo(fam, t):
    u = t * 2.0
    if fam == 0:
        return 0.5 * u * u
    if fam == 1:
        return 0.5 * u * u * u
    if fam == 2:
        return 0.5 * u * u * u * u
    if fam == 3:
        return 0.5 * math.pow(2.0, 10.0 * (u - 1.0)) - 0.0005
    if fam == 4:
        return -0.5 * (math.cos(math.pi * t) - 1.0)
    if fam == 5:
        s = 1.70158 * 1.525
        return 0.5 * (u * u * ((s + 1.0) * u - s))
    if fam == 6:
        p = 0.3 * 1.5
        s2 = p / 4.0
        u1 = u - 1.0
        return -0.5 * (math.pow(2.0, 10.0 * u1) * math.sin((u1 - s2) * math.tau / p))
    if fam == 7:
        return 0.5 * (1.0 - _bounce_out(1.0 - u))
    return t


def _in_out_hi(fam, t):
    u = t * 2.0
    if fam == 0:
        return -0.5 * ((u - 1.0) * (u - 3.0) - 1.0)
    if fam == 1:
        v = u - 2.0
        return 0.5 * (v * v * v + 2.0)
    if fam == 2:
        v = u - 2.0
        return -0.5 * (v * v * v * v - 2.0)
    if fam == 3:
        return 0.5 * 1.0005 * (-math.pow(2.0, -10.0 * (u - 1.0)) + 2.0)
    if fam == 4:
        return -0.5 * (math.cos(math.pi * t) - 1.0)
    if fam == 5:
        s = 1.70158 * 1.525
        v = u - 2.0
        return 0.5 * (v * v * ((s + 1.0) * v + s) + 2.0)
    if fam == 6:
        p = 0.3 * 1.5
        s2 = p / 4.0
        u1 = u - 1.0
        return math.pow(2.0, -10.0 * u1) * math.sin((u1 - s2) * math.tau / p) * 0.5 + 1.0
    if fam == 7:
        return 0.5 + 0.5 * _bounce_out(u - 1.0)
    return t


def apply(name, t):
    """Eased progress for t in [0, 1] (t clamped). Steps return 0 below 1 and 1 at 1."""
    t = min(1.0, max(0.0, t))
    if name == "linear" or not name:
        return t
    if name in ("hold", "pop"):
        return 1.0 if t >= 1.0 else 0.0
    if "_" not in name:
        raise ValueError("unknown ease '%s'" % name)
    kind, fam_name = name.rsplit("_", 1)
    if kind not in KINDS or fam_name not in FAMILIES:
        raise ValueError("unknown ease '%s' (use %s)" % (name, ", ".join(names())))
    fam = FAMILIES.index(fam_name)
    if fam in (3, 6):
        if t == 0.0:
            return 0.0
        if t == 1.0 and not (fam == 3 and kind == "in"):
            return 1.0
    if kind == "in":
        return _in(fam, t)
    if kind == "out":
        return _out(fam, t)
    if t < 0.5:
        return _in_out_lo(fam, t)
    return _in_out_hi(fam, t)
