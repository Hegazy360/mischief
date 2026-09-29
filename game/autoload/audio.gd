## Audio — every sound in Mischief Next Door (TECH §5.8).
##
## Buses (res://default_bus_layout.tres): Master ← Music, SFX, Voice, Crowd, UI, plus pan
## sub-buses SFX_PanL2/L1/R1/R2 → SFX and Voice_PanL/R → Voice. A 12-player SFX pool
## (steals the oldest), 3 voice players, 2 crowd players, two music players that crossfade.
##
## Ids resolve through res://audio/sfx_map.json (written by tools/audio/gen_audio.py): a
## file id, a bank (a random member — never the same file twice in a row) or an alias
## chain. Unknown ids are silent no-ops (one warning per id in debug builds).
##
## Music states: curtain (one-shot overture), sneak, suspense (the suspense stem fades in
## on top of the sneak stem inside one AudioStreamSynchronized), chase, results, silence.
## `chain_section(n)` swaps sneak/suspense for Mountain King section n, switched on the
## next bar line of whatever is playing. `sting(id)` ducks the Music bus −6 dB for the
## sting's length; the Crowd bus ducks −6 dB while Bellows' voice plays.
##
## Gate-0 A/B: `set_voice_style("formant" | "tuba")` maps vo_bellows_* banks to
## vo_bellows_tuba_*; `set_crowd_style("formant" | "fallback")` maps crowd_* to crowd_fb_*
## where a fallback file exists. Both follow the Settings keys `voice_style` / `crowd_style`
## (on ready and on `changed`). `preview(id, style)` plays one voice / crowd id (or a timed
## preview sequence) in a given style on its own players without touching Settings or the
## current styles — the stage door's A/B pair buttons. `set_voice_squeaky(true)` (the SQUEAKY
## residue) maps aria / shout banks to their +12 st vo_bellows_squeaky_* variants.
##
## Cycles (sfx_map.json "cycles"): an id whose members play in order — Hush's `step_pizz_up`
## tiptoe walks up the E-minor scale and back down, and starts at the bottom again after
## `reset_s` without a step.
##
## Volumes follow the Settings keys music_vol, sfx_vol (also the UI bus), voice_vol and
## crowd_vol when a Settings autoload exists (soft hook). Fades and ducks run on wall-clock
## time (never Engine.time_scale); tests set `auto_advance = false` and call `advance(dt)`.
extends Node

## Emitted when the playing music track changes ("" = silence).
signal music_changed(track: String)

const MAP_PATH := "res://audio/sfx_map.json"
const AUDIO_ROOT := "res://audio/"
const SFX_POOL := 12
const VOICE_POOL := 3
const CROWD_POOL := 2
const BUSES: PackedStringArray = ["Music", "SFX", "Voice", "Crowd", "UI"]
## Settings key per bus (soft: only read when a Settings autoload exists).
const SETTING_KEYS := {"Music": "music_vol", "SFX": "sfx_vol", "UI": "sfx_vol", "Voice": "voice_vol",
	"Crowd": "crowd_vol"}
const MUSIC_STATES: PackedStringArray = ["curtain", "sneak", "suspense", "chase", "results", "silence"]
## crowd(kind) kinds → priority (a busy crowd player is only stolen by an equal or higher one).
const CROWD_KINDS := {"t0": 0, "t1": 1, "t2": 2, "t3": 3, "t4": 4, "ooh": 2, "gasp": 2, "aww": 2, "shh": 1,
	"shush": 1, "behind_you": 3, "chant": 3, "bow_chant": 3, "boo": 2, "relief": 2, "cheer": 3}
## crowd(kind) spellings that play another kind's files (the Stalls say "shush" too).
const CROWD_ALIASES := {"shush": "shh"}
const VOICE_STYLES: PackedStringArray = ["formant", "tuba"]
const CROWD_STYLES: PackedStringArray = ["formant", "fallback"]
## Dedicated preview players (the A/B page) and the timed parts a preview sequence may queue.
const PREVIEW_POOL := 3
const PREVIEW_QUEUE := 16
## music state track → file id (chain tracks are "chain_1".."chain_4").
const TRACK_FILES := {"sneak": "mus_sneak", "chase": "mus_chase", "curtain": "mus_curtain",
	"results": "mus_results", "chain_1": "mus_chain_1", "chain_2": "mus_chain_2", "chain_3": "mus_chain_3",
	"chain_4": "mus_chain_4"}
const STING_DUCK_DB := -6.0
const CROWD_DUCK_DB := -6.0
const PAUSE_DUCK_DB := -10.0
const DUCK_ATTACK_S := 0.05
const DUCK_RELEASE_S := 0.3
const SUSPENSE_FADE_S := 0.4
## The sneak stem sits this much lower while the suspense stem plays on top.
const SUSPENSE_SNEAK_DB := -2.5
const FADE_STATE_S := 0.6
const FADE_CHASE_S := 0.25
const FADE_SILENCE_S := 1.0
const FADE_BAR_IN_S := 0.03
const FADE_BAR_OUT_S := 0.15
const MIN_REPEAT_S := 0.03
const SILENT_DB := -80.0
const SR := 22050.0
## Pan buses: |pan| < 0.2 plays centred; the SFX pool has two steps each side, voices one.
const SFX_PAN_BUSES: PackedStringArray = ["SFX_PanL2", "SFX_PanL1", "SFX", "SFX_PanR1", "SFX_PanR2"]
const SFX_PAN_VALUES: PackedFloat32Array = [-0.8, -0.4, 0.0, 0.4, 0.8]
const VOICE_PAN_BUSES: PackedStringArray = ["Voice_PanL", "Voice", "Voice_PanR"]
const VOICE_PAN_VALUES: PackedFloat32Array = [-0.4, 0.0, 0.4]
## tuba + squeaky: the tuba bank has no squeaky files, so it plays a fifth up instead.
const TUBA_SQUEAKY_PITCH := 1.4983

