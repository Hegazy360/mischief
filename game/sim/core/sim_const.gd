## SimConst — every tunable number of the simulation, named, with its GDD section (TECH §3.1).
##
## Units: sub-pixels (SUB per px; a speed of V px/s moves exactly V sub-px per tick), ticks at TPS,
## temper in points × TEMPER_Q, applause in tenths. Episode `rules` may override the whitelisted subset
## (`RULE_KEYS`). If a GDD number and this file disagree, the GDD wins (fix this file).
class_name SimConst
extends RefCounted

# --- units (TECH §2) ----------------------------------------------------------------------------
## Sub-pixels per px.
const SUB := 60
## Sim ticks per second.
const TPS := 60

# --- speeds, px/s == sub-px/tick (GDD §4.1) -----------------------------------------------------
## Hush tiptoe (silent). GDD §4.1.
const HUSH_TIPTOE := 400
## Hush run (noisy). GDD §4.1.
const HUSH_RUN := 720
## Bellows walk. GDD §4.1.
const B_WALK := 240
## Bellows chase. GDD §4.1, §4.4.
const B_CHASE := 600
## Walk speed bonus per temper tier (Calm, Irked, Steaming, Livid), percent. GDD §4.5 (never > 15).
const TIER_SPEED_PCT: Array[int] = [0, 5, 10, 15]

# --- doors and stairs (GDD §4.1) -----------------------------------------------------------------
## Door open/close time for Hush (0.35 s). GDD §4.1.
const HUSH_DOOR_TICKS := 21
## Door open/close time for Bellows (0.5 s). GDD §4.1.
const B_DOOR_TICKS := 30
## Stairs traversal for Hush (1.0 s) unless house.json overrides. GDD §4.1.
const HUSH_STAIRS_TICKS := 60
## Stairs traversal for Bellows (1.8 s) unless house.json overrides. GDD §4.1.
const B_STAIRS_TICKS := 108

# --- movers (NavGraph.path) ----------------------------------------------------------------------
const MOVER_HUSH_WALK := 0
const MOVER_HUSH_RUN := 1
const MOVER_B_WALK := 2
const MOVER_B_CHASE := 3

# --- sight, px (GDD §4.3) ------------------------------------------------------------------------
## Specs off: sees moving Hush within 600 px ahead. GDD §4.3.
const SIGHT_OFF_MOVING := 600
## Specs off: sees frozen Hush within 250 px ahead. GDD §4.3.
const SIGHT_OFF_FROZEN := 250
## Specs on: moving = the whole room ahead (-1). GDD §4.3.
const SIGHT_ON_MOVING := -1
## Specs on: frozen within 600 px. GDD §4.3.
const SIGHT_ON_FROZEN := 600
## Absorbed (bath): moving 250, frozen 0. GDD §4.3.
const SIGHT_ABSORBED_MOVING := 250
const SIGHT_ABSORBED_FROZEN := 0
## Blinded / Exhausted: 150 / 150. GDD §4.3.
const SIGHT_BLIND_MOVING := 150
const SIGHT_BLIND_FROZEN := 150
## Doorway look-through: within this many px of an open doorway he faces … GDD §4.3.
const LOOK_THROUGH_NEAR := 250
## … he sees this many px into the next room. GDD §4.3.
const LOOK_THROUGH_DEPTH := 300
## Blind and deaf this long after a reaction ends (1 s). GDD §4.3, §4.7 rule 5.
const REACT_BLIND_AFTER := 60

