"""hush/act_squeak — the squeak (state:squeaking, 18 f): she whips Clarence out of the brace (grab f 3, attached to
her glove f 4), rises up with him held out in front of her chest (f 6, the anticipation: up on her toes) and SQUEEZES
(f 8): the whole body squashes down with him — knees bend, the spine curls over him, shoulders up to her ears, both
gloves clamped round his middle at chest height — while his neck and beak shoot out forward-up clear of her face (his
body squashes, his comb flares); a springy recoil, and she tucks him back into the brace by f 16. The 64 px verb board
samples f 8 (issues.md D12: squeak at the chest with a body squash, never hoisted overhead like a reach). Table row:
no events (the sim plays the squeak)."""
import math
from mathutils import Vector, Quaternion
from lib.clip import Clip
from lib.pose import merge, sym, mix
from lib.hush_presets import ARMS_DOWN, STAND, gloves, glove, lean, head

L = 18
ROLL_DEG = 0.0                  # the fist's roll about his axis (his beak to the front)


def build(ctx):
    c = Clip(ctx, "hush/act_squeak", length=L, cheat_deg=35, audio="table", blend_in=3, blend_out=8)
    stand = merge(ARMS_DOWN, STAND, gloves(18, 12), head())
    GRAB_R = {"clavicle_r": [("y", 4)], "upperarm_r": [("y", -64), ("z", 36)], "lowerarm_r": [("z", 96)],
              "hand_r": [("x", -20)]}
    # Clarence held out in front of her chest, his head pointing forward-up out of the fist; the left glove clamps
    # round his middle from above (both gloves on him)
    OUT_R = {"clavicle_r": [("y", 8)], "upperarm_r": [("y", -24), ("z", 62)], "lowerarm_r": [("z", 78)],
             "hand_r": [("x", 55), ("z", 10)]}
    OUT_L = {"clavicle_l": [("y", -6)], "upperarm_l": [("y", 20), ("z", -58)], "lowerarm_l": [("z", -92)],
             "hand_l": [("x", -10), ("z", -40)]}
    LIFT = {"upperarm_r": [("y", 16)], "upperarm_l": [("y", -16)]}      # the gloves stay at her chest in the curl
    SQUEEZE_UP = {"clavicle_l": [("y", -24), ("z", -8)], "clavicle_r": [("y", 24), ("z", 8)]}   # shoulders to her ears
    # the whole-body squash: knees dip deep, feet planted, the heels stay down
    SQUASH = {"thigh_l": [("x", -44), ("z", 8)], "calf_l": [("x", 80)], "foot_l": [("x", -36), ("z", -4)],
              "thigh_r": [("x", -42), ("z", -8)], "calf_r": [("x", 78)], "foot_r": [("x", -36), ("z", 4)]}
    c.key(0, stand)
    c.key(3, merge(stand, GRAB_R, glove("r", 50, 30), lean(fwd=6, turn=-10), head(x=14, z=-10)), "out_quad")   # grab
    c.key(6, merge(stand, OUT_R, OUT_L, glove("r", 40, 30), glove("l", 30, 20), lean(fwd=-8, turn=10),
                   head(x=-12, z=10)), "out_back")                                                           # up, out!
    c.key(8, merge(stand, SQUASH, OUT_R, OUT_L, SQUEEZE_UP, LIFT, glove("r", 92, 60), glove("l", 88, 50), lean(fwd=26, turn=8),
                   head(x=6, z=12)), "pop")                                                                 # SQUEEZE
    c.key(11, merge(stand, mix(SQUASH, {}, 0.55), OUT_R, OUT_L, mix(SQUEEZE_UP, {}, 0.5), glove("r", 74, 50),
                    glove("l", 66, 40), lean(fwd=8, turn=8), head(x=-8, z=10)), "out_back")                  # recoil
    c.key(15, merge(stand, GRAB_R, glove("r", 50, 30), lean(fwd=4, turn=-6), head(x=10, z=-4)), "in_out_sine")  # tuck
    c.key(L, stand, "in_out_sine")
    # Clarence's own squeeze (his body bone: the honk stretches him long and fat) and comb flare
    def squash(f):
        if f < 7 or f > 13:
            return {}
        k = max(0.0, 1.0 - abs(f - 8) / 4.0) if f >= 8 else (f - 7) / 1.0
        return {"clarence_body": {"s": (1.0 + 0.35 * k, 1.0 + 0.40 * k, 1.0 + 0.35 * k)},
                "clarence_comb": {"s": (1.0 + 0.7 * k, 1.0 + 0.7 * k, 1.0 + 0.7 * k), "r": [("x", -30 * k)],
                                  "t": (0.0, 0.025 * k, 0.0)}}
    c.motion(squash)
    # the gloves on him by IK (riding on her chest, so they follow the squash): both fists round him, stacked like a
    # bat grip, his neck + head pointing forward-up out of the top fist (his long axis = the glove's finger axis in
    # grip_r) — the shape the 64 px board reads, clear in front of her face
    sk = ctx.skel
    chest = sk.head("spine_03")
    FIST = chest + Vector((-0.02, -0.30, 0.20))
    AXIS = Vector((0.06, -0.55, 0.83)).normalized()          # his head: forward-up, a touch to her left
    ROLL = Quaternion(AXIS, math.radians(ROLL_DEG))
    HAND_R = ROLL @ (sk.rest_q["hand_r"] @ Vector((0, 1, 0))).rotation_difference(AXIS)
    HAND_L = ROLL @ (sk.rest_q["hand_l"] @ Vector((0, 1, 0))).rotation_difference(AXIS)
    TAIL = FIST - AXIS * 0.075 + Vector((0.035, 0.0, 0.0))
    c.ik("r", ("spine_03", FIST), 4, 15, blend=(2, 7), pole=(-0.9, 0.2, -0.5), hand=HAND_R, effector="grip_r",
         world=False)
    c.ik("l", ("spine_03", TAIL), 1, 17, blend=(5, 8), pole=(0.9, 0.2, -0.5), hand=HAND_L, effector="grip_l",
         world=False)
    c.ground()
    c.plant("l", 0, L, part="foot")                        # the squash is all knees: both feet stay flat and put
    c.plant("r", 0, L, part="foot")
    c.event(4, "prop", op="attach", prop="clarence", socket="grip_r")
    c.event(15, "prop", op="attach", prop="clarence", socket="brace_r")
    c.face(0, "determined")
    c.face(4, "grin")
    c.face(8, "laugh")
    c.face(13, "smug")
    c.mark(8, "accent")
    c.pop_frames.extend([4, 5])                            # the whip out of the brace (2 f snap up to the chest)
    # lead note D8: the squeeze's laugh faces the audience (runtime gaze, facing-proof)
    c.look_camera(6, 13, weight=0.8, blend=2)
    return c
