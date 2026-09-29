## Playbill — the slice stub (Router key `playbill`, s2-night §4.2): four posters in a row — the
## Prologue, Night 1, Night 2 with their Curtain Calls (the ★ stamps earned, from Save) and a Play
## button, and Night 3 locked ("coming soon"). Labels from `playbill.*`. No meta (Stage 4).
class_name Playbill
extends Control

const POSTERS := [["p00_curtain_up", "playbill.prologue"], ["n01_throat_tea", "playbill.night1"],
	["n02_something_fishy", "playbill.night2"], ["n03_singing_in_the_bath", "playbill.night3"]]
const LOCKED: PackedStringArray = ["n03_singing_in_the_bath"]
const POSTER := Vector2(400, 560)
const GAP := 40.0

var buttons: Dictionary = {}
## Test hook: record the launch instead of routing.
var dry_run: bool = false
var launched: String = ""
var _stars: Dictionary = {}
var _titles: Dictionary = {}
var _star_tex: Texture2D = null
var _empty_tex: Texture2D = null
var _lock_tex: Texture2D = null


func _init() -> void:
	name = "Playbill"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiKit.theme()


func _ready() -> void:
	_star_tex = UiIcons.get_icon(&"star")
	_empty_tex = UiIcons.get_icon(&"star_empty")
	_lock_tex = UiIcons.get_icon(&"lock")
	var sv := ViewKit.autoload("Save")
	for p in POSTERS:
		var id := String(p[0])
		_titles[id] = UiStrings.t(String(p[1]))
		var st: Array = [false, false, false]
		if sv != null and sv.has_method("night"):
			var n: Variant = sv.call("night", id)
			if n is Dictionary and (n as Dictionary).get("stars") is Array:
				st = (n as Dictionary)["stars"]
		_stars[id] = st
	for i in POSTERS.size():
		var id := String(POSTERS[i][0])
		if LOCKED.has(id):
			continue
		var b := UiButton.make(UiStrings.t("playbill.play"), Vector2(POSTER.x - 60.0, 144), UiKit.GOLD, UiKit.GOLD_SHADE,
			UiIcons.get_icon(&"play"))
		b.icon_after = true
		b.name = "Play_" + id
		b.pressed.connect(play.bind(id))
		add_child(b)
		buttons[id] = b
	resized.connect(_layout)
	_layout()


## Poster rect i for a view of `vs`.
static func poster_rect(vs: Vector2, i: int) -> Rect2:
	var total := POSTER.x * 4.0 + GAP * 3.0
	var x := (vs.x - total) * 0.5 + float(i) * (POSTER.x + GAP)
	return Rect2(x, (vs.y - POSTER.y) * 0.5 + 60.0, POSTER.x, POSTER.y)


func _layout() -> void:
	var vs := size if size.x > 0.0 else Vector2(1920, 1080)
	for i in POSTERS.size():
		var id := String(POSTERS[i][0])
		if buttons.has(id):
			var r := poster_rect(vs, i)
			(buttons[id] as UiButton).position = Vector2(r.position.x + 30.0, r.end.y - 144.0 - 24.0)
	queue_redraw()


## Play a Night (Router `night`).
func play(id: String) -> void:
	launched = id
	if dry_run:
		return
	var r := ViewKit.autoload("Router")
	if r != null and r.has_method("goto"):
		r.call("goto", "night", {"episode": id, "from": "playbill"})


func handle_back() -> bool:
	return true


func _draw() -> void:
	var vs := size if size.x > 0.0 else Vector2(1920, 1080)
	draw_rect(Rect2(Vector2.ZERO, vs), UiKit.CURTAIN_SHADE)
	var fold := vs.x / 16.0
	for i in 16:
		draw_rect(Rect2(float(i) * fold + fold * 0.6, 0, fold * 0.4, vs.y), Color(UiKit.CURTAIN, 0.55))
	var df := UiKit.display_font()
	UiKit.draw_text_centered(self, df, Vector2(vs.x * 0.5, 96.0), UiStrings.t("playbill.title"), UiKit.SIZE_TITLE,
		UiKit.GOLD_LIGHT, 18)
	for i in POSTERS.size():
		var id := String(POSTERS[i][0])
		var r := poster_rect(vs, i)
		var locked := LOCKED.has(id)
		UiKit.draw_chunky_rect(self, r, 28.0, UiKit.PAPER if not locked else Color("#9A94AE"), UiKit.PAPER_SHADE,
			UiKit.BUTTON_OUTLINE, 12.0)
		draw_rect(r.grow(-18.0), Color(UiKit.BRASS, 0.9), false, 5.0)
		var title := String(_titles.get(id, id))
		var fs := ScriptPanel.fit_size(df, title, r.size.x - 60.0, UiKit.SIZE_BANNER)
		UiKit.draw_text_centered(self, df, Vector2(r.get_center().x, r.position.y + 80.0), title, fs, UiKit.NAVY, 0)
		if locked:
			if _lock_tex != null:
				UiKit.draw_icon(self, _lock_tex, Rect2(r.get_center() - Vector2(80, 110), Vector2(160, 160)))
			UiKit.draw_text_centered(self, df, Vector2(r.get_center().x, r.end.y - 150.0), UiStrings.t("playbill.locked"),
				UiKit.SIZE_PLAY, UiKit.NAVY, 0)
			UiKit.draw_text_centered(self, UiKit.ui_font(), Vector2(r.get_center().x, r.end.y - 90.0),
				UiStrings.t("playbill.coming_soon"), UiKit.SIZE_MIN, UiKit.NAVY, 0)
			continue
		# Curtain Calls: three stamps
		UiKit.draw_text_centered(self, UiKit.ui_font(), Vector2(r.get_center().x, r.position.y + 170.0),
			UiStrings.t("playbill.curtain_calls"), UiKit.SIZE_MIN, UiKit.NAVY, 0)
		var st: Array = _stars.get(id, [false, false, false])
		if id == "p00_curtain_up":
			continue
		for k in 3:
			var c := Vector2(r.get_center().x + float(k - 1) * 110.0, r.position.y + 270.0)
			var earned := k < st.size() and bool(st[k])
			var tex := _star_tex if earned else _empty_tex
			if tex != null:
				UiKit.draw_icon(self, tex, Rect2(c - Vector2(46, 46), Vector2(92, 92)), Color(1, 1, 1, 1.0 if earned else 0.5))
