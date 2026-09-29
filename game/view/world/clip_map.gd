## ClipMap — snapshot state → animation clips, in the s2-view map-key schema (brief §4.1.1,
## binding for both animation tasks). Pure: no nodes, no clip loading beyond existence and
## length checks.
##
## **Maps.** `load_map(rig)` = `view/world/default_maps/<rig>.json` overlaid key by key with
## `data/anim/<rig>/map.json` (the animation task's file wins whenever it has a key). An entry
## is a clip id, a list of clip ids (picked by a variant / seed), `""` (the actor is not drawn:
## Hush hidden) or `{"clip", "loop", "stride_px", "speed_px_s", "then", "while_moving"}`. Keys
## `bit:*` / `mg:*` expand per id with `{id}`. A `skin:<skin>` block overrides entries while that
## skin is on (Settings `hush_skin == "pip"`, both rigs).
##
## **Resolution order** (base layer): reaction (frame-locked to the sim; tier / suppressed; the
## `<clip>_ko` knock-on variant when `entry > 0`; `last_beat` after the settle;
## `reaction_fallback`) → `oneshot:<id>` / `bit:<id>` (frame-locked to the one-shot clock; rows
## clip_rules.json marks `overlay` go to the overlay layer instead) → `state:<state>`
## (`rigging@q|s|b` first while Hush rigs; a state entry without `stride_px` / `while_moving` is
## skipped while the actor moves, so CURIOUS / SEARCH walks use the walk) → `activity:<id>`
## while performing (the activities.json clip when the map has no key) → `freeze_midjob` /
## `freeze` → `door` / `stairs_up` / `stairs_down` on those legs → `run`, `walk@blind` /
## `walk@tier3` / `walk@on_guard` / `walk@tier2` / `walk` → `turn` → `flavour:<id>` →
## `idle_fidgets` → `idle`.
## **Overlay layer** (never during a reaction): a sim overlay one-shot (`oneshot:head_turn`,
## `specs_on`, `fizzle`) → `cue:<id>` → `mg:<id>` → an overlay flavour (`shrug`, `pickup`).
## Whenever a rule matches but its clip is not authored the pick records it (`wanted`,
## `ov_wanted`; CharacterView counts it for `WorldView.fallback_counts()`) and resolution falls
## through to the next rule — never a puppet, never nothing.
class_name ClipMap
extends RefCounted

const DEFAULT_DIR := "res://view/world/default_maps"
const ANIM_DIR := "res://data/anim"
## Reaction marker: the clip comes from the snapshot (`react_clip`).
const FROM_SIM := "<from sim>"
## Every key family of the schema (`*` = per id). Used by tests and SliceClips.
const SCHEMA_KEYS: PackedStringArray = ["idle", "idle_fidgets", "walk", "walk@tier2", "walk@tier3",
	"walk@blind", "walk@on_guard", "run", "turn", "door", "stairs_up", "stairs_down", "activity:*",
	"state:*", "rigging@q", "rigging@s", "rigging@b", "freeze", "freeze_midjob", "oneshot:*", "bit:*",
	"flavour:*", "mg:*", "cue:*", "reaction", "reaction_fallback", "skin:*"]
## Map keys that are metadata, not clips.
const META_KEYS: PackedStringArray = ["version", "rig", "doc", "stand_in", "note", "notes", "cadence"]


