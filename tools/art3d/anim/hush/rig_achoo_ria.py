"""hush/rig_achoo_ria — ACHOO-RIA! (rig:achoo_ria, tier Q = 48 f, lock rig_pm; REDESIGN §4.3, index R5): the honey jar
sits on the high shelf, so Hush hops onto Bellows' own kitchen stool (seat 0.55 m; the view has eased her to the jar's
reach_pos), leans out over the edge — one leg kicked back for balance — to snatch the tall pepper pot standing beside
the jar, swings it over the open jar and gives it three big shakes (pops at f 16 / 26 / 36: the pot's SPOUT on the
placed reach target = the jar's mouth, a pepper stream each time), leans out again to put it back, hops down. Cheat
10°, the head turned to the audience through the joke; the stool wobbles on the landing and the take-off.

Staging comes from house3d.json (reach_geometry: the jar's reach_target and reach_pos; the set pot's spot = the jar's
`pepper_pot` part pivot) — re-bake (`bake.sh hush rig_achoo_ria`) when r3d-sets moves the jar."""
import math
from mathutils import Vector, Quaternion
from lib.clip import Clip
from lib.stage import Stage, reach_geometry, house3d, prop_point
from lib import pose as P
from lib.pose import merge, sym
from lib.hush_presets import ARMS_DOWN, STAND, gloves, lean, head

L = 48
SHAKES = (16, 26, 36)
GRAB, PUT = 7, 42                     # the pot leaves the shelf / is back on it
FALLBACK = {"target": (14.55, 2.0225, -1.72), "pos": {"x": 14.85, "z": -1.42, "step": "stool:kitchen_stool", "step_h": 0.55},
            "facing": -1, "band": "high"}
POT_PIVOT = (-0.2, 0.0, 0.0)          # the set pot's part pivot in the honey_jar prop (tools/art3d/set/build.py), unscaled
POT_HOLES_Y = 0.288                   # the set pot's holes above the shelf (prop-local, unscaled)

CROUCH = {"thigh_l": [("x", -44), ("z", 6)], "calf_l": [("x", 74)], "foot_l": [("x", -28)],
          "thigh_r": [("x", -40), ("z", -6)], "calf_r": [("x", 70)], "foot_r": [("x", -28)]}
TUCK = {"thigh_l": [("x", -80), ("z", 6)], "calf_l": [("x", 110)], "foot_l": [("x", 20)],
        "thigh_r": [("x", -76), ("z", -6)], "calf_r": [("x", 106)], "foot_r": [("x", 20)]}
ARMS_BACK = sym({"upperarm_l": [("y", 55), ("z", 35)], "lowerarm_l": [("z", -10)], "hand_l": [("x", 20)]})
ARMS_UP = sym({"upperarm_l": [("y", 22), ("z", -14)], "lowerarm_l": [("z", -24)], "hand_l": [("x", -10)]})
BALANCE_L = {"clavicle_l": [("y", -6)], "upperarm_l": [("y", 8), ("z", 6)], "lowerarm_l": [("z", -14), ("y", 10)],
             "hand_l": [("x", -10), ("y", -20)]}
READY_R = {"clavicle_r": [("y", 12)], "upperarm_r": [("y", 28), ("z", -4)], "lowerarm_r": [("z", 70)],   # a claw by
           "hand_r": [("x", -20)]}                                                                  # her shoulder
REACH_R = {"clavicle_r": [("y", 14)], "upperarm_r": [("y", 30), ("z", 55)], "lowerarm_r": [("z", 15)]}   # out front, for the pot
SHRUG_R = {"clavicle_r": [("y", 26), ("z", 8)]}                      # the reaching shoulder rides up
HIGH_TOE = {"foot_l": [("x", 52)], "ball_l": [("x", -48)], "foot_r": [("x", 52)], "ball_r": [("x", -48)]}
# the lean-out: on the ball of the right foot, the left leg kicked back, the hips over the seat's front edge
LEAN_OUT = merge({"thigh_r": [("x", -6), ("z", -4)], "calf_r": [("x", 8)], "foot_r": [("x", 48)], "ball_r": [("x", -46)],
                  "thigh_l": [("x", 38), ("z", 8)], "calf_l": [("x", 52)], "foot_l": [("x", 34)], "ball_l": [("x", -10)],
                  "pelvis": [("x", 18)], "_pelvis": (-0.05, -0.12, 0.0)},        # (L27: the hips stay within 0.15 m)
                 lean(fwd=34, side=-14, turn=20), head(x=-32, z=18),
                 {"clavicle_l": [("y", -14)], "upperarm_l": [("y", -12), ("z", 40)], "lowerarm_l": [("z", -20)],
                  "hand_l": [("x", -20)]})


