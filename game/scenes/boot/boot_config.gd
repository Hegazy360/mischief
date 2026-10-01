## BootConfig — every key of `scenes/boot/boot_config.json` with its default (R3D index §7.10; the file is
## `r3d-night`'s, its values the orchestrator's). Pure: `read(path)` returns the file merged over DEFAULTS, every
## value coerced to its type (a missing or malformed file = the defaults).
##
## | key | default | read by |
## |---|---|---|
## | `start` | `"auto"` | Boot (`BootRouting.read_config`): `auto` \| `stage_door` \| an episode id |
## | `view` | `"3d"` | the APK check (row 20a); the only view since `r3d-integrate` removed the 2D one |
## | `show_previews` | `false` | the stage door's Night 1 / Night 2 (preview) entries (Settings debug default) |
## | `bellows_window` | `"sim"` | WorldView3D / PipView3D through Settings (`"sim"` \| `"lean"`, ruling R15) |
## | `render.msaa_3d` | `true` | NightScene: 3D MSAA 2× (Settings debug default; NightArgs `--msaa` overrides) |
## | `render.render_scale` | `1.0` | NightScene: `Viewport.scaling_3d_scale` (0.5–1.0) |
## | `render.outline` | `true` | NightScene: the ink outlines on / off (`mnd_outline_scale` 0 when off) |
## The owner APK ships `{"start": "stage_door", "view": "3d", "show_previews": false, "bellows_window": "sim",
## "render": {"msaa_3d": true, "render_scale": 1.0, "outline": true}}` (orchestrator flips per R15 / O2).
class_name BootConfig
extends RefCounted

const PATH := "res://scenes/boot/boot_config.json"
## The views a build can run (the 2D view was removed, r3d-integrate: "2d" is read as the default "3d").
const VIEWS: PackedStringArray = ["3d"]
const WINDOWS: PackedStringArray = ["sim", "lean"]
const DEFAULTS := {"start": "auto", "view": "3d", "show_previews": false, "bellows_window": "sim",
	"render": {"msaa_3d": true, "render_scale": 1.0, "outline": true}}


## The file at `path` merged over DEFAULTS (a fresh deep copy; values coerced, invalid ones = the default).
static func read(path: String = PATH) -> Dictionary:
	var raw := {}
	if path != "" and FileAccess.file_exists(path):
		var j := JSON.new()
		if j.parse(FileAccess.get_file_as_string(path)) == OK and j.data is Dictionary:
			raw = j.data
	return merged(raw)


## `raw` (a parsed boot_config.json) merged over DEFAULTS (pure).
static func merged(raw: Dictionary) -> Dictionary:
	var out: Dictionary = DEFAULTS.duplicate(true)
	var s: Variant = raw.get("start", null)
	if s is String and String(s) != "":
		out["start"] = String(s)
	var v: Variant = raw.get("view", null)
	if v is String and VIEWS.has(String(v).to_lower()):
		out["view"] = String(v).to_lower()
	var sp: Variant = raw.get("show_previews", null)
	if sp is bool:
		out["show_previews"] = sp
	var bw: Variant = raw.get("bellows_window", null)
	if bw is String and WINDOWS.has(String(bw)):
		out["bellows_window"] = String(bw)
	var r: Variant = raw.get("render", null)
	if r is Dictionary:
		var rd: Dictionary = r
		var ro: Dictionary = out["render"]
		if rd.get("msaa_3d") is bool:
			ro["msaa_3d"] = rd["msaa_3d"]
		if rd.get("render_scale") is float or rd.get("render_scale") is int:
			ro["render_scale"] = clampf(float(rd["render_scale"]), 0.5, 1.0)
		if rd.get("outline") is bool:
			ro["outline"] = rd["outline"]
	return out


## `view` of the file (always "3d" since the 2D view was removed).
static func view(path: String = PATH) -> String:
	return String(read(path)["view"])


## `render` of the file ({msaa_3d, render_scale, outline}).
static func render(path: String = PATH) -> Dictionary:
	return read(path)["render"]