## "formant" | "tuba" — see set_voice_style().
var voice_style: String = "formant"
## "formant" | "fallback" — see set_crowd_style().
var crowd_style: String = "formant"
## SQUEAKY residue: aria / shout banks use their chipmunk variants.
var voice_squeaky: bool = false
## When false, `_process` does not advance fades/ducks/bar switches (tests call advance()).
var auto_advance: bool = true
## Tests: ≥ 0 overrides the music playback position used for bar maths.
var debug_music_pos: float = -1.0

var _files: Dictionary = {}          # id → {path, bus, len, cat}
var _banks: Dictionary = {}          # bank id → Array[String] of file ids
var _aliases: Dictionary = {}        # name → name
var _music: Dictionary = {}          # file id → {bpm, beats_per_bar, bars, spb, loop, path, len}
var _stems: Dictionary = {}          # "sneak" → [base, layer...]
var _vary: Dictionary = {}           # file id → pitch jitter fraction
var _cycles: Dictionary = {}         # cycle id → {members, mode, reset_s}
var _sequences: Dictionary = {}      # preview sequence id → [[t_s, id], ...]
var _cycle_step: Dictionary = {}     # cycle id → steps taken in the current run
var _cycle_last: Dictionary = {}     # cycle id → clock time of the last step
var _streams: Dictionary = {}        # file id → AudioStream (null = missing)
var _last_pick: Dictionary = {}      # bank id → last file id picked
var _last_play: Dictionary = {}      # file id → clock time of its last start
var _warned: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _clock: float = 0.0
var _last_usec: int = 0
var _paused: bool = false

var _bus_linear: Dictionary = {}     # bus → user linear volume
var _music_duck_db: float = 0.0
var _crowd_duck_db: float = 0.0
var _sting_until: float = -1.0
var _voice_until: float = -1.0

var _sfx: Array[AudioStreamPlayer] = []
var _sfx_started: PackedFloat64Array = []
var _voice: Array[AudioStreamPlayer] = []
var _voice_started: PackedFloat64Array = []
var _voice_last_file: String = ""
var _crowd_players: Array[AudioStreamPlayer] = []
var _crowd_started: PackedFloat64Array = []
var _crowd_prio: PackedInt32Array = []
var _crowd_ends: PackedFloat64Array = []
var _preview: Array[AudioStreamPlayer] = []
var _preview_next: int = 0
var _preview_q_t: PackedFloat32Array = []      # seconds until the queued part plays (< 0 = free)
var _preview_q_file: PackedStringArray = []
var _preview_last: PackedStringArray = []      # the files the last preview() plays, in order (tests)

# music
var _mus: Array[AudioStreamPlayer] = []
var _mgain: PackedFloat32Array = [0.0, 0.0]
var _mtarget: PackedFloat32Array = [0.0, 0.0]
var _mrate: PackedFloat32Array = [1.0, 1.0]
var _mtrack: PackedStringArray = ["", ""]
var _active: int = 0
var _state: String = "silence"
var _chain: int = 0
var _track: String = ""
var _pending_track: String = ""
var _pending_in: float = -1.0
var _sync: AudioStreamSynchronized = null
var _suspense_gain: float = 0.0
var _suspense_target: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_ensure_buses()
	_load_map()
	for i in SFX_POOL:
		_sfx.append(_make_player("Sfx%d" % i, "SFX"))
		_sfx_started.append(-1.0)
	for i in VOICE_POOL:
		_voice.append(_make_player("Voice%d" % i, "Voice"))
		_voice_started.append(-1.0)
	for i in CROWD_POOL:
		_crowd_players.append(_make_player("Crowd%d" % i, "Crowd"))
		_crowd_started.append(-1.0)
		_crowd_prio.append(-1)
		_crowd_ends.append(-1.0)
	for i in PREVIEW_POOL:
		_preview.append(_make_player("Preview%d" % i, "Voice"))
	for i in PREVIEW_QUEUE:
		_preview_q_t.append(-1.0)
		_preview_q_file.append("")
	for i in 2:
		var p := _make_player("Music%d" % i, "Music")
		p.volume_db = SILENT_DB
		_mus.append(p)
	for b in BUSES:
		_bus_linear[b] = 1.0
	if not _apply_settings():
		_apply_settings.call_deferred()   # Settings may be registered after Audio
	_last_usec = Time.get_ticks_usec()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var dt := clampf(float(now - _last_usec) / 1000000.0, 0.0, 0.25)
	_last_usec = now
	if auto_advance:
		advance(dt)


# =============================================================================== public API (TECH §5.8)

