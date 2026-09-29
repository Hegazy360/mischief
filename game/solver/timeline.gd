## SolverTimeline — renders one run log as a PNG strip chart for review (headless, no GPU).
##
##   SolverTimeline.save(log, report, "/abs/out.png")
##
## Time runs left → right (1 px = `TICKS_PER_PX` ticks; a grid line every 10 s, labels every 30 s).
## Rows: BELLOWS room · BELLOWS state (reacting yellow, chase red, caught magenta, detour teal,
## curious orange, search pink) · HUSH room (hidden = dark stripes, frozen = white stripes) ·
## "?" meter (red bars, the fill line dashed) · INPUT (commands and holds) · LAUGHS (yellow;
## prank accents full height, director cues grey) · BEATS (Bellows' micro-gags, D1: a thin tick per beat — room
## green, PiP blue, edge-bubble orange, full height; invisible ones short and grey) · DEAD AIR (grey: the D1 mask,
## visible beats count) · FF (where the persona's ⏩ is latched: those ticks weigh 1/3 in the gate) · EVENTS (rig
## steps green, catches red, near misses orange, bow blue). Legends of the room and beat colours sit at the bottom.
class_name SolverTimeline
extends RefCounted

const TICKS_PER_PX := 12
const ROW_H := 22
const LABEL_W := 92
const TOP := 26
const ROWS: PackedStringArray = ["BELLOWS ROOM", "BELLOWS STATE", "HUSH ROOM", "? METER", "INPUT", "LAUGHS",
	"BEATS", "DEAD AIR", "FF", "EVENTS"]
const ROW_LAUGHS := 5
const ROW_BEATS := 6
const ROW_DEAD := 7
const ROW_FF := 8
const ROW_EVENTS := 9
const BEAT_COLORS := {"room": "#2E9E4F", "pip": "#2F6FD0", "edge": "#F08A24", "hidden": "#C9C2B6"}
const BG := Color("#FBF7F0")
const INK := Color("#1B2340")
const GRID := Color("#DDD5C8")
const ROOM_COLORS := {"porch": "#B8C9A3", "hall": "#A9B79A", "parlour": "#D9A7A0", "kitchen": "#E8D08A",
	"conservatory": "#9FD3C7", "garden": "#7FB77E", "landing": "#B7A6D6", "bathroom": "#8FC1E3",
	"bedroom": "#E3A6C8", "dressing": "#D6B38F"}
const STATE_COLORS := {"ROUTINE": "#C9C2B6", "DETOUR": "#3AA7A0", "CURIOUS": "#F08A24", "SPOTTED": "#E0443A",
	"CHASE": "#C8102E", "SEARCH": "#E77FB3", "REACTING": "#F6C21B", "MELTDOWN": "#A0209A", "EXHAUSTED": "#8A6A4A",
	"CAUGHT_HOLD": "#6B2FA0"}

## 3×5 pixel glyphs (rows top→bottom, 3 bits each) for labels.
const FONT := {
	"A": [2, 5, 7, 5, 5], "B": [6, 5, 6, 5, 6], "C": [3, 4, 4, 4, 3], "D": [6, 5, 5, 5, 6], "E": [7, 4, 6, 4, 7],
	"F": [7, 4, 6, 4, 4], "G": [3, 4, 5, 5, 3], "H": [5, 5, 7, 5, 5], "I": [7, 2, 2, 2, 7], "J": [1, 1, 1, 5, 2],
	"K": [5, 5, 6, 5, 5], "L": [4, 4, 4, 4, 7], "M": [5, 7, 7, 5, 5], "N": [6, 5, 5, 5, 5], "O": [2, 5, 5, 5, 2],
	"P": [6, 5, 6, 4, 4], "Q": [2, 5, 5, 6, 3], "R": [6, 5, 6, 5, 5], "S": [3, 4, 2, 1, 6], "T": [7, 2, 2, 2, 2],
	"U": [5, 5, 5, 5, 7], "V": [5, 5, 5, 5, 2], "W": [5, 5, 7, 7, 5], "X": [5, 5, 2, 5, 5], "Y": [5, 5, 2, 2, 2],
	"Z": [7, 1, 2, 4, 7], "0": [7, 5, 5, 5, 7], "1": [2, 6, 2, 2, 7], "2": [6, 1, 2, 4, 7], "3": [6, 1, 2, 1, 6],
	"4": [5, 5, 7, 1, 1], "5": [7, 4, 6, 1, 6], "6": [3, 4, 7, 5, 7], "7": [7, 1, 2, 2, 2], "8": [7, 5, 7, 5, 7],
	"9": [7, 5, 7, 1, 6], " ": [0, 0, 0, 0, 0], "?": [6, 1, 2, 0, 2], ".": [0, 0, 0, 0, 2], ":": [0, 2, 0, 2, 0],
	"-": [0, 0, 7, 0, 0], "%": [5, 1, 2, 4, 5], "/": [1, 1, 2, 4, 4], "_": [0, 0, 0, 0, 7], "*": [0, 5, 2, 5, 0],
	"(": [1, 2, 2, 2, 1], ")": [4, 2, 2, 2, 4], "+": [0, 2, 7, 2, 0], "=": [0, 7, 0, 7, 0]}


