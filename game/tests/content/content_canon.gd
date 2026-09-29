## Canonical ids from docs/TECH.md §14 plus the GDD numbers the content tests check against.
## Standalone on purpose: the content tests read raw JSON and never depend on ContentDB.
extends RefCounted

const DATA := "res://data/"

const ROOMS: Array[String] = ["porch", "hall", "parlour", "kitchen", "conservatory", "garden", "landing",
	"bathroom", "bedroom", "dressing"]

## Room x ranges and floors (GDD §7.1).
const ROOM_X := {
	"porch": [0, 500, 0], "hall": [500, 1500, 0], "parlour": [1500, 2800, 0], "kitchen": [2800, 3900, 0],
	"conservatory": [3900, 4700, 0], "garden": [4700, 6200, 0], "landing": [1000, 1800, 1],
	"bathroom": [1800, 2800, 1], "bedroom": [2800, 3700, 1], "dressing": [3700, 4500, 1],
}

## station id -> [room, kinds]
const STATIONS := {
	"st_gramophone": ["parlour", []], "st_piano": ["parlour", []], "st_recliner": ["parlour", []],
	"st_fireplace": ["parlour", ["DRY"]], "st_chaise": ["parlour", []], "st_parlour_centre": ["parlour", []],
	"st_tea": ["kitchen", ["HONEY"]], "st_pickles": ["kitchen", []], "st_fridge": ["kitchen", []],
	"st_sink": ["kitchen", ["SINK"]], "st_hall_mirror": ["hall", ["MIRROR"]], "st_phone": ["hall", []],
	"st_clock": ["hall", []], "st_front_door": ["hall", []], "st_feed_bin": ["conservatory", []],
	"st_sun_lounger": ["conservatory", ["DRY"]], "st_hose": ["garden", []], "st_marrow": ["garden", []],
	"st_path": ["garden", []], "st_stage": ["garden", []], "st_radiator": ["landing", ["DRY"]],
	"st_basin": ["bathroom", ["SINK", "MIRROR"]], "st_bath": ["bathroom", []], "st_wardrobe": ["bedroom", []],
	"st_bed": ["bedroom", []], "st_dressing_mirror": ["dressing", ["MIRROR"]], "st_trophy": ["dressing", []],
	"st_dummy": ["dressing", []],
}

## container hotspot -> room
const CONTAINERS := {
	"hall_confiscated_box": "hall", "hall_piggy_bank": "hall", "kitchen_fridge": "kitchen",
	"kitchen_pantry_shelf": "kitchen", "bathroom_cabinet": "bathroom",
	"conservatory_potting_bench": "conservatory", "dressing_costume_trunk": "dressing",
}

## hiding hotspot -> [room, in-use activity or ""]
const HIDING := {
	"hall_coat_cupboard": ["hall", ""], "hall_clock_case": ["hall", "clock"],
	"parlour_piano_back": ["parlour", ""], "parlour_chaise_back": ["parlour", ""],
	"kitchen_pantry_curtain": ["kitchen", ""], "kitchen_table": ["kitchen", ""],
	"conservatory_hamper": ["conservatory", ""], "garden_shed": ["garden", ""], "garden_compost": ["garden", ""],
	"landing_airing_cupboard": ["landing", ""], "bathroom_bath": ["bathroom", "bath"],
	"bathroom_laundry_basket": ["bathroom", ""], "bedroom_wardrobe": ["bedroom", "dress"],
	"bedroom_under_bed": ["bedroom", ""], "dressing_costume_rail": ["dressing", ""],
}