# --- the "?" meter (GDD §4.3) --------------------------------------------------------------------
## Default fill time per act (Prologue 2.0, Act I 1.0, Act II+ 0.8 s) when `rules.spot_fill_s` is absent.
const SPOT_FILL_S: Array[float] = [2.0, 1.0, 0.8, 0.8, 0.8]
## The fill time is never below 0.8 s (48 ticks). GDD §4.3.
const SPOT_FILL_MIN := 48
## Relaxed mode widens every "?" window by this percent. GDD §3.11.
const RELAXED_PCT := 150
## Meter drain per tick while he can't see her (2× speed). GDD §4.3.
const SPOT_DRAIN := 2
## Near miss when the meter peaked at ≥ this percent before draining to zero. GDD §4.3.
const NEAR_MISS_MIN_PCT := 50
## Face-to-face "?" window (0.8 s) for an in-use hiding spot or the Mirror. GDD §3.4, #15.
const FACE_TO_FACE_TICKS := 48
## Spotted "!" double take before the chase (0.3 s). GDD §4.4.
const SPOTTED_TICKS := 18

# --- bump rule (GDD §4.3) ------------------------------------------------------------------------
## His walk step overlapping a FROZEN Hush within this many px is a bump. TECH §3.7.3.
const BUMP_PX := 40
## First bump: "Pardon" pat (0.5 s). GDD §4.3.
const BUMP_PAT_TICKS := 30
## First bump: he walks on 2 steps before the double take. GDD §4.3.
const BUMP_WALK_ON_TICKS := 40
## Double take turn before the "?" window opens. GDD §4.3.
const BUMP_TURN_TICKS := 12
## Longest he stands looking at a bumped statue before walking on (if the meter never starts).
const BUMP_LOOK_MAX := 180

# --- chase (GDD §4.4, §4.6) ----------------------------------------------------------------------
## Catch radius, px. GDD §4.4.
const CATCH_PX := 80
## Chase: run, then wheeze, then run again, then search once out of sight. GDD §4.4.
const CHASE_RUN1 := 240
const CHASE_WHEEZE := 90
const CHASE_RUN2 := 120
## Out of sight this long (after the phases) → Search. GDD §4.4.
const CHASE_LOST := 90
## Hard cap on a chase. TECH §3.7.1.
const CHASE_CAP := 600
## Search: specs on, looks around the room (6 s). GDD §4.4.
const SEARCH_TICKS := 360
## Search turns to look the other way this often.
const SEARCH_TURN_EVERY := 90
## On Guard after a Search or a catch (15 s, specs on). GDD §4.4, §4.6.
const ON_GUARD_TICKS := 900
## Door slam: Hush passes a doorway with him chasing within this many px (once per chase). GDD §4.4.
const DOOR_SLAM_PX := 500
## Door slam stun (1 s). GDD §4.4.
const DOOR_SLAM_STUN := 60
## He follows Hush through the stairs / a door if he saw her within this many ticks before she entered it.
const CHASE_FOLLOW_TICKS := 20
## A chase re-paths to Hush this often while she is in another room.
const CHASE_REPATH := 30

# --- caught (GDD §4.6) ---------------------------------------------------------------------------
## CAUGHT_HOLD total: busted cam 60 → Lecture 132 → wipe 12 → doorstep 36. TECH §3.7.1.
const CAUGHT_HOLD := 240
const CAUGHT_BUSTED := 60
const CAUGHT_LECTURE := 132
const CAUGHT_WIPE := 12
## Hush lands on the doorstep at +204.
const CAUGHT_DOORSTEP_AT := 204
## Applause lost per catch (−5.0). GDD §4.6, §6.1.
const CATCH_PENALTY := 50
## Lecture variants (3). GDD §4.6.
const LECTURE_VARIANTS := 3

# --- entry warning, look-back (GDD §4.2, §4.5) -----------------------------------------------------
## Entry warning ≥ 1.5 s before he enters Hush's room (except in a chase). GDD §4.2, §4.7 rule 3.
const ENTRY_WARN := 90
## Look-back pause at a doorway at Steaming+ (1.0 s). GDD §4.5.
const LOOK_BACK_TICKS := 60

