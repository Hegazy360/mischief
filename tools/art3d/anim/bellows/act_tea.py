"""bellows/act_tea — the tea (loop, 480 f = the activity's 8 s; the audio table's sounds): on his stool at st_tea
(x 15.0, seat 0.55, facing the dresser, cheat 35 so the face is on the camera), the ×1.8 teacup on its saucer in his
left glove the whole time it is not at his lips:

  0-96    the KETTLE comes to his right glove (`prop lend set:kitchen_kettle grip_r` f 14) — he lifts it over the cup
          and pours (kettle_pour f 40), sets it back (`return` f 78)
  96-160  the saucer goes onto the shelf of his belly; the HONEY jar comes to his left palm (`lend set:kitchen_honey
          grip_l` f 104), the spoon dips in and the jar's lid FLIPS on the spoon contact (`set_anim lid_flip` f 126);
          the jar goes home on f 148 (`return`)
  160-250 the honey spoon into the cup (spoon_clink 169), a stir (tea_stir 182), a tap on the rim (spoon_clink 243)
  250-480 saucer back in the left glove, the cup in the right: a sniff (270), a pompous blow, the sip with the PINKIE
          up (tea_slurp 388) — f 420 (ACHOO-RIA!'s trigger, mark_s 7.0) is THE SIP of _lib.presets, the sneeze's f 0 —
          then the cup down on the saucer (teacup_clink 462), a shift on the stool (stool_creak 472).

Every lent piece is home by f 160 (`keeps` none). Staged at the stool (the kettle's home is a world point)."""
import math
from mathutils import Vector, Quaternion
from lib.clip import Clip
from lib import pose as P
from _lib.presets import *

L = 480
UP = Vector((0, 0, 1))
KETTLE_HOME = (14.40, 0.75, -1.82)          # house3d.json kitchen_kettle: rect centre-x + visual_offset, base y, z
CUP_REL = qz(15) @ CUP_LOW_R                # the cup on its saucer (in the left glove it sits exactly as held low)
BELLY_SHELF = Vector((0.0, -0.335, 0.93))   # the saucer resting on the top of his belly (chest-carried)
BELLY_TILT = qx(-30)                        # ... tilted with the barrel's curve


