## E2eProbe's two false reds (s2-fix G #4 / #15): a `cue_staged` that WorldView emits in the same
## tick before the probe records the director cue still counts as staged, and a sound's time is the
## AudioDirector's own clock at the call — not the frame the probe happened to read it in, which made
## two calls 100 ms apart read as 83–94 ms ("step_pizz_up twice", prologue_ideal).
extends TestBase


class FakeNight extends Node:
	var audio_dir: Object = null


var p: E2eProbe = null
var n: FakeNight = null
var ad: AudioDirector = null


func before_each() -> void:
	p = E2eProbe.new()
	n = FakeNight.new()
	ad = AudioDirector.new()
	ad.record = true
	n.audio_dir = ad
	p.night = n


func after_each() -> void:
	p.free()
	n.free()
	ad.free()


func test_cue_staged_before_the_probe_records_it_counts() -> void:
	p._t = 12.5
	p._on_cue_staged("laugh_vase", "room")
	p._on_ticked([{"e": "director_cue", "id": "laugh_vase", "t": 750}])
	assert_eq(p._cues.size(), 1)
	assert_almost_eq(float(p._cues[0]["staged_t"]), 12.5, 0.0001, "staged in the same tick")


func test_a_stale_early_stage_does_not_match_a_later_cue() -> void:
	p._t = 3.0
	p._on_cue_staged("laugh_vase", "room")
	p._t = 9.0
	p._on_ticked([{"e": "director_cue", "id": "laugh_vase", "t": 540}])
	assert_lt(float(p._cues[0]["staged_t"]), 0.0, "an old stage is not this cue's")
	p._on_cue_staged("laugh_vase", "room")
	assert_almost_eq(float(p._cues[0]["staged_t"]), 9.0, 0.0001, "the next stage is")


func test_sound_time_is_the_directors_call_time() -> void:
	# Call 1 at director time 1.000 is read one frame late (probe at 1.0167); call 2 at 1.100 is
	# read in its own frame. 100 ms apart: not a double.
	ad.calls.append(["play_sfx", "step_pizz_up", 0.0, 0.0, 1.0])
	ad.call_times.append(1.0)
	ad._now = 1.0167
	p._t = 1.0167
	p._read_sounds()
	ad.calls.append(["play_sfx", "step_pizz_up", 0.0, 0.0, 1.0])
	ad.call_times.append(1.1)
	ad._now = 1.1
	p._t = 1.1
	p._read_sounds()
	assert_eq(p._sounds.size(), 2)
	assert_almost_eq(float(p._sounds[0][0]), 1.0, 0.0005, "mapped back to the call's frame")
	assert_eq(E2eProbe.doubles(p._sounds).size(), 0, "100 ms apart is not a double")


func test_a_real_double_is_still_reported() -> void:
	ad.calls.append(["play_sfx", "sink_crash", 0.0, 0.0, 1.0])
	ad.call_times.append(2.0)
	ad.calls.append(["play_sfx", "sink_crash", 0.0, 0.0, 1.0])
	ad.call_times.append(2.05)
	ad._now = 2.05
	p._t = 2.05
	p._read_sounds()
	var d := E2eProbe.doubles(p._sounds)
	assert_eq(d.size(), 1)
	assert_almost_eq(float(d[0]["dt"]), 0.05, 0.001)


## The texture-memory gate (s2-fix G #7): every route fails above 256 MB over the whole Night on a
## rendered run; a headless run (peak 0) is not judged.
func test_texture_peak_gate() -> void:
	assert_eq(int(E2eScenarios.thresholds("n01_caught").get("tex_mb_peak_max", -1)), 256)
	assert_eq(int(E2eScenarios.thresholds("g0_sneeze").get("tex_mb_peak_max", -1)), 256)
	var e2e: Script = load("res://tools/e2e.gd")
	var over: PackedStringArray = e2e.call("check", "n01_caught", {"tex_mb_peak": 275.1, "end_reason": "bow"}, false)
	var hit := false
	for f in over:
		hit = hit or f.begins_with("texture memory peak")
	assert_true(hit, "275 MB fails: %s" % [over])
	for rep in [{"tex_mb_peak": 250.0}, {"tex_mb_peak": 0.0}]:
		for f in e2e.call("check", "n01_caught", rep, false):
			assert_false(String(f).begins_with("texture memory"), "%s passes the gate" % [rep])
