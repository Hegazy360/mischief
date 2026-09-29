## SimEvents — every event name of TECH §3.8 as a constant, plus `is_laugh()`.
##
## Every event is `{"e": String, "t": int, ...}` with int / String / bool payload fields only.
## Positions in payloads are px (ints); `room` fields are room ids.
class_name SimEvents
extends RefCounted

# --- Hush ---
const HUSH_GO := "hush_go"                  ## {target, run}
const HUSH_ARRIVE := "hush_arrive"          ## {hotspot}
const HUSH_ROOM := "hush_room"              ## {room}
const RUMMAGE := "rummage"                  ## {container}
const PICK_WINDOW := "pick_window"          ## {container, items} (items: comma-joined ids)
const PICK := "pick"                        ## {item}
const ITEM_HOME := "item_home"              ## {item}
const RESTOCK := "restock"                  ## {item, container}
const RIG_START := "rig_start"              ## {prank, step}
const RIG_PAUSE := "rig_pause"              ## {prank}
const RIG_STEP_DONE := "rig_step_done"      ## {prank, step}
const RIGGED := "rigged"                    ## {prank}
const HIDE := "hide"                        ## {spot, watched}
const POP_OUT := "pop_out"                  ## {spot}
const FREEZE := "freeze"                    ## {on}
const NOISE := "noise"                      ## {kind, room, x, r}
const SQUEAK := "squeak"                    ## {room, x, heard}
const PIN := "pin"                          ## {room, x}
# --- Bellows ---
const B_ACTIVITY := "b_activity"            ## {id}
const B_ACTIVITY_END := "b_activity_end"    ## {id}
const B_NEXT := "b_next"                    ## {id, detour}
const B_DETOUR := "b_detour"                ## {kind, station, why}
const B_ROOM := "b_room"                    ## {room, chase} (chase: entered while chasing — exempt from warnings)
const ENTRY_WARNING := "entry_warning"      ## {room, eta}
const DOORWAY_PAUSE := "doorway_pause"      ## {ticks}
const SPECS := "specs"                      ## {on}
const GLYPH := "glyph"                      ## {id}
const LOOK_BACK := "look_back"
const EAR_PIP := "ear_pip"                  ## {n}
const SQUEAK_BIT := "squeak_bit"            ## {bit, score}
const HEAD_TURN := "head_turn"
const LURE := "lure"                        ## {room, x}
const LURE_FATIGUE := "lure_fatigue"
## A micro-gag beat (GDD §2.1 "a micro-gag every 5–8 s"): {id, activity, room, x, len, emote, vis}.
## `activity` = the activity or detour id ("walk" for a walk beat), `len` = clip frames, `emote` ∈
## `EMOTES` or "" (none), `vis` = `SimVisibility.beat_vis()` at emission: "room" | "pip" | "edge" | "".
## Not a laugh; never changes applause, temper or senses.
const MICRO_GAG := "micro_gag"
# --- Danger ---
const SPOT_START := "spot_start"            ## {by}
const NEAR_MISS := "near_miss"              ## {by}
const SPOTTED := "spotted"                  ## {by}
const CHASE_START := "chase_start"
const WHEEZE := "wheeze"
const DOOR_SLAM := "door_slam"
const CHASE_END := "chase_end"              ## {why}
const SEARCH := "search"
const ON_GUARD := "on_guard"
const BUMP := "bump"                        ## {first}
const FACE_TO_FACE := "face_to_face"        ## {spot}
const CAUGHT := "caught"                    ## {cause, spotted_tick, by}
const BUSTED_CAM := "busted_cam"
const LECTURE := "lecture"                  ## {variant}
const DOORSTEP := "doorstep"
const TOMATO := "tomato"                    ## {n}
const HOOK := "hook"
# --- Comedy ---
const PRANK_FIRE := "prank_fire"            ## {prank, trigger, link, tier, witnessed}
const REACTION_START := "reaction_start"    ## {prank, archetype, variant, tier, suppressed, len, entry, last_beat, beat_len}
const REACTION_ACCENT := "reaction_accent"  ## {prank}
const REACTION_END := "reaction_end"        ## {prank}
const KNOCK_ON := "knock_on"                ## {a, b}
const FIZZLE := "fizzle"                    ## {prank}
const RESIDUE_ADD := "residue_add"          ## {kind}
const RESIDUE_CLEAR := "residue_clear"      ## {kind}
const COMBO := "combo"                      ## {id}
const TEMPER_TIER := "temper_tier"          ## {tier}
const RUNNING_GAG := "running_gag"          ## {link, mult}
const RUNNING_GAG_END := "running_gag_end"
const MELTDOWN_START := "meltdown_start"
const MELTDOWN_STOMP := "meltdown_stomp"    ## {n}
const EXHAUSTED := "exhausted"
const PANTO_ROUND := "panto_round"          ## {round, phase}
const PANTO_BIT := "panto_bit"
const MIRROR_ROUND := "mirror_round"        ## {round}
const WINK := "wink"                        ## {round}
const HEADBUTT := "headbutt"                ## {target, landing}
# --- Score ---
const APPLAUSE := "applause"                ## {delta, total, kind, label}
const BONUS := "bonus"                      ## {kind, amount}
const LINE_DONE := "line_done"              ## {line}
const BIG_NUMBER_UNSEALED := "big_number_unsealed"
const ALL_LINES_DONE := "all_lines_done"
const STAR := "star"                        ## {n}
# --- Flow ---
const DIRECTOR_CUE := "director_cue"        ## {id}
const SAFETY_NET := "safety_net"            ## {on}
const FIGGIS_HOOK := "figgis_hook"
const NIGHT_END := "night_end"              ## {reason}
const CMD_REJECTED := "cmd_rejected"        ## {c, why}
const CMD_QUEUED := "cmd_queued"            ## {c, why, target} (a go/move held while busy; why: entering | busy)
# --- Stage 3 ---
const BERYL_MOOD := "beryl_mood"            ## {mood}
const BLEAT := "bleat"
const HERD_START := "herd_start"
const HERD_END := "herd_end"
const DELPHINE_ARRIVE := "delphine_arrive"
const GLASSES := "glasses"                  ## {up}
const HIGH_C := "high_c"                    ## {room, x}
const EMBARRASSED := "embarrassed"          ## {prank}