# --- Hush actions (GDD §3) -----------------------------------------------------------------------
## Rig prep tiers: Q 0.8 s, S 1.5 s, B 2.5 s. GDD §3.2, §5.1.
const PREP_Q := 48
const PREP_S := 90
const PREP_B := 150
## B-tier steps emit a 500 px noise every 0.5 s while filling. GDD §5.1.
const B_RIG_NOISE_EVERY := 30
const NOISE_PX := 500
## Running emits a 500 px noise ring every 0.5 s. GDD §3.1, §4.3.
const RUN_NOISE_EVERY := 30
## Rummage 0.6 s. GDD §3.6.
const RUMMAGE_TICKS := 36
## Pick strip window 3 s. GDD §3.6.
const PICK_WINDOW_TICKS := 180
## Dive into a hiding spot 0.25 s. GDD §3.4.
const DIVE_TICKS := 15
## Pop out of a hiding spot.
const POP_TICKS := 15
## A squeak moves her arm for 0.3 s (counts as moving). GDD §3.3.
const SQUEAK_ARM_TICKS := 18
## Longest wheeze (1.5 s). GDD §3.3.
const WHEEZE_MAX_TICKS := 90
## Tray slots. GDD §3.6.
const TRAY_CAP := 4
## A used item restocks at its container 20 s after its last use. GDD §3.6.
const RESTOCK_S := 20
const RESTOCK_TICKS := 1200
## Mirror frame tolerance: Hush counts as "in the frame" within this many px of `frame_x`.
const MIRROR_FRAME_PX := 60
## Door hotspot: Hush steps this far past the door into the other room.
const DOOR_STEP_PX := 60

# --- temper (GDD §4.5) ---------------------------------------------------------------------------
## Temper sub-units per point (2 points/s decay = exactly 2 q per tick).
const TEMPER_Q := 60
## Gains by prank size S, M, L, SIG (points). GDD §4.5.
const GAIN_S := 25
const GAIN_M := 35
const GAIN_L := 45
const GAIN_SIG := 55
## A squeak bit or panto round +5. GDD §4.5.
const GAIN_BIT := 5
## Beryl's headbutt +45 (Stage 3). GDD §4.5.
const GAIN_HEADBUTT := 45
## Witnessed by Delphine +10 (Stage 3). GDD §4.5.
const GAIN_WITNESSED := 10
## Hold after the latest gain (6 s). GDD §4.5.
const HOLD_S := 6
const HOLD_TICKS := 360
## Decay per second (points) → per tick in q.
const DECAY_PER_S := 2
const DECAY_Q_PER_TICK := 2
## Tier thresholds (points): Irked 20, Steaming 45, Livid 70, Meltdown 100. GDD §4.5.
const TIER_IRKED := 20
const TIER_STEAMING := 45
const TIER_LIVID := 70
const TIER_MELTDOWN := 100
const TIER_CALM_ID := 0
const TIER_IRKED_ID := 1
const TIER_STEAMING_ID := 2
const TIER_LIVID_ID := 3
const TIER_NAMES: Array[String] = ["calm", "irked", "steaming", "livid"]
## Running Gag multipliers by link 1, 2, 3, 4+ (percent). GDD §6.1.
const CHAIN_MULT: Array[int] = [100, 150, 200, 300]
## Meltdown: 5.5 s tantrum, stomps at 1.0 / 2.5 / 4.0 s, then Exhausted 8 s, temper → 60. GDD §4.5.
const MELTDOWN_TICKS := 330
const MELTDOWN_STOMPS: Array[int] = [60, 150, 240]
const EXHAUSTED_TICKS := 480
const MELTDOWN_RESET := 60
## Reaction cut by temper: T1 < 45 ≤ T2 < 70 ≤ T3. GDD §4.5, §5.8.
const REACT_T2 := 45
const REACT_T3 := 70
## Tier hold stretch (percent): T1 100, T2 120, T3 150. GDD §5.8.
const TIER_SCALE: Array[int] = [100, 100, 120, 150]
## Suppressed (witnessed) replaces the settle with this many frames. TECH §3.7.4.
const SUPPRESSED_SETTLE := 60
## Default reaction when an archetype is missing from reactions.json (loud in validate()).
const DEFAULT_RX_FRAMES := 120
const DEFAULT_RX_ACCENT := 30