## Play a one-shot (file, bank or alias). `pan` −1..1 (screen x), `vol_db` on top of the
## file's level, `pitch` as a pitch_scale. Voice / crowd ids are routed to their pools.
func play_sfx(id: String, pan := 0.0, vol_db := 0.0, pitch := 1.0) -> void:
	var files := _styled_files(id)
	if files.is_empty():
		_warn(id)
		return
	var key := _canonical(id)
	var fid := _cycle_next(key) if _cycles.has(key) else _pick(key, files)
	var bus := String((_files[fid] as Dictionary).get("bus", "SFX"))
	if bus == "Voice":
		_play_voice_file(fid, vol_db, pan, pitch)
		return
	if bus == "Crowd":
		_play_crowd_file(fid, 2, vol_db)
		return
	var stream := _stream(fid)
	if stream == null:
		_warn(id)
		return
	if _clock - float(_last_play.get(fid, -100.0)) < MIN_REPEAT_S:
		return
	_last_play[fid] = _clock
	var si := _take_oldest(_sfx, _sfx_started)
	_sfx_started[si] = _clock
	var p := _sfx[si]
	p.stop()
	p.stream = stream
	p.bus = bus if bus == "UI" else _pan_bus(SFX_PAN_BUSES, SFX_PAN_VALUES, pan)
	p.volume_db = vol_db
	var v := float(_vary.get(fid, 0.0))
	var jit := 1.0 + (_rng.randf_range(-v, v) if v > 0.0 else 0.0)
	p.pitch_scale = clampf(pitch * jit, 0.25, 4.0)
	p.play()


## Bellows (or any speaker) says a line: a random variant of `bank`, never the same file
## twice in a row. Optional `vol_db` / `pan` (rooms away, screen side).
func play_voice(bank: String, vol_db := 0.0, pan := 0.0) -> void:
	var files := _styled_files(bank)
	if files.is_empty():
		_warn(bank)
		return
	var fid := _pick(_canonical(bank), files)
	var pitch := 1.0
	if voice_squeaky and voice_style == "tuba" and _has_squeaky_variant(bank):
		pitch = TUBA_SQUEAKY_PITCH
	_play_voice_file(fid, vol_db, pan, pitch)


## The Stalls react: t0..t4, ooh, gasp, aww, shh, behind_you, chant, bow_chant, boo,
## relief, cheer. A lower-priority reaction never cuts off a bigger one still playing.
func crowd(kind: String) -> void:
	if not CROWD_KINDS.has(kind):
		_warn("crowd:" + kind)
		return
	var k := String(CROWD_ALIASES.get(kind, kind))
	var files := _styled_files("crowd_" + k)
	if files.is_empty():
		_warn("crowd_" + k)
		return
	var fid := _pick(_canonical("crowd_" + k), files)
	_play_crowd_file(fid, int(CROWD_KINDS[kind]), 0.0)


## Switch the music state (curtain, sneak, suspense, chase, results, silence). Crossfades;
## sneak ↔ suspense only fades the suspense stem. A live chain section replaces sneak/suspense.
func music_state(state: String) -> void:
	if not MUSIC_STATES.has(state):
		_warn("music_state:" + state)
		return
	var was_base := _state == "sneak" or _state == "suspense"
	_state = state
	_suspense_target = 1.0 if state == "suspense" else 0.0
	var want := track_for(state, _chain)
	if want == _track and _pending_track == "":
		return
	if was_base and (state == "sneak" or state == "suspense") and _pending_track == want:
		return   # sneak ↔ suspense while a bar-synced chain switch waits: keep the bar line
	_pending_track = ""
	_pending_in = -1.0
	var fade := FADE_CHASE_S if state == "chase" else FADE_SILENCE_S if state == "silence" else FADE_STATE_S
	_start_track(want, fade, fade)


## Running Gag link → Mountain King section (0 off, 1..4; a Meltdown is 4). Switched on the
## next bar line of the current track; outside sneak/suspense it applies on the way back.
func chain_section(n: int) -> void:
	var k := clampi(n, 0, 4)
	if k == _chain and (_pending_track == "" or _pending_track == track_for(_state, k)):
		return
	_chain = k
	var want := track_for(_state, _chain)
	if _state != "sneak" and _state != "suspense":
		return
	if want == _track:
		_pending_track = ""
		_pending_in = -1.0
		return
	var bar := _bar_length(_track)
	if _track == "" or bar <= 0.0 or not _mus[_active].playing and debug_music_pos < 0.0:
		_start_track(want, FADE_BAR_IN_S, FADE_BAR_OUT_S)
		return
	if _pending_track == "":
		_pending_in = next_bar_delay(_music_position(), bar)
	_pending_track = want
	if _pending_in <= 0.0:
		_fire_pending()


## Play `sting_<id>` (the prefix is optional) and duck the music −6 dB for its length.
func sting(id: String) -> void:
	var sid := id if id.begins_with("sting_") else "sting_" + id
	var files := _styled_files(sid)
	if files.is_empty():
		_warn(sid)
		return
	var fid := _pick(_canonical(sid), files)
	var stream := _stream(fid)
	if stream == null:
		_warn(sid)
		return
	var si := _take_oldest(_sfx, _sfx_started)
	_sfx_started[si] = _clock
	var p := _sfx[si]
	p.stop()
	p.stream = stream
	p.bus = "SFX"
	p.volume_db = 0.0
	p.pitch_scale = 1.0
	p.play()
	_sting_until = maxf(_sting_until, _clock + _length(fid))


