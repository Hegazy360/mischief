## FallbackPuppet — the stand-in character drawn when no RigPlayer / rig data exists yet
## (TECH §5.4 fallback): flat SVG sprites (res://art/fx/fallback/puppet_*.svg) with squash,
## stretch, lean and tremble applied by CharacterView, plus a facing arrow. Unknown actors
## get the spec's plain capsule with a face dot. 1–3 textured rects per character (batched).
class_name FallbackPuppet
extends Node2D

## GDD §9.2 / TECH §4.7 temper tint tiers (face only).
const TINTS := [Color("#FFFFFF"), Color("#FFE0DC"), Color("#FFC2B8"), Color("#F59A94"), Color("#E0707A")]
const PEACH := Color("#F4C9A8")

var kind: String = "hush"
## stand | step | freeze | shock
var pose: String = "stand":
	set(v):
		if pose != v:
			pose = v
			queue_redraw()
var tier: int = 0:
	set(v):
		if tier != v:
			tier = v
			queue_redraw()
var specs: bool = false:
	set(v):
		if specs != v:
			specs = v
			queue_redraw()
var show_arrow: bool = true
var capsule_color: Color = Color("#8A7FB0")
## Squash / stretch around the feet, lean (radians), extra offset (tremble, bob).
var squash: Vector2 = Vector2.ONE
var lean: float = 0.0
var bob: Vector2 = Vector2.ZERO
var facing: float = 1.0

var _tex: Dictionary = {}


func _ready() -> void:
	_load()


func _load() -> void:
	match kind:
		"hush":
			for p in ["stand", "step", "freeze", "shock"]:
				_tex[p] = FxArt.sprite("fallback/puppet_hush_%s" % p)
		"bellows":
			for p in ["stand", "step"]:
				_tex["body_" + p] = FxArt.sprite("fallback/puppet_bellows_body_%s" % p)
			for p in ["stand", "shock"]:
				_tex["face_" + p] = FxArt.sprite("fallback/puppet_bellows_face_%s" % p)
				_tex["hair_" + p] = FxArt.sprite("fallback/puppet_bellows_hair_%s" % p)
			_tex["specs"] = FxArt.sprite("fallback/puppet_bellows_specs")
	_tex["dot"] = FxArt.sprite("dot")


## Height of the puppet in world px (feet to top).
func height_px() -> float:
	return 350.0 if kind == "hush" else (390.0 if kind == "bellows" else 300.0)


## Push the per-frame transform (squash, lean, bob, facing) — cheap: a transform only.
func set_motion(sq: Vector2, lean_rad: float, offset: Vector2, face: float) -> void:
	squash = sq
	lean = lean_rad
	bob = offset
	facing = face
	var fx := facing if absf(facing) > 0.05 else 0.05
	transform = Transform2D(lean, Vector2(sq.x * fx, sq.y), 0.0, offset)


func _draw() -> void:
	match kind:
		"hush":
			var t: Texture2D = _tex.get(pose if _tex.has(pose) else "stand", null)
			if t != null:
				draw_texture(t, Vector2(-110, -346))
		"bellows":
			var bp := "step" if pose == "step" else "stand"
			var fp := "shock" if pose == "shock" else "stand"
			var body: Texture2D = _tex.get("body_" + bp, null)
			if body != null:
				draw_texture(body, Vector2(-130, -386))
			var face: Texture2D = _tex.get("face_" + fp, null)
			if face != null:
				var tint: Color = TINTS[clampi(tier, 0, TINTS.size() - 1)]
				draw_texture(face, Vector2(-130, -390), PEACH * tint)
			var hair: Texture2D = _tex.get("hair_" + fp, null)
			if hair != null:
				draw_texture(hair, Vector2(-130, -390))
			if specs:
				var sp: Texture2D = _tex.get("specs", null)
				if sp != null:
					draw_texture(sp, Vector2(-130, -390))
		_:
			draw_rect(Rect2(-50, -260, 100, 260), capsule_color)
			draw_circle(Vector2(0, -290), 50.0, capsule_color.lightened(0.3))
			draw_circle(Vector2(22, -300), 8.0, ViewKit.INK)
	if show_arrow:
		var y := -height_px() - 26.0
		draw_line(Vector2(-14, y), Vector2(14, y), Color(ViewKit.INK, 0.55), 5.0)
		draw_line(Vector2(14, y), Vector2(4, y - 9), Color(ViewKit.INK, 0.55), 5.0)
		draw_line(Vector2(14, y), Vector2(4, y + 9), Color(ViewKit.INK, 0.55), 5.0)
