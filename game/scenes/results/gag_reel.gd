## GagReel — the Night's Gag Reel recording (GDD §6.2, s2-night §4.3) and its moment windows; the playback is
## GagReel3D (the recorded MomentRecorder3D windows re-staged in a SubViewport, r3d-night).
##
## Recording (`GagReel.Log`, fed by NightScene every tick during PLAY): one **moment** per reaction:
## `reaction_start` (antic − 12 f) → `reaction_end` (hold end + the sim's last beat, which the sim includes in the
## length); a knock-on (`reaction_start.entry > 0` right after its trigger) merges into the moment of its trigger (the
## sneeze → the drench is ONE moment); each moment keeps its Applause (the gag's `applause` events), tier, variant,
## the "+NEW!" keys it produced and its MomentRecorder3D window (`keep_3d`). World clones (`record_clones`, the 2D
## reel's re-sim; off in 3D) stay available for tests. (The 2D playback node was removed with the 2D view,
## r3d-integrate.)
class_name GagReel
extends RefCounted

## Ticks before a reaction's start a moment opens (the anticipation's run-up).
const PRE_TICKS := 12


## Per-Night recording of reel moments (pure data + world clones in 2D; in 3D the view's MomentRecorder3D windows).
class Log:
	extends RefCounted
	var clone_every: int = 60
	var ring_size: int = 4
	var moments: Array = []
	## 3D (NightScene sets it false): no world clones — each moment keeps a MomentRecorder3D window (`rec`) instead
	## (`keep_3d`), re-staged by GagReel3D.
	var record_clones: bool = true
	var _ring: Array = []          # [[tick, clone], …] oldest first
	var _open: int = -1

	func reset() -> void:
		moments.clear()
		_ring.clear()
		_open = -1

	## Per tick (NightScene._on_ticked): clones on the ring cadence, moments from the reaction events.
	func on_events(events: Array, world: Object) -> void:
		if world == null or not world.has_method("clone"):
			return
		var t := int(world.get("tick"))
		if record_clones and (_ring.is_empty() or t - int(_ring[_ring.size() - 1][0]) >= clone_every):
			_ring.append([t, world.call("clone")])
			while _ring.size() > ring_size:
				_ring.pop_front()
		for ev in events:
			var d: Dictionary = ev
			match String(d.get("e", "")):
				"reaction_start":
					_start(d, t)
				"reaction_accent":
					if _open >= 0 and int(moments[_open]["accent"]) < 0:
						moments[_open]["accent"] = int(d.get("t", t))
				"reaction_end":
					if _open >= 0:
						moments[_open]["end"] = int(d.get("t", t))
				"applause":
					if _open >= 0 and String(d.get("kind", "")) != "catch":
						moments[_open]["applause"] = int(moments[_open]["applause"]) + int(d.get("delta", 0))

	func _start(d: Dictionary, t: int) -> void:
		var st := int(d.get("t", t))
		var entry := int(d.get("entry", 0))
		var prank := String(d.get("prank", ""))
		var key := "rx:%s:t%d:%s" % [prank, int(d.get("tier", 1)), String(d.get("variant", "a"))]
		if entry > 0 and _open >= 0 and st - int(moments[_open]["end"]) <= 30:
			var m: Dictionary = moments[_open]
			(m["chain"] as Array).append(prank)
			(m["keys"] as Array).append(key)
			m["end"] = st + int(d.get("len", 0))
			m["tier"] = maxi(int(m["tier"]), int(d.get("tier", 1)))
			return
		var base: Variant = null
		var base_tick := -1
		for i in range(_ring.size() - 1, -1, -1):
			if int(_ring[i][0]) <= st - GagReel.PRE_TICKS:
				base = (_ring[i][1] as Object).call("clone")
				base_tick = int(_ring[i][0])
				break
		moments.append({"prank": prank, "chain": [prank], "keys": [key], "start": st, "accent": -1,
			"end": st + int(d.get("len", 0)), "tier": int(d.get("tier", 1)), "variant": String(d.get("variant", "a")),
			"applause": 0, "base": base, "base_tick": base_tick, "new": false, "rec": -1})
		_open = moments.size() - 1

	## 3D (after `on_events` on the same tick): keep / extend the recorder window of the open moment
	## ([start − PRE_TICKS, end]; a window that ends in the future fills as ticks arrive).
	func keep_3d(events: Array, recorder: Object) -> void:
		if recorder == null or _open < 0 or not recorder.has_method("keep"):
			return
		for ev in events:
			var e := String((ev as Dictionary).get("e", ""))
			if e != "reaction_start" and e != "applause":
				continue
			var m: Dictionary = moments[_open]
			var from := int(m["start"]) - GagReel.PRE_TICKS
			var want_to := int(m["end"])
			var rec := int(m.get("rec", -1))
			var mo: Variant = recorder.call("moment", rec) if rec >= 0 else null
			if mo != null and int((mo as Object).get("to_tick")) == want_to:
				(mo as Object).set("applause", int(m["applause"]))
				continue
			if mo != null and bool((mo as Object).get("open")):
				# still filling (a knock-on merged into it): just move its end
				(mo as Object).set("to_tick", want_to)
				(mo as Object).set("applause", int(m["applause"]))
				continue
			if mo != null:
				(mo as Object).set("used", false)
			m["rec"] = int(recorder.call("keep", from, want_to, "gag:%s" % String(m["prank"]), int(m["applause"])))

	## The moments to show: best `n` by Applause (ties: higher tier, then later), in Night order;
	## `new_keys` marks "+NEW!" moments; `repeat` = best 1 + every new one.
	func best(n: int, repeat: bool = false) -> Array:
		var ok: Array = []
		for m in moments:
			if (m as Dictionary).get("base") != null or int((m as Dictionary).get("rec", -1)) >= 0:
				ok.append(m)
		ok.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if int(a["applause"]) != int(b["applause"]):
				return int(a["applause"]) > int(b["applause"])
			if int(a["tier"]) != int(b["tier"]):
				return int(a["tier"]) > int(b["tier"])
			return int(a["start"]) > int(b["start"]))
		var pick: Array = []
		for m in ok:
			if pick.size() < (1 if repeat else n):
				pick.append(m)
			elif repeat and bool(m.get("new", false)) and pick.size() < n:
				pick.append(m)
		pick.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["start"]) < int(b["start"]))
		return pick


## Tick window [from, to] of a moment within a per-moment share of the reel (seconds).
static func window(m: Dictionary, share_s: float) -> Vector2i:
	var start := int(m.get("start", 0)) - PRE_TICKS
	var accent := int(m.get("accent", -1))
	var end := int(m.get("end", start + 120))
	var share := maxi(60, int(share_s * 60.0))
	var from := start
	if accent >= 0 and accent - start > int(share * 0.45):
		from = accent - int(share * 0.45)
	var to := mini(end, from + share)
	return Vector2i(from, maxi(from + 1, to))

