## RunningGagBanner — the Running Gag fuse under the transient meter (REDESIGN_3D §2.2): a 420 × 18
## fuse bar at y T+144 with "RUNNING GAG ×1.5" (44 px) under it, 460 wide, centred. Shown only while a
## Running Gag is live (link > 0; the meter stays up with it). Pops 1.2 → 1.0 on every new link; the
## fuse spark flickers at the burning end. Never a touch target (MOUSE_FILTER_IGNORE).
class_name RunningGagBanner
extends Control

const W := 460.0
const H := 88.0
## Text size (REDESIGN §2.2: 44 px).
const TEXT_PX := 44
const FUSE_W := 420.0
const FUSE_H := 18.0
const POP_MS := 260

var link: int = 0
var mult_pct: int = 100
var fuse_frac: float = 0.0

var _text: String = ""
var _pop_ms: int = -100000
var _show_k: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(W, H)
	visible = false


func _ready() -> void:
	set_process(false)


## Pure: "×1", "×1.5", "×2", "×3" from a percent.
static func mult_text(pct: int) -> String:
	if pct % 100 == 0:
		return "×%d" % (pct / 100)
	return "×%s" % String.num(float(pct) / 100.0, 2).trim_suffix("0")


## Update; text is rebuilt only when link / multiplier change.
func set_values(p_link: int, p_mult_pct: int, p_fuse: float) -> void:
	var f := clampf(p_fuse, 0.0, 1.0)
	if p_link != link or p_mult_pct != mult_pct:
		if p_link > link and p_link > 0:
			_pop_ms = UiKit.now_ms()
		link = p_link
		mult_pct = p_mult_pct
		_text = "%s %s" % [UiStrings.t("hud.running_gag"), mult_text(mult_pct)]
		set_process(true)
	if not is_equal_approx(f, fuse_frac):
		fuse_frac = f
		queue_redraw()
	visible = link > 0 or _show_k > 0.0
	if link > 0:
		set_process(true)


func _process(delta: float) -> void:
	_show_k = move_toward(_show_k, 1.0 if link > 0 else 0.0, delta / 0.18)
	visible = _show_k > 0.0
	queue_redraw()
	if link <= 0 and _show_k <= 0.0:
		set_process(false)


func _draw() -> void:
	var now := UiKit.now_ms()
	var k := _show_k
	var pt := float(now - _pop_ms) / float(POP_MS)
	if pt >= 0.0 and pt < 1.0 and not UiKit.reduce_motion():
		k *= 1.2 - 0.2 * pt
	draw_set_transform(Vector2(W * 0.5, 17.0), 0.0, Vector2(k, k))
	var f := UiKit.display_font()
	var hot := mult_pct >= 200
	# fuse (its centre line at T+144 + 9)
	var fr := Rect2(-FUSE_W * 0.5, -FUSE_H * 0.5, FUSE_W, FUSE_H)
	UiShapes.begin()
	UiShapes.rrect(fr.grow(5.0), 14.0, UiKit.NAVY)
	UiShapes.rrect(fr, 9.0, Color("#4A3B2A"))
	var lit := fuse_frac * FUSE_W
	var tip := fr.position + Vector2(lit, FUSE_H * 0.5)
	var fl := 0.5 if UiKit.reduce_flash() else 0.5 + 0.5 * sin(float(now) * 0.045)
	if lit > 1.0:
		var col := UiKit.BRASS.lerp(UiKit.CHERRY, 1.0 - fuse_frac)
		UiShapes.rrect(Rect2(fr.position, Vector2(lit, FUSE_H)), 9.0, col)
		UiShapes.circle(tip, 12.0 + 4.0 * fl, Color(UiKit.YELLOW, 0.55))
		UiShapes.circle(tip, 7.0 + 2.0 * fl, UiKit.WHITE)
	UiShapes.flush(self)
	UiKit.draw_text_centered(self, f, Vector2(0, 44.0), _text, TEXT_PX, UiKit.GOLD_LIGHT if hot else UiKit.CREAM, 12)
	draw_set_transform(Vector2.ZERO)
