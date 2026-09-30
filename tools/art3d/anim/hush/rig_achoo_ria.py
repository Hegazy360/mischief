"""hush/rig_achoo_ria — ACHOO-RIA! (rig:achoo_ria, tier Q = 48 f, lock rig_pm; REDESIGN §4.3, index R5): the honey jar
sits high on the shelf (its placed reach target ≈ 2.08 m), so Hush hops onto Bellows' own kitchen stool (seat 0.55 m;
the view eases her to the jar's reach_pos x 15.0, z -1.4), takes the OVERSIZED pepper pot, lifts it over the open jar
and gives it three big shakes (pops at f 16 / 26 / 36: the glove on the reach target, a pepper stream each time), puts
it back, hops down. Cheat 10°, her head turned to the audience so the face reads through the joke; the stool wobbles
on the landing and the take-off; the jar's own rig animation runs from the view's progress.

Staging comes from house3d.json (reach_geometry) — re-bake when r3d-sets moves the jar."""
import math
from mathutils import Vector
from lib.clip import Clip
from lib.stage import Stage, reach_geometry
from lib.pose import merge, sym, mirror
from lib.hush_presets import ARMS_DOWN, STAND, TIPTOE, gloves, glove, lean, head

L = 48
SHAKES = (16, 26, 36)
FALLBACK = {"target": (14.85, 2.0825, -1.66), "pos": {"x": 15.0, "z": -1.4, "step": "stool:kitchen_stool", "step_h": 0.55},
            "facing": -1, "band": "high"}

CROUCH = {"thigh_l": [("x", -44), ("z", 6)], "calf_l": [("x", 74)], "foot_l": [("x", -28)],
          "thigh_r": [("x", -40), ("z", -6)], "calf_r": [("x", 70)], "foot_r": [("x", -28)]}
TUCK = {"thigh_l": [("x", -80), ("z", 6)], "calf_l": [("x", 110)], "foot_l": [("x", 20)],
        "thigh_r": [("x", -76), ("z", -6)], "calf_r": [("x", 106)], "foot_r": [("x", 20)]}
ARMS_BACK = sym({"upperarm_l": [("y", 55), ("z", 35)], "lowerarm_l": [("z", -10)], "hand_l": [("x", 20)]})
ARMS_UP = sym({"upperarm_l": [("y", 22), ("z", -14)], "lowerarm_l": [("z", -24)], "hand_l": [("x", -10)]})
BALANCE_L = {"clavicle_l": [("y", -6)], "upperarm_l": [("y", 8), ("z", 6)], "lowerarm_l": [("z", -14), ("y", 10)],
             "hand_l": [("x", -10), ("y", -20)]}