## rig point hotspot -> [room, pranks]
const RIG_POINTS := {
	"kitchen_honey": ["kitchen", ["achoo_ria"]], "kitchen_kettle": ["kitchen", ["kettle_drum"]],
	"kitchen_pickle_jar": ["kitchen", ["in_a_pickle"]], "kitchen_fridge_shelf": ["kitchen", ["cold_open"]],
	"kitchen_sink_tap": ["kitchen", ["tap_dance"]],
	"parlour_gramophone": ["parlour", ["allegro_go_go", "it_takes_two"]],
	"parlour_recliner": ["parlour", ["lift_off"]], "parlour_newspaper": ["parlour", ["eye_popping_news"]],
	"parlour_bellows": ["parlour", ["bellows_blows"]], "parlour_chandelier": ["parlour", ["prima_ballerina"]],
	"parlour_piano_wedge": ["parlour", ["grand_exit"]], "parlour_tea_tray": ["parlour", ["spit_take"]],
	"parlour_fan": ["parlour", ["fan_mail"]], "hall_phone": ["hall", ["something_fishy"]],
	"hall_clock": ["hall", ["times_up"]], "hall_mirror": ["hall", ["mirror_mirror"]],
	"stairs_rods": ["hall", ["rug_burn"]], "bathroom_basin_spray": ["bathroom", ["sopran_oh_no"]],
	"bathroom_duck": ["bathroom", ["snap_decision"]], "bathroom_bath_taps": ["bathroom", ["in_over_his_head"]],
	"landing_boiler_valve": ["landing", ["pipe_down"]], "bedroom_pillow": ["bedroom", ["pillow_talk"]],
	"bedroom_bedside": ["bedroom", ["butter_fingers"]], "bedroom_bed": ["bedroom", ["kidding_around"]],
	"dressing_dummy": ["dressing", ["tutu_much"]], "dressing_trophy_shelf": ["dressing", ["award_winning"]],
	"conservatory_feed_bin": ["conservatory", ["sweet_tooth"]], "garden_hose": ["garden", ["hosed"]],
	"garden_marrow": ["garden", ["marrow_escape"]], "garden_coin_1": ["garden", ["penny_pincher"]],
	"garden_coin_2": ["garden", ["penny_pincher"]], "garden_coin_3": ["garden", ["penny_pincher"]],
	"garden_spotlight": ["garden", ["spotlight_stealer"]],
}

const OTHER_HOTSPOTS := {"hall_front_door": "hall", "kitchen_back_door": "kitchen", "stairs_foot": "hall",
	"stairs_head": "landing", "kitchen_window": "kitchen"}

const ITEMS: Array[String] = ["squeaker", "magnifier", "balloon", "croc", "kipper", "butter", "flour", "sherbet",
	"treacle", "salt", "bubble_bath", "apple", "feathers", "coins", "tutu", "record"]

const ACTIVITIES: Array[String] = ["warmup", "tea", "pickles", "snack", "rinse", "paper", "fire", "mirror", "phone",
	"clock", "piano", "gargle", "bath", "radiator", "dress", "nap", "feed_beryl", "roses", "marrow", "stroll",
	"polish", "cloak", "answer_door", "host_tea", "tango", "rehearse", "hunt"]

const DETOURS: Array[String] = ["fixup_dry", "fixup_sink", "fixup_honey", "fixup_mirror", "curious", "herd_beryl",
	"search", "exit"]

## Activity durations changed by lead decision D1 (Stage 2; `docs/review/s2-content/d1_changes.md`, to be folded
## into GDD §4.1.1): Act I loops ≤ 60 s, no `dur_s` below 5 s. Every other activity keeps its GDD §4.1.1 value.
const D1_DURATIONS := {"warmup": 8, "tea": 8, "pickles": 5, "snack": 5, "paper": 8, "fire": 5, "mirror": 5}

const PRANKS: Array[String] = ["achoo_ria", "tap_dance", "kettle_drum", "in_a_pickle", "cold_open", "allegro_go_go",
	"lift_off", "eye_popping_news", "bellows_blows", "prima_ballerina", "grand_exit", "it_takes_two",
	"something_fishy", "times_up", "mirror_mirror", "rug_burn", "sopran_oh_no", "snap_decision",
	"in_over_his_head", "pipe_down", "pillow_talk", "butter_fingers", "kidding_around", "tutu_much",
	"award_winning", "hosed", "marrow_escape", "penny_pincher", "sweet_tooth", "spit_take", "fan_mail",
	"spotlight_stealer"]

const SQUEAK_BITS: Array[String] = ["bit_warmup", "bit_tea", "bit_paper", "bit_mirror", "bit_phone", "bit_bath",
	"bit_nap", "bit_feed", "bit_piano", "bit_livid"]

const RESIDUES: Array[String] = ["SOAKED", "FLOURY", "STICKY", "SQUEAKY", "FRAZZLED", "FEATHERED", "COSTUME"]
const FIXUP_KINDS: Array[String] = ["DRY", "SINK", "HONEY", "MIRROR"]
const COMBOS: Array[String] = ["dough_man", "poodle", "chicken", "mad_maestro"]
const DOUBLE_ACTS: Array[String] = ["hot_and_cold", "up_in_smoke", "marrow_mayhem", "encore", "tea_for_two",
	"curtain_call"]

const EPISODES: Array[String] = ["p00_curtain_up", "n01_throat_tea", "n02_something_fishy",
	"n03_singing_in_the_bath", "n04_the_big_sulk", "n05_enter_beryl", "n06_behind_you", "n07_kidding_around",
	"n08_companys_coming", "n09_tutu_much", "n10_it_takes_two", "gala_the_comeback"]
const FINAL_EPISODES: Array[String] = ["p00_curtain_up", "n01_throat_tea", "n02_something_fishy"]

