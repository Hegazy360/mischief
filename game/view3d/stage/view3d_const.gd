## View3DConst — the shared numbers of the 3D view (REDESIGN §5, R3D index R4/R5 and §7.6/§7.7). Pure constants and
## unit conversions; every 3D module (view3d, rig, sets, hud overlays, tools) reads these instead of re-typing them.
##
## Units: 1 m = 200 sim px (`x_m = x_px / 200 = x_sub / 12000`); floor `f` stands at y = 3.5·f m; a `house.json` rect
## y (negative up from the floor line) maps to `y_m = −y_px / 200`. Godot axes: +x right, +y up, +z toward the camera.
class_name View3DConst
extends RefCounted

# --- world units (REDESIGN §5.5, index R4) ---
const PX_PER_M := 200.0
const SUB_PER_M := 12000.0
const FLOOR_PITCH_M := 3.5
const ROOM_H_M := 3.2
const SET_DEPTH_M := 2.4

# --- depth bands (REDESIGN §5.1; z toward the camera) ---
const LIP_Z := 0.25
const APRON_Z := [0.0, -0.4]
const LANE_Z := -1.0                 ## characters walk here
const BELLOWS_STATION_Z := -1.4      ## Bellows at his stations
const REACH_Z := -1.6                ## Hush's default reach_pos z while rigging (R5b)
const REACH_Z_MIN := -1.6            ## reach_pos z is never deeper than this
const REACH_ROW := [-1.65, -1.80]    ## the reach part of every live rig prop (R5a)
const SET_BAND := [-1.6, -2.4]
const BACK_WALL_Z := -2.4
const WING_FRONT_Z := -1.4
const STARE_STRIP_Z := [-1.5, -0.5]

# --- camera base framing (REDESIGN §5.2, index §7.7) ---
const CAM_FOV_DEG := 30.0
const CAM_Z := 6.5                   ## 7.5 m in front of the lane
const CAM_Y := 1.9                   ## above the floor of the framed floor
const CAM_AIM_Y := 1.35              ## aimed at this height on the lane → pitch −4.2°
const CAM_NEAR := 0.5
const CAM_FAR := 60.0
const LOGICAL_H := 1080.0            ## logical px (the 1920×1080 base; a 20:9 phone is 2400×1080)
const LOGICAL_W_20X9 := 2400.0
const PX_PER_M_LANE := 269.0         ## measured on the blockout (REDESIGN Appendix A)
const PX_PER_M_BACK := 226.0
const PX_PER_M_MIN_PLAY := 201.0     ## any play framing keeps the back wall ≤ 10 m away
const VISIBLE_W := {"20x9": 8.93, "16x9": 7.15, "4x3": 5.36}
const EDGE_CLAMP_M := 0.3            ## C2
const ROOM_FIT_MARGIN_M := 0.3       ## C1: the room fits if width + 2·0.3 ≤ V
const NEIGHBOUR_STRIP_M := {"20x9": 1.7, "16x9": 0.8}
const TWO_SHOT_MAX := 1.15           ## C3 (8.63 m)
const GAG_ZOOMS := {"small": 1.15, "big": 1.3, "m": 1.4, "finale": 1.6, "s": 1.15, "l": 1.3, "sig": 1.6}
const GAG_MIN_DIST_M := 4.5
const OVERVIEW_DIST_M := 15.0
const CRANE_S := 0.40                ## C5 floor change

# --- visual layers (index §7.6; layer numbers 1-based as in the editor) ---
const LAYER_WORLD := 1
const LAYER_CHAR := 2
const LAYER_PROP_INK := 3
const LAYER_DECAL := 4
const LAYER_MAIN_ONLY := 5
const MASK_WORLD := 1 << 0
const MASK_CHAR := 1 << 1
const MASK_PROP_INK := 1 << 2
const MASK_DECAL := 1 << 3
const MASK_MAIN_ONLY := 1 << 4
const MASK_MAIN := MASK_WORLD | MASK_CHAR | MASK_PROP_INK | MASK_DECAL | MASK_MAIN_ONLY
const MASK_PIP := MASK_WORLD | MASK_CHAR   ## the Bellows window: no prop ink / halo, no decals, no MAIN_ONLY FX

# --- colours (REDESIGN §3.7, §4, §5.3–§5.4) ---
const BG := Color("#1D1728")
const INK := Color("#1B2340")
const VERB_RIG := Color("#FFC838")
const VERB_HIDE := Color("#5C9EFF")
const VERB_TAKE := Color("#FFF4DB")
const VERB_EXIT := Color("#FFF4DB")
const RING_START := Color("#F2D23A")
const RING_END := Color("#5CCF6A")
const NOISE_RING := Color(1.0, 1.0, 1.0, 0.85)
const SQUEAK_RING := Color("#FFD84A")
const DEST_RING := Color(1.0, 1.0, 1.0, 0.9)
const STARE_STRIP := Color(1.0, 0.86, 0.35, 0.34)
const STARE_FROZEN := Color(0.95, 0.52, 0.16, 0.52)
const STARE_BLIND := Color(0.62, 0.62, 0.66, 0.30)
const POOL := Color(1.0, 0.90, 0.62, 0.42)
const STONE := Color("#E8E6E1")
const BLOB_ALPHA := 0.32

