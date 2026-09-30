"""Write Bellows' rig descriptor + face presets (index §7.3): game/data/rigs3d/bellows/{rig3d.json,faces.json}.

    python3 tools/art3d/bellows/descriptor.py --meta <build meta json> --face game/art3d/chars/bellows/face_bellows.json
        [--out game/data/rigs3d/bellows]

faces.json: all 45 presets of the 2D game/data/rigs/bellows/faces.json by their 2D names, every slot mapped to the 3D
layers: eyes/brows/mouth 1:1 (same cell names), pupils `default` -> `default` / `half` / `angry` (clipped under the lid
of that eye cell) or null, the 2D lids -> `lids` (the heavy-lid wash), the 2D extras -> extra_a (blush, vein, singe,
pinch) + extra_b (sweat, steam_l / steam_r / both = `steam`, hiccup, tears).
"""
import json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
FACES_2D = os.path.join(ROOT, "game", "data", "rigs", "bellows", "faces.json")

LAYERS = ["brows", "eyes", "pupils", "mouth", "extra_a", "extra_b", "lids"]


def preset_3d(p):
    eyes = p["eyes"]
    lids = p.get("lids", "none")
    pupils = None
    if p.get("pupils", "none") != "none":
        pupils = {"half": "half", "angry": "angry"}.get(eyes, "default")
    ea, eb = None, None
    if p.get("blush") == "on":
        ea = "blush"
    if p.get("vein") == "on":
        ea = "vein" if ea is None else ea
    sl, sr = p.get("steam_l") == "on", p.get("steam_r") == "on"
    if sl and sr:
        eb = "steam"
    elif sl:
        eb = "steam_l"
    elif sr:
        eb = "steam_r"
    if p.get("sweat") == "on":
        if eb is None:
            eb = "sweat"
        elif ea is None:
            ea = None   # no free layer; sweat only where the second layer is free (never happens in the 45)
    return {"brows": p["brows"], "eyes": eyes, "pupils": pupils, "mouth": p["mouth"], "extra_a": ea, "extra_b": eb,
            "lids": None if lids == "none" else lids}


def faces_json(face_layout):
    src = json.load(open(FACES_2D))
    presets = {}
    for name, p in src["presets"].items():
        q = preset_3d(p)
        for layer, cell in q.items():
            if cell is not None:
                assert cell in face_layout["cells"][layer], (name, layer, cell)
        presets[name] = q
    gaze = {k: [round(v[0] / 6.0, 3), round(-v[1] / 4.0, 3)] for k, v in src.get("gaze", {}).items()}
    return {"version": 1, "rig": "bellows",
            "doc": "The 45 2D presets (game/data/rigs/bellows/faces.json) by name, every slot mapped to a 3D face layer cell "
                   "(null = layer off). pupils: default | half | angry (clipped under that lid) | small. gaze = a suggested "
                   "pupil_offset (-1..1 of face.pupil_range; +x = his left, +y = up) from the 2D gaze px.",
            "layers": LAYERS, "presets": presets, "gaze": gaze}