def pot_spot(g):
    """World point of her grip on the set's pepper pot (standing beside the jar on the shelf): the `pepper_pot` part
    pivot, her grip 0.215 m under its holes."""
    if g.get("source") == "fallback":
        return (g["target"][0] - 0.29, g["target"][1] - 0.0075, g["target"][2] - 0.06)
    sc = float((house3d().get("hotspots", {}).get("kitchen_honey") or {}).get("scale", 1.5))
    return prop_point("kitchen_honey", (POT_PIVOT[0], POT_HOLES_Y - 0.215 / sc, POT_PIVOT[2]))


def build(ctx):
    sk = ctx.skel
    g = reach_geometry("kitchen_honey", fallback=FALLBACK)
    pos = g["pos"]
    st = Stage(x=pos["x"], z=pos["z"], facing=g["facing"], cheat=10.0)
    h = float(pos.get("step_h") or 0.55)
    T = st.to_char(g["target"])                  # the jar's mouth in her space (front-right, high)
    T.freeze()
    POT = st.to_char(pot_spot(g))                # her grip on the set pot (further out front)
    POT.freeze()
    up = Vector((0, 0, 1))
    c = Clip(ctx, "hush/rig_achoo_ria", length=L, lock="rig_pm", cheat_deg=10.0, stage=st, audio="own", blend_in=6,
             notes="staged at %s from %s" % (st.as_json(), g.get("source")))
    stand = merge(ARMS_DOWN, STAND, gloves(20, 12), head(x=-4, z=10))
    c.key(0, stand)
    c.key(3, merge(stand, CROUCH, ARMS_BACK, READY_R, lean(fwd=18), head(x=-24)), "linear")         # anticipation
    c.key(5, merge(stand, TUCK, ARMS_UP, REACH_R, lean(fwd=6), head(x=-14)), "out_quad")             # airborne
    c.key(6, merge(stand, CROUCH, BALANCE_L, REACH_R, lean(fwd=14, side=4), head(x=-10, z=16)), "in_quad")   # lands
    c.key(GRAB, merge(stand, LEAN_OUT, REACH_R), "out_quad")                                           # snatch!
    c.key(GRAB + 2, merge(stand, LEAN_OUT, REACH_R, lean(fwd=26, side=-4, turn=16)))                   # teeters
    WALL = {"_pelvis": (-0.04, 0.0, 0.0)}
    # over the jar she leans BACK (screen right, away from it) so her head clears the jar and the pot from the camera
    body = merge(stand, HIGH_TOE, BALANCE_L, REACH_R, SHRUG_R, WALL, lean(fwd=-6, side=6, turn=10))
    c.key(14, merge(body, head(x=-6, z=24)), "in_out_sine")                                            # back upright
    for f in (22, 32):
        c.key(f, merge(body, {"clavicle_l": [("y", -10)]}))
    for f in SHAKES:                              # the pop: the hips kick, the free arm flings out
        c.key(f, merge(body, lean(fwd=-2, side=9, turn=12), {"pelvis": [("y", -5)]},
                       {"upperarm_l": [("y", 0), ("z", 14)], "lowerarm_l": [("z", -4), ("y", 10)]}), "pop")
    c.key(37, merge(body, lean(fwd=-4, side=7, turn=10)), "out_back")
    c.key(PUT - 1, merge(stand, LEAN_OUT, REACH_R), "in_out_sine")                                    # puts it back
    c.key(PUT, merge(stand, LEAN_OUT, REACH_R, lean(fwd=25, side=-4, turn=15)))
    c.key(44, merge(stand, CROUCH, {"foot_l": [("x", -6)], "foot_r": [("x", 2)]}, ARMS_BACK, READY_R, lean(fwd=16),
                    head(x=-14)), "in_out_sine")                                                  # springs back, crouches
    TUCK_DN = merge(TUCK, {"foot_l": [("x", 4)], "foot_r": [("x", 4)]})                              # toes for the floor
    c.key(46, merge(stand, TUCK_DN, ARMS_UP, lean(fwd=6), head(x=-6)), "out_quad")
    LAND = merge(CROUCH, {"foot_l": [("x", -14)], "foot_r": [("x", -14)]})                            # the balls first
    c.key(47, merge(stand, LAND, sym({"upperarm_l": [("y", 30), ("z", -20)]}), lean(fwd=12)), "in_quad")
    c.key(48, merge(stand, LAND, {"calf_l": [("x", 80)], "calf_r": [("x", 76)]}, sym({"upperarm_l": [("y", 40), ("z", -14)]}),
                    lean(fwd=10)), "out_quad")                                                     # sinks into it
    c.ground()
    c.step_up("stool", h, 3, 6, decor_id="kitchen_stool")
    c.step_down(44, 47)
    c.auto_plant(speed_m_s=0.0)

    # --- the pot: her glove's world orientation and the spout (fx_pepper, 0.215 m out of the fist along the pot) --------
    grip_rest = ctx.socket("grip_r")[1]
    spout_off = sk.head("fx_pepper") - grip_rest          # rest armature space, rides rigidly on hand_r (prop_r unkeyed)
    UPRIGHT = P.rot_q([("z", 90), ("y", -90)])            # fingers forward, the pot standing up out of the fist
    toward = Vector((T.x, T.y, 0.0)) - Vector((sk.head("upperarm_r").x, sk.head("upperarm_r").y, 0.0))
    toward.normalize()                                    # from her shoulder toward the jar, level

    def tilted(phi):
        """The glove's orientation with the pot's holes pointing `phi` degrees from straight DOWN, out toward the jar."""
        d = Vector((0, 0, -1)) * math.cos(math.radians(phi)) + toward * math.sin(math.radians(phi))
        axis_up = UPRIGHT @ spout_off.normalized()
        return axis_up.rotation_difference(d) @ UPRIGHT

    COCK, POP = 78.0, 52.0                                 # the wind-up (lifted, near level) / the shake (jerked down)

    def shake(f):
        """(spout lift above the mouth, tilt phi) during the shakes: pop on the frame, ease back to cocked."""
        prev = max([s for s in SHAKES if s <= f] or [0])
        if prev not in SHAKES:
            return 0.07, COCK
        u = min(1.0, (f - prev) / 7.0)
        e = 1.0 - (1.0 - u) ** 2
        return 0.07 * e, POP + (COCK - POP) * e

    def smooth(k):
        k = min(1.0, max(0.0, k))
        return k * k * (3 - 2 * k)

    def pot_state(f):
        """(grip target, glove orientation) at frame f in her space."""
        if f <= GRAB + 1:                                   # at the set pot
            return POT, UPRIGHT
        if f <= 15:                                         # swing it over the jar mouth, tilting over
            u = min(1.0, max(0.0, (f - (GRAB + 1)) / float(15 - (GRAB + 1))))
            k = 0.5 * (u + smooth(u))
            q = UPRIGHT.slerp(tilted(COCK), k)
            spout = (POT + UPRIGHT @ spout_off).lerp(T + up * 0.07, k)
            return spout - q @ spout_off, q
        if f <= SHAKES[-1] + 1 or f in SHAKES:
            lift, phi = shake(f)
            q = tilted(phi)
            return T + up * lift - q @ spout_off, q
        u = min(1.0, max(0.0, (f - (SHAKES[-1] + 1)) / float(PUT - (SHAKES[-1] + 1))))   # back to the shelf, upright
        k = 0.5 * (u + smooth(u))                            # a flatter ramp: the pot turns ~130 deg in 4 frames
        lift, phi = shake(f)
        q = tilted(phi).slerp(UPRIGHT, k)
        spout = (T + up * lift).lerp(POT + UPRIGHT @ spout_off, k)
        return spout - q @ spout_off, q

    c.look(("camera",), 10, 40, weight=0.85, blend=4)     # before the IK: the look turns the spine too
    # the IK takes over from the KEYED hand during the hop (f 2 -> 7) and gives it back after the put-down (-> 47)
    c.ik_handoff("r", lambda f: pot_state(f)[0], 2, PUT + 5, pole=(-0.9, 0.5, -0.3), hand=lambda f: pot_state(f)[1],
                 effector="grip_r", ramp=5, ramp_out=5, soft=0.03, hand_ramp=(5, 5))
    c.pop_frames.extend(SHAKES)
    c.pop_frames.extend([4, GRAB])                         # the launch (the arm shoots up for the pot) / the snatch
    c.spout_target = T                                     # (exp scripts / notes: the spout's target at the shakes)
    # props, set parts, sounds, fx
    c.event(GRAB, "prop", op="show", prop="pepper_pot")
    c.event(GRAB, "set_part", hotspot="kitchen_honey", part="pepper_pot", visible=False)
    c.event(PUT, "prop", op="hide", prop="pepper_pot")
    c.event(PUT, "set_part", hotspot="kitchen_honey", part="pepper_pot", visible=True)
    for f in SHAKES:
        c.sfx(f, "pepper_shake")
        c.event(f, "fx", id="pepper_stream")
    c.sfx(6, "stool_creak")
    c.sfx(47, "step_pizz_up")
    c.face(0, "determined")
    c.face(6, "grin")
    c.face(GRAB, "sneak")
    c.face(16, "snicker")
    c.face(26, "grin")
    c.face(36, "laugh")
    c.face(PUT, "smug")
    c.face(47, "happy")
    return c
