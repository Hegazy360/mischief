"""bellows/act_warmup — the warm-up at the gramophone (loop, 480 f = the activity's 8 s; audio "own": the 2D 1200 f row's two phrases
re-timed into one 8 s loop for r3d-integrate's audio table): he taps the needle down with the tip of his BATON
(`set_anim parlour_gramophone play` f 24 — ALLEGRO-GO-GO! triggers at mark_s 0.5 = f 30, the dizzy spin starts from
this pose), turns to the Stalls, fills his chest, and sings his scales — the baton beating time, the left glove on
his heart, the belly trembling with the vibrato — a top note that rattles the vase (vase_nudge), a second phrase, a
low note down in his knees, and back. The baton is in his hand the whole loop (REDESIGN §4.2: the signature prop).

Staged at st_gramophone (stand_x 1730 px = 8.65 m, z -1.4, facing -1, cheat 35); the record is a world point."""
import math
from mathutils import Vector
from lib.clip import Clip
from lib.stage import Stage
from _lib.presets import *

L = 480
X, Z = 8.65, -1.4
RECORD = (8.20, 1.02, -1.95)          # the gramophone's turntable (house3d.json parlour_gramophone, x1.5 model)
HEART = ("spine_03", Vector((0.12, -0.36, 0.96)))     # the left glove on his chest