## Set a bus's user volume (0..1 linear; 0 mutes). Bus: Music, SFX, Voice, Crowd, UI.
func set_bus_volume(bus: String, linear: float) -> void:
	if not BUSES.has(bus):
		_warn("bus:" + bus)
		return
	_bus_linear[bus] = clampf(linear, 0.0, 1.0)
	_apply_bus(bus)


## True when `id` (file, bank or alias) resolves to at least one audio file.
## Load (and cache) the streams of every non-music sound, or only `ids` (file ids) when given,
## so the first play of each variant never hitches mid-gag. Call it under the curtain (Boot /
## NightScene warm-up). Returns how many streams are cached afterwards.
func warm(ids: PackedStringArray = PackedStringArray()) -> int:
	var list: Array = Array(ids) if not ids.is_empty() else _files.keys()
	for fid in list:
		if ids.is_empty() and _music.has(fid):
			continue
		_stream(String(fid))
	return _streams.size()


func has_sfx(id: String) -> bool:
	return not resolve_files(id).is_empty()


## "formant" (default) or "tuba": which Bellows voice bank plays (Gate-0 A/B).
func set_voice_style(style: String) -> void:
	if style == "formant" or style == "tuba":
		voice_style = style
	else:
		_warn("voice_style:" + style)


## "formant" (default) or "fallback": which audience plays (Gate-0 A/B).
func set_crowd_style(style: String) -> void:
	if style == "formant" or style == "fallback":
		crowd_style = style
	else:
		_warn("crowd_style:" + style)


## Stage-door A/B: play one voice id (style "formant" | "tuba") or crowd id / kind (style
## "formant" | "fallback") — or a preview sequence (sfx_map.json "sequences", e.g.
## `vo_bellows_sneeze_seq`) — in exactly that style, on dedicated players, without touching
## Settings or the current `voice_style` / `crowd_style`. A bank previews its first member
## so both sides of a pair play the same take. A new preview cuts the previous one.
func preview(id: String, style: String) -> void:
	stop_preview()
	var plan := _preview_plan(id, style)
	_preview_last = PackedStringArray()
	if plan.is_empty():
		_warn("preview:" + id)
		return
	var qi := 0
	for step: Array in plan:
		var t := float(step[0])
		var fid := String(step[1])
		_preview_last.append(fid)
		if t <= 0.0:
			_play_preview_file(fid)
		elif qi < PREVIEW_QUEUE:
			_preview_q_t[qi] = t
			_preview_q_file[qi] = fid
			qi += 1


## True when `preview(id, …)` has something to play (a preview sequence or any resolvable id).
func has_preview(id: String) -> bool:
	return _sequences.has(id) or has_sfx(id) or (CROWD_KINDS.has(id) and has_sfx("crowd_" + id))


## The files `preview(id, style)` plays, in order (empty = nothing to play).
func preview_files(id: String, style: String) -> PackedStringArray:
	var out := PackedStringArray()
	for step: Array in _preview_plan(id, style):
		out.append(String(step[1]))
	return out


## [[t_s, file id], …] a preview plays: a sequence's parts (or the id itself at 0 s), each
## resolved in `style` (a voice style for voice ids, a crowd style for crowd ids / kinds;
## the other axis keeps its current style), the first member of a bank.
func _preview_plan(id: String, style: String) -> Array:
	var out: Array = []
	var parts: Array = _sequences.get(id, [[0.0, id]])
	var vs := style if VOICE_STYLES.has(style) else voice_style
	var cs := style if CROWD_STYLES.has(style) else crowd_style
	for part in parts:
		var pid := String((part as Array)[1])
		if CROWD_KINDS.has(pid):
			pid = "crowd_" + String(CROWD_ALIASES.get(pid, pid))
		var files := _styled_files_as(_canonical(pid), vs, cs, false)
		if not files.is_empty():
			out.append([float((part as Array)[0]), files[0]])
	return out


## Stop a running preview and drop its queued parts.
func stop_preview() -> void:
	for p: AudioStreamPlayer in _preview:
		p.stop()
	for i in PREVIEW_QUEUE:
		_preview_q_t[i] = -1.0
		_preview_q_file[i] = ""


## True while a preview is sounding or has parts queued.
func is_previewing() -> bool:
	for p: AudioStreamPlayer in _preview:
		if p.playing:
			return true
	for i in PREVIEW_QUEUE:
		if _preview_q_t[i] >= 0.0:
			return true
	return false


## The files the last `preview()` call plays, in order (tests / the A/B page's label).
func last_preview_files() -> PackedStringArray:
	return _preview_last


## Cut Bellows' voice (a reaction or bit interrupting a line mid-phrase): fades nothing, just
## stops the voice players and lifts the crowd duck.
func stop_voice() -> void:
	for p: AudioStreamPlayer in _voice:
		p.stop()
	_voice_until = -1.0


# =============================================================================== additions

## SQUEAKY residue on/off: arias and shouts come out +12 semitones.
func set_voice_squeaky(on: bool) -> void:
	voice_squeaky = on