## The chosen clips for one frame (reused; no allocation per frame).
class Pick:
	## Base layer.
	var clip: String = ""
	var loop: bool = true
	## Playback rate multiplier (walk cycles scale with the actor's speed).
	var speed: float = 1.0
	## True when the frame is driven from a clock (the sim's reaction / one-shot clock or the
	## view's own flavour clock): `frame`.
	var external: bool = false
	var frame: float = 0.0
	## Which map key matched (debug / tests).
	var key: String = ""
	## The entry has `stride_px`: RigPlayer takes the actor's speed in px/s.
	var stride: bool = false
	## The matched entry is "": the actor is not drawn (Hush hidden).
	var hidden: bool = false
	## Reactions: PlayPlan options.
	var tier: int = 1
	var suppressed: bool = false
	var last_beat: String = ""
	## A clip the first matching rule wanted but is not authored ("" = none), and its key.
	var wanted: String = ""
	var wanted_key: String = ""
	## Overlay layer ("" = none).
	var ov_clip: String = ""
	var ov_key: String = ""
	var ov_frame: float = 0.0
	var ov_wanted: String = ""
	var ov_wanted_key: String = ""
	## Fallback for a missing micro-gag overlay: the emote to show as a face preset.
	var ov_face: String = ""
	## A view effect the current one-shot stages (`wipe`, `cane`, …) from clip_rules.json.
	var fx: String = ""
	## The one-shot row links this rig into another's socket (the Lecture dangle).
	var attach: bool = false

	func reset() -> void:
		clip = ""
		loop = true
		speed = 1.0
		external = false
		frame = 0.0
		key = ""
		stride = false
		hidden = false
		tier = 1
		suppressed = false
		last_beat = ""
		wanted = ""
		wanted_key = ""
		ov_clip = ""
		ov_key = ""
		ov_frame = 0.0
		ov_wanted = ""
		ov_wanted_key = ""
		ov_face = ""
		fx = ""
		attach = false


## View-side flags the snapshot does not carry (flavours, fidgets, turns, micro-gags, cues).
## CharacterView owns one per actor and updates it every frame.
class Ctx:
	## Rig id for clip_rules.json rows ("hush", "bellows").
	var rig: String = ""
	## Settings `hush_skin` ("" | "pip").
	var skin: String = ""
	## `(clip) -> bool` (default ClipMap.clip_exists) and `(clip) -> int` frames (default
	## ClipMap.clip_length).
	var exists_fn: Callable = Callable()
	var len_fn: Callable = Callable()
	## `(activity id) -> clip` for activities without a map key (activities.json `clip`).
	var activity_clip_fn: Callable = Callable()
	## Hush rigging tier of the current step: "q" | "s" | "b" | "".
	var rig_tier: String = ""
	## The state's variant (Meltdown A/B/C from `meltdown_start.variant`).
	var state_var: int = 0
	## Frames since a standing facing flip (−1 = none).
	var turn_f: float = -1.0
	## Base flavour ("snicker", "glance") and frames since it started.
	var flavour: String = ""
	var flavour_f: float = 0.0
	## Idle fidget index (−1 = none) and its frame.
	var fidget_i: int = -1
	var fidget_f: float = 0.0
	## Overlay flavour ("shrug", "pickup") and its frame.
	var ov_flavour: String = ""
	var ov_flavour_f: float = 0.0
	## Micro-gag overlay id, frame and emote (fallback face).
	var mg: String = ""
	var mg_f: float = 0.0
	var mg_emote: String = ""
	## Staged director cue overlay id and frame.
	var cue: String = ""
	var cue_f: float = 0.0


## Test hooks: rig → map used instead of the files; fixture clip ids that exist (id → frames).
static var map_override: Dictionary = {}
static var fixture_clips: Dictionary = {}

static var _exists: Dictionary = {}
static var _len: Dictionary = {}
static var _keys: Dictionary = {}
static var _wild: Dictionary = {}
static var _default_ctx: Ctx = Ctx.new()


## The merged map for a rig: the view's default map overlaid key by key with the animation
## task's `data/anim/<rig>/map.json` (its entries win). `skin:*` blocks merge the same way.
static func load_map(rig: String) -> Dictionary:
	if map_override.has(rig):
		return map_override[rig]
	var base: Variant = ViewKit.json("%s/%s.json" % [DEFAULT_DIR, rig])
	var data: Variant = ViewKit.json("%s/%s/map.json" % [ANIM_DIR, rig])
	return ClipMap.merge(base if base is Dictionary else {}, data if data is Dictionary else {})


## True when `data/anim/<rig>/map.json` exists (the animation task's map is live).
static func has_data_map(rig: String) -> bool:
	return FileAccess.file_exists("%s/%s/map.json" % [ANIM_DIR, rig])