## Every event name (for tools and tests).
const ALL: Array[String] = [HUSH_GO, HUSH_ARRIVE, HUSH_ROOM, RUMMAGE, PICK_WINDOW, PICK, ITEM_HOME, RESTOCK,
	RIG_START, RIG_PAUSE, RIG_STEP_DONE, RIGGED, HIDE, POP_OUT, FREEZE, NOISE, SQUEAK, PIN,
	B_ACTIVITY, B_ACTIVITY_END, B_NEXT, B_DETOUR, B_ROOM, ENTRY_WARNING, DOORWAY_PAUSE, SPECS, GLYPH,
	LOOK_BACK, EAR_PIP, SQUEAK_BIT, HEAD_TURN, LURE, LURE_FATIGUE, MICRO_GAG,
	SPOT_START, NEAR_MISS, SPOTTED, CHASE_START, WHEEZE, DOOR_SLAM, CHASE_END, SEARCH, ON_GUARD, BUMP,
	FACE_TO_FACE, CAUGHT, BUSTED_CAM, LECTURE, DOORSTEP, TOMATO, HOOK,
	PRANK_FIRE, REACTION_START, REACTION_ACCENT, REACTION_END, KNOCK_ON, FIZZLE, RESIDUE_ADD, RESIDUE_CLEAR,
	COMBO, TEMPER_TIER, RUNNING_GAG, RUNNING_GAG_END, MELTDOWN_START, MELTDOWN_STOMP, EXHAUSTED,
	PANTO_ROUND, PANTO_BIT, MIRROR_ROUND, WINK, HEADBUTT,
	APPLAUSE, BONUS, LINE_DONE, BIG_NUMBER_UNSEALED, ALL_LINES_DONE, STAR,
	DIRECTOR_CUE, SAFETY_NET, FIGGIS_HOOK, NIGHT_END, CMD_REJECTED, CMD_QUEUED,
	BERYL_MOOD, BLEAT, HERD_START, HERD_END, DELPHINE_ARRIVE, GLASSES, HIGH_C, EMBARRASSED]


## The emotes the HUD edge bubble can draw on Bellows' 112 px face (a micro-gag's `emote`; "" = none).
const EMOTES: Array[String] = ["sing", "hum", "smug", "laugh", "tut", "sniff", "yum", "yawn"]


## True for any micro-gag beat (visible or not).
static func is_beat(ev: Dictionary) -> bool:
	return str(ev.get("e", "")) == MICRO_GAG


## True for a micro-gag beat the player can see (`vis` != ""): in Hush's room, in the PiP, or as an
## emote on the HUD edge bubble (D1: only these count against dead air).
static func is_visible_beat(ev: Dictionary) -> bool:
	return str(ev.get("e", "")) == MICRO_GAG and str(ev.get("vis", "")) != ""


## True for events that are laughs (TECH §3.8): reaction accents, squeak bits, panto rounds and bits,
## near misses, combos, Meltdowns, the first bump of a Night, door slams, `director_cue` ids starting
## with `laugh_`.
static func is_laugh(ev: Dictionary) -> bool:
	var e: String = str(ev.get("e", ""))
	match e:
		REACTION_ACCENT, SQUEAK_BIT, PANTO_ROUND, PANTO_BIT, NEAR_MISS, COMBO, MELTDOWN_START, DOOR_SLAM:
			return true
		BUMP:
			return bool(ev.get("first", false))
		DIRECTOR_CUE:
			return str(ev.get("id", "")).begins_with("laugh_")
	return false
