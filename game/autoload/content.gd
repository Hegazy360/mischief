## Content — the loaded ContentDB (TECH §3.2). Registered as the `Content` autoload by the orchestrator;
## tests construct ContentDB directly.
##
## Loads `res://data` once at startup. In debug builds a non-empty `validate()` prints every error and,
## when a display exists, shows a red banner listing them.
extends Node

const DATA_ROOT := "res://data"

## The loaded content (never null after _ready; check `db.errors`).
var db: ContentDB = null

var _banner: CanvasLayer = null


func _ready() -> void:
	load_db(DATA_ROOT)


## (Re)load content from `root`. Returns the db.
func load_db(root: String = DATA_ROOT) -> ContentDB:
	var t0 := Time.get_ticks_msec()
	db = ContentDB.load_dir(root)
	if OS.is_debug_build():
		print("[Content] loaded %s in %d ms: %d errors, %d warnings" % [root, Time.get_ticks_msec() - t0,
			db.errors.size(), db.warnings.size()])
		if not db.errors.is_empty():
			for e in db.errors:
				printerr("[Content] ", e)
			_show_banner(db.errors)
	return db


## True when the content loaded without errors.
func ok() -> bool:
	return db != null and db.errors.is_empty()


func _show_banner(errors: PackedStringArray) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if _banner != null:
		_banner.queue_free()
	_banner = CanvasLayer.new()
	_banner.layer = 128
	var bg := ColorRect.new()
	bg.color = Color(0.75, 0.05, 0.1, 0.92)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bg.custom_minimum_size = Vector2(0, 220)
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 28)
	label.position = Vector2(24, 12)
	var shown := PackedStringArray()
	for i in mini(errors.size(), 5):
		shown.append(errors[i])
	label.text = "CONTENT ERRORS (%d):\n%s" % [errors.size(), "\n".join(shown)]
	bg.add_child(label)
	_banner.add_child(bg)
	add_child(_banner)
