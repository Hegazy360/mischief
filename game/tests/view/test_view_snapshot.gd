## ViewSnapshot.from_sim (TECH §5.4) against a stub world with the TECH §3.4 accessors and
## §3.7.1–§3.7.2 field names (interned ints, enum states), against FakeWorld, and — when the
## sim exists — against the real SimWorld on the sim's fixtures (soft).
extends TestBase

const SIM_WORLD := "res://sim/world/sim_world.gd"
const CONTENT_DB := "res://sim/content/content_db.gd"


class StubHush:
	enum State { IDLE, WALK, RUN, STAIRS, DOOR, RUMMAGE, PICK_WINDOW, RIGGING, DIVING, HIDDEN, POPPING, FROZEN,
		SQUEAKING, CAUGHT, BOWING }
	var room: int = 1          # an interned id: index into the sorted room ids
	var floor: int = 0
	var x_sub: int = 3000 * 60
	var facing: int = -1
	var state: int = State.RIGGING
	var hidden_spot: String = ""
	var watched_spot: String = ""
	var frozen: bool = false
	var freeze_pose_seed: int = 5
	var carrying: Array = ["squeaker"]
	var rig_prank: String = "achoo_ria"
	var rig_step: int = 0


class StubBellows:
	enum State { ROUTINE, DETOUR, CURIOUS, SPOTTED, CHASE, SEARCH, REACTING, MELTDOWN, EXHAUSTED, CAUGHT_HOLD }
	var room: String = "kitchen"
	var floor: int = 0
	var x_sub: int = 2900 * 60
	var facing: int = 1
	var state: int = State.REACTING
	var activity_id: String = "tea"
	var activity_t: int = 120
	var activity_len: int = 600
	var detour: Variant = {"kind": "fixup_mirror", "station": "st_hall_mirror"}
	var specs_on: bool = true
	var blinded_until: int = 999
	var temper_q: int = 45 * 60
	var tier: int = 2
	var residues: Array = ["FRAZZLED", "SOAKED"]
	var spot_meter: int = 30
	var spot_fill: int = 60
	var ear_pips: int = 2
	var reacting: Variant = {"prank": "achoo_ria", "archetype": "sneeze_blast", "variant": "b", "tier": 2,
		"suppressed": false, "t": 40, "len": 180}
	var look_back_until: int = 0
	var on_guard_until: int = 0


class StubWorld extends RefCounted:
	var tick: int = 100
	var ended: bool = false
	var hush: StubHush = StubHush.new()
	var bellows: StubBellows = StubBellows.new()
	var db: Variant = null

	func bubble() -> Dictionary:
		return {"next": "pickles", "icon": "res://art/icons/activities/pickles.svg", "ring_ticks": 200,
			"glyph": "specs_on", "ear_pips": 2}

	func hotspot_state(id: String) -> Dictionary:
		return {"kind": "rig_point", "enabled": true, "rigged": id == "kitchen_honey", "spent": false}

	func bellows_path_preview(_ticks: int) -> PackedInt32Array:
		return PackedInt32Array([4, 2950 * 60, 4, 3000 * 60])

	func rig_progress_pm(_id: String) -> int:
		return 500

	func applause_tenths() -> int:
		return 420

	func link() -> int:
		return 2

	func fuse_ticks() -> int:
		return 300

	func tomatoes() -> int:
		return 1

	func tomatoes_max() -> int:
		return 3


func test_from_stub_world_with_tech_fields() -> void:
	var w := StubWorld.new()
	var s := ViewSnapshot.from_sim(w)
	assert_eq(s.tick, 100)
	var sorted := HouseLayout.default_room_ids()
	sorted.sort()
	assert_eq(s.hush.room, sorted[1], "interned room int → id")
	assert_almost_eq(s.hush.x, 3000.0, 0.001, "sub-px → px")
	assert_eq(s.hush.y, 0.0)
	assert_eq(s.hush.facing, -1)
	assert_eq(s.hush.state, "RIGGING", "enum int → name via the script's enum")
	assert_eq(s.hush.rig_pm, 500)
	assert_eq(s.hush.carrying, PackedStringArray(["squeaker"]))
	assert_eq(s.bellows.state, "REACTING")
	assert_true(s.bellows.reacting)
	assert_eq(s.bellows.react_clip, "bellows/rx_sneeze_blast_b", "TECH §14 clip id")
	assert_eq(s.bellows.react_t, 40)
	assert_eq(s.bellows.react_tier, 2)
	assert_true(s.bellows.blinded)
	assert_almost_eq(s.bellows.spot_pct, 0.5, 0.001)
	assert_eq(s.bellows.residues, PackedStringArray(["FRAZZLED", "SOAKED"]))
	assert_eq(s.bellows.detour_kind, "fixup_mirror")
	assert_eq(s.bubble_next, "pickles")
	assert_eq(s.bubble_ring_ticks, 200)
	assert_eq(s.bubble_glyph, "specs_on")
	assert_eq(s.applause_tenths, 420)
	assert_eq(s.link, 2)
	assert_eq(s.fuse_ticks, 300)
	assert_eq(s.tomatoes_max, 3)
	assert_eq(s.path_rooms.size(), 2)
	assert_almost_eq(s.path_x[1], 3000.0, 0.001)
	assert_true(bool(s.hotspots.get("kitchen_honey", {}).get("rigged", false)))