def build(ctx):
    st = Stage(x=X, z=Z, facing=-1, cheat=35.0)
    c = Clip(ctx, "bellows/act_warmup", length=L, loop=True, cheat_deg=35, stage=st, audio="own", blend_in=10,
             notes="staged at st_gramophone; f 24 needle drop, f 30 = ALLEGRO-GO-GO!'s trigger")
    ts = TeaSet(ctx)
    rec = st.to_char(RECORD)
    rec.freeze()

    def stand(fwd=0.0, side=0.0, turn=0.0, hx=0.0, hy=0.0, hz=0.0, arm=None, knees=0.0):
        legs = merge(STAND, {"thigh_l": [("x", -2 - 18 * knees), ("z", 8)], "calf_l": [("x", 3 + 36 * knees)],
                             "thigh_r": [("x", -2 - 18 * knees), ("z", -8)], "calf_r": [("x", 3 + 36 * knees)],
                             "foot_l": [("x", -1 - 18 * knees)], "foot_r": [("x", -1 - 18 * knees)]})
        return merge(legs, ARMS_POMPOUS, grip("r", 66, 40), glove("l", 14, 8), pompous(1.0),
                     lean(fwd=fwd, side=side, turn=turn), head(x=hx, y=hy, z=hz), arm or {})

    def baton(k, up=0.0):
        """The baton arm beating time: k = -1 (down beat) .. +1 (up), `up` raises the whole arm (a top note)."""
        return {"clavicle_r": [("y", 6 + 6 * up)], "upperarm_r": [("y", -18 - 26 * up - 10 * k), ("z", 46)],
                "lowerarm_r": [("z", 70 - 20 * up + 18 * k)], "hand_r": [("x", -20 - 24 * k), ("y", 10)]}
    # 0-40: the needle (with the baton's tip), a turn to the Stalls, the big breath
    c.key(0, stand(turn=-6, hx=-6, hz=-10, arm=baton(0.0)))
    c.key(14, stand(fwd=6, turn=-14, hx=4, hz=-28), "in_out_sine")          # a look back at the record
    c.key(24, stand(fwd=8, turn=-16, hx=6, hz=-30), "in_out_quad")          # tap — the needle drops
    c.key(32, stand(fwd=2, turn=-8, hx=-2, hz=-10, arm=baton(0.2)), "out_cubic")
    c.key(40, stand(fwd=-8, turn=4, hx=-14, hz=12, arm=baton(1.0, 0.3)), "in_out_sine")   # the breath: chest up
    # phrase 1 (40-250): beating time on every 30 f, the top note 100-160
    k = 1.0
    for t in range(70, 250, 30):
        k = -k
        top = 1.0 if 100 <= t <= 160 else 0.0
        c.key(t, stand(fwd=-6 - 6 * top, side=2 * k, turn=4, hx=-12 - 10 * top, hy=3 * k, hz=12,
                       arm=baton(k, up=top)), "in_out_sine")
    # phrase 2 (250-460): a flourish, then the low note down in his knees (350-400)
    c.key(250, stand(fwd=-8, turn=6, hx=-14, hz=14, arm=baton(1.0, 0.5)), "in_out_sine")
    c.key(275, stand(fwd=-4, side=4, turn=6, hx=-10, hy=4, hz=14, arm=baton(-1.0, 0.2)), "in_out_sine")
    c.key(300, stand(fwd=-6, side=-4, turn=6, hx=-12, hy=-4, hz=12, arm=baton(1.0, 0.2)), "in_out_sine")
    c.key(325, stand(fwd=-2, turn=4, hx=-6, hz=10, arm=baton(-1.0)), "in_out_sine")
    c.key(350, stand(fwd=10, turn=2, hx=14, hz=8, arm=baton(-1.0, -0.4), knees=1.0), "in_out_cubic")   # LOW
    c.key(380, stand(fwd=12, turn=2, hx=16, hz=8, arm=baton(-0.6, -0.4), knees=1.0))
    c.key(405, stand(fwd=-4, turn=4, hx=-10, hz=12, arm=baton(1.0, 0.2)), "out_back")
    c.key(430, stand(fwd=-7, side=3, turn=4, hx=-13, hy=3, hz=12, arm=baton(-1.0, 0.3)), "in_out_sine")
    c.key(456, stand(fwd=-2, turn=0, hx=-8, hz=0, arm=baton(0.0)), "in_out_sine")
    c.key(L, stand(turn=-6, hx=-6, hz=-10, arm=baton(0.0)), "in_out_sine")
    # the vibrato: the belly trembles while he holds a note (motion on the belly bone; the view's jiggle rides it)
    c.motion(lambda f: {"belly": [("x", 5.0 * math.sin(2 * math.pi * f / 8.0))]},
             40, 456, weight=lambda f: window(f, 40, 60, 440, 456))
    c.ground()
    c.auto_plant(speed_m_s=0.0)
    face_cam(c, 40, 456, ease=(8, 8))          # D8: he sings to the Stalls (yaw only: the chest-up pitch stays)
    # the needle: the baton's tip onto the record (IK: the fingertips), then the left glove on his heart
    tip = ctx.skel.head("prop_baton") + Vector((-0.34, -0.01, 0.02))     # the baton's tip (rides the right glove)
    tip.freeze()
    needle = rec + Vector((0.0, 0.0, 0.03))

    def tap(pose, f):
        arm_ik(pose, "r", needle, POLE_R, hand_R=qx(40) @ qz(170), effector=tip, w=window(f, 6, 16, 26, 34))
    c.custom(tap, 6, 34)
    c.ik("l", HEART, 0, L, pole=POLE_L, hand=[("z", -100), ("x", 20)], effector="palm", blend=0, world=False)
    c.event(0, "prop", op="show", prop="baton")
    c.event(24, "set_anim", hotspot="parlour_gramophone", anim="play")
    c.mark(24, "contact")
    c.event(40, "voice", id="vo_bellows_warmup_1")
    for f in (45, 55, 65, 75, 86):
        c.sfx(f, "vase_nudge", sync=False)
    c.event(250, "voice", id="vo_bellows_warmup_3")
    for f in (254, 266, 278):
        c.sfx(f, "vase_nudge", sync=False)
    c.beats(needle=(6, 30), phrase1=(40, 250), top_note=(100, 160), phrase2=(250, 456), low_note=(350, 405))
    for f, p in ((0, "pompous"), (14, "suspicious"), (24, "smug"), (34, "inhale"), (40, "sing_mid"), (100, "sing_big"),
                 (160, "sing_mid"), (210, "sing_small"), (250, "sing_big"), (300, "sing_mid"), (350, "sing_small"),
                 (405, "sing_big"), (430, "sing_mid"), (456, "pompous")):
        c.face(f, p)
    c.look_camera(40, 456, weight=1.0, blend=8)
    return c
