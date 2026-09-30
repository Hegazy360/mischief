"""bellows/bit_warmup — the warm-up's squeak bit (activities.json squeak_bits.bit_warmup, 90 f, lock "sim", base layer;
the sim plays it the tick he hears Hush's squeak at the gramophone): "His high note cracks into a yodel; he clutches
his throat: '...the pipes.'" (GDD §4.1 warmup row, the Prologue's first player laugh ≈ 6–7 s).

  0-8     still singing the top note, chin up, baton raised, operatic left palm out (the warm-up carriage)
  8       the squeak lands in his ear — the note CRACKS (a pop: eyes bulge, the head jerks back)
  8-30    ... into a yodel he cannot stop: the head waggles side to side, the barrel jiggles, the arms flap wider
  30-36   anticipation — the arms flung wide, the chest up, the face horrified
  36      ACCENT (= the squeak_bit rim-shot at +0.6 s, audio_director): both gloves SNAP to his throat, elbows winged
          out — the choking silhouette — mouth clamped
  36-70   a moving hold: he pats his throat, peers down at it, then turns the whole face to the house (D8):
          "...the pipes." (voice f 48), a wounded little cough
  70-90   dignity recovered: chest out, baton back up, into the warm-up carriage again

Staged at st_gramophone (house.json stand_x 1730 → 8.65 m; house3d.json bellows_z -1.4, yaw -55 → facing -1, cheat 35).
The face beats turn the head to the camera (lead ruling D8): baked for this staging + the runtime gaze entries."""
import math
from mathutils import Vector
from lib.clip import Clip
from lib.stage import Stage
from _lib.presets import *

L = 90
GRAM_X, GRAM_Z, GRAM_FACING, GRAM_CHEAT = 8.65, -1.4, -1, 35.0

# the warm-up carriage: chest out, chin up, the baton hand raised (conducting himself), the left palm out, operatic
SING_ARMS = {"clavicle_l": [("y", -6)], "upperarm_l": [("y", 38), ("z", -44)], "lowerarm_l": [("z", -34)],
             "hand_l": [("x", -30), ("y", -10)],
             "clavicle_r": [("y", 10)], "upperarm_r": [("y", -34), ("z", 40)], "lowerarm_r": [("z", 78)],
             "hand_r": [("x", -24), ("y", 8)]}
# the yodel: arms flapping wider and higher
FLAP_A = {"clavicle_l": [("y", -12)], "upperarm_l": [("y", 18), ("z", 14)], "lowerarm_l": [("z", -16)],
          "hand_l": [("x", -34)],
          "clavicle_r": [("y", 14)], "upperarm_r": [("y", -10), ("z", -22)], "lowerarm_r": [("z", 18)],
          "hand_r": [("x", -30)]}
FLAP_B = {"clavicle_l": [("y", -16)], "upperarm_l": [("y", 6), ("z", 28)], "lowerarm_l": [("z", -10)],
          "hand_l": [("x", -38), ("y", -16)],
          "clavicle_r": [("y", 18)], "upperarm_r": [("y", 4), ("z", -34)], "lowerarm_r": [("z", 10)],
          "hand_r": [("x", -34), ("y", 16)]}
# the anticipation: flung wide and up (against the snap in)
WIDE = sym({"clavicle_l": [("y", -12), ("z", 16)], "upperarm_l": [("y", 30), ("z", 56)], "lowerarm_l": [("z", -4)],
            "hand_l": [("x", -30), ("y", -20)]})
# the clutch: the LEFT glove (the camera side) grabs his throat with the elbow winged up high, the right glove (the
# baton pointing down) pressed to his heart — the wounded soprano, readable at 64 px
CLUTCH = {"clavicle_l": [("y", -22), ("z", -6)], "upperarm_l": [("y", 10), ("z", -40)], "lowerarm_l": [("z", -128)],
          "hand_l": [("x", 10)],
          "clavicle_r": [("y", 6), ("z", 4)], "upperarm_r": [("y", -62), ("z", 40)], "lowerarm_r": [("z", 100)],
          "hand_r": [("x", 30)]}

THROAT_L = ("spine_03", Vector((0.17, -0.30, 0.99)))      # the side of his neck under the left jowl
HEART_R = ("spine_03", Vector((-0.10, -0.43, 0.88)))      # the top of the barrel, over his heart


def body(*parts):
    return merge(STAND, *parts)



def hide_fx(c):
    """Every key carries the FX bones at scale 0 (they are shown only when a clip keys their scale; an overlay's
    unkeyed rest scale would show the CHOO puff and the stars)."""
    hid = fx_hidden("fx_choo", "fx_stars", "fx_notes")
    k0, o0 = c.key, c.overshoot
    c.key = lambda f, pose, ease="in_out_sine": k0(f, merge(hid, pose), ease)
    c.overshoot = lambda f, pose, **kw: o0(f, merge(hid, pose), **kw)
    return c