# --- residue / fix-up (GDD §5.4) -----------------------------------------------------------------
## Fix-up at the station 4 s; its `fixup` hooks fire at 1 s. GDD §5.4.
const FIXUP_S := 4
const FIXUP_TICKS := 240
const FIXUP_MARK_S := 1
const FIXUP_MARK_TICKS := 60
const FIXUP_KINDS: Array[String] = ["DRY", "SINK", "HONEY", "MIRROR"]

# --- scoring, applause tenths (GDD §6.1) ---------------------------------------------------------
## Size weights S 1.0, M 1.4, L 2.0, SIG 3.0 (×10). GDD §6.1.
const WEIGHT_S := 10
const WEIGHT_M := 14
const WEIGHT_L := 20
const WEIGHT_SIG := 30
## Prank-line bases of a Night sum to exactly 70.0 Applause. GDD §6.1.
const BASE_TOTAL := 700
## Squeak bit +2 / +1 / 0 per bit per Night. GDD §6.1.
const BIT_SCORES: Array[int] = [20, 10]
## Panto rounds +2 / +3 / +5 (Stage 3). GDD §5.6.
const PANTO_SCORES: Array[int] = [20, 30, 50]
## BUTT OF THE JOKE +3 (Stage 3). GDD §4.8.
const BUTT_SCORE := 30
## Named bonuses. GDD §6.1.
const BONUS_MELTDOWN := 80
const BONUS_MELTDOWN_MAX := 2
const BONUS_COMBO := 40
const BONUS_NEAR_MISS := 20
const BONUS_NEAR_MISS_MAX := 3
const BONUS_EMBARRASSED := 50
## ★★★ Standing Ovation at ≥ 100 Applause at the curtain. GDD §6.2.
const STAR3_TENTHS := 1000

# --- squeaks and lures (GDD §5.6) ----------------------------------------------------------------
## Ear pips fade 8 s after the squeak. GDD §5.6.
const EAR_PIP_WINDOW := 480
## Max ear pips shown.
const EAR_PIPS_MAX := 3
## A squeak bit plays at most 3 times per activity visit. GDD §5.6.
const BIT_MAX_PER_VISIT := 3
## Default squeak-bit length when squeak_bits has none (1.5 s).
const BIT_DEFAULT_TICKS := 90
## Head turn "…the pipes?" (1.0 s). GDD §5.6.
const HEAD_TURN_TICKS := 60
## Lure: Curious detour, looks 3 s. GDD §5.6.
const LURE_LOOK_TICKS := 180
## Lure fatigue: after 2 lures within 60 s, further lures only get a shout. GDD §5.6.
const LURE_FATIGUE_COUNT := 2
const LURE_FATIGUE_WINDOW := 3600
## Curious from a noise or near miss: look 3 s. GDD §4.4.
const CURIOUS_LOOK_TICKS := 180

# --- Mirror, Mirror (GDD §5.7 #15) ---------------------------------------------------------------
## Round lengths: preen 1.2 s, squint 1.2 s, specs tell 1.0 s.
const MIRROR_ROUNDS: Array[int] = [72, 72, 60]

# --- bubble / routine (GDD §3.9, §4.1) -----------------------------------------------------------
## The bubble ring shows remaining PERFORM ticks when ≤ 4 s. GDD §3.9.
const RING_TICKS := 240
## Nerves (Night 10): every loop starts at least Irked. GDD §7.2.
const NERVES_TEMPER := 20

