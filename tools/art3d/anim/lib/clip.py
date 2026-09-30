"""Clip spec -> per-frame poses -> Blender action -> `build/art3d/anim/<rig>/<clip>.glb` + the sidecar
`game/data/anim/<rig>3d/<clip>.json` (index §7.2). Used by every clip spec under `tools/art3d/anim/<rig>/`.

    from lib.clip import Clip
    from lib.pose import sym, merge, curl
    def build(ctx):
        c = Clip(ctx, "hush/act_snicker", length=60, cheat_deg=35)
        c.key(0, POSE_A)                      # a key: frame, pose, ease INTO this key (default "in_out_sine")
        c.key(6, POSE_B, "pop")               # a pop key: the accent pose pops in on f 6 (added to lint.pop_frames)
        c.beats(anticipation=(0, 6), accent=(6, 9), hold=(9, 47), settle=(47, 60))
        c.ground()                            # the lowest sole on the floor every frame
        c.face(0, "glance"); c.sfx(0, "hush_snicker")
        return c

Evaluation per frame (60 fps, frame 0 = clip start, frames 0..length): key interpolation (slerp per bone with the
key's ease; back/elastic overshoot) -> the rig's default pose layers (rig3d.json `anim.layers`, e.g. Bellows'
`arm_out`) + the clip's own layers -> constraints in the order added (ground, steps, IK / reach, plants, look).
"""
import json, math, os, time
from mathutils import Vector, Quaternion, Matrix

from . import ease as E
from . import pose as P
from .stage import Stage

FPS = 60
LAYERS = ("base", "overlay", "additive")
MASKS = (None, "upper", "head", "arms", "face")
LOCKS = (None, "sim", "rig_pm")
EVENT_TYPES = ("sfx", "voice", "laugh", "fx", "face", "cam", "shake", "hitstop", "slowmo", "freeze", "prop", "mark",
               "decor", "set_anim", "set_part", "look", "jiggle")
SOUND_TYPES = ("sfx", "voice")


class BakeError(Exception):
    pass


# ------------------------------------------------------------------------------------------------
# built-in pose layers (rig3d.json `anim.layers` names; `anim.layer_defs` in the descriptor overrides the angles)
# ------------------------------------------------------------------------------------------------
LAYER_DEFS = {
    # look B's Bellows layer: +40° upper-arm abduction so his arms clear the 0.85 m barrel
    "arm_out": {"upperarm_l": [("y", -40)], "upperarm_r": [("y", 40)]},
    # the mime's paws for UAL locomotion: elbows up and out, forearms bent, gloves drooping like paws
    "mime": {"upperarm_l": [("y", -18), ("z", -30)], "upperarm_r": [("y", 18), ("z", 30)],
             "lowerarm_l": [("z", -55)], "lowerarm_r": [("z", 55)],
             "hand_l": [("y", 55)], "hand_r": [("y", -55)]},
}


class Ctx:
    """What a spec's build(ctx) gets: the rig's skeleton, its descriptor, the stage helpers and the repo root."""

    def __init__(self, rig, skel, rig3d=None, root=None, arm=None):
        self.rig = rig
        self.skel = skel
        self.rig3d = rig3d or {}
        self.root = root
        self.arm = arm
        self.ual = None          # set by bake_main when a UAL library is loaded

    def default_layers(self):
        a = (self.rig3d.get("anim") or {})
        return list(a.get("layers") or [])

    def layer_def(self, name):
        a = self.rig3d.get("anim") or {}
        defs = dict(a.get("layer_defs") or {})
        for k, v in (a.get("layer_params") or {}).items():     # the cast descriptors' form: {name: {rots: {...}}}
            if isinstance(v, dict) and isinstance(v.get("rots"), dict):
                defs.setdefault(k, v["rots"])
        d = defs.get(name, LAYER_DEFS.get(name))
        if d is None:
            raise BakeError("unknown pose layer '%s' (known: %s)" % (name, ", ".join(sorted(set(LAYER_DEFS) | set(defs)))))
        return {b: [tuple(r) for r in v] for b, v in d.items()}

    def socket(self, name):
        """(bone, rest armature-space point) of a rig3d.json socket (pos in the bone's local frame, metres)."""
        s = (self.rig3d.get("sockets") or {}).get(name)
        if s is None:
            return None
        bone = s["bone"]
        pos = Vector(s.get("pos", [0, 0, 0]))
        return bone, self.skel.rest[bone] @ pos


class _Key:
    __slots__ = ("f", "pose", "ease", "src")

    def __init__(self, f, pose, ease, src):
        self.f, self.pose, self.ease, self.src = f, pose, ease, src