# --- light levels (REDESIGN §5.3, index §7.6) ---
const LIGHT_HUSH := 1.0
const LIGHT_BELLOWS := 0.9
const LIGHT_OTHER := 0.78
const DESAT_OTHER := 0.4
const LIGHT_BACKSTAGE := 0.3
const LIGHT_BACKSTAGE_BELLOWS := 0.9
const LIGHT_BELLOWS_MIN := 0.9       ## his char_toon stage_light never below this
const LIGHT_EASE_S := 0.4
const HIDDEN_DESAT := 0.2            ## the "safe" world while Hush hides

# --- outlines, glow, halo (REDESIGN §5.4, §3.7; widths = lead ruling D7: look A's 2.4 px @540 = 4.8 px @1080 on
# characters, 3.4 px on live props — the spec's 3.5 / 2.5 ratio; dressing and architecture none; Settings
# "Outline +50 %" multiplies through the mnd_outline_scale global) ---
const OUTLINE_CHAR_PX := 4.8
const OUTLINE_PROP_PX := 3.4
const HALO_PX := 8.0
const GLOW_HZ := 1.2
const GLOW_OFF := 0.0
const GLOW_NORMAL := 1.0
const GLOW_ACTIVE := 2.0
const OUTLINE_ROOM_LERP_DIM := 0.5

# --- cheat-out (REDESIGN §5.1, index R5d) ---
const CHEAT_IDLE := 35.0
const CHEAT_WALK := 20.0
const CHEAT_PERFORM := 35.0
const CHEAT_FACE_TO_FACE := 5.0
const CHEAT_REACH_MAX := 10.0
const CHEAT_EASE_S := 0.2

# --- characters (REDESIGN §5.5, index §5.2) ---
const HUSH_H_M := 1.60
const BELLOWS_H_M := 1.78
const BLOB_R := {"hush": 0.34, "bellows": 0.45}
const REACH_EASE_S := 0.2

# --- shaders (index §7.6) ---
const SHADER_DIR := "res://art3d/shaders/"
const SH_CHAR := "res://art3d/shaders/char_toon.gdshader"
const SH_SET := "res://art3d/shaders/set_toon.gdshader"
const SH_PROP := "res://art3d/shaders/prop_toon.gdshader"
const SH_OUTLINE := "res://art3d/shaders/outline.gdshader"
const SH_OUTLINE_PROP := "res://art3d/shaders/outline_prop.gdshader"
const SH_HALO := "res://art3d/shaders/halo.gdshader"
const SH_DECAL := "res://art3d/shaders/decal.gdshader"
const SH_FX := "res://art3d/shaders/fx_toon.gdshader"

# --- floor decals (decal.gdshader `shape`, render priority by kind: later kinds draw on top) ---
const DECAL_TEX := 0
const DECAL_DISC := 1
const DECAL_RING := 2
const DECAL_STRIP := 3
const DECAL_DOTS := 4
const DECAL_PRIORITY := {"blob": -8, "pool": -7, "strip": -6, "footprint": -5, "path": -4, "ring": -3, "pin": -2, "pop": -1}
const DECAL_Y := 0.006               ## decals float this far above their floor (no z-fight)


## Sim px (x) → metres.
static func x_m(x_px: float) -> float:
	return x_px / PX_PER_M


## Metres → sim px (x).
static func x_px(x_m_: float) -> float:
	return x_m_ * PX_PER_M


## The floor height of floor `f` (m).
static func floor_y(f: int) -> float:
	return FLOOR_PITCH_M * float(f)


## A sim-world point (px; y negative up, floor f's line at y = −700·f) → metres (x, y).
static func px_to_m2(p: Vector2) -> Vector2:
	return Vector2(p.x / PX_PER_M, -p.y / PX_PER_M)


## Metres (x, y) → sim-world px.
static func m_to_px2(p: Vector2) -> Vector2:
	return Vector2(p.x * PX_PER_M, -p.y * PX_PER_M)


## A sim-world point (px) at depth z → a world Vector3.
static func px_to_world(p: Vector2, z: float = LANE_Z) -> Vector3:
	return Vector3(p.x / PX_PER_M, -p.y / PX_PER_M, z)


## The floor a height (m) belongs to.
static func floor_of_y(y_m: float) -> int:
	return int(floor((y_m + 0.5) / FLOOR_PITCH_M))


## The verb colour of a hotspot kind (&"rig", &"hide", &"take", &"exit"); white otherwise.
static func verb_color(kind: StringName) -> Color:
	match kind:
		&"rig":
			return VERB_RIG
		&"hide":
			return VERB_HIDE
		&"take":
			return VERB_TAKE
		&"exit", &"door":
			return VERB_EXIT
	return Color.WHITE


## The logical screen size for an aspect key ("20x9" 2400×1080, "16x9" 1920×1080, "4x3" 1440×1080).
static func logical_size(aspect: String) -> Vector2:
	match aspect:
		"16x9":
			return Vector2(1920.0, LOGICAL_H)
		"4x3":
			return Vector2(1440.0, LOGICAL_H)
	return Vector2(LOGICAL_W_20X9, LOGICAL_H)