## Pause menu: pauses one-shots, voices and the crowd; ducks the music.
func set_paused(on: bool) -> void:
	_paused = on
	for arr in [_sfx, _voice, _crowd_players, _preview]:
		for p: AudioStreamPlayer in arr:
			p.stream_paused = on and p.playing


## Stop every one-shot, voice and crowd sound (retry, scene change). Music keeps its state
## unless `include_music`.
func stop_all(include_music := false) -> void:
	for arr in [_sfx, _voice, _crowd_players]:
		for p: AudioStreamPlayer in arr:
			p.stop()
	_voice_until = -1.0
	_sting_until = -1.0
	for i in CROWD_POOL:
		_crowd_prio[i] = -1
	if include_music:
		music_state("silence")
		_chain = 0


## Load every stream now (under the Boot curtain) so the first play never hitches.
## Returns how many streams are loaded.
func warm_up() -> int:
	var n := 0
	for fid: String in _files:
		if _stream(fid) != null:
			n += 1
	return n


## File ids an id resolves to (file → itself; bank → members; aliases followed).
func resolve_files(id: String) -> PackedStringArray:
	var out := PackedStringArray()
	var name := id
	for _i in 8:
		if _files.has(name):
			out.append(name)
			return out
		if _banks.has(name):
			for f: String in _banks[name]:
				if _files.has(f):
					out.append(f)
			return out
		if _cycles.has(name):
			for f in (_cycles[name] as Dictionary).get("members", []):
				if _files.has(String(f)):
					out.append(String(f))
			return out
		if not _aliases.has(name):
			return out
		name = String(_aliases[name])
	return out


## The music track playing now ("sneak", "chase", "chain_2", "curtain", "results", "").
func current_track() -> String:
	return _track


## The requested music state.
func current_state() -> String:
	return _state


## The requested chain section (0..4).
func current_chain() -> int:
	return _chain


## A bar-synced switch waiting to fire ("" = none) and the seconds left.
func pending_track() -> String:
	return _pending_track


func pending_in() -> float:
	return _pending_in


## Current music duck (dB, ≤ 0) from stings / pause, and the crowd duck under the voice.
func music_duck_db() -> float:
	return _music_duck_db


func crowd_duck_db() -> float:
	return _crowd_duck_db


## Current suspense-stem gain 0..1.
func suspense_gain() -> float:
	return _suspense_gain


## The user linear volume of a bus.
func bus_volume(bus: String) -> float:
	return float(_bus_linear.get(bus, 1.0))


## The last file picked from a bank (or played as a voice), "" if none yet.
func last_pick(bank: String) -> String:
	return String(_last_pick.get(bank, ""))


func last_voice_file() -> String:
	return _voice_last_file


## Seconds per bar of a track ("sneak", "chain_3" …) from sfx_map.json; 0 when unknown.
func bar_length_of(track: String) -> float:
	return _bar_length(track)


## Advance fades, ducks and bar-synced switches by `dt` real seconds.
func advance(dt: float) -> void:
	if dt <= 0.0:
		return
	_clock += dt
	if _pending_track != "":
		_pending_in -= dt
		if _pending_in <= 0.0:
			_fire_pending()
	_advance_music(dt)
	_advance_ducks(dt)
	_advance_preview(dt)


# =============================================================================== pure helpers

## Seconds from playback position `pos_s` to the next bar line (bars of `bar_s` seconds).
## 0 when `pos_s` sits on a bar line (within 5 ms).
static func next_bar_delay(pos_s: float, bar_s: float) -> float:
	if bar_s <= 0.0:
		return 0.0
	var rem := fposmod(pos_s, bar_s)
	if rem < 0.005 or bar_s - rem < 0.0005:
		return 0.0
	return bar_s - rem


## The track a music state plays with chain section `chain` live.
static func track_for(state: String, chain: int) -> String:
	match state:
		"silence":
			return ""
		"curtain":
			return "curtain"
		"results":
			return "results"
		"chase":
			return "chase"
		"sneak", "suspense":
			return "chain_%d" % chain if chain > 0 else "sneak"
	return ""


## Index into a bank of `count` files avoiding `last` (−1 = none) given a random `roll` ≥ 0.
static func pick_index(count: int, last: int, roll: int) -> int:
	if count <= 1:
		return 0
	if last < 0 or last >= count:
		return roll % count
	var i := roll % (count - 1)
	return i + 1 if i >= last else i


## Member index of step `step` (0 = the first) of a cycle of `count` members: "pingpong" walks
## up and back down without repeating the ends (0 1 … n−1 n−2 … 1 0 1 …), anything else wraps.
static func cycle_index(step: int, count: int, mode: String) -> int:
	if count <= 1:
		return 0
	if mode == "pingpong":
		var period := 2 * count - 2
		var k := step % period
		return k if k < count else period - k
	return step % count


## Seconds per bar for a tempo.
static func bar_seconds(bpm: float, beats_per_bar: int) -> float:
	return 60.0 / bpm * beats_per_bar if bpm > 0.0 else 0.0


# =============================================================================== internals

func _make_player(n: String, bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = n
	p.bus = bus
	add_child(p)
	return p


func _ensure_buses() -> void:
	for b in BUSES:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, b)
			AudioServer.set_bus_send(idx, "Master")
	for i in SFX_PAN_BUSES.size():
		_ensure_pan_bus(SFX_PAN_BUSES[i], "SFX", SFX_PAN_VALUES[i])
	for i in VOICE_PAN_BUSES.size():
		_ensure_pan_bus(VOICE_PAN_BUSES[i], "Voice", VOICE_PAN_VALUES[i])