def build(ctx):
    g = reach_geometry("kitchen_honey", fallback=FALLBACK)
    pos = g["pos"]
    st = Stage(x=pos["x"], z=pos["z"], facing=g["facing"], cheat=10.0)
    h = float(pos.get("step_h") or 0.55)
    T = st.to_char(g["target"])                  # the reach target in her space (her right, a little in front, high)
    T.freeze()
    up = Vector((0, 0, 1))
    c = Clip(ctx, "hush/rig_achoo_ria", length=L, lock="rig_pm", cheat_deg=10.0, stage=st, audio="own", blend_in=6,
             notes="staged at %s from %s" % (st.as_json(), g.get("source")))
    stand = merge(ARMS_DOWN, STAND, gloves(20, 12), head(x=-4, z=10))
    c.key(0, stand)
    REACH_R = {"clavicle_r": [("y", 10)], "upperarm_r": [("y", -20), ("z", 25)], "lowerarm_r": [("z", 30)]}
    c.key(3, merge(stand, CROUCH, ARMS_BACK, {"upperarm_r": [("y", -60), ("z", 20)]}, lean(fwd=18), head(x=-24)), "in_out_sine")  # anticipation
    c.key(5, merge(stand, TUCK, ARMS_UP, REACH_R, lean(fwd=4), head(x=-12)), "out_quad")           # airborne, reaching
    c.key(6, merge(stand, CROUCH, BALANCE_L, REACH_R, lean(fwd=14, side=4), head(x=-6, z=20)), "in_quad")   # lands: squash
    SHRUG_R = {"clavicle_r": [("y", 18), ("z", 6)]}                    # the reaching shoulder rides up
    HIGH_TOE = {"foot_l": [("x", 52)], "ball_l": [("x", -48)], "foot_r": [("x", 52)], "ball_r": [("x", -48)]}
    c.key(10, merge(stand, TIPTOE, BALANCE_L, SHRUG_R, lean(fwd=4, side=6, turn=-10), head(x=-8, y=6, z=30)), "out_cubic")
    body = merge(stand, HIGH_TOE, BALANCE_L, SHRUG_R, lean(fwd=3, side=9, turn=-10))
    for f in (14, 22, 32):
        c.key(f, merge(body, {"clavicle_l": [("y", -10)]}))
    for f in SHAKES:
        c.key(f, merge(body, lean(fwd=7, side=7, turn=-12), {"calf_l": [("x", 8)], "calf_r": [("x", 8)]}), "pop")
    c.key(38, merge(body, lean(fwd=5, side=8, turn=-10)), "out_back")
    c.key(41, merge(stand, BALANCE_L, REACH_R, lean(fwd=4, side=4)))
    c.key(43, merge(stand, CROUCH, ARMS_BACK, REACH_R, lean(fwd=16), head(x=-14)), "in_out_sine")  # anticipation down
    c.key(45, merge(stand, TUCK, ARMS_UP, lean(fwd=6), head(x=-6)), "out_quad")
    c.key(46, merge(stand, CROUCH, sym({"upperarm_l": [("y", 30), ("z", -20)]}), lean(fwd=12)), "in_quad")   # lands
    c.key(48, merge(stand, {"thigh_l": [("x", -20)], "calf_l": [("x", 36)], "thigh_r": [("x", -18)], "calf_r": [("x", 34)]},
                    lean(fwd=6)), "out_quad")
    c.ground()
    c.step_up("stool", h, 3, 6, decor_id="kitchen_stool")
    c.step_down(43, 46)
    c.auto_plant(speed_m_s=0.0)

    # the right glove: grab the pot beside the jar (f 7), lift it over the jar mouth, three shakes on the target
    pot_home = T + Vector((0.10, 0.02, -0.16))
    def hand_target(f):
        if f <= 8:
            return pot_home
        if f <= 14:
            k = (f - 8) / 6.0
            k = k * k * (3 - 2 * k)
            return pot_home.lerp(T + up * 0.045, k)
        if f >= 37:
            k = min(1.0, (f - 37) / 5.0)
            k = k * k * (3 - 2 * k)
            return T.lerp(pot_home, k)
        # between the shakes: the pot rises (the wind-up), then POPS down onto the target on the shake frame
        prev = max([s for s in SHAKES if s <= f] or [14])
        nxt = min([s for s in SHAKES if s > f] or [38])
        if f in SHAKES:
            return T
        k = (f - prev) / float(nxt - prev)
        rise = 0.045 * math.sin(math.pi * min(1.0, k * 1.15)) if prev in SHAKES else 0.045
        return T + up * rise
    UPRIGHT = [("z", 90), ("y", -90)]

    def tip(f):
        """The pot tips down hard on each pop and rolls back up through the wind-up."""
        if f < 13 or f >= 42:
            return 0.0
        if f >= SHAKES[-1]:
            return 60.0 * max(0.0, 1.0 - (f - SHAKES[-1]) / 6.0) ** 2        # the last shake settles out
        prev = max([s for s in SHAKES if s <= f] or [14])
        if prev not in SHAKES:
            return -20.0 * min(1.0, (f - 13) / 3.0)
        k = (f - prev) / 10.0
        return 60.0 * max(0.0, 1.0 - k * 1.5) - 25.0 * min(1.0, k * 1.5)

    c.look(("camera",), 9, 41, weight=0.85, blend=4)            # before the IK: the look turns the spine too
    c.ik("r", lambda f: hand_target(f), 4, 43, pole=(-0.9, 0.5, -0.3), hand=lambda f: UPRIGHT + [("x", tip(f))],
         effector="grip_r", blend=5, world=False)
    c.pop_frames.extend(SHAKES)
    # props, set parts, sounds, fx
    c.event(8, "prop", op="show", prop="pepper_pot")
    c.event(8, "set_part", hotspot="kitchen_honey", part="pepper_pot", visible=False)
    c.event(42, "prop", op="hide", prop="pepper_pot")
    c.event(42, "set_part", hotspot="kitchen_honey", part="pepper_pot", visible=True)
    for f in SHAKES:
        c.sfx(f, "pepper_shake")
        c.event(f, "fx", id="pepper_stream")
    c.sfx(6, "stool_creak")
    c.sfx(46, "step_pizz_up")
    c.face(0, "determined")
    c.face(6, "grin")
    c.face(12, "sneak")
    c.face(16, "snicker")
    c.face(26, "grin")
    c.face(36, "laugh")
    c.face(41, "smug")
    c.face(46, "happy")
    return c
