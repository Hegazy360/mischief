"""hush/act_snicker — AFTER the arm (flavour:snicker, 60 f, interruptible): both gloves clap over her mouth and she
folds forward at the hips into a giggling hunch, one knee jerked up (the other heel popped), the shoulders shaking
with a stifled giggle; a sly look out at the audience mid-giggle (runtime gaze to the camera + the `glance` face, both
facing-proof), one last snort and she settles back to the rest pose by f 48 (40 f of action inside 60). Cheat 35
(face to camera). The 64 px verb board samples f 18 (lead 22:15Z: gloves over the mouth + the hunch + the knee, a
different SHAPE from the squeak's straight-armed squat; before the gaze window, which turns the upper spine)."""
import math
from lib.clip import Clip
from lib.pose import merge, sym
from mathutils import Vector
from lib.hush_presets import ARMS_DOWN, STAND, CHIN, gloves, lean, head, breath

L = 60


def build(ctx):
    c = Clip(ctx, "hush/act_snicker", length=L, cheat_deg=35, audio="table", blend_in=4, blend_out=10)
    stand = merge(ARMS_DOWN, STAND, gloves(20, 14), head(x=-3))
    # the tee-hee: knees knocked together and bent, one heel popped up, shoulders to the ears, gloves at the chin
    TEEHEE = {"thigh_l": [("x", -22), ("z", -6)], "calf_l": [("x", 38)], "foot_l": [("x", -14)],
              "thigh_r": [("x", -30), ("z", 8)], "calf_r": [("x", 56)], "foot_r": [("x", 36)], "ball_r": [("x", -30)]}
    # the giggling hunch: the hinge at the hips (the pelvis tips forward, the standing thigh undoes it), the left knee
    # jerked up with the heel flicked up behind her (the coy tee-hee kick — a sneak's knee steps forward instead), the
    # right heel popped on the ball; shoulders to the ears
    HUNCH_LEGS = {"pelvis": [("x", 24)],
                  "thigh_l": [("x", -70), ("z", -6)], "calf_l": [("x", 132)], "foot_l": [("x", 36)],
                  "thigh_r": [("x", -40), ("z", 6)], "calf_r": [("x", 34)], "foot_r": [("x", 30)], "ball_r": [("x", -30)]}
    hunch = merge(STAND, TEEHEE, CHIN, gloves(62, 40), {"clavicle_l": [("y", -24)], "clavicle_r": [("y", 24)]})
    fold = merge(STAND, HUNCH_LEGS, CHIN, gloves(70, 44), {"clavicle_l": [("y", -26)], "clavicle_r": [("y", 26)]})
    peek = merge(STAND, TEEHEE, CHIN, gloves(70, 44), {"clavicle_l": [("y", -24)], "clavicle_r": [("y", 24)]})
    c.key(0, stand)
    c.key(2, merge(stand, {"clavicle_l": [("y", -10)], "clavicle_r": [("y", 10)]}, lean(fwd=-4), head(x=-10)), "out_quad")
    half = sym({"clavicle_l": [("y", -6)], "upperarm_l": [("y", 54), ("z", -48)], "lowerarm_l": [("y", -54), ("z", -12)],
                "hand_l": [("x", -18), ("z", -10)]})
    c.key(5, merge(stand, half, gloves(40, 24), lean(fwd=6), head(x=4)), "in_out_sine")
    c.key(8, merge(fold, lean(fwd=34, turn=-6), head(x=-10, z=-4)), "out_quad")             # gloves over the mouth
    c.key(20, merge(fold, lean(fwd=40, side=4, turn=-4), head(x=-12, y=8, z=4)))
    c.key(26, merge(peek, lean(fwd=22, side=6, turn=4), head(x=-12, y=10, z=6)), "in_out_sine")   # the sly look
    c.key(36, merge(peek, lean(fwd=20, side=6, turn=4), head(x=-8, y=10, z=6)))
    c.key(40, merge(peek, lean(fwd=24, turn=-8), head(x=8, z=-4)), "out_quad")              # the snort
    c.key(48, merge(stand, lean(fwd=2), head(x=-4)), "in_out_cubic")                        # composure
    c.key(L, stand)
    # the giggle: shoulders and head shake in bursts (8 Hz), fading out by the snort
    def giggle(f):
        if f < 7 or f > 44:
            return {}
        env = min(1.0, (f - 7) / 4.0) * min(1.0, (44 - f) / 6.0)
        burst = 0.55 + 0.45 * math.sin(2 * math.pi * (f - 7) / 18.0)
        s = math.sin(2 * math.pi * f / 7.5) * env * burst
        return {"spine_03": [("x", 3.5 * s)], "clavicle_l": [("y", -5 * s)], "clavicle_r": [("y", 5 * s)],
                "Head": [("x", 4 * s), ("z", 1.5 * s)]}
    c.motion(giggle)
    c.motion(lambda f: breath(f, 90.0, 0.6))
    # both gloves over her mouth by IK (riding on the head, so they shake with the giggle): the right palm on the mouth,
    # the left clapped over it, elbows out and down
    MOUTH = Vector((0.0, -0.150, 1.272))                   # in front of her mouth (armature rest; the face front ~-0.11)
    c.ik("r", ("Head", MOUTH + Vector((-0.022, 0.0, 0.004))), 4, 46, blend=(4, 8), pole=(-1.0, 0.1, -0.7), world=False)
    c.ik("l", ("Head", MOUTH + Vector((0.026, -0.040, -0.012))), 4, 46, blend=(4, 8), pole=(1.0, 0.1, -0.7),
         world=False)
    c.ground()
    c.plant("r", 0, L, part="ball")                        # the heel pops up; the ball (and toes) stay put
    c.auto_plant(speed_m_s=0.0, sides=("l",))              # the left foot leaves the floor for the knee jerk
    c.look_camera(22, 40, weight=0.9, blend=4)
    c.face(0, "grin")
    c.face(6, "snicker")
    c.face(24, "glance")
    c.face(38, "snicker")
    c.face(46, "smug")
    c.mark(8, "accent")
    c.pop_frames.extend([6, 7])                            # the clap: both gloves snap over the mouth (2 f)
    return c