func _ensure_pan_bus(bus: String, parent: String, pan: float) -> void:
	if bus == parent or AudioServer.get_bus_index(bus) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus)
	AudioServer.set_bus_send(idx, parent)
	var fx := AudioEffectPanner.new()
	fx.pan = pan
	AudioServer.add_bus_effect(idx, fx)


func _load_map() -> void:
	if not FileAccess.file_exists(MAP_PATH):
		push_warning("Audio: %s missing — every sound is a no-op" % MAP_PATH)
		return
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(MAP_PATH))
	if not (d is Dictionary):
		push_warning("Audio: %s does not parse" % MAP_PATH)
		return
	var doc: Dictionary = d
	_files = doc.get("files", {}) as Dictionary
	_banks = doc.get("banks", {}) as Dictionary
	_aliases = doc.get("aliases", {}) as Dictionary
	_music = doc.get("music", {}) as Dictionary
	_stems = doc.get("stems", {}) as Dictionary
	_vary = doc.get("vary", {}) as Dictionary
	_cycles = doc.get("cycles", {}) as Dictionary
	_sequences = doc.get("sequences", {}) as Dictionary


## Read the four volume keys from a Settings autoload (soft hook). False when there is none.
func _apply_settings() -> bool:
	if not is_inside_tree():
		return false
	var s := get_node_or_null("/root/Settings")
	if s == null:
		return false
	if s.has_signal("changed") and not s.is_connected("changed", _on_setting_changed):
		s.connect("changed", _on_setting_changed)
	if s.has_method("get_value"):
		for bus: String in SETTING_KEYS:
			var v: Variant = s.call("get_value", String(SETTING_KEYS[bus]), 1.0)
			if v is float or v is int:
				set_bus_volume(bus, float(v))
		for key: String in ["voice_style", "crowd_style"]:
			_apply_style(key, s.call("get_value", key, voice_style if key == "voice_style" else crowd_style))
	return true


func _on_setting_changed(key: String, value: Variant) -> void:
	if key == "voice_style" or key == "crowd_style":
		_apply_style(key, value)
		return
	if not (value is float or value is int):
		return
	for bus: String in SETTING_KEYS:
		if String(SETTING_KEYS[bus]) == key:
			set_bus_volume(bus, float(value))


## Settings `voice_style` / `crowd_style` → the style switches (unknown values are ignored).
func _apply_style(key: String, value: Variant) -> void:
	if not (value is String or value is StringName):
		return
	var v := String(value)
	if key == "voice_style" and VOICE_STYLES.has(v):
		set_voice_style(v)
	elif key == "crowd_style" and CROWD_STYLES.has(v):
		set_crowd_style(v)


func _apply_bus(bus: String) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	var lin := float(_bus_linear.get(bus, 1.0))
	var extra := 0.0
	if bus == "Music":
		extra = _music_duck_db
	elif bus == "Crowd":
		extra = _crowd_duck_db
	AudioServer.set_bus_mute(idx, lin <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(lin, 0.0001)) + extra)


## Follow aliases to the first file or bank id (the id itself when unknown).
func _canonical(id: String) -> String:
	var name := id
	for _i in 8:
		if _files.has(name) or _banks.has(name) or not _aliases.has(name):
			return name
		name = String(_aliases[name])
	return name


## resolve_files() after the voice / crowd style and squeaky mappings.
func _styled_files(id: String) -> PackedStringArray:
	return _styled_files_as(_canonical(id), voice_style, crowd_style, voice_squeaky)


## resolve_files() of canonical id `c` in the given styles.
func _styled_files_as(c: String, vstyle: String, cstyle: String, squeaky: bool) -> PackedStringArray:
	if c.begins_with("vo_bellows_") and not c.begins_with("vo_bellows_tuba_") \
			and not c.begins_with("vo_bellows_squeaky_"):
		var rest := c.substr(11)
		if squeaky and vstyle == "formant":
			var sq := resolve_files("vo_bellows_squeaky_" + rest)
			if not sq.is_empty():
				return sq
		if vstyle == "tuba":
			var tb := resolve_files("vo_bellows_tuba_" + rest)
			if not tb.is_empty():
				return tb
	elif c.begins_with("crowd_") and not c.begins_with("crowd_fb_") and cstyle == "fallback":
		var fb := resolve_files("crowd_fb_" + c.substr(6))
		if not fb.is_empty():
			return fb
	return resolve_files(c)


func _has_squeaky_variant(id: String) -> bool:
	var c := _canonical(id)
	return c.begins_with("vo_bellows_") and not resolve_files("vo_bellows_squeaky_" + c.substr(11)).is_empty()


## Pick a file from `files` (the members of `key`) avoiding the last pick for that key.
func _pick(key: String, files: PackedStringArray) -> String:
	if files.size() == 1:
		_last_pick[key] = files[0]
		return files[0]
	var last := files.find(String(_last_pick.get(key, "")))
	var f := files[pick_index(files.size(), last, _rng.randi() & 0x7FFFFFFF)]
	_last_pick[key] = f
	return f


