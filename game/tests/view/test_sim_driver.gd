## SimDriver (TECH §5.2): accumulator rates, ×3 fast-forward only while hidden and its
## auto-off, the 8-tick cap, pause, safety slow-mo, hit-stop via JuiceClock, alpha, command
## order, ticked(events), reset — and it never touches Engine.time_scale.
extends TestBase

const DT := 1.0 / 60.0


class StubHush:
	var room: String = "kitchen"
	var floor: int = 0
	var x_sub: int = 60000
	var facing: int = 1
	var state: String = "IDLE"


class StubWorld extends RefCounted:
	var tick: int = 0
	var hush: StubHush = StubHush.new()
	var bellows: Variant = null
	var steps: int = 0
	var cmds_seen: Array = []
	var pending: Array = []
	var resets: int = 0

	func step(cmds: Array) -> void:
		tick += 1
		steps += 1
		for c in cmds:
			cmds_seen.append([tick, c])

	func drain_events() -> Array:
		var e := pending
		pending = []
		return e

	func reset() -> void:
		resets += 1
		tick = 0


var _d: SimDriver = null
var _w: StubWorld = null


func before_each() -> void:
	_w = StubWorld.new()
	_d = SimDriver.new()
	_d.juice.test_now_us = 1_000_000
	_d.setup(_w)


func after_each() -> void:
	_d.free()


func _frames(n: int, dt: float = DT) -> int:
	var total := 0
	for i in n:
		total += _d.advance(dt)
	return total


func test_one_tick_per_frame_at_rate_1() -> void:
	assert_eq(_frames(60), 60)
	assert_eq(_w.tick, 60)


func test_pause_stops_ticks() -> void:
	_d.set_paused(true)
	assert_eq(_frames(30), 0)
	assert_eq(_d.rate(), 0.0)
	_d.set_paused(false)
	assert_eq(_frames(30), 30)


func test_ff_only_honoured_while_hidden() -> void:
	_d.set_ff(true)
	assert_true(_d.ff_requested())
	assert_eq(_frames(10), 10, "not hidden: ×1")
	_w.hush.state = "HIDDEN"
	_frames(1)   # the snapshot picks up HIDDEN
	assert_true(_d.ff_active())
	assert_eq(_frames(10), 30, "hidden: ×3")


func test_ff_auto_off_on_danger_events() -> void:
	_w.hush.state = "HIDDEN"
	_frames(1)
	for ev in [{"e": "prank_fire", "prank": "x"}, {"e": "spot_start", "by": "bellows"},
			{"e": "entry_warning", "room": "kitchen", "eta": 90}]:
		_d.set_ff(true)
		_w.pending = [ev]
		_frames(1)
		assert_false(_d.ff_requested(), "ff dropped on %s" % ev["e"])
	# An entry warning for another room keeps ⏩.
	_d.set_ff(true)
	_w.pending = [{"e": "entry_warning", "room": "bedroom", "eta": 90}]
	_frames(1)
	assert_true(_d.ff_requested(), "other room keeps ff")


func test_max_8_ticks_per_frame_and_drop_the_rest() -> void:
	assert_eq(_d.advance(1.0), SimDriver.MAX_TICKS_PER_FRAME)
	assert_lt(_d.alpha(), 1.0, "the backlog is dropped")
	assert_eq(_d.advance(DT), 1, "next frame is normal again")


func test_alpha_is_the_tick_fraction() -> void:
	_d.advance(DT * 0.5)
	assert_almost_eq(_d.alpha(), 0.5, 0.001)
	_d.advance(DT * 0.25)
	assert_almost_eq(_d.alpha(), 0.75, 0.001)
	_d.advance(DT * 0.5)
	assert_almost_eq(_d.alpha(), 0.25, 0.001)


func test_safety_slowmo_halves_the_rate() -> void:
	_d.set_safety_slowmo(true)
	assert_eq(_frames(60), 30)
	assert_almost_eq(_d.view_delta(), DT * 0.5, 1e-6)


func test_hitstop_slows_via_juice_never_engine_time_scale() -> void:
	_d.juice.request_kind(&"hit_big")
	assert_almost_eq(_d.juice.scale(), JuiceClock.FREEZE_SCALE, 1e-6)
	assert_eq(_frames(4), 0, "frozen: 0.05 × 4 frames < 1 tick")
	assert_eq(Engine.time_scale, 1.0, "Engine.time_scale untouched")
	_d.juice.test_now_us += 100_000
	assert_eq(_frames(10), 10, "after the freeze ticks resume")


func test_commands_arrive_next_tick_in_order() -> void:
	_d.push_cmd({"c": "go", "hotspot": "a"})
	_d.push_cmd({"c": "freeze", "on": true})
	_frames(1)
	assert_eq(_w.cmds_seen.size(), 2)
	assert_eq(_w.cmds_seen[0][0], 1)
	assert_eq(String(_w.cmds_seen[0][1]["c"]), "go")
	assert_eq(String(_w.cmds_seen[1][1]["c"]), "freeze")
	assert_eq(_d.cmd_log.size(), 2, "commands logged")
	_frames(1)
	assert_eq(_w.cmds_seen.size(), 2, "not repeated")


func test_ticked_emits_each_tick_with_its_events() -> void:
	var got: Array = []
	_d.ticked.connect(func(evs: Array) -> void: got.append(evs.size()))
	_w.pending = [{"e": "rigged", "prank": "p"}]
	_d.advance(DT * 3.0)
	assert_eq(got, [1, 0, 0])


func test_snapshots_swap_and_track_the_world() -> void:
	_w.hush.x_sub = 60 * 100
	_frames(1)
	var s1 := _d.snapshot().hush.x
	_w.hush.x_sub = 60 * 110
	_frames(1)
	assert_almost_eq(_d.prev_snapshot().hush.x, s1, 0.01)
	assert_almost_eq(_d.snapshot().hush.x, 110.0, 0.01)


func test_reset_resets_world_and_juice() -> void:
	_frames(5)
	_d.set_ff(true)
	_d.juice.request_kind(&"hit_small")
	_d.reset()
	assert_eq(_w.resets, 1)
	assert_false(_d.ff_requested())
	assert_almost_eq(_d.juice.scale(), 1.0, 1e-6)
	assert_eq(_d.snapshot().tick, 0)