## Render and save a PNG; returns OK or an error code.
static func save(log: SolverLog, report: Dictionary, path: String) -> int:
	var img := render(log, report)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	return img.save_png(path)


## Render the strip chart.
static func render(log: SolverLog, report: Dictionary = {}) -> Image:
	var n := log.size()
	var cols := maxi(1, (n + TICKS_PER_PX - 1) / TICKS_PER_PX)
	var w := maxi(LABEL_W + cols + 8, 760)
	var legend_h := 50
	var h := TOP + ROWS.size() * ROW_H + legend_h
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	img.fill(BG)
	var bt: Dictionary = report.get("beats", {})
	var title := "%s %s %s  %.0fS  APPLAUSE %.0f" % [String(report.get("episode", log.episode)),
		String(report.get("route", log.route)), "OK" if bool(report.get("ok", true)) else "FAIL",
		float(report.get("duration_s", n / 60.0)), float(report.get("applause", 0.0))]
	var sub := "DEAD AIR FF %.1f%% (SIM %.1f%%, NAIVE %.1f%%)   MAX GAP FF %.1fS (SIM %.1fS)   BEATS %d: ROOM %d PIP %d EDGE %d HIDDEN %d   EDGE SHARE %.0f%%" % [
		float(report.get("dead_air_ff_pct", 0.0)), float(report.get("dead_air_sim_pct", report.get("dead_air_pct", 0.0))),
		float(report.get("dead_air_ff_naive_pct", 0.0)), float(report.get("max_gap_ff_s", 0.0)),
		float(report.get("max_gap_sim_s", report.get("max_gap_s", 0.0))), int(bt.get("total", 0)), int(bt.get("room", 0)),
		int(bt.get("pip", 0)), int(bt.get("edge", 0)), int(bt.get("hidden", 0)), 100.0 * float(bt.get("edge_share", 0.0))]
	_text(img, 6, 4, title.to_upper(), INK, 2)
	_text(img, 6, 17, sub, INK, 1)
	for r in ROWS.size():
		_text(img, 4, TOP + r * ROW_H + 7, ROWS[r], INK, 1)
		img.fill_rect(Rect2i(LABEL_W, TOP + (r + 1) * ROW_H - 1, cols, 1), GRID)
	# Grid every 10 s, labels every 30 s.
	var s := 0
	while s * 60 <= n:
		var x := LABEL_W + s * 60 / TICKS_PER_PX
		img.fill_rect(Rect2i(x, TOP, 1, ROWS.size() * ROW_H), GRID)
		if s % 30 == 0:
			_text(img, x + 2, TOP + ROWS.size() * ROW_H + 2, "%dS" % s, INK, 1)
		s += 10
	var dead := Metrics.dead_air_mask(log, SolverHooks.is_laugh)
	var ffm := Metrics.ff_mask(log, SolverHooks.is_laugh)
	var fill := maxi(1, log.fill_ticks)
	for c in cols:
		var i0 := c * TICKS_PER_PX
		var i1 := mini(n, i0 + TICKS_PER_PX)
		var x := LABEL_W + c
		var i := i0
		# Rows 0-2: majority sample of the column.
		_cell(img, x, 0, _room_color(log.name_of(log.b_room[i])))
		var st := log.name_of(log.b_state[i])
		for k in range(i0, i1):
			var sk := log.name_of(log.b_state[k])
			if sk != "ROUTINE":
				st = sk
		_cell(img, x, 1, Color(STATE_COLORS.get(st, "#C9C2B6")))
		var hc := _room_color(log.name_of(log.hush_room[i]))
		_cell(img, x, 2, hc)
		if log.hush_hidden[i] != 0 and c % 3 != 2:
			_cell(img, x, 2, hc.darkened(0.55))
		elif log.hush_frozen[i] == 1 and c % 3 != 2:
			_cell(img, x, 2, Color.WHITE)
		# Row 3: meter.
		var m := 0
		var inp := false
		var dd := false
		var ff := false
		for k in range(i0, i1):
			m = maxi(m, log.spot[k])
			inp = inp or log.input[k] == 1
			dd = dd or dead[k] == 1
			ff = ff or ffm[k] == 1
		var bar := clampi(m * (ROW_H - 4) / fill, 0, ROW_H - 4)
		if bar > 0:
			img.fill_rect(Rect2i(x, TOP + 4 * ROW_H - 2 - bar, 1, bar), Color("#E0443A"))
		if c % 4 < 2:
			img.set_pixel(x, TOP + 3 * ROW_H + 2, Color("#E0443A").lightened(0.4))
		if inp:
			img.fill_rect(Rect2i(x, TOP + 4 * ROW_H + 5, 1, ROW_H - 10), INK)
		if dd:
			_cell(img, x, ROW_DEAD, Color("#9A958C"))
		if ff:
			img.fill_rect(Rect2i(x, TOP + ROW_FF * ROW_H + 7, 1, ROW_H - 14), Color("#6B8FB8"))
	var t0 := log.start_tick
	for ev in log.events:
		var e := SolverData.sv(ev.get("e", ""))
		var x := LABEL_W + (int(ev.get("t", 0)) - t0 - 1) / TICKS_PER_PX
		if x < LABEL_W or x >= w:
			continue
		if SolverHooks.is_laugh(ev):
			var cue := e == "director_cue"
			var col := Color("#9A958C") if cue else Color("#F6B21B")
			var full := e == "reaction_accent"
			var hh := ROW_H - 2 if full else ROW_H / 2
			img.fill_rect(Rect2i(x - (1 if full else 0), TOP + (ROW_LAUGHS + 1) * ROW_H - 1 - hh, 3 if full else 2, hh), col)
		var bk := Metrics.beat_kind(ev)
		if bk != "":
			var bh := ROW_H - 4 if bk != "hidden" else ROW_H / 3
			img.fill_rect(Rect2i(x, TOP + (ROW_BEATS + 1) * ROW_H - 2 - bh, 2, bh), Color(BEAT_COLORS[bk]))
		match e:
			"rig_step_done":
				img.fill_rect(Rect2i(x, TOP + ROW_EVENTS * ROW_H + 3, 2, 7), Color("#2E9E4F"))
			"caught":
				_cross(img, x, TOP + ROW_EVENTS * ROW_H + 11, Color("#C8102E"))
			"near_miss":
				img.fill_rect(Rect2i(x, TOP + ROW_EVENTS * ROW_H + 12, 2, 7), Color("#F08A24"))
			"night_end":
				img.fill_rect(Rect2i(x, TOP, 2, ROWS.size() * ROW_H), Color("#2F6FD0"))
	# Room legend.
	var lx := LABEL_W
	var ly := TOP + ROWS.size() * ROW_H + 14
	for r in ROOM_COLORS:
		img.fill_rect(Rect2i(lx, ly, 10, 10), Color(ROOM_COLORS[r]))
		_text(img, lx + 13, ly + 2, String(r).to_upper(), INK, 1)
		lx += 13 + String(r).length() * 4 + 12
		if lx > w - 60:
			break
	lx = LABEL_W
	ly += 16
	for k in ["room", "pip", "edge", "hidden"]:
		img.fill_rect(Rect2i(lx, ly, 10, 10), Color(BEAT_COLORS[k]))
		var lab: String = "BEAT " + String(k).to_upper()
		_text(img, lx + 13, ly + 2, lab, INK, 1)
		lx += 13 + lab.length() * 4 + 12
	img.fill_rect(Rect2i(lx, ly, 10, 10), Color("#6B8FB8"))
	_text(img, lx + 13, ly + 2, "FF LATCHED (1/3)", INK, 1)
	return img


static func _room_color(room: String) -> Color:
	return Color(ROOM_COLORS.get(room, "#EEE8DC"))


static func _cell(img: Image, x: int, row: int, col: Color) -> void:
	img.fill_rect(Rect2i(x, TOP + row * ROW_H + 2, 1, ROW_H - 4), col)


static func _cross(img: Image, x: int, y: int, col: Color) -> void:
	for d in range(-3, 4):
		for k in 2:
			_px(img, x + d + k, y + d, col)
			_px(img, x + d + k, y - d, col)


static func _px(img: Image, x: int, y: int, col: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, col)


## Draw `s` with the 3×5 font at scale `k`.
static func _text(img: Image, x: int, y: int, s: String, col: Color, k: int) -> void:
	var cx := x
	for ch in s:
		var g: Array = FONT.get(ch, FONT["?"])
		for row in 5:
			var bits: int = g[row]
			for b in 3:
				if bits & (4 >> b):
					img.fill_rect(Rect2i(cx + b * k, y + row * k, k, k), col)
		cx += 4 * k
		if cx > img.get_width() - 4 * k:
			return