const ARCHETYPES: Array[String] = ["sneeze_blast", "drench", "sing_crack", "strain_slip", "avalanche_helmet",
	"dizzy_spin", "launch_ceiling", "blind_bumble", "poof", "drop_on", "fish_slap", "jackhammer_cling", "surf_out",
	"squeaky_voice", "scare_leap", "steam_duel", "feather_burst", "costume_burn", "balloon_chase",
	"headbutt_launch", "goat_kiss", "suppressed"]
const SIGNATURES: Array[String] = ["sig_mirror_mirror", "sig_in_over_his_head", "sig_grand_exit",
	"sig_kidding_around", "sig_it_takes_two", "sig_spotlight_stealer"]

const DIRECTOR_CUES: Array[String] = ["laugh_vase", "figgis_psst", "ghost_squeak", "ghost_honey", "ghost_hold",
	"ghost_hide", "sparkle_lever", "title_card"]

const LINE_KINDS: Array[String] = ["prank", "double_act", "combo", "combo_witnessed", "prank_witnessed", "meltdown",
	"panto", "witness", "herd", "chase_trip", "chain"]

## Prank conditions and solution/director condition keys (TECH §4.4, §8.2 + the documented extensions).
const PRANK_CONDITIONS: Array[String] = ["tier_min", "beryl_within", "beryl_on", "delphine_present",
	"meltdown_in_room", "hush_in_frame_frozen", "or_chase"]
const WHEN_CONDITIONS: Array[String] = ["bellows_activity", "bellows_activity_in", "bellows_state", "bellows_in_room",
	"bellows_not_in_room", "bellows_eta_to_room_gt_s", "bellows_activity_remaining_le_s",
	"bellows_facing_away_from_hush", "hush_visible", "hush_hidden", "spot_meter_pct_ge", "prank_state",
	"temper_tier_ge", "link_ge", "line_done", "all_required_done", "tick_ge_s", "first_squeak", "first_rig",
	"event_seen", "and", "or", "not"]
const SOLUTION_STEPS: Array[String] = ["go", "move", "pick", "rig", "hide", "pop_out", "freeze", "squeak", "stand_in",
	"panto", "wait", "wait_event", "idle", "bow"]
const EXPECT_KEYS: Array[String] = ["stars", "applause", "lines", "catches_max", "duration_s",
	"first_player_laugh_s_max", "first_prank_s_max", "laughs_by_s", "dead_air_pct_max", "max_gap_s_max"]

## GDD §7.2 Script weights (tenths) and §9.3 reaction timing ranges.
const SIZE_WEIGHT := {"S": 10, "M": 14, "L": 20, "SIG": 30}
const TIMING := {
	"small": {"antic": [8, 12], "hold": [30, 45], "settle": [8, 15], "total": [90, 240]},
	"big": {"antic": [15, 24], "hold": [45, 90], "settle": [15, 30], "total": [90, 240]},
	"sig": {"antic": [15, 24], "hold": [45, 90], "settle": [15, 30], "total": [90, 420]},
}


## Parse a JSON file under res://data (null when missing or invalid).
static func read(rel: String) -> Variant:
	var path := DATA + rel
	if not FileAccess.file_exists(path):
		return null
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(path)) != OK:
		push_warning("%s:%d %s" % [path, j.get_error_line(), j.get_error_message()])
		return null
	return j.data


## Every hotspot id in TECH §14, any kind.
static func all_hotspots() -> Array[String]:
	var out: Array[String] = []
	for d in [CONTAINERS, HIDING, RIG_POINTS, OTHER_HOTSPOTS]:
		for k in (d as Dictionary).keys():
			out.append(String(k))
	return out


## Room of any canonical hotspot ("" if unknown).
static func hotspot_room(id: String) -> String:
	if CONTAINERS.has(id):
		return CONTAINERS[id]
	if HIDING.has(id):
		return HIDING[id][0]
	if RIG_POINTS.has(id):
		return RIG_POINTS[id][0]
	return String(OTHER_HOTSPOTS.get(id, ""))


## Largest-remainder split of `total` over `weights` (ties by order), as in TECH §3.2.
static func largest_remainder(weights: Array, total: int) -> Array:
	var sum := 0
	for w in weights:
		sum += int(w)
	var out: Array = []
	var rems: Array = []
	var given := 0
	for i in weights.size():
		var num := int(weights[i]) * total
		out.append(num / sum)
		given += num / sum
		rems.append([num % sum, i])
	rems.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0] or (a[0] == b[0] and a[1] < b[1]))
	var k := 0
	while given < total:
		out[rems[k][1]] += 1
		given += 1
		k += 1
	return out