# --- one-shots the view plays (SimOneshots; lengths the clips must match, ruling L14 / lint A29) ------
## `specs {on: true}`: the specs-on flick (0.2 s).
const SPECS_ON_TICKS := 12
## CURIOUS: the first second is the "?" stop before he walks to look.
const CURIOUS_STOP_TICKS := 60
## A fizzle (conditions false on a rigged trigger): his "huh?" (0.5 s).
const FIZZLE_TICKS := 30
## Figgis's hook yanks Hush into a hiding spot (0.6 s).
const FIGGIS_YANK_TICKS := 36
## Mirror, Mirror: Hush's wink as she breaks the stand-in (0.5 s).
const WINK_TICKS := 30

# --- micro-gags (GDD §2.1, lead decision D1) -----------------------------------------------------
## Never two micro-gag beats within this many ticks (3 s).
const MG_MIN_GAP := 180
## Every 4th non-T3 reaction of a Night ends with a slow burn (GDD §9.3 "one reaction in four").
const SLOW_BURN_EVERY := 4
## The slow-burn last beat's clip.
const SLOW_BURN_CLIP := "bellows/beat_slow_burn"

# --- misc ----------------------------------------------------------------------------------------
## Bow: Hush is busy while bowing; the Night ends when it is accepted.
const BOW_TICKS := 1
## Episode `rules` keys that may override defaults.
## `combos`: the combo ids this Night allows (absent = all, [] = none; ruling L4). `senses: false`: Bellows
## never starts a "?" and never catches (the Gate-0 scene).
const RULE_KEYS: Array[String] = ["spot_fill_s", "tomatoes", "cant_fail", "nerves", "nerves_temper", "curtain_calls",
	"loop_repeat", "max_minutes", "combos", "senses"]


## Walk speed at a temper tier (0..3), sub-px per tick. TECH §3.7.1.
static func b_walk_speed(tier: int) -> int:
	var t := tier if tier >= 0 and tier < 4 else 3
	return Fx.div(B_WALK * (100 + TIER_SPEED_PCT[t]), 100)


## Temper gain (points) for a prank size id (PrankDef.SIZE_*).
static func gain_for_size(size_id: int) -> int:
	match size_id:
		0:
			return GAIN_S
		1:
			return GAIN_M
		2:
			return GAIN_L
		_:
			return GAIN_SIG


## Script weight (×10) for a prank size id.
static func weight_for_size(size_id: int) -> int:
	match size_id:
		0:
			return WEIGHT_S
		1:
			return WEIGHT_M
		2:
			return WEIGHT_L
		_:
			return WEIGHT_SIG


## Running Gag multiplier (percent) for a link count (1-based; 0 → 100).
static func mult_for_link(link: int) -> int:
	if link <= 1:
		return CHAIN_MULT[0]
	if link >= 4:
		return CHAIN_MULT[3]
	return CHAIN_MULT[link - 1]


## Temper tier id (0..3) for a temper in q units.
static func tier_of(temper_q: int) -> int:
	if temper_q >= TIER_LIVID * TEMPER_Q:
		return TIER_LIVID_ID
	if temper_q >= TIER_STEAMING * TEMPER_Q:
		return TIER_STEAMING_ID
	if temper_q >= TIER_IRKED * TEMPER_Q:
		return TIER_IRKED_ID
	return TIER_CALM_ID


## Reaction tier (1..3) for a temper in q units.
static func react_tier_of(temper_q: int) -> int:
	if temper_q >= REACT_T3 * TEMPER_Q:
		return 3
	if temper_q >= REACT_T2 * TEMPER_Q:
		return 2
	return 1


## Prep ticks for a prep tier letter.
static func prep_ticks(prep: String) -> int:
	match prep:
		"S":
			return PREP_S
		"B":
			return PREP_B
		_:
			return PREP_Q


## Tier id for a tier name ("calm", "irked", "steaming", "livid"); -1 if unknown.
static func tier_id(tier_name: String) -> int:
	return TIER_NAMES.find(tier_name.to_lower())