def rig3d(meta, face_layout):
    lm = meta["landmarks"]
    sockets = {
        # hands: where held props sit and where set pieces are lent to (the kettle -> grip_r, the honey jar -> grip_l)
        "grip_r": {"bone": "prop_r", "pos": [0.0, 0.0, 0.0], "rot_deg": [0, 0, 0]},
        "grip_l": {"bone": "prop_l", "pos": [0.0, 0.0, 0.0], "rot_deg": [0, 0, 0]},
        "mouth": {"bone": "Head", "pos": meta["sockets"]["mouth"]},
        "head_top": {"bone": "Head", "pos": meta["sockets"]["head_top"]},
        "nose_tip": {"bone": "nose", "pos": meta["sockets"]["nose_tip"]},
        "face": {"bone": "Head", "pos": meta["sockets"]["face"]},
        "specs_face": {"bone": "specs_face", "pos": [0.0, 0.0, 0.0]},
        "specs_chest": {"bone": "specs_chest", "pos": [0.0, 0.0, 0.0]},
        "belly_front": {"bone": "spine_02", "pos": meta["sockets"]["belly_front"]},
        "seat": {"bone": "pelvis", "pos": meta["sockets"]["seat"]},
        "feet": {"bone": "root", "pos": [0.0, 0.0, 0.0]},
        "ride": {"bone": "ride", "pos": [0.0, 0.0, 0.0]},
    }
    props = {
        "teacup": {"bone": "prop_teacup", "states": {"held": "grip_r", "sip": "grip_r"}, "default": "hidden",
                   "doc": "x1.8: cup + saucer 0.16 m+ wide, white with a gold band, handle toward the palm (pinkie up)"},
        "saucer": {"bone": "prop_saucer", "states": {"held": "grip_l"}, "default": "hidden"},
        "spoon": {"bone": "prop_spoon", "states": {"held": "grip_r"}, "default": "hidden", "doc": "the honey spoon"},
        "comb": {"bone": "prop_comb", "states": {"held": "grip_r"}, "default": "hidden", "doc": "the mirror fix-up"},
        "baton": {"bone": "prop_baton", "states": {"held": "grip_r"}, "default": "hidden", "doc": "the conduct-air micro-gag"},
        "specs": {"bone": "specs_face", "states": {"on": "specs_face", "magnifier": "specs_face"}, "default": "hidden",
                  "hides": ["specs_dangling"], "doc": "worn on the nose; showing it hides specs_dangling (and back)"},
        "specs_dangling": {"bone": "specs_chest", "states": {"dangling": "specs_chest"}, "default": "dangling",
                           "hides": ["specs"]},
    }
    for pid in ("newspaper", "phone_handset", "kettle_lid", "kipper_held", "pickled_onion", "megaphone"):
        pass   # P2 (Nights 1-2): attachment scenes on prop_r, listed under attachments once built
    attachments = {
        "bouffant_flipped": {"scene": "res://art3d/chars/bellows/bouffant_flipped.glb", "bone": "Head", "default": False},
        "bouffant_frazzled": {"scene": "res://art3d/chars/bellows/bouffant_frazzled.glb", "bone": "Head", "default": False},
        "bouffant_wet": {"scene": "res://art3d/chars/bellows/bouffant_wet.glb", "bone": "Head", "default": False},
        "bouffant_floured": {"scene": "res://art3d/chars/bellows/bouffant_floured.glb", "bone": "Head", "default": False},
        "stool": {"scene": "res://art3d/set/stool.glb", "bone": "ride", "default": False, "soft": True,
                  "doc": "the ride-along kitchen stool (r3d-sets' mesh): shown by the sneeze (prop show stool) while the set's "
                         "stool is hidden by the clip's decor event; missing scene = logged, not fatal"},
    }
    slots = {"bouffant": {"neat": None, "flipped": "bouffant_flipped", "frazzled": "bouffant_frazzled",
                          "wet": "bouffant_wet", "floured": "bouffant_floured"}}
    looks = {
        "FRAZZLED": {"swap": {"bouffant": "frazzled"}, "face_extra": {"extra_a": "singe"}},
        "BLINDED": {"swap": {"bouffant": "flipped"}},
        "SOAKED": {"swap": {"bouffant": "wet"}},
        "FLOURY": {"swap": {"bouffant": "floured"}, "params": {"flash_color": "#FFFFFF", "flash": 0.18}},
        "SQUEAKY": {"face_extra": {"extra_a": "pinch", "extra_b": "hiccup"}},
    }
    faces_path = "res://data/rigs3d/bellows/faces.json"
    face = {"atlas": "res://art3d/chars/bellows/face_bellows.png", "atlas_px": face_layout["atlas_px"],
            "grid": face_layout["grid"], "layers": LAYERS, "order": face_layout["order"],
            "layer_rects": face_layout["layer_rects"], "cells": face_layout["cells"],
            "pupil_range": [0.035, 0.025], "presets": faces_path, "default": "pompous",
            "mirror_cells": face_layout["mirror_cells"], "no_pupils": face_layout["no_pupils"],
            "blink": {"every_s": [2.0, 6.0], "frames": 6, "cell": "closed", "blinkable": face_layout["blinkable"],
                      "hide_layers": ["pupils", "lids"]},
            "card": {"uv": "UV2", "centre_m": lm["face_card"]["centre"], "w_m": lm["face_card"]["w"], "h_m": lm["face_card"]["h"]}}
    return {
        "version": 1, "rig": "bellows", "scene": "res://art3d/chars/bellows/bellows.glb",
        "skeleton": "Armature/Skeleton3D", "mesh": "Armature/Skeleton3D/bellows_body",
        "height_m": 1.78, "head_scale": 1.0, "tris": meta["tris"], "deform_bones": meta["deform_bones"],
        "bones": {"root": "root", "pelvis": "pelvis", "spine_top": "spine_03", "neck": "neck_01", "head": "Head",
                  "hand_l": "hand_l", "hand_r": "hand_r", "foot_l": "foot_l", "foot_r": "foot_r"},
        "sockets": sockets, "props": props, "attachments": attachments, "slots": slots,
        "slot_parts": {"bouffant": {"hide_bones": ["bouffant", "bouffant_l", "bouffant_r"]}},
        "fx": {"choo_puff": {"bone": "fx_choo"}, "stars": {"bone": "fx_stars"}, "notes": {"bone": "fx_notes"}},
        "hidden_bones": ["prop_teacup", "prop_saucer", "prop_spoon", "prop_comb", "prop_baton", "specs_face",
                         "fx_choo", "fx_stars", "fx_notes"],
        "anim": {"layers": ["arm_out"],
                 "layer_params": {"arm_out": {"space": "armature_axes", "rots": meta["arm_out"],
                                              "doc": "pre-multiplied onto the keyed local rotation of each bone (look B's "
                                                     "layer_rotation): +abduction so the arms clear the 0.85 m barrel. FK "
                                                     "channels only: IK-solved arm keys are solved after the layer."}}},
        "jiggle": [
            {"bones": ["bouffant", "bouffant_l", "bouffant_r"], "stiffness": 2.2, "drag": 0.35, "gravity": 0.15, "radius": 0.12, "clamp_deg": 14},
            {"bones": ["sideburn_l", "sideburn_r"], "stiffness": 3.5, "drag": 0.4, "gravity": 0.1, "radius": 0.06, "clamp_deg": 12},
            {"bones": ["belly"], "stiffness": 4.0, "drag": 0.5, "gravity": 0.0, "radius": 0.2, "clamp_deg": 8},
            {"bones": ["cravat"], "stiffness": 2.5, "drag": 0.4, "gravity": 0.4, "radius": 0.05, "clamp_deg": 25},
            {"bones": ["tail_l", "tail_r"], "stiffness": 2.0, "drag": 0.3, "gravity": 0.5, "radius": 0.06, "clamp_deg": 35}],
        "face": face,
        "material": {"palette": "res://art3d/chars/bellows/palette_bellows.png", "outline_px": 3.5, "rim": 0.45},
        "vertex_color": {"r": "skin_tint", "g": "stone_keep", "b": "rim_damp", "a": "outline_scale"},
        "looks": looks,
        "tint": {"tiers": ["#FFFFFF", "#FFE0DC", "#FFC2B8", "#F59A94"], "livid": "#B8324B",
                 "sideburn_scale": [1.0, 1.15, 1.15, 1.35], "livid_specs": "on"},
        "stone": {"color": "#E8E6E1"}, "cheat": {"idle": 35, "walk": 20, "perform": 35, "face_to_face": 5},
        "blob_shadow_r": 0.48, "skins": {},
        "portraits": {"dir": "res://art3d/chars/bellows/portraits", "names": []},
        "build": {"script": "tools/art3d/bellows/build.py", "skeleton": "tools/art3d/bellows/skeleton.json",
                  "landmarks": lm},
    }


if __name__ == "__main__":
    a = sys.argv[1:]
    meta = json.load(open(a[a.index("--meta") + 1]))
    lay = json.load(open(a[a.index("--face") + 1]))
    out = a[a.index("--out") + 1] if "--out" in a else os.path.join(ROOT, "game", "data", "rigs3d", "bellows")
    os.makedirs(out, exist_ok=True)
    fj = faces_json(lay)
    rj = rig3d(meta, lay)
    if "--portraits" in a:
        rj["portraits"]["names"] = a[a.index("--portraits") + 1].split(",")
    with open(os.path.join(out, "faces.json"), "w") as f:
        json.dump(fj, f, indent=2)
    with open(os.path.join(out, "rig3d.json"), "w") as f:
        json.dump(rj, f, indent=2)
    print("DESCRIPTOR_OK", out, len(fj["presets"]), "presets")
