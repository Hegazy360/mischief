## E2eScenarios — the e2e driver's scenario table (s2-night §4.6). Pure.
## * Route scenarios replay a solver route through the real Boot → NightScene path:
##   `g0_sneeze`, `prologue_{ideal,required,slow}`, `n01_{ideal,required,slow}`, `n02_…`, and the
##   scenario routes `n01_caught`, `n01_chase`, `n01_meltdown`, `n02_face_to_face`, `n02_face_to_face_lost`.
## * Flow scenarios drive the scene with synthetic input: `retry`, `pause_back`, `curtain_call`,
##   `touch_smoke`, `tap_accuracy`, `cold_<episode>`.
## * `slice_all` = every route + scenario route of P00/N01/N02 + g0_sneeze (e2e.sh runs one process each).
class_name E2eScenarios
extends RefCounted

const EPISODES := {"g0": "g0_sneeze", "prologue": "p00_curtain_up", "n01": "n01_throat_tea", "n02": "n02_something_fishy"}
const ROUTE_SCENARIOS := {
	"g0_sneeze": ["g0_sneeze", "ideal"],
	"prologue_ideal": ["p00_curtain_up", "ideal"], "prologue_required": ["p00_curtain_up", "required"],
	"prologue_slow": ["p00_curtain_up", "slow"],
	"n01_ideal": ["n01_throat_tea", "ideal"], "n01_required": ["n01_throat_tea", "required"],
	"n01_slow": ["n01_throat_tea", "slow"],
	"n02_ideal": ["n02_something_fishy", "ideal"], "n02_required": ["n02_something_fishy", "required"],
	"n02_slow": ["n02_something_fishy", "slow"],
	"n01_caught": ["n01_throat_tea", "caught"], "n01_chase": ["n01_throat_tea", "chase"],
	"n01_meltdown": ["n01_throat_tea", "meltdown"], "n02_face_to_face": ["n02_something_fishy", "face_to_face"],
	"n02_face_to_face_lost": ["n02_something_fishy", "face_to_face_lost"],
}
## Flow scenario → the episode it plays on.
const FLOW_SCENARIOS := {"retry": "n01_throat_tea", "pause_back": "n01_throat_tea", "curtain_call": "n01_throat_tea",
	"touch_smoke": "p00_curtain_up", "tap_accuracy": "n01_throat_tea"}
## Route scenarios that are optional (missing from the solution file until s2-content adds them → SKIP).
const OPTIONAL: PackedStringArray = ["n01_caught", "n01_chase", "n01_meltdown", "n02_face_to_face", "n02_face_to_face_lost"]


static func is_route(s: String) -> bool:
	return ROUTE_SCENARIOS.has(s)


static func is_flow(s: String) -> bool:
	return FLOW_SCENARIOS.has(s) or s.begins_with("cold_")


## [episode, route] of a route scenario ([] otherwise).
static func route_of(s: String) -> Array:
	return (ROUTE_SCENARIOS[s] as Array).duplicate() if ROUTE_SCENARIOS.has(s) else []


## The episode a scenario boots into ("" = unknown).
static func episode_of(s: String) -> String:
	if ROUTE_SCENARIOS.has(s):
		return String(ROUTE_SCENARIOS[s][0])
	if FLOW_SCENARIOS.has(s):
		return String(FLOW_SCENARIOS[s])
	if s.begins_with("cold_"):
		var ep := s.substr(5)
		return String(EPISODES.get(ep, ep))
	return ""


## Every scenario name `slice_all` runs (route + scenario routes).
static func slice_all() -> PackedStringArray:
	var out := PackedStringArray()
	for k in ROUTE_SCENARIOS:
		out.append(String(k))
	out.sort()
	return out


## The pass thresholds of a scenario (the pre-gate rows it feeds). Keys:
## `input_live_s_max`, `first_laugh_s_max`, `first_prank_s_max` (from tick 0), `tick0_frames_max`,
## `laughs_by_60_min` (launch-relative), `cue_crowd_s_max`, `draw_p95_max`, `draw_max`,
## `pages_in_play_max`, `doubles_max`, `ends_with`, `fallbacks_max` (strict runs only), `tex_mb_peak_max`.
static func thresholds(s: String) -> Dictionary:
	var t := {"tick0_frames_max": 1, "doubles_max": 0, "errors_max": 0}
	match s:
		"g0_sneeze":
			t["ends_with"] = "g0_done"
		"prologue_slow":
			t["input_live_s_max"] = 0.4
			t["first_laugh_s_max"] = 7.7
			t["first_prank_s_max"] = 27.7
		"prologue_ideal":
			t["laughs_by_60_min"] = 6
			t["cue_crowd_s_max"] = 0.3
		"n01_ideal", "n02_ideal":
			t["draw_p95_max"] = 150
			t["draw_max"] = 250
			t["pages_in_play_max"] = 0
	if is_route(s):
		t["fallbacks_max"] = 0
		# texture memory over the whole Night (build → curtain call), RENDER_TEXTURE_MEM_USED: a 3 GB
		# phone (s2-fix G #7; checked on rendered runs only — headless reports 0)
		t["tex_mb_peak_max"] = 256
	return t
