"""bellows/rx_sneeze_blast_a — ACHOO-RIA!'s payoff (Gate 0, 165 f, lock "sim"; reactions.json sneeze_blast_a): on his
stool at st_tea, mid-sip, the peppered honey gets him — "ah… ahh… AHHH…" with the chest swelling, the head tipping
back and the teary face kept on the camera; a false stop ("hm.", a smug re-sip); a gasp; CHOO (f 94: the pop, the
vinyl puff, hit-stop 5, the 1.4 punch-in, the bouffant flipped over his eyes, the teacup and saucer launched) and he
rockets backwards on his own stool (the view carries him 94 -> 112 along the travel arc into the sink), arms
windmilling, slippers up; in the sink at 112 (knock_on) with the slippers kicking and the stool tumbling away; then
dazed under a ring of vinyl stars, sitting up groggy (145-165).

Staged at the stool (x 15.0, z -1.4, facing -1, cheat 35: his left side and face toward the audience). Frame 0 is
act_tea's sip (both clips build it from _lib.presets SIP_BODY + sip_arms). Sounds: the audio table (R3)."""
import math
from mathutils import Vector
from lib.clip import Clip
from lib import pose as P
from _lib.presets import *

L = 165


def build(ctx):
    st = tea_stage()
    ts = TeaSet(ctx)
    c = Clip(ctx, "bellows/rx_sneeze_blast_a", length=L, lock="sim", cheat_deg=TEA_CHEAT, stage=st, blend_in=0,
             blend_out=10, tags=["reaction", "take", "sneeze"],
             notes="staged at the stool (st_tea); the view carries the root 94 -> 112 into the sink (landing kitchen.sink)")
    HIDE_FX = fx_hidden("fx_choo", "fx_stars")

    def body(*parts, **kw):
        p = merge(HIDE_FX, *parts)
        if kw.get("nose") is not None:
            p["nose"] = {"r": [("x", kw["nose"][0])], "s": kw["nose"][1]}
        if kw.get("belly") is not None:
            p["belly"] = {"r": [], "s": kw["belly"]}
        return p

    # ---- the build (0-94): seated, arms on the tea set (IK below), the FK body keys --------------------------------
    SEAT_LEGS = SIT
    c.key(0, body(SIP_BODY, nose=(0, 1.0), belly=1.0))
    c.key(8, body(SEAT_LEGS, lean(fwd=-2, turn=6), head(x=-4, z=14), pinkie_up("r", 0.6), {"pelvis": [("x", -2)]},
                  nose=(-10, 1.12), belly=1.02), "out_quad")
    c.key(12, body(SEAT_LEGS, lean(fwd=-2, turn=6), head(x=-5, z=14), pinkie_up("r", 0.5), {"pelvis": [("x", -2)]},
                   nose=(8, 0.96), belly=1.02), "in_out_sine")
    c.key(16, body(SEAT_LEGS, lean(fwd=-3, turn=6), head(x=-6, z=14), pinkie_up("r", 0.5), {"pelvis": [("x", -3)]},
                   nose=(-12, 1.16), belly=1.03), "in_out_sine")
    # "ah" (0-20) -> "ahh" (20-44): the chest swells, the head tips back, turned toward the audience
    c.key(24, body(SEAT_LEGS, lean(fwd=-9, turn=8), head(x=-13, z=18), pinkie_up("r", 0.4), {"pelvis": [("x", -4)],
                   "clavicle_l": [("y", -8)], "clavicle_r": [("y", 8)]}, nose=(-14, 1.2), belly=1.07), "out_cubic")
    c.key(36, body(SEAT_LEGS, lean(fwd=-7, turn=8), head(x=-10, z=16), pinkie_up("r", 0.4), {"pelvis": [("x", -4)],
                   "clavicle_l": [("y", -5)], "clavicle_r": [("y", 5)]}, nose=(6, 1.06), belly=1.05), "in_out_sine")
    # "AHHH" (44-74): the big one — arched back on the stool, the head right back but the face still on the camera
    c.key(48, body(SEAT_LEGS, lean(fwd=-16, turn=10), head(x=-20, z=20), pinkie_up("r", 0.3), {"pelvis": [("x", -6)],
                   "clavicle_l": [("y", -13)], "clavicle_r": [("y", 13)]}, nose=(-18, 1.28), belly=1.1), "out_cubic")
    c.key(62, body(SEAT_LEGS, lean(fwd=-20, turn=10), head(x=-24, z=20), pinkie_up("r", 0.3), {"pelvis": [("x", -7)],
                   "clavicle_l": [("y", -16)], "clavicle_r": [("y", 16)]}, nose=(-20, 1.34), belly=1.13), "in_out_sine")
    c.key(74, body(SEAT_LEGS, lean(fwd=-23, turn=11), head(x=-27, z=21), pinkie_up("r", 0.3), {"pelvis": [("x", -8)],
                   "clavicle_l": [("y", -18)], "clavicle_r": [("y", 18)]}, nose=(-22, 1.38), belly=1.15), "in_out_sine")
    # the false stop (74-94): "hm." — it passes; relief, then a smug little re-sip
    c.key(82, body(SEAT_LEGS, lean(fwd=-2, turn=6), head(x=-2, z=14), pinkie_up("r", 0.8), {"pelvis": [("x", -2)]},
                   nose=(0, 1.06), belly=1.0), "out_cubic")
    c.key(88, body(SEAT_LEGS, lean(fwd=-4, turn=5), head(x=-10, z=12), pinkie_up("r", 1.1), {"pelvis": [("x", -3)]},
                   nose=(0, 1.04), belly=1.0), "in_out_sine")
    c.key(91, body(SEAT_LEGS, lean(fwd=-5, turn=5), head(x=-11, z=12), pinkie_up("r", 1.1), {"pelvis": [("x", -3)]},
                   nose=(-8, 1.12), belly=1.02), "in_out_sine")
    # HUP — the gasp (93): the head snaps back, the chest fills (the wind-up against the CHOO)
    c.key(93, body(SEAT_LEGS, lean(fwd=-14, turn=8), head(x=-22, z=16), pinkie_up("r", 0.6), {"pelvis": [("x", -10)],
                   "clavicle_l": [("y", -14)], "clavicle_r": [("y", 14)]}, nose=(-24, 1.4), belly=1.14), "out_quad")
    # ---- CHOO (94, the pop): head whipped down, arms flung, the legs kick, the puff blooms -------------------------
    CHOO_ARMS = sym({"clavicle_l": [("y", -10), ("z", 10)], "upperarm_l": [("y", 6), ("z", 18)],
                     "lowerarm_l": [("z", -14)], "hand_l": [("x", -30), ("y", -30)]})
    c.key(94, body(CHOO_ARMS, open_hand("l", 24), open_hand("r", 24), lean(fwd=12, turn=-4), head(x=14, y=-6, z=-16),
                   {"pelvis": [("x", 7)], "thigh_l": [("x", -104), ("z", 10)], "calf_l": [("x", 74)],
                    "thigh_r": [("x", -98), ("z", -10)], "calf_r": [("x", 70)], "foot_l": [("x", -20)],
                    "foot_r": [("x", -20)], "fx_choo": {"r": [], "s": 0.72}}, nose=(20, 0.9), belly=0.94), "pop")
    # blown back (97): the recoil launches him — tipping back on the stool, legs up, arms thrown up
    BLOWN_ARMS = sym({"clavicle_l": [("y", -22)], "upperarm_l": [("y", -78), ("z", -8)], "lowerarm_l": [("z", -10)],
                      "hand_l": [("x", -20)]})
    c.key(97, body(BLOWN_ARMS, open_hand("l", 20), open_hand("r", 20), lean(fwd=4), head(x=-8, z=6),
                   {"pelvis": [("x", -56)], "thigh_l": [("x", -100), ("y", -18)], "calf_l": [("x", 10)],
                    "thigh_r": [("x", -92), ("y", 18)], "calf_r": [("x", 16)], "foot_l": [("x", -28)],
                    "foot_r": [("x", -26)], "fx_choo": {"r": [], "s": 0.66}}, nose=(0, 1.0), belly=1.04), "out_cubic")

    # the flight (97-112): windmilling arms, flutter-kicking slippers, riding the stool backwards
    def fly(k, arm_ph, puff=0.0):
        """k 0..1 along the flight; arm_ph the windmill phase (deg); puff = the CHOO puff's scale (it dissipates)."""
        a = math.radians(arm_ph)
        arms = {"clavicle_l": [("y", -14)], "clavicle_r": [("y", 14)],
                "upperarm_l": [("y", -40 + 30 * math.sin(a)), ("z", -70 * math.cos(a))],
                "upperarm_r": [("y", 40 - 30 * math.sin(a + 2.4)), ("z", 70 * math.cos(a + 2.4))],
                "lowerarm_l": [("z", -24 - 16 * math.sin(a))], "lowerarm_r": [("z", 24 + 16 * math.sin(a + 2.4))],
                "hand_l": [("x", -20)], "hand_r": [("x", -20)]}
        kick = math.sin(a * 1.5)
        legs = {"thigh_l": [("x", -100 - 8 * kick), ("y", -16)], "calf_l": [("x", 16 + 10 * kick)], "foot_l": [("x", -30)],
                "thigh_r": [("x", -94 + 8 * kick), ("y", 16)], "calf_r": [("x", 24 - 10 * kick)], "foot_r": [("x", -28)]}
        return body(arms, legs, open_hand("l", 22), open_hand("r", 22), lean(fwd=8 + 4 * k), head(x=-4 + 8 * k, z=6),
                    {"pelvis": [("x", -48 - 14 * k)], "fx_choo": {"r": [], "s": puff}}, belly=1.02)
    for f, k, ph, pf in ((100, 0.2, 60, 0.34), (103, 0.4, 150, 0.0), (106, 0.6, 240, 0.0), (109, 0.8, 330, 0.0)):
        c.key(f, fly(k, ph, pf), "linear")
    # SPLASH (112, knock_on): into the basin — squashed, slippers straight up out of the sink
    SINK_ARMS = sym({"clavicle_l": [("y", 6)], "upperarm_l": [("y", 36), ("z", 24)], "lowerarm_l": [("z", -10)],
                     "hand_l": [("x", 10), ("y", 20)]})

    def sink(sq=0.0, kick=0.0, loll=0.0, sit=0.0, star=0.0):
        """In the sink: sq = the landing squash, kick = slipper kick phase (-1..1), loll = head roll, sit = 0..1 up,
        star = the dazed star ring's scale."""
        # stuck in the basin like a cork: bottom down, the torso back, the little legs straight up over the front rim
        legs = {"thigh_l": [("x", -118 + 18 * sit - 10 * kick), ("y", -40 + 20 * sit)], "calf_l": [("x", 6 + 40 * sit + 14 * kick)],
                "foot_l": [("x", 18 - 10 * sit)],
                "thigh_r": [("x", -112 + 18 * sit + 10 * kick), ("y", 38 - 20 * sit)], "calf_r": [("x", 10 + 40 * sit - 14 * kick)],
                "foot_r": [("x", 16 - 10 * sit)]}
        arms = merge(SINK_ARMS, {"upperarm_l": [("y", 36 + 30 * sit), ("z", 24 - 6 * sit)],
                                 "upperarm_r": [("y", -36 - 30 * sit), ("z", -24 + 6 * sit)]})
        return body(arms, legs, glove("l", 30, 16), glove("r", 30, 16),
                    lean(fwd=14 + 10 * sq - 4 * sit, side=4 * loll), head(x=14 + 6 * sq - 8 * sit, y=10 * loll, z=10),
                    {"pelvis": [("x", -56 + 30 * sit)], "fx_stars": {"r": [], "s": star}}, belly=1.0 - 0.06 * sq)
    c.key(112, sink(sq=1.0), "pop")
    c.key(115, sink(sq=-0.3, kick=0.6), "out_quad")
    c.key(119, sink(sq=0.1, kick=-0.8, loll=0.4), "in_out_sine")
    c.key(125, sink(kick=0.9, loll=-0.5), "in_out_sine")
    c.key(131, sink(kick=-0.7, loll=0.6), "in_out_sine")
    c.key(138, sink(kick=0.6, loll=-0.4), "in_out_sine")
    c.key(145, sink(kick=-0.3, loll=0.3), "in_out_sine")
    # dazed (145-165): sits up groggy, head circling under the stars
    c.key(149, sink(kick=0.1, loll=-0.3, sit=0.2, star=1.25), "out_back")
    c.key(152, sink(kick=0.2, loll=-0.6, sit=0.45, star=1.0), "in_out_sine")
    c.key(158, sink(kick=0.0, loll=0.5, sit=0.7, star=1.0), "in_out_sine")
    c.key(165, sink(kick=0.0, loll=-0.2, sit=0.8, star=1.0), "out_back")

    # ---- motion layers ---------------------------------------------------------------------------------------------
    c.motion(lambda f: dangle(f, 44.0, 6.0, feet=False), 0, 93)     # = act_tea's dangle at its f 420 (THE SIP)
    c.motion(lambda f: tremble(f, 0.5 + 1.2 * ramp(f, 44, 70), ("spine_03", "Head", "neck_01")), 44, 78,
             weight=lambda f: window(f, 44, 52, 74, 78))
    c.motion(lambda f: breath(f, 70.0, 0.6), 0, 44)
    c.motion(lambda f: {"Head": [("z", 9 * math.sin(2 * math.pi * (f - 145) / 20.0)),
                                 ("y", 6 * math.cos(2 * math.pi * (f - 145) / 20.0))]}, 145, L,
             weight=lambda f: ramp(f, 145, 150))
    c.motion(lambda f: {"fx_stars": [("z", 12.0 * (f - 145))]}, 145, L)
    # the stool rides under him from 95; at 112 it is knocked away backwards, tumbling
    c.motion(lambda f: {"ride": {"r": [("x", -38 * ramp(f, 112, 128) - 220 * ramp(f, 113, 128) ** 1.4)],
                                 "t": (0.12 * ramp(f, 112, 128), 0.55 * ramp(f, 112, 128), -0.25 * ramp(f, 118, 128))}},
             112, L)

    # ---- constraints: the seat, the look at the audience, the tea set in his gloves ---------------------------------
    seat(c, 0, L)
    c.look(("camera",), 0, 93, weight=0.4, blend=(0, 4))

    cup_keys = [(0, 1.0), (8, 0.55), (20, 0.15), (74, 0.0), (82, 0.55), (88, 1.0), (91, 0.95), (93, 0.55)]
    out_keys = [(0, CUP_BELLY), (8, CUP_BELLY), (20, (-0.24, -0.46, 1.00)), (44, (-0.34, -0.40, 1.08)),
                (74, (-0.40, -0.34, 1.14)), (82, (-0.16, -0.46, 1.02)), (93, (-0.22, -0.44, 1.04))]
    sau_keys = [(0, SAUCER_CHIN), (8, SAUCER_BELLY), (44, (-0.02, -0.46, 0.92)), (74, (0.02, -0.44, 0.95)),
                (82, SAUCER_BELLY), (88, SAUCER_CHIN), (93, SAUCER_BELLY)]
    tilt_keys = [(0, 0.0), (20, 6.0), (44, 16.0), (74, 26.0), (82, 4.0), (93, 8.0)]

    def tea_hands(pose, f):
        w = 1.0 if f <= 93 else 0.0
        if w <= 0.0:
            return
        lift = track(f, cup_keys)
        low = track(f, out_keys)
        sau = track(f, sau_keys)
        tilt = track(f, tilt_keys)
        sip_arms(ts, pose, lift=lift, cup_low=low, saucer_at=sau, saucer_R=qy(-tilt) @ SAUCER_L, w_r=w, w_l=w)
    c.custom(tea_hands, 0, 93)

    # the CHOO puff stays where it burst (in front of his nose at f 94) while he is blown back from it
    def puff_stays(pose, f):
        w = 1.0 - ramp(f, 98, 103)            # eases back onto the head while it shrinks away (gone by 103)
        loc0, rot0, sc0 = pose.get("fx_choo")
        place_bone(pose, "fx_choo", c.evaluate(94).world["fx_choo"])
        loc1, rot1, _ = pose.get("fx_choo")
        pose.basis["fx_choo"] = (loc0.lerp(loc1, w), P.qslerp(rot0, rot1, w), sc0)
        pose.update_from("fx_choo")
    c.custom(puff_stays, 95, 103)
    c.pop_frames.append(95)          # the blast's recoil frame (the puff pinned in front of him, the body snapped back)

    # ---- events -------------------------------------------------------------------------------------------------
    c.beats(anticipation=(74, 94), accent=(94, 97), hold=(97, 145), settle=(145, 165),
            ah=(0, 20), ahh=(20, 44), ahhh=(44, 74), false_stop=(74, 94), hm=(76, 88), choo=(94, 97),
            in_the_sink=(97, 145), dazed=(145, 165), sits_up=(154, 165))
    c.event(0, "prop", op="show", prop="teacup")
    c.event(0, "prop", op="show", prop="saucer")
    c.event(4, "cam", op="push", zoom=1.15, frames=70)
    c.mark(94, "accent")
    c.event(94, "hitstop", frames=5)
    c.event(94, "cam", op="punch", zoom=1.4, **{"in": 11}, hold=90, out=21, yaw=5)
    c.event(94, "shake", trauma=0.55)
    c.event(94, "fx", id="choo_puff")
    c.event(94, "look", set={"bouffant": "flipped"})
    c.event(94, "prop", op="launch", prop="teacup", vel=[-1.5, 3.5, 0.0], spin=540)
    c.event(94, "prop", op="launch", prop="saucer", vel=[0.9, 2.6, 0.6], spin=-420)
    c.event(94, "jiggle", bones=["bouffant", "tail_l", "tail_r", "belly"], kick=0.9)
    c.event(95, "decor", id="kitchen_stool", visible=False)
    c.event(95, "prop", op="show", prop="stool")
    c.mark(112, "knock_on")
    c.event(112, "shake", trauma=0.6)
    c.event(112, "fx", id="drops")
    c.event(112, "jiggle", bones=["belly", "tail_l", "tail_r"], kick=0.7)
    c.event(128, "prop", op="hide", prop="stool")
    c.event(158, "decor", id="kitchen_stool", visible=True)
    c.mark(165, "release")
    # the face (2D sneeze vocabulary; the take swaps on the accent)
    for f, p in ((0, "sip"), (8, "sneeze_build"), (40, "sneeze_build2"), (64, "sneeze_build3"), (82, "relief"),
                 (88, "smug"), (93, "sneeze_gasp"), (94, "sneeze_choo"), (97, "wild_take"), (112, "dazed_open"),
                 (146, "dazed"), (151, "dazed_open"), (158, "dazed")):
        c.face(f, p)
    return c