func test_upper_floor_y_and_motion_flags() -> void:
	var w := StubWorld.new()
	var prev := ViewSnapshot.from_sim(w)
	w.bellows.floor = 1
	w.bellows.x_sub += 4 * 60
	w.bellows.state = StubBellows.State.ROUTINE
	w.bellows.reacting = null
	w.bellows.floor = 0
	var s := ViewSnapshot.new()
	s.fill(w, prev)
	assert_true(s.bellows.moving)
	assert_almost_eq(s.bellows.speed_px_s, 240.0, 0.5)
	assert_false(s.bellows.reacting)
	w.hush.floor = 1
	s.fill(w, prev)
	assert_eq(s.hush.y, -700.0, "upper floor line")


func test_glyph_normalisation_and_state_strings() -> void:
	var b := ViewSnapshot.Actor.new()
	assert_eq(ViewSnapshot.normalise_glyph("zZ", b), "asleep")
	assert_eq(ViewSnapshot.normalise_glyph("dangling", b), "specs_off")
	b.reacting = true
	assert_eq(ViewSnapshot.normalise_glyph("", b), "stars")
	assert_eq(ViewSnapshot.state_name(RefCounted.new(), "chase", PackedStringArray(), "ROUTINE"), "CHASE")


func test_fake_world_produces_the_same_shape() -> void:
	var fw := FakeWorld.create()
	fw.loop = false
	fw.seek(700)
	var s := ViewSnapshot.from_sim(fw)
	assert_eq(s.bellows.state, "REACTING")
	assert_eq(s.bellows.react_prank, "achoo_ria")
	assert_eq(s.bellows.react_clip, "bellows/rx_sneeze_blast_a")
	assert_eq(s.hush.state, "HIDDEN")
	assert_eq(s.hush.hidden_spot, "kitchen_pantry_curtain")
	assert_eq(s.bubble_glyph, "stars")
	assert_true(s.hotspots.has("kitchen_honey"))


func test_against_real_sim_world_if_present() -> void:
	var sw := ViewKit.soft_script(SIM_WORLD)
	var cdb := ViewKit.soft_script(CONTENT_DB)
	if sw == null or cdb == null:
		skip("sim not built yet (SimWorld / ContentDB missing)")
		return
	var root := "res://tests/sim/fixtures"
	if not DirAccess.dir_exists_absolute(root):
		skip("sim fixtures not present")
		return
	allow_errors()
	var db: Variant = cdb.call("load_dir", root)
	if not (db is Object):
		skip("ContentDB.load_dir(fixtures) failed")
		return
	var ep := ""
	var eps: Variant = (db as Object).get("episodes")
	if eps is Dictionary and not (eps as Dictionary).is_empty():
		var keys := (eps as Dictionary).keys()
		keys.sort()
		ep = String(keys[0])
	if ep == "":
		skip("no fixture episode")
		return
	var w: Variant = sw.call("create", db, ep, {})
	if not (w is Object):
		skip("SimWorld.create failed on the fixtures")
		return
	for i in 120:
		(w as Object).call("step", [])
		(w as Object).call("drain_events")
	var s := ViewSnapshot.from_sim(w)
	assert_eq(s.tick, 120)
	assert_true(s.hush.present and s.bellows.present, "both actors read")
	assert_ne(s.hush.room, "", "Hush's room resolves to an id")
	assert_ne(s.bellows.state, "", "Bellows' state resolves to a name")
	assert_true(ViewSnapshot.BELLOWS_STATES.has(s.bellows.state), "a TECH §3.7.1 state: %s" % s.bellows.state)
	assert_true(ViewSnapshot.HUSH_STATES.has(s.hush.state), "a TECH §3.7.2 state: %s" % s.hush.state)