## The next member of cycle `key` (a new run starts after `reset_s` without a step).
func _cycle_next(key: String) -> String:
	var c: Dictionary = _cycles[key]
	var members: Array = c.get("members", [])
	if members.is_empty():
		return ""
	var step := int(_cycle_step.get(key, -1)) + 1
	if _clock - float(_cycle_last.get(key, -1000.0)) > float(c.get("reset_s", 0.8)):
		step = 0
	_cycle_step[key] = step
	_cycle_last[key] = _clock
	var f := String(members[cycle_index(step, members.size(), String(c.get("mode", "wrap")))])
	_last_pick[key] = f
	return f


func _play_preview_file(fid: String) -> void:
	var stream := _stream(fid)
	if stream == null:
		_warn(fid)
		return
	var p := _preview[_preview_next]
	_preview_next = (_preview_next + 1) % PREVIEW_POOL
	p.stop()
	p.stream = stream
	var bus := String((_files.get(fid, {}) as Dictionary).get("bus", "Voice"))
	p.bus = bus if BUSES.has(bus) else "Voice"
	p.volume_db = 0.0
	p.pitch_scale = 1.0
	p.play()


func _advance_preview(dt: float) -> void:
	for i in PREVIEW_QUEUE:
		if _preview_q_t[i] < 0.0:
			continue
		_preview_q_t[i] -= dt
		if _preview_q_t[i] <= 0.0:
			_preview_q_t[i] = -1.0
			var fid := _preview_q_file[i]
			_preview_q_file[i] = ""
			if fid != "":
				_play_preview_file(fid)


func _stream(fid: String) -> AudioStream:
	if _streams.has(fid):
		return _streams[fid]
	var s: AudioStream = null
	var e: Variant = _files.get(fid)
	if e is Dictionary:
		var path := AUDIO_ROOT + String((e as Dictionary).get("path", ""))
		if ResourceLoader.exists(path):
			s = load(path) as AudioStream
	if s is AudioStreamWAV and _music.has(fid):
		var w := s as AudioStreamWAV
		var loop := bool((_music[fid] as Dictionary).get("loop", false))
		if loop and w.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			w.loop_end = int(round(w.get_length() * w.mix_rate))
		elif not loop:
			w.loop_mode = AudioStreamWAV.LOOP_DISABLED
	_streams[fid] = s
	return s


func _length(fid: String) -> float:
	var e: Variant = _files.get(fid)
	if e is Dictionary and (e as Dictionary).has("len"):
		return float((e as Dictionary)["len"])
	var s := _stream(fid)
	return s.get_length() if s != null else 0.0


func _warn(id: String) -> void:
	if _warned.has(id):
		return
	_warned[id] = true
	if OS.is_debug_build():
		push_warning("Audio: unknown id '%s' (silent)" % id)


## Index of a free player in `pool`, else of the one started longest ago (voice stealing).
func _take_oldest(pool: Array[AudioStreamPlayer], started: PackedFloat64Array) -> int:
	var oldest := 0
	for i in pool.size():
		if not pool[i].playing:
			return i
		if started[i] < started[oldest]:
			oldest = i
	return oldest


func _pan_bus(buses: PackedStringArray, values: PackedFloat32Array, pan: float) -> String:
	if absf(pan) < 0.2:
		return buses[buses.size() >> 1]
	var best := 0
	for i in values.size():
		if absf(values[i] - pan) < absf(values[best] - pan):
			best = i
	return buses[best]


func _play_voice_file(fid: String, vol_db: float, pan: float, pitch: float) -> void:
	var stream := _stream(fid)
	if stream == null:
		_warn(fid)
		return
	var vi := _take_oldest(_voice, _voice_started)
	_voice_started[vi] = _clock
	var p := _voice[vi]
	p.stop()
	p.stream = stream
	p.bus = _pan_bus(VOICE_PAN_BUSES, VOICE_PAN_VALUES, pan)
	p.volume_db = vol_db
	p.pitch_scale = clampf(pitch, 0.25, 4.0)
	p.play()
	_voice_last_file = fid
	_voice_until = maxf(_voice_until, _clock + _length(fid) / maxf(pitch, 0.25))


func _play_crowd_file(fid: String, prio: int, vol_db: float) -> void:
	var stream := _stream(fid)
	if stream == null:
		_warn(fid)
		return
	var idx := -1
	for i in CROWD_POOL:
		if not _crowd_players[i].playing or _clock >= _crowd_ends[i]:
			idx = i
			break
	if idx < 0:
		var low := 0
		for i in CROWD_POOL:
			if _crowd_prio[i] < _crowd_prio[low] or (_crowd_prio[i] == _crowd_prio[low]
					and _crowd_started[i] < _crowd_started[low]):
				low = i
		if _crowd_prio[low] > prio:
			return   # never cut a bigger laugh with a smaller one
		idx = low
	var p := _crowd_players[idx]
	p.stop()
	p.stream = stream
	p.volume_db = vol_db
	p.play()
	_crowd_started[idx] = _clock
	_crowd_prio[idx] = prio
	_crowd_ends[idx] = _clock + _length(fid)


# --- music ---------------------------------------------------------------------------------

