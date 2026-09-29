## ClipEvents — the events a clip crosses between two frames (TECH §5.3), for audio, FX and
## the camera. Semantics: an event at frame f fires when f0 < f ≤ f1 (so starting a clip at
## frame 0 with f0 = -1 fires its frame-0 events). Looping clips wrap (an f1 below f0 means
## the clip wrapped: (f0, length) then [0, f1]).
##
## `between()` returns a new Array (tools, tests); the players use `between_into()` with a
## reused Array, which allocates nothing once the array has grown.
class_name ClipEvents
extends RefCounted


## Events of `clip` crossed going from frame f0 to f1 (new Array).
static func between(clip: ClipDef, f0: float, f1: float) -> Array:
	var out: Array = []
	between_into(clip, f0, f1, out)
	return out


## Same as between() into `out` (cleared first). Returns the count.
static func between_into(clip: ClipDef, f0: float, f1: float, out: Array) -> int:
	out.clear()
	if clip == null or clip.ev_f.is_empty():
		return 0
	if clip.loop and f1 < f0:
		collect(clip.ev_f, clip.events, f0, float(clip.length), out)
		collect(clip.ev_f, clip.events, -1.0, f1, out)
	else:
		collect(clip.ev_f, clip.events, f0, f1, out)
	return out.size()


## Appends every events[i] with f0 < ev_f[i] ≤ f1 (ev_f sorted ascending) to `out`.
static func collect(ev_f: PackedInt32Array, events: Array, f0: float, f1: float, out: Array) -> void:
	if f1 <= f0 or ev_f.is_empty():
		return
	var i := ev_f.bsearch(int(floor(f0)) + 1, true)
	var n := ev_f.size()
	while i < n and float(ev_f[i]) <= f1:
		out.append(events[i])
		i += 1