def build(ctx):
    sk = ctx.skel
    st = tea_stage()
    ts = TeaSet(ctx)
    c = Clip(ctx, "bellows/act_tea", length=L, loop=True, cheat_deg=TEA_CHEAT, stage=st, blend_in=8,
             notes="staged at the stool (st_tea); f 420 = the sneeze's f 0 (THE SIP)")
    kettle_arch_home = st.to_char((KETTLE_HOME[0], KETTLE_HOME[1] + KETTLE_ARCH, KETTLE_HOME[2]))
    kettle_arch_home.freeze()

    # ---- the body (FK keys; the arms are IK below) --------------------------------------------------------------
    def sit(fwd=-4.0, turn=4.0, hx=-8.0, hz=10.0, hy=0.0, pel=-2.0, extra=None):
        return merge(SIT, lean(fwd=fwd, turn=turn), head(x=hx, y=hy, z=hz), glove("l", 16, 10), glove("r", 20, 12),
                     {"pelvis": [("x", pel)]}, extra or {})
    REST = sit()
    c.key(0, REST)
    c.key(12, sit(fwd=0, turn=-6, hx=-2, hz=-6, extra=glove("r", 20, 12)), "in_out_sine")        # eyes the kettle
    c.key(22, sit(fwd=2, turn=-4, hx=0, hz=2, extra=grip("r", 70, 44)), "in_out_sine")          # it's in his glove
    c.key(40, sit(fwd=6, turn=2, hx=6, hz=12, extra=grip("r", 70, 44)), "in_out_cubic")         # pours, peering in
    c.key(66, sit(fwd=6, turn=2, hx=8, hz=14, extra=grip("r", 70, 44)))
    c.key(80, sit(fwd=0, turn=-4, hx=-4, hz=-2, extra=grip("r", 70, 44)), "in_out_sine")
    c.key(96, sit(fwd=-8, turn=4, hx=-8, hz=10), "in_out_sine")                                  # belly out: a shelf!
    c.key(110, sit(fwd=-10, turn=6, hx=-4, hz=16, extra=grip("r", 60, 40)), "in_out_sine")
    c.key(126, sit(fwd=-8, turn=6, hx=2, hz=18, extra=grip("r", 60, 40)), "in_out_sine")        # the lid flips
    c.key(132, sit(fwd=-10, turn=6, hx=-10, hy=6, hz=18, extra=grip("r", 60, 40)), "out_back")   # "huh" — a tilt
    c.key(150, sit(fwd=-6, turn=4, hx=-4, hz=12, extra=grip("r", 60, 40)), "in_out_sine")
    c.key(169, sit(fwd=-4, turn=4, hx=4, hz=10, extra=grip("r", 60, 40)), "in_out_sine")         # clink
    c.key(206, sit(fwd=-5, turn=5, hx=0, hy=4, hz=12, extra=grip("r", 60, 40)))                  # stirring, humming
    c.key(243, sit(fwd=-4, turn=4, hx=4, hy=-3, hz=10, extra=grip("r", 60, 40)), "in_out_sine")  # tap
    c.key(260, sit(fwd=-2, turn=4, hx=-2, hz=10, extra=pinkie_up("r", 1.0)), "in_out_sine")
    c.key(270, sit(fwd=-2, turn=5, hx=-10, hz=10, extra=pinkie_up("r", 1.0)), "in_out_sine")    # the sniff
    c.key(300, sit(fwd=-6, turn=5, hx=-12, hz=12, extra=pinkie_up("r", 1.0)), "out_cubic")
    c.key(330, sit(fwd=-5, turn=6, hx=-6, hy=5, hz=14, extra=pinkie_up("r", 1.0)), "in_out_sine")  # a pompous blow
    c.key(360, sit(fwd=-5, turn=6, hx=-6, hy=-3, hz=12, extra=pinkie_up("r", 1.0)), "in_out_sine")
    c.key(388, SIP_BODY, "in_out_sine")                                                           # slurp
    c.key(420, SIP_BODY, "in_out_sine")                                                           # THE SIP (trigger)
    c.key(446, merge(SIP_BODY, head(x=-14, z=12)), "in_out_sine")
    c.key(462, sit(fwd=-2, turn=4, hx=-4, hz=10, extra=pinkie_up("r", 1.0)), "in_out_sine")      # clink
    c.key(472, sit(fwd=2, turn=2, hx=-6, hz=8, pel=1), "in_out_sine")                           # creak
    c.key(L, REST, "in_out_sine")
    c.motion(lambda f: dangle(f, 60.0, 6.0, feet=False))
    c.motion(lambda f: {"spine_02": [("x", -1.4 * math.sin(2 * math.pi * f / 120.0))]})    # breathing (light: size)

    # ---- constraints ---------------------------------------------------------------------------------------------
    seat(c, 0, L)
    # D8: the face to the audience on the face beats (yaw only, the keyed pitch stays): a smug glance with the kettle
    # up (18-40), "huh" at the lid flip and the smug look after it (128-166), and the whole performance from the
    # smug stir to the loop seam (240-480 + 0-12: the sniff, the kiss, THE SIP = the sneeze's f 0, the creak)
    for f0, f1, ease in ((0, 12, (0, 8)), (18, 40, (6, 6)), (128, 166, (8, 8)), (240, L, (10, 0))):
        face_cam(c, f0, f1, ease=ease)
        c.look_camera(f0, f1, weight=1.0, blend=max(ease))

    R_REST = qz(-40) @ qx(10)
    PALM_R, PALM_L = ts.palm_rest("r"), ts.palm_rest("l")
    SHELF_R = BELLY_TILT @ SAUCER_L

    def saucer_frame(pose):
        """(centre, up, R-from-rest) of the saucer as it is in this pose."""
        cen = sk.carried(pose.world, "prop_saucer", ts.saucer_c)
        R = pose.world_rot("prop_saucer") @ sk.rest_q["prop_saucer"].inverted()
        return cen, (R @ UP).normalized(), R

    def hands(pose, f):
        on_shelf = 98 <= f < 166          # the saucer (+ the cup) balanced on his belly
        cup_in_hand = 266 <= f < 462
        # ---- LEFT --------------------------------------------------------------------------------------------
        hold = chest_point(pose, SAUCER_BELLY)
        shelf = chest_point(pose, BELLY_SHELF)
        if not on_shelf:
            tgt, R = hold, SAUCER_L
            if 86 <= f < 98:                        # glide it onto the belly shelf
                k = ramp(f, 86, 98)
                tgt, R = hold.lerp(shelf, k), SAUCER_L.slerp(SHELF_R, k)
            elif 166 <= f < 178:                    # and back off it
                k = ramp(f, 166, 178)
                tgt, R = shelf.lerp(hold, k), SHELF_R.slerp(SAUCER_L, k)
            if not cup_in_hand:
                arm_ik(pose, "l", tgt, POLE_L, hand_R=R, effector=ts.saucer_c)
        else:
            # the glove leaves the saucer on the shelf, turns palm up for the jar (100-156), then comes back onto the
            # saucer where it sits (156-166)
            arm_ik(pose, "l", shelf, POLE_L, hand_R=SHELF_R, effector=ts.saucer_c)
            wait = chest_point(pose, track(f, [(100, (0.26, -0.46, 0.80)), (110, (0.24, -0.50, 0.83)),
                                               (126, (0.22, -0.50, 0.85)), (140, (0.23, -0.50, 0.83)),
                                               (156, (0.26, -0.46, 0.80))]))
            arm_ik(pose, "l", wait, POLE_L, hand_R=JAR_L, effector=PALM_L, w=window(f, 100, 108, 152, 160))
        if 98 <= f < 164:
            place_prop(pose, sk, "prop_l", Quaternion(), ts.palm(pose, "l") + UP * 0.012,   # the lent jar on the palm
                       w=window(f, 98, 100, 160, 164))
        if on_shelf:
            ts.place_saucer(pose, shelf, SHELF_R)
        s_cen, s_up, s_R = saucer_frame(pose)
        cup_c = s_cen + s_up * (SAUCER_TOP + CUP_DROP)
        cup_R = s_R @ CUP_REL
        cup_top = cup_c + s_up * (CUP_DROP + 0.01)
        # ---- RIGHT -------------------------------------------------------------------------------------------
        rest_t = chest_point(pose, (-0.40, -0.40, 0.90))
        arm_ik(pose, "r", rest_t, POLE_R, hand_R=R_REST, effector=PALM_R)
        if 4 <= f < 92:                             # the kettle
            tilt = track(f, [(14, 0.0), (32, 0.0), (40, 46.0), (64, 50.0), (72, 0.0)])
            Rk = qy(tilt) @ qz(180)
            arch_pour = cup_top + Vector((-0.36, -0.02, 0.10)) + Rk @ (UP * KETTLE_ARCH)
            arch = kettle_arch_home.lerp(arch_pour, ramp(f, 16, 32)).lerp(kettle_arch_home, ramp(f, 72, 84))
            arm_ik(pose, "r", arch, POLE_R, hand_R=Rk @ KETTLE_R, effector=PALM_R, w=window(f, 4, 13, 80, 92))
            if 14 <= f < 88:
                place_prop(pose, sk, "prop_r", Rk, ts.palm(pose, "r") - Rk @ (UP * KETTLE_ARCH), w=window(f, 14, 20, 78, 88))
        if 104 <= f < 258:                          # the spoon: into the jar, then the cup (hidden from 250)
            if f < 150:
                mouth = ts.palm(pose, "l") + UP * (0.012 + JAR_MOUTH)
                dip = track(f, [(108, 0.20), (120, 0.10), (126, 0.035), (134, 0.06), (144, 0.16), (150, 0.22)])
                bowl_t = mouth + Vector((0.0, 0.0, dip - 0.03))
                palm_t = mouth + Vector((-0.06, -0.03, dip + 0.15))
            else:
                a = 2 * math.pi * (f - 169) / 24.0 if 169 <= f < 243 else 0.0
                r = 0.028 * ramp(f, 169, 176) * (1.0 - ramp(f, 236, 243))
                circ = Vector((r * math.cos(a), r * math.sin(a), 0.0))
                dip = track(f, [(150, 0.22), (164, 0.08), (169, 0.03), (243, 0.03), (250, 0.14)])
                bowl_t = cup_top + circ + Vector((0.0, 0.0, dip - 0.04))
                palm_t = cup_top + circ * 0.6 + Vector((-0.07, -0.02, dip + 0.14))
            arm_ik(pose, "r", palm_t, POLE_R, hand_R=qz(-60) @ qx(20), effector=PALM_R, w=window(f, 104, 112, 244, 252))
            ts.place_spoon(pose, ts.palm(pose, "r"), bowl_t - ts.palm(pose, "r"), w=window(f, 104, 108, 250, 257))
        if 250 <= f < 266:                          # takes the cup off the saucer
            arm_ik(pose, "r", cup_c, POLE_R, hand_R=cup_R, effector=ts.cup_c, w=ramp(f, 250, 262))
        if cup_in_hand:
            # the cup (and the saucer in the left) on THE SIP's path: sniff, a pompous blow, the sip (380-446 at lift
            # 1 = the sneeze's frame 0), then down onto the saucer (cup_low = where it sat)
            lift = track(f, [(266, 0.0), (274, 0.82), (300, 0.86), (312, 0.42), (380, 0.42), (388, 1.0), (446, 1.0),
                             (461, 0.0)])
            lift += 0.06 * math.sin(2 * math.pi * (f - 312) / 34.0) * window(f, 312, 320, 372, 380)
            sip_arms(ts, pose, lift=max(0.0, min(1.0, lift)))
        elif 462 <= f < 474:                        # lets go of the cup
            arm_ik(pose, "r", cup_c, POLE_R, hand_R=cup_R, effector=ts.cup_c, w=1.0 - ramp(f, 462, 474))
        if not cup_in_hand:
            ts.place_cup(pose, cup_c, cup_R)
    c.custom(hands, 0, L)

    def settle_fingers(pose, f):
        """Two held left-glove joints nudged 0.5 deg: their constant values otherwise defeat the converter's key
        reduction (glb_to_res angle_to noise on identical quaternions: ~470 identical keys each, ~23 KB)."""
        for b in ("middle_02_l", "pinky_02_l"):
            pose.set_rot(b, pose.get(b)[1] @ Quaternion((1.0, 0.0, 0.0), math.radians(0.5)))
        pose.solve()
    c.custom(settle_fingers, 0, L)

    # ---- events ---------------------------------------------------------------------------------------------------
    c.event(0, "prop", op="show", prop="teacup")
    c.event(0, "prop", op="show", prop="saucer")
    c.event(14, "prop", op="lend", prop="set:kitchen_kettle", socket="grip_r", frames=6)
    c.event(78, "prop", op="return", prop="set:kitchen_kettle", frames=8)
    c.event(104, "prop", op="lend", prop="set:kitchen_honey", socket="grip_l", frames=6)
    c.event(108, "prop", op="show", prop="spoon")
    c.event(126, "set_anim", hotspot="kitchen_honey", anim="lid_flip")
    c.event(148, "prop", op="return", prop="set:kitchen_honey", frames=8)
    c.event(250, "prop", op="hide", prop="spoon")
    c.beats(kettle=(14, 86), pour=(40, 72), honey=(104, 156), stir=(169, 243), stirring=(182, 236),
            sniff=(270, 300), sip=(388, 455), put_down=(462, 472), creak=(472, 480))
    for f, p in ((0, "pompous"), (12, "suspicious"), (22, "smug"), (40, "admiring"), (80, "pompous"),
                 (104, "admiring"), (126, "huh"), (134, "smug"), (169, "hum"), (243, "smug"), (262, "pompous"),
                 (270, "sniff"), (300, "blissful"), (330, "kiss"), (360, "smug"), (388, "sip"), (446, "blissful"),
                 (462, "relief"), (472, "pompous")):
        c.face(f, p)
    return c