def build(ctx):
    st = Stage(x=GRAM_X, z=GRAM_Z, facing=GRAM_FACING, cheat=GRAM_CHEAT)
    c = Clip(ctx, "bellows/bit_warmup", length=L, lock="sim", cheat_deg=GRAM_CHEAT, stage=st, blend_in=6,
             blend_out=8, audio="own", tags=["bit", "squeak_bit"],
             notes="staged at st_gramophone (x 8.65, z -1.4, facing -1, cheat 35); the baton stays in his right glove")
    hide_fx(c)
    SING = merge(SING_ARMS, grip("r", 64, 40), open_hand("l", 12), pompous(1.3), head(x=-16, z=4))
    c.key(0, body(SING, {"_pelvis": (0.0, 0.0, 0.0)}))
    c.key(6, body(SING, lean(fwd=-9), head(x=-20, z=4)), "in_out_sine")                # the note swells
    # THE CRACK (8): the head jerks back and up, eyes bulge
    c.key(8, body(SING, lean(fwd=-12, side=-3), head(x=-30, y=-8, z=8)), "pop")
    # the yodel (8-30): the head waggles side to side, the arms flap
    for i, f in enumerate((11, 14, 17, 20, 23, 26)):
        s = 1.0 if i % 2 == 0 else -1.0
        arms = FLAP_A if i % 2 == 0 else FLAP_B
        c.key(f, body(arms, grip("r", 64, 40), open_hand("l", 18), lean(fwd=-10, side=6 * s, turn=3 * s),
                      head(x=-22, y=18 * s, z=6 - 6 * s)), "in_out_sine")
    # anticipation (30-36): flung wide, chest up, horrified
    c.key(30, body(WIDE, grip("r", 64, 40), open_hand("l", 24), lean(fwd=-18), head(x=-26, z=4)), "in_out_quad")
    c.key(34, body(WIDE, grip("r", 64, 40), open_hand("l", 26), lean(fwd=-24), head(x=-32, z=4),
                   {"upperarm_l": [("y", 26), ("z", 62)], "upperarm_r": [("y", -26), ("z", -62)]}), "in_out_sine")
    # ACCENT (36): SNAP — both gloves to the throat, elbows winged, the head ducks into them
    c.key(36, body(CLUTCH, grip("r", 70, 44), glove("l", 50, 30), lean(fwd=12, side=4), head(x=4, y=10, z=2)), "pop")
    c.overshoot(38, body(CLUTCH, grip("r", 70, 44), glove("l", 46, 28), lean(fwd=8, side=4), head(x=0, y=12, z=2)), pct=0.3,
                frames=4)
    # the moving hold: pats, peers down at the throat, then the face to the house
    c.key(46, body(CLUTCH, grip("r", 70, 44), glove("l", 30, 20), lean(fwd=-6, side=5), head(x=-18, y=14, z=0)),
          "in_out_sine")
    c.key(52, body(CLUTCH, grip("r", 70, 44), glove("l", 40, 24), lean(fwd=-8, side=3), head(x=-20, y=10, z=0)),
          "in_out_sine")
    c.key(62, body(CLUTCH, grip("r", 70, 44), glove("l", 36, 22), lean(fwd=-6, side=1), head(x=-12, y=12, z=0)),
          "in_out_sine")
    c.key(68, body(CLUTCH, grip("r", 70, 44), glove("l", 30, 20), lean(fwd=-4), head(x=-6, y=-4, z=0)),
          "in_out_sine")
    # recovered: chest out, back into the warm-up carriage
    c.key(78, body(SING, lean(fwd=-10), head(x=-18, z=2), {"upperarm_r": [("y", -26), ("z", 44)]}), "out_cubic")
    c.key(L, body(SING), "in_out_sine")

    # the gloves on the throat (IK over the clutch; blends in over the snap, out into the recovery)
    c.ik("l", THROAT_L, 35, 74, pole=(0.9, 0.25, 0.2), effector="palm", blend=(1, 6), world=False)
    c.ik("r", HEART_R, 35, 74, pole=(-0.9, 0.3, -0.3), effector="palm", blend=(1, 8), world=False)
    # little pats on the throat (the left glove) and the cough shake
    c.motion(lambda f: {"hand_l": [("x", 12 * math.sin(2 * math.pi * (f - 44) / 8.0))]}, 44, 60,
             weight=lambda f: window(f, 44, 47, 56, 60))
    c.motion(lambda f: {"spine_03": [("x", 5 * math.exp(-((f - 58) / 3.0) ** 2))],
                        "Head": [("x", 6 * math.exp(-((f - 58) / 3.0) ** 2))]}, 52, 66)
    c.motion(lambda f: breath(f, 90.0, 1.0))
    c.motion(lambda f: tremble(f, 1.4, ("spine_03", "Head")), 8, 30, weight=lambda f: window(f, 8, 10, 27, 30))

    c.ground()
    c.auto_plant(speed_m_s=0.0)
    # the face on the house (D8): the crack, the clutch, "...the pipes."
    c.look(("camera",), 0, 90, weight=0.75, blend=(0, 8))
    c.look_camera(4, 32, weight=1.0, blend=6)
    c.look_camera(40, 76, weight=1.0, blend=8)

    c.beats(anticipation=(30, 35), accent=(35, 38), hold=(38, 70), settle=(70, L),
            crack=(8, 11), yodel=(11, 30), the_pipes=(46, 62))
    c.event(0, "prop", op="show", prop="baton")
    c.event(8, "voice", id="vo_bellows_yodel")
    c.event(36, "jiggle", bones=["bouffant", "tail_l", "tail_r", "belly"], kick=0.5)
    c.mark(36, "accent")
    c.event(46, "voice", id="vo_bellows_the_pipes")
    for f, p in ((0, "sing_big"), (8, "shock"), (12, "trill"), (18, "sing_mid"), (24, "trill"), (30, "terrified"),
                 (36, "mortified"), (46, "pardon"), (60, "sulk"), (72, "pompous"), (80, "sing_small")):
        c.face(f, p)
    return c
