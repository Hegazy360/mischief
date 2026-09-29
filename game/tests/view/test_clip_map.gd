## ClipMap (TECH §5.4 map.json): reaction frame-lock, state → activity → freeze → walk/run →
## idle order, missing clips fall through, walk speed scaling, the default maps.
extends TestBase

const MAP := {
	"idle": "b/idle",
	"walk": {"clip": "b/walk", "stride_px": 56, "speed_px_s": 240},
	"run": "b/run",
	"reaction": "<from sim>",
	"reaction_fallback": "b/rx_generic",
	"state:chase": "b/chase",
	"state:hidden": "",
	"activity:tea": "b/tea",
	"freeze": ["b/f1", "b/f2", "b/f3"],
}

var _have: Dictionary = {}


func _exists(c: String) -> bool:
	return _have.is_empty() or _have.has(c)


func _pick(a: ViewSnapshot.Actor, alpha: float = 0.0) -> ClipMap.Pick:
	var p := ClipMap.Pick.new()
	ClipMap.resolve(MAP, a, alpha, p, _exists)
	return p


func before_each() -> void:
	_have.clear()


func test_reaction_is_frame_locked() -> void:
	var a := ViewSnapshot.Actor.new()
	a.reacting = true
	a.react_clip = "b/rx_sneeze_blast_a"
	a.react_t = 41
	var p := _pick(a, 0.5)
	assert_eq(p.clip, "b/rx_sneeze_blast_a")
	assert_true(p.external)
	assert_almost_eq(p.frame, 41.5, 1e-6)
	assert_false(p.loop)


func test_missing_reaction_clip_uses_the_fallback() -> void:
	_have = {"b/rx_generic": true, "b/idle": true}
	var a := ViewSnapshot.Actor.new()
	a.reacting = true
	a.react_clip = "b/rx_not_authored"
	assert_eq(_pick(a).clip, "b/rx_generic")


func test_order_state_activity_freeze_walk_idle() -> void:
	var a := ViewSnapshot.Actor.new()
	a.state = "CHASE"
	a.moving = true
	assert_eq(_pick(a).key, "state:chase")
	a.state = "ROUTINE"
	a.activity = "tea"
	a.moving = false
	assert_eq(_pick(a).clip, "b/tea")
	a.activity = ""
	a.frozen = true
	a.freeze_pose_seed = 4
	assert_eq(_pick(a).clip, "b/f2", "seed % 3")
	a.frozen = false
	a.moving = true
	a.speed_px_s = 120.0
	var p := _pick(a)
	assert_eq(p.clip, "b/walk")
	assert_almost_eq(p.speed, 0.5, 1e-6, "walk rate follows speed")
	assert_true(p.stride)
	a.running = true
	assert_eq(_pick(a).clip, "b/run")
	a.moving = false
	a.running = false
	assert_eq(_pick(a).clip, "b/idle")


func test_hidden_state_draws_nothing() -> void:
	var a := ViewSnapshot.Actor.new()
	a.state = "HIDDEN"
	var p := _pick(a)
	assert_eq(p.key, "state:hidden")
	assert_eq(p.clip, "")


func test_unauthored_activity_falls_back_to_idle() -> void:
	_have = {"b/idle": true}
	var a := ViewSnapshot.Actor.new()
	a.activity = "tea"
	assert_eq(_pick(a).clip, "b/idle")


func test_default_maps_load() -> void:
	for rig in ["hush", "bellows", "_mannequin"]:
		var m := ClipMap.load_map(rig)
		assert_true(m.has("idle"), "%s map has idle" % rig)
	assert_eq((ClipMap.load_map("hush")["freeze"] as Array).size(), 8, "8 freeze poses")
