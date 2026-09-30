"""hush/freeze_midjob — FROZEN while rigging (clip_rules.json `freeze_midjob`: FROZEN with rig progress > 0; REDESIGN
§4.2 Freeze): she is caught with her gloves still on the thing and stops dead in the reach pose — a statue of guilt,
cheeks puffed (holding her breath), a strained tremble; the view turns her to marble (eyes, beret and braces keep their
colour — the rig's stone-keep mask) and pops the plinth.

The pose is SAMPLED from the band clip she was playing (index §5.3: "the reach pose held … high / mid / low variants by
the prank's band"): one loop in three held segments (`lint.freeze_holds`), and an optional sidecar field
`variants {band: [first, last frame]}` so the view can hold the prank's band — play with start_frame = the segment's
first frame and hold it (`set_external_frame`). A view that ignores `variants` loops from frame 0: the MID statue for
6 s, then high, then low. Segments:
  mid  f   0–359  rig_mid's crank (both gloves on the thing, the elbow up), standing
  high f 360–479  rig_high's overhead crank, dropped off the invisible step (arms still up; mid's feet)
  low  f 480–599  rig_low's crawl (on all fours, the glove under the thing, the foot cocked)
Baked facing +1 like the band clips (their `stage`)."""
import math
from mathutils import Vector
from lib.clip import Clip
from lib.pose import merge
from lib.hush_presets import TIPTOE
import rig_mid, rig_high, rig_low

SEG = {"mid": (0, 359), "high": (360, 479), "low": (480, 599)}
L = 600
SAMPLE = {"mid": (rig_mid, 22), "high": (rig_high, 66), "low": (rig_low, 60)}


def frozen(ctx, mod, f):
    """The evaluated pose of a band clip at frame f as a pose dict (armature-axis quaternions + the pelvis offset)."""
    c = mod.build(ctx)
    p = c.evaluate(f)
    sk = ctx.skel
    d = {}
    for n in sk.names:
        _, rot, _ = p.get(n)
        d[n] = sk.rest_q[n] @ rot @ sk.rest_q[n].inverted()
    d["_pelvis"] = tuple(p.pelvis_offset())
    return d


def tremble(f):
    """The strain of holding still: a fine 8 Hz shiver in the shoulders, arms and head."""
    a = math.sin(2 * math.pi * f * 8.0 / 60.0)
    b = math.sin(2 * math.pi * f * 6.5 / 60.0 + 1.3)
    return {"spine_03": [("y", 0.6 * a)], "neck_01": [("x", 0.5 * b)], "Head": [("z", 0.7 * a)],
            "upperarm_l": [("z", 0.8 * b)], "upperarm_r": [("z", -0.8 * a)], "lowerarm_l": [("z", -0.6 * a)],
            "lowerarm_r": [("z", 0.6 * b)]}


def build(ctx):
    st = rig_mid.stage()
    poses = {k: frozen(ctx, m, f) for k, (m, f) in SAMPLE.items()}
    # high: off the step — the soles go back to the floor (ground() on that segment), up on her toes
    hp = dict(poses["high"])
    for n in ("pelvis", "_pelvis", "thigh_l", "calf_l", "foot_l", "ball_l", "thigh_r", "calf_r", "foot_r", "ball_r"):
        hp[n] = poses["mid"][n]                    # her feet exactly where the mid statue has them
    poses["high"] = hp
    c = Clip(ctx, "hush/freeze_midjob", length=L, loop=True, cheat_deg=10.0, stage=st, blend_in=3, blend_out=6,
             audio="own", notes="variants: " + ", ".join("%s %d-%d" % (k, a, b) for k, (a, b) in SEG.items()))
    for k in ("mid", "high", "low"):
        a, b = SEG[k]
        c.key(a, poses[k], "pop" if a > 0 else "in_out_sine")
        c.key(b, poses[k], "linear")
        c.freeze_hold(a, b)
    c.pop_frames.append(L)                         # the loop seam (low -> mid) is a cut, like the segment starts
    c.motion(tremble)
    c.face(0, "hold_breath")
    c.face(SEG["high"][0], "hold_breath")
    c.face(SEG["low"][0], "hold_breath")
    orig = c.sidecar

    def sidecar(anim_res):
        d = orig(anim_res)
        d["variants"] = {k: [a, b] for k, (a, b) in SEG.items()}
        d["variant_default"] = "mid"
        return d
    c.sidecar = sidecar
    return c