class Clip:
    def __init__(self, ctx, clip_id, length, loop=False, layer="base", mask=None, lock=None, blend_in=0,
                 blend_out=10, cheat_deg=35.0, stride_m=None, speed_m_s=None, travel="sim", audio="table",
                 skippable=False, draft=False, stage=None, keeps=None, tags=None, notes=""):
        if "/" not in clip_id:
            clip_id = ctx.rig + "/" + clip_id
        if layer not in LAYERS:
            raise BakeError("%s: layer '%s' not in %s" % (clip_id, layer, LAYERS))
        if mask not in MASKS:
            raise BakeError("%s: mask '%s' not in %s" % (clip_id, mask, MASKS))
        if lock not in LOCKS:
            raise BakeError("%s: lock '%s' not in %s" % (clip_id, lock, LOCKS))
        self.ctx = ctx
        self.skel = ctx.skel
        self.id = clip_id
        self.rig = clip_id.split("/")[0]
        self.short = clip_id.split("/", 1)[1]
        self.length = int(length)
        self.loop = bool(loop)
        self.layer, self.mask, self.lock = layer, mask, lock
        self.blend_in, self.blend_out = int(blend_in), int(blend_out)
        self.cheat_deg = float(cheat_deg)
        self.stride_m, self.speed_m_s = stride_m, speed_m_s
        self.travel = travel
        self.audio = audio
        self.skippable, self.draft = skippable, draft
        self.stage = stage or Stage(cheat=self.cheat_deg)
        self.keeps = list(keeps or [])
        self.tags = list(tags or [])
        self.notes = notes
        self._keys = []
        self._beats = {}
        self.events = []
        self.face_tl = []
        self.gaze = []
        self.constraints = []
        self.layers = []                 # per-clip layer names (UAL: mime, damp_head …)
        self.motions = []                # procedural layers (fn(frame) -> pose dict), see motion()
        self.fk_hooks = []               # callables(frame, pose_dict) -> pose_dict before evaluation
        self.pop_frames = []
        self.freeze_holds = []
        self.support = [(0, 0.0)]        # (from frame, support height) — the floor or a step
        self.step = None
        self.source = {"kind": "custom"}
        self.ual_basis = None            # [{bone: (loc, rot, scale)}] per frame for UAL clips
        self._cache = {}
        self._bcache = {}
        self._key_poses = None

    # --- authoring ------------------------------------------------------------------------------
    def key(self, f, pose, ease="in_out_sine"):
        """A key pose at frame f; `ease` is the curve INTO this key."""
        if not E.valid(ease):
            raise BakeError("%s: unknown ease '%s'" % (self.id, ease))
        f = int(f)
        if f < 0 or f > self.length:
            raise BakeError("%s: key frame %d outside 0..%d" % (self.id, f, self.length))
        if self._keys and f <= self._keys[-1].f:
            raise BakeError("%s: key frames must increase (%d after %d)" % (self.id, f, self._keys[-1].f))
        self._keys.append(_Key(f, dict(pose), ease, None))
        if ease == "pop" and f not in self.pop_frames:
            self.pop_frames.append(f)
        self._key_poses = None
        return self

    def hold(self, f0, f1, pose, drift=None, ease="in_out_sine"):
        """A moving hold: `pose` at f0 and at f1 with `drift` (a small pose added at the hold's end, e.g. breathing)."""
        self.key(f0, pose, ease)
        self.key(f1, P.add(pose, drift) if drift else pose, "in_out_sine")
        return self

    def overshoot(self, f, pose, pct=0.15, frames=6, ease_in="out_cubic", ease_out="in_out_sine"):
        """Arrive at `pose` by f + frames through ONE overshoot: at f the pose is pushed `pct` past it (away from the
        previous key), then it settles."""
        if not self._keys:
            raise BakeError("%s: overshoot() needs a previous key" % self.id)
        self._keys.append(_Key(int(f), dict(pose), ease_in, ("overshoot", pct)))
        self._key_poses = None
        self.key(int(f) + int(frames), pose, ease_out)
        return self

    def beats(self, **b):
        for k, v in b.items():
            self._beats[k] = [int(v[0]), int(v[1])]
        return self

    def event(self, f, type_, **fields):
        if type_ not in EVENT_TYPES:
            raise BakeError("%s: unknown event type '%s'" % (self.id, type_))
        e = {"f": int(f), "type": type_}
        e.update(fields)
        self.events.append(e)
        return self

    def sfx(self, f, sid, **kw):
        return self.event(f, "sfx", id=sid, **kw)

    def mark(self, f, name):
        return self.event(f, "mark", name=name)

    def face(self, f, preset=None, slots=None, blink=None):
        e = {"f": int(f)}
        if preset:
            e["preset"] = preset
        if slots:
            e["slots"] = dict(slots)
        if blink is not None:
            e["blink"] = bool(blink)
        self.face_tl.append(e)
        return self

    def look_camera(self, f0, f1, weight=1.0, blend=4):
        """Runtime gaze toward the audience camera (sidecar `gaze`: the player's look_at_point, facing-proof) — use
        this for glances at the Stalls in clips that play facing either way."""
        self.gaze.append({"f0": int(f0), "f1": int(f1), "at": "camera", "weight": float(weight), "blend": int(blend)})
        return self

    def freeze_hold(self, f0, f1):
        self.freeze_holds.append([int(f0), int(f1)])
        return self

    def motion(self, fn, f0=0, f1=None, weight=None):
        """A procedural layer on top of the keys: fn(frame) -> pose dict whose rotations are applied AFTER the keyed
        ones (armature axes) and whose _pelvis / _root offsets add — breathing, sways, trembles, finger drums. Smooth
        (no key velocity stops). weight: optional callable(frame) -> 0..1 envelope."""
        self.motions.append((fn, int(f0), self.length if f1 is None else int(f1), weight))
        return self

    def pose_layer(self, name):
        self.layers.append(name)
        return self

    # --- constraints ----------------------------------------------------------------------------
    def ground(self, f0=0, f1=None, lift=0.0, weight=1.0, per_frame=True):
        """Every frame in [f0, f1]: move the pelvis vertically so the lowest sole point sits on the support (the
        floor, or a step while on it). `lift` (m, or callable(f)) raises the body (hops). per_frame False: ONE
        offset for the whole range (the lowest sole of the whole range on the support) — runs with a flight phase."""
        if per_frame:
            self.constraints.append(("ground", int(f0), self.length if f1 is None else int(f1), lift, weight))
        else:
            self.constraints.append(("ground_clip", int(f0), self.length if f1 is None else int(f1), lift, weight))
        return self

    def _clip_ground_offset(self, f0, f1):
        key = ("ground_clip", f0, f1)
        if key not in self._cache:
            lows = []
            for f in range(f0, f1 + 1):
                b = self._base(f % self.length if self.loop else f)
                lows.append(self.skel.lowest_sole(b.world) - self.support_at(f))
            self._cache[key] = -min(lows) if lows else 0.0
        return self._cache[key]

    def plant(self, side, f0, f1, at=None, part="foot", travel=None):
        """Hold a foot fixed in the world over [f0, f1] (f1 may pass `length` on loops: the range wraps). The anchor is
        the foot's pose at frame `at` (default f0). part "foot" holds the whole foot (flat), "ball" holds the ball of
        the foot (the heel may lift as keyed). travel (m/s, default `speed_m_s`): in-place walks — the planted foot
        slides backward at the walking speed in clip space, i.e. stays put in lane space."""
        self.constraints.append(("plant", side, int(f0), int(f1), at, part, travel))
        return self

    def ik(self, side, target, f0=0, f1=None, pole=None, hand=None, effector="palm", blend=4, world=True):
        """Arm IK over [f0, f1]: target = a world (Godot) point (x, y, z) if world else an armature-space point, or a
        callable(frame) -> point, or (bone, rest point) riding on a bone. pole = the elbow's direction (armature
        space; default down-and-out). hand = rotation list about armature axes for the glove (else keyed). effector:
        "wrist" | "palm" | "tip" | a rig3d socket name. blend = frames to ease the IK weight in/out."""
        if pole is None:
            pole = (0.8 if side == "l" else -0.8, 0.3, -0.6)
        self.constraints.append(("ik", side, target, int(f0), self.length if f1 is None else int(f1), Vector(pole),
                                 hand, effector, int(blend), world))
        return self

    def reach(self, side, target, f0, f1, pole=None, hand=None, effector="palm", blend=5, look=True):
        """IK to a world target (a placed reach target) + the head turned to the camera so the face reads (R5d)."""
        self.ik(side, target, f0, f1, pole=pole, hand=hand, effector=effector, blend=blend, world=True)
        if look:
            self.look(("camera",), f0, f1, weight=0.8, blend=blend)
        return self

    def look(self, target, f0, f1, weight=1.0, blend=4, bones=("spine_03", "neck_01", "Head"), share=(0.15, 0.3, 0.55)):
        """Baked head + neck aim at a world point, ("camera",) or a callable(frame) -> armature point. Facing-specific:
        use it on staged clips (rigs); use look_camera() for glances that must work facing either way."""
        self.constraints.append(("look", target, int(f0), int(f1), float(weight), int(blend), bones, share))
        return self

    def auto_plant(self, speed_m_s=None, thr=0.02, min_run=3, release=6, sides=("l", "r")):
        """Locomotion helper — rolling contacts in LANE space. On the base motion (keys / UAL + layers + ground) each
        foot's stance phases are the frames its lowest sole point is within `thr` of the support. Through a stance the
        foot keeps its keyed orientation (the heel-toe roll) while its CONTACT point — heel, then ball, then toe, as
        each one reaches the support — is pinned in lane space (it slides backward at the walking speed in clip space);
        after lift-off the foot eases back to the keyed swing over `release` frames. speed_m_s None = the motion's own
        stance speed (UAL clips); a number retimes the stride to it. Sets the clip's `speed_m_s` (and `stride_m` on
        loops = speed × length / 60). Add ground() BEFORE this."""
        self._auto = {"speed": speed_m_s, "thr": float(thr), "min_run": int(min_run), "release": int(release),
                      "sides": tuple(sides)}
        return self

    def _stance_runs(self, side, thr, min_run):
        sk = self.skel
        n = self.length
        last = n - 1 if self.loop else n
        st = []
        for f in range(last + 1):
            ap = self._anchor_pose(f)
            st.append(min(p.z for p in sk.sole_points(ap.world, side)) <= self.support_at(f) + thr)
        spans = []
        f = 0
        while f <= last:
            if st[f]:
                g = f
                while g + 1 <= last and st[g + 1]:
                    g += 1
                spans.append([f, g])
                f = g + 1
            else:
                f += 1
        if self.loop and len(spans) >= 2 and spans[0][0] == 0 and spans[-1][1] == last:
            first = spans.pop(0)
            spans[-1][1] = first[1] + n
        elif self.loop and len(spans) == 1 and spans[0] == [0, last]:
            spans = [[0, last]]
        return [sp for sp in spans if sp[1] - sp[0] + 1 >= min_run]

    def _setup_auto(self):
        a = getattr(self, "_auto", None)
        if not a or a.get("done"):
            return
        a["done"] = True
        sk = self.skel
        n = self.length
        mod = (lambda f: f % n) if self.loop else (lambda f: f)
        runs = {side: self._stance_runs(side, a["thr"], a["min_run"]) for side in a["sides"]}
        vel = []
        for side, spans in runs.items():
            for f0, f1 in spans:
                p0 = min(sk.sole_points(self._anchor_pose(mod(f0)).world, side), key=lambda p: p.z)
                p1 = min(sk.sole_points(self._anchor_pose(mod(f1)).world, side), key=lambda p: p.z)
                if f1 > f0:
                    vel.append((p1.y - p0.y) / ((f1 - f0) / float(FPS)))   # + = the foot moves back = she walks forward
        spd = a["speed"]
        if spd is None:
            vel.sort()
            spd = vel[len(vel) // 2] if vel else 0.0
        spd = round(float(spd), 4)
        self.speed_m_s = spd if spd > 0 else None
        if self.loop and self.speed_m_s:
            self.stride_m = round(self.speed_m_s * n / float(FPS), 4)
        back = Vector((0, 1, 0)) * ((self.speed_m_s or 0.0) / FPS)
        plan = {}
        for side, spans in runs.items():
            ft = "foot_" + side
            for f0, f1 in spans:
                pivot = None
                anchor = None
                fa = f0
                ankle = None
                yaw0 = None
                for f in range(f0, f1 + 1):
                    ap = self._anchor_pose(mod(f))
                    R = ap.world_rot(ft)
                    ank_fk = ap.pos(ft)
                    raw = sk.sole_points(ap.world, side)
                    # a planted foot does not spin: its yaw stays the one it landed with (the pitch roll is kept)
                    d = raw[2] - raw[0]
                    yaw = math.atan2(d.y, d.x)
                    if yaw0 is None:
                        yaw0 = yaw
                    Y = Quaternion((0, 0, 1), yaw0 - yaw)
                    R = Y @ R
                    offs = [Y @ (p - ank_fk) for p in raw]
                    sup = self.support_at(mod(f))
                    if pivot is None:
                        pts = [ank_fk + o for o in offs]
                        pivot = min(range(3), key=lambda k: pts[k].z)
                        anchor = pts[pivot].copy()
                        anchor.z = sup
                        fa = f
                    zf = (ank_fk + offs[pivot]).z
                    for _ in range(3):
                        pos = anchor + back * (f - fa)
                        # the contact stays put horizontally; it rises with the keyed foot once that lifts
                        pos.z = sup if zf - sup <= 0.004 else zf
                        ankle = pos - offs[pivot]
                        pts = [ankle + o for o in offs]
                        j = min(range(3), key=lambda k: pts[k].z)
                        if j != pivot and pts[j].z < sup - 0.0005:
                            pivot = j
                            anchor = pts[j].copy()
                            anchor.z = sup
                            fa = f
                            zf = (ank_fk + offs[pivot]).z
                            continue
                        break
                    plan[(side, mod(f))] = (ankle.copy(), R.copy())
                # release: ease from the pinned lift-off back to the keyed swing
                ap1 = self._anchor_pose(mod(f1))
                off = ankle - ap1.pos(ft)
                for i in range(1, a["release"] + 1):
                    f = f1 + i
                    if (side, mod(f)) in plan or (not self.loop and f > n):
                        break
                    w = 1.0 - E.apply("in_out_sine", i / float(a["release"] + 1))
                    apf = self._anchor_pose(mod(f))
                    plan[(side, mod(f))] = (apf.pos(ft) + off * w, apf.world_rot(ft))
        self._plan = plan
        self._auto_runs = runs
        self.constraints.append(("plan",))

    @classmethod
    def from_ual(cls, ctx, clip_id, ual_name, lib=None, layers=(), **kw):
        """A clip on a retargeted UAL action (leg-ratio scaled pelvis, the rig's default layers + `layers`); add
        ground(), auto_plant(), events, face, look … like on any clip. kw: Clip options (loop defaults to the name
        ending in _Loop, audio to "own")."""
        from . import ual as U
        names = [lib] if lib else ["UAL1", "UAL2"]
        L = None
        for ln in names:
            cand = ctx.ual_lib(ln)
            if ual_name in cand.actions:
                L = cand
                break
        if L is None:
            raise BakeError("no UAL clip '%s' in %s" % (ual_name, ", ".join(names)))
        frames, k = U.retarget(L, ual_name, ctx.skel)
        kw.setdefault("loop", ual_name.endswith("_Loop"))
        kw.setdefault("audio", "own")
        c = cls(ctx, clip_id, length=len(frames) - 1, **kw)
        c.ual_basis = frames
        for l in layers:
            c.pose_layer(l)
        c.source = {"kind": "ual", "lib": L.name, "clip": ual_name, "layers": list(layers), "leg_ratio": round(k, 4)}
        return c

    def custom(self, fn, f0=0, f1=None):
        """fn(pose: Pose, frame: int) mutates the evaluated pose (world solved) — anything the helpers do not cover."""
        self.constraints.append(("custom", fn, int(f0), self.length if f1 is None else int(f1)))
        return self

    # --- steps (R5: the stool / the mime's invisible step) ----------------------------------------
    def step_up(self, kind, h, f0, f1, decor_id=None, arc=0.10, wobble=True):
        """Hop up onto a support of height h between f0 (take-off) and f1 (landing): the feet ground on the support
        from f1 on; the pelvis follows an arc (+`arc` m) in the air. kind "stool" (a real seat: `decor {id, anim:
        wobble}` at the landing) or "mime" (a virtual plane). Root x/z never moves."""
        self.support.append((int(f1), float(h)))
        self.support.sort()
        self.constraints.append(("air", int(f0), int(f1), float(arc)))
        self.step = self.step or {"kind": kind, "h": float(h)}
        if decor_id:
            self.step["id"] = decor_id
        if kind == "stool" and decor_id and wobble:
            self.event(f1, "decor", id=decor_id, anim="wobble")
        return self

    def step_down(self, f0, f1, arc=0.06, decor_id=None, wobble=True):
        """Hop down to the floor between f0 (take-off, still on the step) and f1 (landing): the support is the floor
        from the first airborne frame f0 + 1 on."""
        self.support.append((int(f0) + 1, 0.0))
        self.support.sort()
        self.constraints.append(("air", int(f0), int(f1), float(arc)))
        did = decor_id or (self.step or {}).get("id")
        if did and wobble and (self.step or {}).get("kind") == "stool":
            self.event(f0, "decor", id=did, anim="wobble")
        return self

    def support_at(self, f):
        h = 0.0
        for f0, v in self.support:
            if f >= f0:
                h = v
        return h

    # --- evaluation ----------------------------------------------------------------------------
    def _poses(self):
        if self._key_poses is None:
            sk = self.skel
            kp = []
            prev = None
            for k in self._keys:
                p = P.Pose.from_dict(sk, k.pose)
                if k.src and k.src[0] == "overshoot" and prev is not None:
                    p = P.blend_pose(prev, p, 1.0 + float(k.src[1]))
                kp.append(p)
                prev = p
            self._key_poses = kp
        return self._key_poses

    def _dict_layers(self):
        names = list(self.ctx.default_layers()) + list(self.layers)
        return [(n, self.ctx.layer_def(n)) for n in names]

    def _base(self, f):
        """Keys (or UAL samples) + pose layers, world solved; no constraints (cached; callers copy)."""
        hit = self._bcache.get(f)
        if hit is not None:
            return hit.copy()
        pose = self._base_uncached(f)
        self._bcache[f] = pose.copy()
        return pose

    def _base_uncached(self, f):
        sk = self.skel
        if self.ual_basis is not None:
            fi = min(len(self.ual_basis) - 1, max(0, int(f)))
            pose = P.Pose(sk)
            pose.basis = {n: (l.copy(), r.copy(), s.copy()) for n, (l, r, s) in self.ual_basis[fi].items()}
        else:
            if not self._keys:
                raise BakeError("%s: no keys" % self.id)
            kp = self._poses()
            ks = self._keys
            if f <= ks[0].f and not (self.loop and ks[0].f > 0):
                pose = kp[0].copy()
            elif f >= ks[-1].f and not self.loop:
                pose = kp[-1].copy()
            else:
                i1 = None
                for i, k in enumerate(ks):
                    if k.f >= f:
                        i1 = i
                        break
                if i1 is None or (i1 == 0 and ks[0].f > f):
                    # loop wrap: last key -> first key (at first.f + length)
                    a, b = len(ks) - 1, 0
                    fa = ks[a].f
                    fb = ks[b].f + self.length
                    ff = f if f >= fa else f + self.length
                    t = (ff - fa) / max(1, fb - fa)
                    pose = P.blend_pose(kp[a], kp[b], E.apply(ks[b].ease, t))
                elif ks[i1].f == f or i1 == 0:
                    pose = kp[i1].copy()
                else:
                    a = i1 - 1
                    t = (f - ks[a].f) / float(ks[i1].f - ks[a].f)
                    pose = P.blend_pose(kp[a], kp[i1], E.apply(ks[i1].ease, t))
        for fn, m0, m1, wfn in self.motions:
            if not (m0 <= f <= m1):
                continue
            d = fn(f)
            w = 1.0 if wfn is None else float(wfn(f))
            if w <= 0.0 or not d:
                continue
            for n, v in d.items():
                if n in ("_pelvis", "_root"):
                    bone = "pelvis" if n == "_pelvis" else "root"
                    if sk.has(bone):
                        loc, rot, sc = pose.get(bone)
                        pose.basis[bone] = (loc + sk.basis_loc(bone, Vector(v) * w), rot, sc)
                    continue
                if n.startswith("_") or not sk.has(n):
                    continue
                rots, _, _ = P._spec(v)
                q = P.rot_q([(ax, deg * w) for ax, deg in rots])
                loc, rot, sc = pose.get(n)
                pose.basis[n] = (loc, sk.basis_rot(n, q) @ rot, sc)
        for _, ld in self._dict_layers():
            for n, rots in ld.items():
                if not sk.has(n):
                    continue
                loc, rot, sc = pose.get(n)
                pose.basis[n] = (loc, sk.basis_rot(n, P.rot_q(rots)) @ rot, sc)
        pose.solve()
        return pose

    def _weight(self, f, f0, f1, blend):
        if blend <= 0:
            return 1.0
        w = 1.0
        if f0 > 0 and f < f0 + blend:
            w = min(w, (f - f0) / float(blend))
        if f1 < self.length and f > f1 - blend:
            w = min(w, (f1 - f) / float(blend))
        w = max(0.0, min(1.0, w))
        return w * w * (3 - 2 * w)

    def _in_range(self, f, f0, f1):
        if f0 <= f <= f1:
            return f
        if self.loop and f0 <= f + self.length <= f1:
            return f + self.length
        return None

    def _target(self, spec, f, pose, world):
        if callable(spec):
            return Vector(spec(f))
        if isinstance(spec, tuple) and len(spec) == 1 and spec[0] == "camera":
            return self.stage.camera()
        if isinstance(spec, tuple) and len(spec) == 2 and isinstance(spec[0], str):
            return self.skel.carried(pose.world, spec[0], spec[1])
        if world:
            return self.stage.to_char(spec)
        return Vector(spec)

    def _effector(self, side, effector):
        sk = self.skel
        hd = "hand_" + side
        if effector in (None, "wrist"):
            return None
        if effector in ("palm", "tip"):
            mid = "middle_01_" + side
            d = (sk.head(mid) - sk.head(hd)).normalized() if sk.has(mid) else (sk.tail[hd] - sk.head(hd)).normalized()
            return sk.head(hd) + d * (0.09 if effector == "palm" else 0.23)
        s = self.ctx.socket(effector)
        if s is None:
            raise BakeError("%s: unknown IK effector / socket '%s'" % (self.id, effector))
        if s[0] != hd:
            raise BakeError("%s: effector socket '%s' rides on %s, not %s" % (self.id, effector, s[0], hd))
        return s[1]

    def _ground_offset(self, pose, f, lift):
        low = self.skel.lowest_sole(pose.world)
        lv = lift(f) if callable(lift) else lift
        return self.support_at(f) + lv - low

    def evaluate(self, f):
        """The final pose of frame f (cached). On loops frame `length` IS frame 0 (the seam is continuous by
        construction; the lint checks the velocity across it)."""
        if f in self._cache:
            return self._cache[f]
        self._setup_auto()
        if self.loop and f == self.length and not getattr(self, "raw_seam", False):
            pose = self.evaluate(0)
            self._cache[f] = pose
            return pose
        pose = self._base(f)
        for c in self.constraints:
            kind = c[0]
            if kind in ("ground", "ground_clip", "air"):
                self._vertical(pose, f, c)
            elif kind == "ik":
                _, side, target, f0, f1, pole, hand, effector, blend, world = c
                ff = self._in_range(f, f0, f1)
                if ff is None:
                    continue
                w = self._weight(ff, f0, f1, blend)
                if w <= 0:
                    continue
                goal = self._target(target, f, pose, world)
                ikp = pose.copy()
                hw = P.rot_q(hand) if hand is not None else None
                P.solve_arm(ikp, side, goal, pole, hand_world=hw, effector=self._effector(side, effector))
                for b in ("upperarm_" + side, "lowerarm_" + side, "hand_" + side):
                    pose.set_rot(b, P.qslerp(pose.get(b)[1], ikp.get(b)[1], w))
                pose.solve()
            elif kind == "plant":
                _, side, f0, f1, at, part, travel = c
                ff = self._in_range(f, f0, f1)
                if ff is None:
                    continue
                self._apply_plant(pose, side, f0, ff, at, part, travel, f1)
            elif kind == "plan":
                for side in ("l", "r"):
                    hit = self._plan.get((side, f))
                    if hit is not None:
                        P.solve_leg(pose, side, hit[0], foot_world=hit[1])
            elif kind == "look":
                _, target, f0, f1, weight, blend, bones, share = c
                ff = self._in_range(f, f0, f1)
                if ff is None:
                    continue
                w = self._weight(ff, f0, f1, blend) * weight
                P.look_at(pose, self._target(target, f, pose, True), w, bones=bones, share=share)
            elif kind == "custom":
                _, fn, f0, f1 = c
                if f0 <= f <= f1:
                    fn(pose, f)
                    pose.solve()
        self._cache[f] = pose
        return pose

    def _airborne(self, f):
        for c in self.constraints:
            if c[0] == "air" and c[1] < f < c[2]:
                return True
        return False

    def _anchor_pose(self, f):
        """The pose a plant anchors to: keys + layers + the vertical placement (ground / air arcs), no IK or plants."""
        pose = self._base(f % self.length if self.loop else f)
        for c in self.constraints:
            if c[0] in ("ground", "ground_clip", "air"):
                self._vertical(pose, f, c)
        return pose

    def _vertical(self, pose, f, c):
        """One vertical-placement constraint on `pose` (world solved): ground per frame, one clip offset, a hop arc."""
        kind = c[0]
        if kind == "ground":
            _, f0, f1, lift, w = c
            if f0 <= f <= f1 and not self._airborne(f):
                pose.add_pelvis_offset(Vector((0, 0, self._ground_offset(pose, f, lift) * w)))
        elif kind == "ground_clip":
            _, f0, f1, lift, w = c
            if f0 <= f <= f1:
                lv = lift(f) if callable(lift) else lift
                pose.add_pelvis_offset(Vector((0, 0, (self._clip_ground_offset(f0, f1) + lv) * w)))
        elif kind == "air":
            _, f0, f1, arc = c
            if f0 < f < f1:
                b0 = self._base(f0)
                b1 = self._base(f1)
                z0 = self._ground_offset(b0, f0, 0.0) + (b0.pelvis_offset().z - pose.pelvis_offset().z)
                z1 = self._ground_offset(b1, f1, 0.0) + (b1.pelvis_offset().z - pose.pelvis_offset().z)
                t = (f - f0) / float(f1 - f0)
                dz = z0 + (z1 - z0) * E.apply("in_out_sine", t) + arc * math.sin(math.pi * t)
                pose.add_pelvis_offset(Vector((0, 0, dz)))

    def _apply_plant(self, pose, side, f0, ff, at, part, travel, f1=None, blend=3):
        sk = self.skel
        fa = f0 if at is None else int(at)
        key = ("anchor", side, f0, fa, part)
        if key not in self._cache:
            ap = self._anchor_pose(fa if not self.loop else fa % self.length)
            ft, bl = "foot_" + side, "ball_" + side
            m = ap.world[ft] if part == "foot" else ap.world[bl]
            # snap the anchor onto the support when within 3 cm
            loc = m.translation.copy()
            low = min(p.z for p in sk.sole_points(ap.world, side))
            sup = self.support_at(fa)
            if abs(low - sup) < 0.03:
                loc.z += sup - low
            self._cache[key] = (loc, ap.world[ft].to_quaternion())
        loc, q = self._cache[key]
        spd = self.speed_m_s if travel is None else travel
        target = loc.copy()
        if spd:
            target += Vector((0, 1, 0)) * (float(spd) * (ff - fa) / FPS)       # backward (+y) in clip space
        ft, bl = "foot_" + side, "ball_" + side
        fk_q = pose.world_rot(ft)
        if part == "foot":
            # the whole foot held (flat); its rotation eases from / back to the keyed one over `blend` frames
            w = 1.0
            if blend > 0 and f1 is not None:
                w = min(1.0, (ff - f0 + 1) / float(blend + 1), (f1 - ff + 1) / float(blend + 1))
            qf = P.qslerp(fk_q, q, w)
            P.solve_leg(pose, side, target, foot_world=qf)
        else:
            # hold the ball joint: the keyed foot pitch kept (the heel rolls), translate so the ball stays put
            v = sk.head(bl) - sk.head(ft)
            ankle = target - (fk_q @ sk.rest_q[ft].inverted()) @ v
            P.solve_leg(pose, side, ankle, foot_world=fk_q)

    # --- output ---------------------------------------------------------------------------------
    def frames(self):
        return [self.evaluate(f) for f in range(self.length + 1)]

    def check(self):
        if self.length <= 0:
            raise BakeError("%s: length must be > 0" % self.id)
        if self.lock == "rig_pm" and self.loop:
            raise BakeError("%s: rig_pm clips do not loop" % self.id)
        for e in self.events:
            if not (0 <= e["f"] <= self.length):
                raise BakeError("%s: event %s at f%d outside 0..%d" % (self.id, e["type"], e["f"], self.length))
        for e in self.face_tl:
            if not (0 <= e["f"] <= self.length):
                raise BakeError("%s: face entry at f%d outside the clip" % (self.id, e["f"]))
        for k, v in self._beats.items():
            if not (0 <= v[0] <= v[1] <= self.length):
                raise BakeError("%s: beat %s %s outside 0..%d" % (self.id, k, v, self.length))

    def sidecar(self, anim_res):
        ev = sorted(self.events, key=lambda e: e["f"])
        out = {
            "version": 2, "format": "anim3d", "clip": self.id, "rig": self.rig, "anim": anim_res,
            "length": self.length, "fps": FPS, "loop": self.loop, "layer": self.layer, "mask": self.mask,
            "blend_in": self.blend_in, "blend_out": self.blend_out, "lock": self.lock,
            "beats": dict(self._beats), "events": ev,
            "face": sorted(self.face_tl, key=lambda e: e["f"]),
            "cheat_deg": self.cheat_deg, "root": {"travel": self.travel},
            "stride_m": self.stride_m, "speed_m_s": self.speed_m_s,
            "variation": {"time_jitter": 0, "rot_jitter_deg": 0},
            "source": dict(self.source),
            "lint": {"skippable": self.skippable, "pop_frames": sorted(set(self.pop_frames)),
                     "freeze_holds": self.freeze_holds, "draft": self.draft},
        }
        if self.gaze:
            out["gaze"] = self.gaze
        if self.step:
            s = dict(self.step)
            s["support"] = [[int(f0), round(h, 4)] for f0, h in self.support]
            out["step"] = s
        if self.stage is not None and (self.lock == "rig_pm" or self.stage.facing != 1 or self.stage.x != 0.0):
            out["stage"] = self.stage.as_json()
        if self.keeps:
            out["keeps"] = self.keeps
        if self.tags:
            out["tags"] = self.tags
        return out

    def max_speed_deg(self, frames):
        worst, wn, wf = 0.0, "", 0
        for f in range(1, len(frames)):
            a, b = frames[f - 1], frames[f]
            for n in self.skel.names:
                d = P.qangle_deg(a.get(n)[1], b.get(n)[1])
                if d > worst:
                    worst, wn, wf = d, n, f
        return worst, wn, wf
