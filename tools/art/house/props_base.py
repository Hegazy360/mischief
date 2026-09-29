"""props_base - the prop pipeline (STYLE.md §6).

A Prop holds one Canvas per state, drawn in WORLD coords (x absolute, y relative to the room's
floor line). `emit` fits ONE canvas box around every state + the outline sprite (so all states
share `art_pos` / `art_size` and swap in place), writes

    props/<name>.svg            idle
    props/<name>_<state>.svg    open / rigged / rigged_<prank> / spent / occupied / front ...
    props/<name>_ol.svg         the idle silhouette grown 4 px, flat white (pulsing outline); its canvas is
                                the prop canvas grown 4 px on every side (top-left = art_pos - (4, 4))

and registers the hotspot (or decor) art in the house.json registry.
"""
import math
import os

from svgk import Canvas, fit_box, reduce_palette, write

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
ART = os.path.join(REPO, "game", "art", "house")
RES = "res://art/house"
MARGIN = 3            # STYLE §1: 3 px canvas margin around the outermost ink/outline pixel
OUTLINE_GROW = 4      # the outline sprite = the silhouette grown 4 px; its canvas starts 4 px up-left of art_pos
WRITTEN = []          # (path, kind) every file emitted this run (validate_svg / sheets)
AREAS = {}            # room -> total 1x canvas px of its prop sprites (atlas budget)


class Prop:
    def __init__(self, name, room):
        self.name = name
        self.room = room
        self.states = {}
        self.extra = {}

    def state(self, s):
        c = Canvas()
        self.states[s] = c
        return c

    def add(self, s, *items):
        if s not in self.states:
            self.state(s)
        self.states[s].add(*items)
        return self.states[s]

    def add_all(self, states, *items):
        for s in states:
            self.add(s, *items)


MERGES = {}          # prop name -> [(from, to)] colour merges done by the <= 10 colours rule


def _emit_files(prop, outline=True, sub="props"):
    canv = dict(prop.states)
    m = reduce_palette(list(canv.values()), 10)
    if m:
        MERGES[prop.name] = m
    ol = canv["idle"].outline(4.0) if outline else None
    # states share the top-left of the box around the STATES; the outline sprite is that canvas grown by
    # OUTLINE_GROW px on every side (its top-left is art_pos - (4, 4); the view draws it there)
    box = fit_box(list(canv.values()), MARGIN)
    x0, y0, _, _ = box
    art = {}
    area = 0
    sizes = {}

    def crop(c):
        """Every state shares the top-left (x0, y0) but ends at its own right/bottom extent."""
        bb = c.bbox()
        return int(math.ceil(bb[2] + MARGIN)) - x0, int(math.ceil(bb[3] + MARGIN)) - y0

    for s, c in canv.items():
        fname = prop.name if s == "idle" else "%s_%s" % (prop.name, s)
        p = os.path.join(ART, sub, fname + ".svg")
        w, h = crop(c)
        sizes[s] = (w, h)
        write(p, c.svg(x0, y0, w, h))
        WRITTEN.append((p, sub))
        art[s] = "%s/%s/%s.svg" % (RES, sub, fname)
        area += w * h * 4
    if ol is not None:
        p = os.path.join(ART, sub, prop.name + "_ol.svg")
        ox, oy = x0 - OUTLINE_GROW, y0 - OUTLINE_GROW
        bb = ol.bbox()
        w, h = int(math.ceil(bb[2] + MARGIN)) - ox, int(math.ceil(bb[3] + MARGIN)) - oy
        write(p, ol.svg(ox, oy, w, h))
        WRITTEN.append((p, sub + "_ol"))
        art["outline"] = "%s/%s/%s_ol.svg" % (RES, sub, prop.name)
        area += w * h          # outline sprites are budgeted at 1x (flat white glow)
        sizes["outline"] = (w, h)
    AREAS[prop.room] = AREAS.get(prop.room, 0) + area
    return (x0, y0), sizes["idle"], art


def emit(reg, hotspot_id, prop, outline=True):
    pos, size, art = _emit_files(prop, outline)
    reg.hotspot(hotspot_id, pos, size, art, **prop.extra)
    return pos, size


def emit_decor(reg, decor_id, prop, z=0, **extra):
    pos, size, art = _emit_files(prop, outline=False)
    d = {"id": decor_id, "room": prop.room, "pos": [int(pos[0]), int(pos[1])], "size": [int(size[0]), int(size[1])],
         "art": art, "z": z}
    d.update(extra)
    d.update(prop.extra)
    reg.decor.append(d)
    return pos, size
