"""house_json - builds game/data/house/house.json (TECH §4.1) from geo.py + the art registry
filled by the generators (props/rooms/stage). Key order is fixed so the file diffs cleanly."""
import json
import os

import geo

RES = "res://art/house"


def res(sub):
    return "%s/%s" % (RES, sub)


class Registry:
    """What the generators produced: hotspot art, decor sprites, set pieces."""

    def __init__(self):
        self.hotspot_art = {}     # id -> {"pos": [x, y], "size": [w, h], "art": {state: res}, extra...}
        self.decor = []           # [{id, room, pos, size, art{}, z, ...}]
        self.pieces = []          # set pieces [{id, art, pos, size, z}]
        self.quake = {}           # room -> [{prop, x, decor}]
        self.stage = {}           # stage block

    def hotspot(self, hid, pos, size, art, **extra):
        d = {"pos": [int(pos[0]), int(pos[1])], "size": [int(size[0]), int(size[1])], "art": art}
        d.update(extra)
        self.hotspot_art[hid] = d


def build(reg):
    rooms = []
    for rid, fl, x0, x1, outdoor, wp in geo.ROOMS:
        rooms.append({
            "id": rid, "floor": fl, "x0": x0, "x1": x1, "outdoor": outdoor, "wallpaper": wp,
            "art": {"bg": res("rooms/%s_bg.svg" % rid), "fg": res("rooms/%s_fg.svg" % rid),
                    "pos": [x0, geo.CEIL], "size": [x1 - x0, geo.INTERIOR_H + geo.SLAB_H],
                    "final": rid in geo.FINAL_ROOMS},
        })
    links = []
    for l in geo.LINKS:
        d = dict(l)
        if l["id"] == "front_door":
            d["art"] = res("props/front_door.svg")
            d["hotspot"] = "hall_front_door"
        elif l["id"] == "back_door":
            d["art"] = res("props/back_door.svg")
            d["hotspot"] = "kitchen_back_door"
        elif l["id"] == "stairs":
            d["hotspots"] = ["stairs_foot", "stairs_head"]
        links.append(d)
    stations = []
    for sid, room, x, stand, facing, kinds, extra in geo.STATIONS:
        d = {"id": sid, "room": room, "x": x, "stand_x": stand, "facing": facing, "kinds": list(kinds)}
        d.update(extra)
        stations.append(d)
    hotspots = []
    for hid, h in geo.HOTSPOTS.items():
        d = {"id": hid}
        for k in ("kind", "room", "use_x", "facing", "rect", "in_use_by", "station", "link", "tappable", "entry", "z"):
            if k in h:
                d[k] = h[k]
        a = reg.hotspot_art.get(hid)
        if a:
            d["art_pos"] = a["pos"]
            d["art_size"] = a["size"]
            d["art"] = a["art"]
            for k, v in a.items():
                if k not in ("pos", "size", "art"):
                    d[k] = [int(round(c)) for c in v] if k == "eyes" else v
        hotspots.append(d)
    house = {
        "version": 1,
        "id": "humdrum_7",
        "floor_pitch": geo.FLOOR_PITCH,
        "interior_h": geo.INTERIOR_H,
        "slab_h": geo.SLAB_H,
        "floors": [{"index": i, "y": y} for i, y in sorted(geo.FLOORS.items())],
        "rooms": rooms,
        "links": links,
        "stations": stations,
        "hotspots": hotspots,
        "stacks": [list(s) for s in geo.STACKS],
        "landings": geo.LANDINGS,
        "quake_props": reg.quake,
        "entries": geo.ENTRIES,
        "decor": reg.decor,
        "stage": reg.stage,
    }
    return house


def dump(house, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    txt = json.dumps(house, indent=2, ensure_ascii=False)
    # keep short numeric arrays on one line ([x, y, w, h], [x, y])
    import re
    txt = re.sub(r"\[\s+(-?[\d.]+),\s+(-?[\d.]+)\s+\]", r"[\1, \2]", txt)
    txt = re.sub(r"\[\s+(-?[\d.]+),\s+(-?[\d.]+),\s+(-?[\d.]+),\s+(-?[\d.]+)\s+\]", r"[\1, \2, \3, \4]", txt)
    txt = re.sub(r'\[\s+("[A-Z]+")\s+\]', r"[\1]", txt)
    txt = re.sub(r'\[\s+("[A-Z]+"),\s+("[A-Z]+")\s+\]', r"[\1, \2]", txt)
    with open(path, "w") as fh:
        fh.write(txt + "\n")
    return path
