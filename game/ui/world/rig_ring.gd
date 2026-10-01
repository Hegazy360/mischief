## RigRing — the rig progress ring AT THE PROP (REDESIGN_3D §4.1, §4.2 "Rig", W2): radius 118 px,
## a 14 px stroke yellow #F2D23A → green #5CCF6A on an 18 px 35 % black track, centred on the prop's
## ring anchor, filling from 12 o'clock. It pulses at 3 Hz over the last 20 % while held; after a
## release it stays partial (dimmer, no pulse); completion pops it 1.0 → 1.18 → 1.0 and fades.
## Echoed on the action button. The node's position is the ring's centre.
## Next to a face (r3d QA Q-C1: the ring sat on Hush's face while she reached for a shelf prop) the
## ring passes BEHIND the head: `set_occluders(face boxes)` — the arc parts inside them are not drawn,
## so the ring stays on the prop and nothing covers her face.
class_name RigRing
extends Node2D

const RADIUS := 118.0
const STROKE := 14.0
const TRACK := 18.0
const YELLOW := Color("#F2D23A")
const GREEN := Color("#5CCF6A")
const PULSE_FROM := 0.8
const DONE_S := 0.35
## Angular bins of the occlusion test (5° each) and the most occluders kept.
const OCC_BINS := 72
const MAX_OCC := 2

var frac: float = 0.0
var active: bool = false
var k: float = 1.0

var _done_t: float = -1.0
var _shown: bool = false
## Screen-space rects the ring passes behind (a fixed pool; unused = Rect2()).
var _occ: Array[Rect2] = [Rect2(), Rect2()]
var _occ_n: int = 0
## Per bin: 1 = drawn (filled in _draw; no allocation).
var _vis := PackedByteArray()


func _init() -> void:
	_vis.resize(OCC_BINS)
	_vis.fill(1)


## The face boxes (screen px) the ring passes behind this frame; [] = none. Redraws on change.
func set_occluders(rects: Array[Rect2]) -> void:
	var n := 0
	var changed := false
	for r in rects:
		if n >= MAX_OCC or not r.has_area():
			continue
		if _occ[n] != r:
			_occ[n] = r
			changed = true
		n += 1
	if n != _occ_n:
		changed = true
	_occ_n = n
	if changed:
		queue_redraw()


## True when any part of the ring is hidden behind an occluder (tests).
func occluded() -> bool:
	_fill_vis(k)
	for b in _vis:
		if b == 0:
			return true
	return false


## Set the ring (frac 0..1; active = she holds now). Hidden via `visible`.
func set_data(p_frac: float, p_active: bool, p_k: float) -> void:
	var f := clampf(p_frac, 0.0, 1.0)
	if f >= 1.0 and frac < 1.0 and _shown:
		_done_t = 0.0
	_shown = true
	if is_equal_approx(f, frac) and p_active == active and is_equal_approx(p_k, k):
		_update_process()
		return
	frac = f
	active = p_active
	k = p_k
	queue_redraw()
	_update_process()


## Hide (keeps the completion pop running to its end).
func clear() -> void:
	_shown = false
	if _done_t < 0.0:
		visible = false


## The ring's drawn outer radius at k = 1 (the track's outer edge; the face keep-out uses it).
static func outer_radius() -> float:
	return RADIUS + TRACK * 0.5


## The ring's colour at `f` (yellow → green).
static func color_at(f: float) -> Color:
	return YELLOW.lerp(GREEN, clampf(f, 0.0, 1.0))


func _ready() -> void:
	set_process(false)


func _update_process() -> void:
	set_process(_done_t >= 0.0 or (active and frac >= PULSE_FROM and frac < 1.0))


func _process(delta: float) -> void:
	if _done_t >= 0.0:
		_done_t += delta
		if _done_t >= DONE_S:
			_done_t = -1.0
			if not _shown:
				visible = false
	queue_redraw()
	_update_process()


func _draw() -> void:
	var s := k
	var a := 1.0 if active or frac >= 1.0 else 0.7
	if _done_t >= 0.0 and not UiKit.reduce_motion():
		var t := _done_t / DONE_S
		s *= 1.0 + 0.18 * sin(minf(1.0, t * 2.0) * PI)
		a *= 1.0 - maxf(0.0, t * 2.0 - 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
	var pulse := 0.0
	if active and frac >= PULSE_FROM and frac < 1.0 and not UiKit.reduce_flash():
		pulse = 0.5 + 0.5 * sin(float(UiKit.now_ms()) * 0.001 * TAU * 3.0)
	_fill_vis(s)
	var a0 := -PI * 0.5
	var bin := TAU / float(OCC_BINS)
	UiShapes.begin()
	# the track: every visible run of bins
	var i := 0
	while i < OCC_BINS:
		if _vis[i] == 0:
			i += 1
			continue
		var j := i
		while j < OCC_BINS and _vis[j] == 1:
			j += 1
		UiShapes.arc(Vector2.ZERO, RADIUS, a0 + bin * i, a0 + bin * j, TRACK, Color(0, 0, 0, 0.35 * a), maxi(2, j - i + 1))
		i = j
	if frac > 0.0:
		var col := Color(color_at(frac).lightened(0.25 * pulse), a)
		var w := STROKE + 4.0 * pulse
		var end_a := a0 + TAU * frac
		i = 0
		while i < OCC_BINS and a0 + bin * i < end_a:
			if _vis[i] == 0:
				i += 1
				continue
			var j := i
			while j < OCC_BINS and _vis[j] == 1 and a0 + bin * j < end_a:
				j += 1
			var e := minf(a0 + bin * j, end_a)
			UiShapes.arc(Vector2.ZERO, RADIUS, a0 + bin * i, e, w, col, maxi(2, j - i + 1))
			i = j
	UiShapes.flush(self)
	draw_set_transform(Vector2.ZERO)


## Which bins are drawn at scale `s` (a bin is hidden when its middle, on the ring, lies inside an
## occluder grown by half the track).
func _fill_vis(s: float) -> void:
	_vis.fill(1)
	if _occ_n == 0:
		return
	var a0 := -PI * 0.5
	var bin := TAU / float(OCC_BINS)
	var rr := RADIUS * s
	var pad := TRACK * 0.5 * s
	for b in OCC_BINS:
		var a := a0 + bin * (float(b) + 0.5)
		var p := position + Vector2(cos(a), sin(a)) * rr
		for o in _occ_n:
			if _occ[o].grow(pad).has_point(p):
				_vis[b] = 0
				break