func _bar_length(track: String) -> float:
	var fid := String(TRACK_FILES.get(track, ""))
	var m: Variant = _music.get(fid)
	if not (m is Dictionary):
		return 0.0
	var md := m as Dictionary
	var spb := float(md.get("spb", 0))
	if spb > 0.0:
		return spb * float(md.get("beats_per_bar", 4)) / SR
	return bar_seconds(float(md.get("bpm", 0.0)), int(md.get("beats_per_bar", 4)))


func _music_position() -> float:
	if debug_music_pos >= 0.0:
		return debug_music_pos
	var p := _mus[_active]
	if not p.playing:
		return 0.0
	return p.get_playback_position() + AudioServer.get_time_since_last_mix()


func _fire_pending() -> void:
	var t := _pending_track
	_pending_track = ""
	_pending_in = -1.0
	if t != _track:
		_start_track(t, FADE_BAR_IN_S, FADE_BAR_OUT_S)


func _track_stream(track: String) -> AudioStream:
	if track == "sneak" and _stems.has("sneak"):
		if _sync == null:
			var names: Array = _stems["sneak"]
			var subs: Array[AudioStream] = []
			for n in names:
				var st := _stream(String(n))
				if st == null:
					subs.clear()
					break
				subs.append(st)
			if not subs.is_empty():
				_sync = AudioStreamSynchronized.new()
				_sync.stream_count = subs.size()
				for i in subs.size():
					_sync.set_sync_stream(i, subs[i])
					_sync.set_sync_stream_volume(i, 0.0 if i == 0 else SILENT_DB)
		if _sync != null:
			return _sync
	var fid := String(TRACK_FILES.get(track, ""))
	return _stream(fid) if fid != "" else null


func _start_track(track: String, fade_in: float, fade_out: float) -> void:
	var old := _active
	if _mgain[old] > 0.0 or _mus[old].playing:
		_mtarget[old] = 0.0
		_mrate[old] = 1.0 / maxf(fade_out, 0.01)
	_track = track
	if track == "":
		music_changed.emit("")
		return
	var stream := _track_stream(track)
	var nxt := 1 - old
	var p := _mus[nxt]
	p.stop()
	if stream == null:
		_mtrack[nxt] = ""
		_warn("music:" + track)
		music_changed.emit(track)
		return
	p.stream = stream
	_mtrack[nxt] = track
	_mgain[nxt] = 0.0
	_mtarget[nxt] = 1.0
	_mrate[nxt] = 1.0 / maxf(fade_in, 0.01)
	p.volume_db = SILENT_DB
	p.play()
	_active = nxt
	if track == "sneak":
		_suspense_gain = _suspense_target
		_apply_suspense()
	music_changed.emit(track)


func _advance_music(dt: float) -> void:
	for i in 2:
		var g := _mgain[i]
		var t := _mtarget[i]
		if g != t:
			g = minf(t, g + dt * _mrate[i]) if t > g else maxf(t, g - dt * _mrate[i])
			_mgain[i] = g
			if g <= 0.0 and t <= 0.0:
				_mus[i].stop()
				_mtrack[i] = ""
		if _mus[i].playing or g > 0.0:
			_mus[i].volume_db = SILENT_DB if g <= 0.001 else linear_to_db(g)
	# a finished one-shot (the curtain) leaves silence behind
	if _track != "" and _mtrack[_active] == _track and not _mus[_active].playing and _mtarget[_active] > 0.0 \
			and _is_one_shot(_track) and _mgain[_active] >= 1.0:
		_track = ""
		_mtarget[_active] = 0.0
		music_changed.emit("")
	if _suspense_gain != _suspense_target:
		var step := dt / SUSPENSE_FADE_S
		_suspense_gain = minf(_suspense_target, _suspense_gain + step) if _suspense_target > _suspense_gain \
				else maxf(_suspense_target, _suspense_gain - step)
		_apply_suspense()


func _is_one_shot(track: String) -> bool:
	var m: Variant = _music.get(String(TRACK_FILES.get(track, "")))
	return m is Dictionary and not bool((m as Dictionary).get("loop", true))


func _apply_suspense() -> void:
	if _sync == null or _sync.stream_count < 2:
		return
	_sync.set_sync_stream_volume(1, SILENT_DB if _suspense_gain <= 0.001 else linear_to_db(_suspense_gain))
	_sync.set_sync_stream_volume(0, SUSPENSE_SNEAK_DB * _suspense_gain)


func _advance_ducks(dt: float) -> void:
	var want_m := (STING_DUCK_DB if _clock < _sting_until else 0.0) + (PAUSE_DUCK_DB if _paused else 0.0)
	var want_c := CROWD_DUCK_DB if _clock < _voice_until else 0.0
	var m := _step_db(_music_duck_db, want_m, dt)
	var c := _step_db(_crowd_duck_db, want_c, dt)
	if m != _music_duck_db:
		_music_duck_db = m
		_apply_bus("Music")
	if c != _crowd_duck_db:
		_crowd_duck_db = c
		_apply_bus("Crowd")


static func _step_db(cur: float, want: float, dt: float) -> float:
	if cur == want:
		return cur
	if want < cur:   # ducking down: fast attack
		return maxf(want, cur - absf(STING_DUCK_DB) * dt / DUCK_ATTACK_S)
	return minf(want, cur + absf(STING_DUCK_DB) * dt / DUCK_RELEASE_S)