## `over` wins key by key over `base`; `skin:*` sub-dictionaries merge the same way.
static func merge(base: Dictionary, over: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	for k in over:
		var ks := ViewKit.s(k)
		if ks.begins_with("skin:") and over[k] is Dictionary and out.get(ks, null) is Dictionary:
			var sk: Dictionary = (out[ks] as Dictionary).duplicate(true)
			for k2 in over[k]:
				sk[k2] = over[k][k2]
			out[ks] = sk
		else:
			out[ks] = over[k]
	return out


## True when the clip's JSON exists (`data/anim/<rig>/<name>.json`) or it is a registered
## fixture clip. Cached.
static func clip_exists(clip_id: String) -> bool:
	if clip_id == "":
		return false
	if fixture_clips.has(clip_id):
		return true
	if _exists.has(clip_id):
		return _exists[clip_id]
	var ok := FileAccess.file_exists("%s/%s.json" % [ANIM_DIR, clip_id])
	_exists[clip_id] = ok
	return ok


## A clip's length in frames (0 when unknown): fixture clips first, then ClipLib (owner rig).
static func clip_length(clip_id: String) -> int:
	if fixture_clips.has(clip_id):
		return int(fixture_clips[clip_id])
	if _len.has(clip_id):
		return _len[clip_id]
	var n := 0
	if ClipMap.clip_exists(clip_id):
		var c := ClipLib.get_clip(clip_id)
		n = c.length if c != null else 0
	_len[clip_id] = n
	return n


## Test hook: forget cached existence checks and lengths.
static func clear_cache() -> void:
	_exists.clear()
	_len.clear()
	_wild.clear()


## The entry for `key` (skin override → exact key → `*` family with `{id}`), or null.
static func entry(map: Dictionary, key: String, skin: String = "") -> Variant:
	if skin != "":
		var sk: Variant = map.get("skin:" + skin, null)
		if sk is Dictionary and (sk as Dictionary).has(key):
			return sk[key]
	if map.has(key):
		return map[key]
	var w := ClipRules.wildcard_of(key)
	if w != "" and map.has(w):
		var fam: Variant = map[w]
		var hit: Variant = _wild.get(key, null)
		if hit is Array and (hit as Array)[0] == fam:
			return (hit as Array)[1]
		var sub: Variant = ClipMap._subst(fam, key.substr(w.length() - 1))
		_wild[key] = [fam, sub]
		return sub
	return null


## The clip of an entry (a list picks `variant`); "" for "" / missing.
static func clip_of(e: Variant, variant: int = 0) -> String:
	if e is String:
		return e
	if e is Array:
		var arr: Array = e
		if arr.is_empty():
			return ""
		return ClipMap.clip_of(arr[absi(variant) % arr.size()], 0)
	if e is Dictionary:
		return ClipMap.clip_of((e as Dictionary).get("clip", ""), variant)
	return ""


## Every clip id an entry can name (lists, `then`), for manifests.
static func clips_of(e: Variant) -> PackedStringArray:
	var out := PackedStringArray()
	if e is String:
		if e != "":
			out.append(e)
	elif e is Array:
		for x in e:
			out.append_array(ClipMap.clips_of(x))
	elif e is Dictionary:
		out.append_array(ClipMap.clips_of((e as Dictionary).get("clip", "")))
		var th: Variant = (e as Dictionary).get("then", null)
		if th != null:
			out.append_array(ClipMap.clips_of(th))
	return out


## The map key a one-shot id selects: "bit:<bit>" stays itself, anything else "oneshot:<id>".
static func oneshot_key(id: String) -> String:
	if id == "":
		return ""
	return id if id.begins_with("bit:") else ClipMap._k("oneshot:", id)


## Resolve `a` (a ViewSnapshot.Actor) against `map` into `out`. `alpha` = the tick fraction.
## `ctx` carries the view-side flags (null = defaults).
static func resolve(map: Dictionary, a: ViewSnapshot.Actor, alpha: float, out: Pick, ctx: Ctx = null) -> void:
	out.reset()
	var c := ctx if ctx != null else _default_ctx
	if a.reacting and ClipMap._reaction(map, a, alpha, out, c):
		return
	var os_key := ""
	var os_layer := "base"
	if a.oneshot != "":
		os_key = ClipMap.oneshot_key(a.oneshot)
		os_layer = ClipRules.layer_of(os_key, c.rig)
		if os_layer == "fx" or os_layer == "none":
			out.fx = ViewKit.s(ClipRules.row(os_key, c.rig).get("fx", ""))
		if os_layer == "base" and ClipMap._base_oneshot(map, a, alpha, out, c, os_key):
			ClipMap._overlay(map, a, alpha, out, c, "")
			return
	ClipMap._base(map, a, out, c)
	ClipMap._overlay(map, a, alpha, out, c, os_key if os_layer == "overlay" else "")


# --- rules ---------------------------------------------------------------------------------

static func _reaction(map: Dictionary, a: ViewSnapshot.Actor, alpha: float, out: Pick, c: Ctx) -> bool:
	var t := float(a.react_t) + alpha
	var base_len := a.react_base_len if a.react_base_len > 0 else a.react_len
	out.tier = a.react_tier
	out.suppressed = a.react_suppressed
	out.last_beat = a.react_last_beat
	if a.react_last_beat != "" and base_len > 0 and a.react_t >= base_len:
		if ClipMap._ok(a.react_last_beat, c):
			out.clip = a.react_last_beat
			out.external = true
			out.loop = false
			out.frame = t - float(base_len)
			out.key = "reaction:last_beat"
			return true
		ClipMap._want(out, a.react_last_beat, "reaction:last_beat")
	var rc := a.react_clip
	var e: Variant = map.get("reaction", FROM_SIM)
	if e is String and e != FROM_SIM and e != "":
		rc = e
	if a.react_entry > 0 and rc != "":
		var ko := ClipMap._k(rc, "_ko")
		if ClipMap._ok(ko, c):
			rc = ko
	if ClipMap._ok(rc, c):
		out.clip = rc
		out.external = true
		out.loop = false
		out.frame = t
		out.key = "reaction"
		return true
	ClipMap._want(out, rc, "reaction")
	var fb := ClipMap.clip_of(map.get("reaction_fallback", ""))
	if ClipMap._ok(fb, c):
		out.clip = fb
		out.external = true
		out.loop = false
		out.frame = t
		out.key = "reaction_fallback"
		return true
	return false


static func _base_oneshot(map: Dictionary, a: ViewSnapshot.Actor, alpha: float, out: Pick, c: Ctx, key: String) -> bool:
	# The two-rig link (the Lecture dangle) is staging, not a clip: it holds even while the
	# dangle clip is still a fallback.
	var row0 := ClipRules.row(key, c.rig)
	var att0: Variant = row0.get("attach", null)
	if att0 is Dictionary:
		var skins0: Variant = (att0 as Dictionary).get("skins", [""])
		out.attach = skins0 is Array and (skins0 as Array).has(c.skin)
	var e: Variant = ClipMap.entry(map, key, c.skin)
	if e == null:
		ClipMap._want(out, key, key)
		return false
	var clip := ClipMap.clip_of(e, a.oneshot_var)
	if clip == "":
		if e is String:
			out.hidden = true
			out.key = key
			return true
		return false
	var frame := float(a.oneshot_t) + alpha
	var then := ViewKit.s((e as Dictionary).get("then", "")) if e is Dictionary else ""
	if then != "":
		var l0 := ClipMap._length(clip, c)
		if l0 > 0 and frame >= float(l0):
			if ClipMap._ok(then, c):
				clip = then
				frame -= float(l0)
			else:
				ClipMap._want(out, then, key)
	if not ClipMap._ok(clip, c):
		ClipMap._want(out, clip, key)
		return false
	var row := ClipRules.row(key, c.rig)
	out.clip = clip
	out.key = key
	out.external = true
	out.frame = frame
	out.loop = bool(row.get("loop", false))
	if e is Dictionary and (e as Dictionary).has("loop"):
		out.loop = bool((e as Dictionary)["loop"])
	return true


static func _base(map: Dictionary, a: ViewSnapshot.Actor, out: Pick, c: Ctx) -> void:
	# state:<state> (Hush rigging: the step's tier first)
	if a.state != "":
		if a.state == "RIGGING" and c.rig_tier != "":
			if ClipMap._try(map, ClipMap._k("rigging@", c.rig_tier), a, out, c, -1.0, 0):
				return
		var sk := ClipMap._state_key(a.state)
		var e: Variant = ClipMap.entry(map, sk, c.skin)
		if e != null and (not a.moving or ClipMap._is_loco(e)):
			var clip := ClipMap.clip_of(e, c.state_var)
			if clip == "":
				out.hidden = true
				out.key = sk
				return
			if ClipMap._ok(clip, c):
				ClipMap._apply(out, e, clip, sk, a)
				return
			ClipMap._want(out, clip, sk)
	# activity:<id> while performing (detours use their ids)
	if a.activity != "" and not a.moving:
		var ak := ClipMap._k("activity:", a.activity)
		var e2: Variant = ClipMap.entry(map, ak, c.skin)
		var clip2 := ClipMap.clip_of(e2) if e2 != null else ""
		if e2 == null and c.activity_clip_fn.is_valid():
			clip2 = ViewKit.s(c.activity_clip_fn.call(a.activity))
		if clip2 != "":
			if ClipMap._ok(clip2, c):
				ClipMap._apply(out, e2, clip2, ak, a)
				return
			ClipMap._want(out, clip2, ak)
	# freeze (mid-job first)
	if a.frozen or a.state == "FROZEN":
		if a.rig_pm > 0 and ClipMap._try(map, "freeze_midjob", a, out, c, -1.0, 0):
			return
		if ClipMap._try(map, "freeze", a, out, c, -1.0, a.freeze_pose_seed):
			return
	# door / stairs legs
	if a.leg_kind == "door":
		if ClipMap._try(map, "door", a, out, c, -1.0, 0):
			return
	elif a.leg_kind == "stairs":
		if ClipMap._try(map, "stairs_up" if a.leg_up else "stairs_down", a, out, c, -1.0, 0):
			return
	# run / walk variants
	if a.moving or a.leg_kind == "door" or a.leg_kind == "stairs":
		if a.running and ClipMap._try(map, "run", a, out, c, -1.0, 0):
			return
		if a.blinded and ClipMap._try(map, "walk@blind", a, out, c, -1.0, 0):
			return
		if a.tier >= 3 and ClipMap._try(map, "walk@tier3", a, out, c, -1.0, 0):
			return
		if a.on_guard and ClipMap._try(map, "walk@on_guard", a, out, c, -1.0, 0):
			return
		if a.tier >= 2 and ClipMap._try(map, "walk@tier2", a, out, c, -1.0, 0):
			return
		if ClipMap._try(map, "walk", a, out, c, -1.0, 0):
			return
	# turn (a standing facing flip)
	if c.turn_f >= 0.0 and not a.moving and ClipMap._try(map, "turn", a, out, c, c.turn_f, 0):
		out.loop = false
		return
	# base flavour (snicker → glance) and idle fidgets
	if c.flavour != "" and ClipMap._try(map, ClipMap._k("flavour:", c.flavour), a, out, c, c.flavour_f, 0):
		out.loop = false
		return
	if c.fidget_i >= 0 and ClipMap._try(map, "idle_fidgets", a, out, c, c.fidget_f, c.fidget_i):
		out.loop = false
		return
	ClipMap._try(map, "idle", a, out, c, -1.0, 0)


static func _overlay(map: Dictionary, a: ViewSnapshot.Actor, alpha: float, out: Pick, c: Ctx, os_key: String) -> void:
	if os_key != "":
		if ClipMap._try_ov(map, os_key, out, c, float(a.oneshot_t) + alpha, a.oneshot_var):
			return
	if c.cue != "":
		if ClipMap._try_ov(map, ClipMap._k("cue:", c.cue), out, c, c.cue_f, 0):
			return
	if c.mg != "":
		if ClipMap._try_ov(map, ClipMap._k("mg:", c.mg), out, c, c.mg_f, 0):
			return
		out.ov_face = c.mg_emote
		return
	if c.ov_flavour != "":
		ClipMap._try_ov(map, ClipMap._k("flavour:", c.ov_flavour), out, c, c.ov_flavour_f, 0)


## Try one base key; `ext_frame` ≥ 0 plays it on that clock. True when it plays.
static func _try(map: Dictionary, key: String, a: ViewSnapshot.Actor, out: Pick, c: Ctx, ext_frame: float, variant: int) -> bool:
	var e: Variant = ClipMap.entry(map, key, c.skin)
	if e == null:
		return false
	var clip := ClipMap.clip_of(e, variant)
	if clip == "":
		return false
	if not ClipMap._ok(clip, c):
		ClipMap._want(out, clip, key)
		return false
	ClipMap._apply(out, e, clip, key, a)
	if ext_frame >= 0.0:
		out.external = true
		out.frame = ext_frame
	return true


static func _try_ov(map: Dictionary, key: String, out: Pick, c: Ctx, frame: float, variant: int) -> bool:
	var e: Variant = ClipMap.entry(map, key, c.skin)
	var clip := ClipMap.clip_of(e, variant) if e != null else ""
	if clip == "" or not ClipMap._ok(clip, c):
		if out.ov_wanted == "":
			out.ov_wanted = clip if clip != "" else key
			out.ov_wanted_key = key
		return false
	out.ov_clip = clip
	out.ov_key = key
	out.ov_frame = frame
	return true


static func _apply(out: Pick, entry_v: Variant, clip: String, key: String, a: ViewSnapshot.Actor) -> void:
	out.key = key
	out.clip = clip
	out.loop = true
	out.speed = 1.0
	out.stride = false
	if entry_v is Dictionary:
		var d: Dictionary = entry_v
		out.loop = bool(d.get("loop", true))
		out.stride = d.has("stride_px")
		var nominal := float(d.get("speed_px_s", 0.0))
		if nominal > 0.0 and a.speed_px_s > 0.0:
			out.speed = clampf(a.speed_px_s / nominal, 0.25, 3.0)


static func _is_loco(e: Variant) -> bool:
	return e is Dictionary and ((e as Dictionary).has("stride_px") or bool((e as Dictionary).get("while_moving", false)))


static func _want(out: Pick, clip: String, key: String) -> void:
	if out.wanted == "":
		out.wanted = clip
		out.wanted_key = key


static func _ok(clip: String, c: Ctx) -> bool:
	if clip == "":
		return false
	if c.exists_fn.is_valid():
		return bool(c.exists_fn.call(clip))
	return ClipMap.clip_exists(clip)


static func _length(clip: String, c: Ctx) -> int:
	if c.len_fn.is_valid():
		return int(c.len_fn.call(clip))
	return ClipMap.clip_length(clip)


## Interned "prefix + id" keys (resolution runs every frame: no string building after warm-up).
static func _k(prefix: String, id: String) -> String:
	var d: Variant = _keys.get(prefix, null)
	if d == null:
		d = {}
		_keys[prefix] = d
	var dd: Dictionary = d
	var hit: Variant = dd.get(id, null)
	if hit != null:
		return hit
	var s := prefix + id
	dd[id] = s
	return s


static func _state_key(state: String) -> String:
	var hit: Variant = _keys.get(state, null)
	if hit is String:
		return hit
	var s := "state:" + state.to_lower()
	_keys[state] = s
	return s


static func _subst(e: Variant, id: String) -> Variant:
	if e is String:
		return (e as String).replace("{id}", id)
	if e is Array:
		var out: Array = []
		for x in e:
			out.append(ClipMap._subst(x, id))
		return out
	if e is Dictionary:
		var d: Dictionary = (e as Dictionary).duplicate()
		if d.has("clip"):
			d["clip"] = ClipMap._subst(d["clip"], id)
		return d
	return e
