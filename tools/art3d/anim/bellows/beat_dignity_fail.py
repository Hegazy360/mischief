"""bellows/beat_dignity_fail — a T3 last beat (70 f; reactions.json clip_timings: straighten 0-30, look_around 30-60,
cravat_pings 60; the audio table: cravat_tug 2, vo_bellows_ahem 34, cravat_ping 60): wearing whatever the prank left
on him, he recovers his dignity — both gloves at his cravat, tugging it straight with a little shimmy (0-30), chin up,
he surveys the room — the Stalls, the wings — with a lofty "ahem" (30-60) … and the cravat PINGS off his chest again
(60): he freezes, eyes down at it, mortified.

Standing, feet planted (IK), cheat 35; the audience glance is a runtime gaze. The cravat is a jiggle bone: the clip
keys it straight while he holds it and lets it fly on the ping (the jiggle kick; the view's spring does the rest)."""
import math
from mathutils import Vector
from lib.clip import Clip
from lib import pose as P
from _lib.presets import *

L = 70
CRAVAT_L = ("spine_03", Vector((0.08, -0.43, 1.00)))
CRAVAT_R = ("spine_03", Vector((-0.07, -0.43, 1.03)))


def hold_feet(c, f0, f1, at=None):
    """Both feet held exactly where they are at frame `at` (default f0) after the keys and vertical constraints."""
    cache = {}

    def fn(pose, f):
        if "a" not in cache:
            ap = c._anchor_pose(f0 if at is None else at)
            cache["a"] = {s: (ap.world["foot_" + s].translation.copy(), ap.world["foot_" + s].to_quaternion())
                          for s in ("l", "r")}
        for s in ("l", "r"):
            loc, q = cache["a"][s]
            P.solve_leg(pose, s, loc, foot_world=q)
    c.custom(fn, f0, f1)


def stand(fwd=0.0, side=0.0, turn=0.0, hx=0.0, hy=0.0, hz=0.0, arms=None, cravat=0.0):
    return merge(STAND, ARMS_POMPOUS, glove("l", 26, 14), glove("r", 26, 14), lean(fwd=fwd, side=side, turn=turn),
                 head(x=hx, y=hy, z=hz), arms or {}, {"cravat": [("x", cravat)]})


# the hands at the cravat (on IK below): pinching it at both ends
AT_CRAVAT = merge({"clavicle_l": [("z", 6)], "upperarm_l": [("y", 64), ("z", -40)], "lowerarm_l": [("z", -100)],
                   "clavicle_r": [("z", -6)], "upperarm_r": [("y", -64), ("z", 40)], "lowerarm_r": [("z", 100)]},
                  curl("l", 50, thumb=40, fingers=("index", "middle")), curl("r", 50, thumb=40, fingers=("index", "middle")))
# smoothing the lapels down, lofty
SMOOTH = {"clavicle_l": [("y", -4)], "upperarm_l": [("y", 76), ("z", -14)], "lowerarm_l": [("z", -56)],
          "hand_l": [("x", 10), ("y", 30)],
          "clavicle_r": [("y", 4)], "upperarm_r": [("y", -76), ("z", 14)], "lowerarm_r": [("z", 56)],
          "hand_r": [("x", 10), ("y", -30)]}
# the ping: arms jerk out, frozen, fingers splayed
PING = merge({"clavicle_l": [("y", -20)], "upperarm_l": [("y", 26), ("z", 10)], "lowerarm_l": [("z", -18)],
              "hand_l": [("x", -30)],
              "clavicle_r": [("y", 18)], "upperarm_r": [("y", -34), ("z", -6)], "lowerarm_r": [("z", 26)],
              "hand_r": [("x", -30)]},
             open_hand("l", 26), open_hand("r", 24))



def hide_fx(c):
    """Key the FX bones (the dazed stars, the orbiting notes, the CHOO puff) at scale 0 on every key: a clip that
    never shows them must still say so, or a stray scale track (exporter float drift) leaves them visible."""
    for k in c._keys:
        for b, v in fx_hidden("fx_notes", "fx_stars", "fx_choo").items():
            k.pose.setdefault(b, v)
    c._key_poses = None

def build(ctx):
    c = Clip(ctx, "bellows/beat_dignity_fail", length=L, cheat_deg=35, blend_in=8, blend_out=10,
             tags=["last_beat", "t3"])
    c.key(0, stand(fwd=4, hx=10, arms=AT_CRAVAT, cravat=-6))
    c.key(8, stand(fwd=2, side=3, hx=6, hy=4, arms=AT_CRAVAT, cravat=-2), "in_out_sine")
    c.key(16, stand(fwd=2, side=-3, hx=6, hy=-4, arms=AT_CRAVAT, cravat=2), "in_out_sine")      # the shimmy
    c.key(26, stand(fwd=-6, hx=-6, arms=AT_CRAVAT, cravat=0), "in_out_sine")
    # the survey is facing-proof: the rig yaws with facing (no mirror), so each way is kept to 12 deg of turn and the
    # face stays at >= 23 deg of cheat in either facing (a 26 deg turn went edge-on under the bouffant at facing +1)
    c.key(34, stand(fwd=-8, turn=4, hx=-14, hz=8, arms=SMOOTH), "in_out_cubic")                  # ahem — one way
    c.key(46, stand(fwd=-8, turn=-4, hx=-14, hz=-8, arms=SMOOTH), "in_out_sine")                 # … and the other
    c.key(57, stand(fwd=-9, hx=-16, hz=4, arms=SMOOTH), "in_out_sine")                           # satisfied
    c.key(60, stand(fwd=-14, hx=-10, hz=4, arms=PING, cravat=-80), "pop")                        # PING — a jolt back
    c.key(64, stand(fwd=8, hx=16, hz=2, arms=PING, cravat=-50), "out_quad")                      # eyes down at it
    c.key(L, stand(fwd=9, hx=18, hz=0, arms=merge(PING, {"clavicle_l": [("y", 6)], "clavicle_r": [("y", -6)]}),
                   cravat=-40), "in_out_sine")
    # the gloves ON the cravat while he straightens it (IK, riding the chest)
    c.ik("l", CRAVAT_L, 0, 28, pole=POLE_L, effector="palm", blend=(0, 5), world=False)
    c.ik("r", CRAVAT_R, 0, 28, pole=POLE_R, effector="palm", blend=(0, 5), world=False)
    c.motion(lambda f: breath(f, 40.0, 1.2))
    c.motion(lambda f: tremble(f, 0.8, ("spine_03", "Head"), rate=2.8), 60, L, weight=lambda f: ramp(f, 60, 63))
    c.ground(0, 0)
    hold_feet(c, 0, L)
    c.look_camera(30, 44, weight=0.9, blend=6)
    c.look_camera(56, L, weight=0.7, blend=4)
    c.beats(straighten=(0, 30), tug=(2, 26), look_around=(30, 60), ahem=(34, 46), cravat_pings=(60, 70),
            ping=(60, 64))
    c.event(60, "jiggle", bones=["cravat", "bouffant", "belly"], kick=1.0)
    for f, p in ((0, "pompous"), (26, "smug"), (34, "disdain"), (46, "pompous"), (59, "smug"), (60, "shock"),
                 (64, "mortified")):
        c.face(f, p)
    hide_fx(c)
    return c
