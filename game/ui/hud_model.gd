## HudModel — everything the HUD shows, as plain typed fields (TECH §5.9).
##
## NightScene owns ONE instance, refills it each frame from the ViewSnapshot, and calls
## `Hud.apply(model)`. The Hud compares against what it last showed, so refilling with the same
## values costs nothing (no allocations, no string formatting, no redraws).
##
## TECH §5.9 fields, plus a few optional ones the widgets need (marked "added"; defaults keep
## the documented behaviour): figgis_ghost, pip_glyph, pip_escalated, script_loop,
## pick_strip_pos, edge_bubble_* (the "(dir, label)" pair as two typed fields). `script` is
## spelled `script_lines` (Object already owns `script`). Stage 2 adds edge_bubble_emote,
## tray_arrows and tray_arrows_item (s2-ui §4.2.1, §4.2.8).
class_name HudModel
extends RefCounted

enum Verb { RIG, RIG_DIM, FREEZE, POP_OUT, GO }
enum ClarenceMode { SQUEAK, FF }
enum Rim { GREEN, AMBER, RED }

const VERB_NAMES: PackedStringArray = ["RIG", "RIG_DIM", "FREEZE", "POP_OUT", "GO"]

# --- the Applause-o-Meter -------------------------------------------------------------------
## Applause (integer; the meter needle caps its display at 150).
var applause: int = 0
## Script counter "lines_done/lines_total".
var lines_done: int = 0
var lines_total: int = 0
## Tomatoes left this Night and the max (−1 = unlimited: tomatoes hidden).
var tomatoes_left: int = -1
var tomatoes_max: int = -1

# --- Running Gag ------------------------------------------------------------------------------
## Running Gag link (0 = no Running Gag: banner hidden) and its multiplier in percent (150 = ×1.5).
var link: int = 0
var mult_pct: int = 100
## Fuse left, 0..1.
var fuse_frac: float = 0.0
## Bellows' temper tier 0 calm … 3 livid (PiP frame colour).
var temper_tier: int = 0

# --- action button ----------------------------------------------------------------------------
var verb: int = Verb.FREEZE
## RIG: the carried item's icon (item id or res:// path; "" = free prank → Hush's glove) and the
## target's icon (activity / prop icon id or path; "" = none).
var verb_item_icon: String = ""
var verb_target_icon: String = ""
## RIG ring progress of the current step, 0..1 (kept when released early).
var ring_frac: float = 0.0
## POP_OUT / GO rim danger.
var rim: int = Rim.GREEN

# --- Clarence / ⏩ ------------------------------------------------------------------------------
var clarence_mode: int = ClarenceMode.SQUEAK
## Lure fatigue: the lure ring greys out.
var lure_grey: bool = false

# --- tray -------------------------------------------------------------------------------------
## Carried item ids, oldest first (≤ 4).
var tray: PackedStringArray = PackedStringArray()
## Slot that the current rig point accepts (rises + glows); −1 = none.
var tray_highlight: int = -1

# --- Figgis -----------------------------------------------------------------------------------
## Hint ladder step 1: "psst" pulse.
var figgis_pulse: bool = false
## (added) Step 3 ("show me") armed: ghost state.
var figgis_ghost: bool = false

# --- Bellows-Cam ------------------------------------------------------------------------------
var pip_visible: bool = false
## Temper tier for the PiP frame colour (usually = temper_tier).
var pip_frame_tier: int = 0
## (added) Awareness glyph id in the PiP corner (specs_off, specs_on, blinded, asleep, stars).
var pip_glyph: String = "specs_off"
## (added) Off-screen payoff: the PiP grows to the 704 × 396 Gag-Cam window.
var pip_escalated: bool = false

# --- edge bubble (the PiP's stand-in while it is hidden) -----------------------------------------
## Direction from the screen centre toward Bellows (ZERO = hidden), e.g. (1, 0) = right,
## (0, -1) = upstairs.
var edge_bubble_dir: Vector2 = Vector2.ZERO
## Its label, e.g. "↑ upstairs", "2 rooms →" (see strings.json hud.edge_*).
var edge_bubble_label: String = ""
## (Stage 2, D1 / ruling L1) The emote Bellows' face plays in the edge bubble while an off-screen
## micro-gag runs: one of EdgeBubble.EMOTES (`sing, hum, smug, laugh, tut, sniff, yum, yawn`) or
## "" = his normal face. NightScene sets it from a `micro_gag` event with `vis == "edge"` for the
## event's `len`, then clears it. This is what lets an off-screen micro-gag count as "seen".
var edge_bubble_emote: String = ""

# --- "where does this go?" (GDD §3.1 tray tap, §3.2 RIG_DIM) ------------------------------------
## (Stage 2) Screen directions (from the screen centre; need not be normalised) of the matching
## OFF-screen targets — the rig points that take the tapped tray item, or the container that holds
## a RIG_DIM prop's missing item. NightScene fills it for 3 s after `tray_tap(i)` / the RIG_DIM tap,
## then empties it. Drawn as bobbing edge arrows (≤ 6) between the top row and the thumb clusters.
var tray_arrows: PackedVector2Array = PackedVector2Array()
## (added) Item id (or res:// path) shown in a disc at each arrow's tail; "" = the item in the
## tray slot tapped last.
var tray_arrows_item: String = ""

# --- panels / strips --------------------------------------------------------------------------
## Script lines for the Script panel (TECH §5.9 `script`; renamed because `script` is Object's
## own property): Array of {id, text, req: bool, done: bool, rigged: bool, discovered: bool,
## big_number: bool, sealed: bool, candle: bool, icon: String (optional)}.
var script_lines: Array = []
## (added) His loop for the Script panel's strip: Array of {activity, icon, rigged: bool,
## current: bool}.
var script_loop: Array = []
## Pick strip: the container being rummaged and its items (empty = hidden).
var pick_strip_container: String = ""
var pick_strip_items: PackedStringArray = PackedStringArray()
## (added) Screen point (logical px) the strip pops above — the container's top centre.
var pick_strip_pos: Vector2 = Vector2.ZERO
## The game is paused (HUD dims and ignores touches).
var paused: bool = false


## Copy every field from `other` (tests, demos).
func copy_from(other: HudModel) -> void:
	for p in get_property_list():
		if int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var v: Variant = other.get(p["name"])
			if v is Array or v is PackedStringArray or v is PackedVector2Array or v is Dictionary:
				v = v.duplicate()
			set(p["name"], v)


## Name of a Verb value (debug).
static func verb_name(v: int) -> String:
	return VERB_NAMES[v] if v >= 0 and v < VERB_NAMES.size() else "?"
