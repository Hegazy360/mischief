"""hush/act_squeak — the squeak (state:squeaking, 18 f): she whips Clarence out of the brace (grab f 3, attached to
her glove f 4), thrusts him OUT at arm's length in front of her chest (f 6, the anticipation: up on her toes) and
SQUEEZES (f 8): both fists clamp round his middle at the end of her straight arms while the whole body squashes down
behind them — knees deep, shoulders up to her ears — and he bulges between the fists, his neck and beak shooting out
forward-up well beyond her outline (his comb flares); a springy recoil, and she tucks him back into the brace by f 16.
The 64 px verb board samples f 8 (lead 22:15Z: squeak = the chicken held OUT at arm's length, a clear protrusion, her
body squashed; never the chest-height clutch that read as the snicker). Table row: no events (the sim plays the
squeak)."""
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
    SQUASH = {"thigh_l": [("x", -62), ("z", 10)], "calf_l": [("x", 104)], "foot_l": [("x", -42), ("z", -4)],
              "thigh_r": [("x", -60), ("z", -10)], "calf_r": [("x", 102)], "foot_r": [("x", -42), ("z", 4)],
              "pelvis": [("x", 14)]}
    c.key(0, stand)
    c.key(3, merge(stand, GRAB_R, glove("r", 50, 30), lean(fwd=6, turn=-10), head(x=14, z=-10)), "out_quad")   # grab
    c.key(6, merge(stand, OUT_R, OUT_L, glove("r", 40, 30), glove("l", 30, 20), lean(fwd=-8, turn=10),
                   head(x=-12, z=10)), "out_back")                                                           # up, out!
    c.key(8, merge(stand, SQUASH, OUT_R, OUT_L, SQUEEZE_UP, LIFT, glove("r", 92, 60), glove("l", 88, 50), lean(fwd=-4, turn=8),
                   head(x=4, z=12)), "pop")                                                                 # SQUEEZE
    c.key(10, merge(stand, SQUASH, OUT_R, OUT_L, SQUEEZE_UP, LIFT, glove("r", 92, 60), glove("l", 88, 50),
                    lean(fwd=-4, turn=8), head(x=6, z=12)))                                                   # held
    c.key(12, merge(stand, mix(SQUASH, {}, 0.45), OUT_R, OUT_L, mix(SQUEEZE_UP, {}, 0.5), glove("r", 74, 50),
                    glove("l", 66, 40), lean(fwd=-2, turn=8), head(x=-8, z=10)), "in_out_sine")               # recoil
    c.key(15, merge(stand, GRAB_R, glove("r", 50, 30), lean(fwd=4, turn=-6), head(x=10, z=-4)), "in_out_sine")  # tuck
    c.key(L, stand, "in_out_sine")
    # Clarence's own squeeze (his body bone bulges; his neck + head ride prop_clarence, rigid) and comb flare
    def squash(f):
        if f < 7 or f > 13:
            return {}
        k = 1.0 if 8 <= f <= 10 else (max(0.0, 1.0 - (f - 10) / 3.0) if f > 10 else (f - 7) / 1.0)
        # he bulges between her fists (x2.4 across, the part the 64 px silhouette reads beyond the gloves; r3d-fix-gags
        # Q-G5 / Q-V1: "fiddling with something small and yellow" — the squeeze must swell the toy, big)
        return {"clarence_body": {"s": (1.0 + 1.40 * k, 1.0 + 0.70 * k, 1.0 + 1.40 * k)},
                "clarence_comb": {"s": (1.0 + 2.0 * k, 1.0 + 2.0 * k, 1.0 + 2.0 * k), "r": [("x", -36 * k)]}}
    c.motion(squash)
    # the gloves on him by IK (riding on her chest, so they follow the squash): both fists round him at the end of her
    # straight arms, stacked like a bat grip, his neck + head pointing forward-up out of the top fist (his long axis =
    # the glove's finger axis in grip_r) — the protrusion the 64 px board reads, well clear of her outline
    sk = ctx.skel
    chest = sk.head("spine_03")
    FIST = chest + Vector((-0.02, -0.43, 0.12))              # at arm's length, shoulder height (reach ~0.47 of 0.50 m)
    AXIS = Vector((0.04, -0.62, 0.78)).normalized()          # his head: forward-up, out beyond the fists
    ROLL = Quaternion(AXIS, math.radians(ROLL_DEG))
    HAND_R = ROLL @ (sk.rest_q["hand_r"] @ Vector((0, 1, 0))).rotation_difference(AXIS)
    HAND_L = ROLL @ (sk.rest_q["hand_l"] @ Vector((0, 1, 0))).rotation_difference(AXIS)
    TAIL = FIST - AXIS * 0.105 + Vector((0.035, 0.0, 0.0))  # under his bulging body (it shows between the fists)
    c.ik("r", ("spine_03", FIST), 4, 16, blend=(2, 8), pole=(-0.9, 0.2, -0.5), hand=HAND_R, effector="grip_r",
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
    # lead note D8: the squeeze's laugh faces the audience (runtime gaze, facing-proof) — from f 9, after the squeeze
    # frame: the gaze turns the whole upper spine, which would swing the straight arms toward the camera on f 8
    c.look_camera(9, 14, weight=0.8, blend=2)
    return c
