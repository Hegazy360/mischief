## glTF clip -> Godot `Animation` resource (index R2, r3d-anim §4.1.3). Run headless in a sandbox:
##   NO_IMPORT=1 tools/scripts/sandbox.sh <key> -s res://tools/anim/glb_to_res.gd -- \
##       --in=/abs/build/art3d/anim/hush/loco_walk.glb --out=/abs/game/art3d/anim/hush/loco_walk.res \
##       --clip=hush/loco_walk [--sidecar=/abs/…/loco_walk.json] [--rig-glb=/abs/…/hush.glb] [--lint] [--strict]
##   … -- --batch=/abs/jobs.json   ([{in, out, clip, sidecar, rig_glb}], one run for a whole bake)
## Loads the glb with GLTFDocument (sampled at 60 fps), takes its one Animation and writes a clean one: track paths
## normalised to `Armature/Skeleton3D:<bone>`, tracks of bones the rig does not have dropped, scale tracks kept only
## for extra (non-UAL: prop / FX / jiggle) bones, every rig UAL bone without a track given a 1-key rest track,
## constant tracks collapsed to one key and keys that linear interpolation reproduces (< 0.001° / 0.01 mm) removed,
## `length = frames / 60`, `loop_mode` from the sidecar; `ResourceSaver.save` binary `.res`, uncompressed. The rig's
## rest skeleton (from `--rig-glb`, else the clip's own) must match the clip's within 1 mm / 0.1° (else an error: the
## clip was baked on another skeleton — re-bake). `--lint` runs the 3D animation lint on each result (bake.sh table).
## Prints one `[glb_to_res] {json}` line per clip; exit 1 when any clip failed (or, with --lint, has lint errors).
extends SceneTree

const Lint3D := preload("res://tools/anim/lint3d_rules.gd")
const FPS := 60.0
const ROT_EPS := 0.001            ## degrees
const POS_EPS := 0.00001          ## metres
const REST_POS_TOL := 0.001
const REST_ROT_TOL := 0.1         ## degrees
const SKEL_PATH := "Armature/Skeleton3D"


func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	var jobs: Array = []
	if args.has("batch"):
		var txt := FileAccess.get_file_as_string(String(args["batch"]))
		var parsed: Variant = JSON.parse_string(txt)
		if not (parsed is Array):
			printerr("glb_to_res: --batch must be a JSON array of jobs")
			quit(2)
			return
		jobs = parsed
	elif args.has("in") and args.has("out"):
		jobs = [{"in": args["in"], "out": args["out"], "clip": args.get("clip", ""), "sidecar": args.get("sidecar", ""),
			"rig_glb": args.get("rig-glb", "")}]
	else:
		printerr("usage: glb_to_res.gd -- --in=/abs.glb --out=/abs.res --clip=<id> [--sidecar=] [--rig-glb=] | --batch=/abs.json")
		quit(2)
		return
	var lint := args.has("lint")
	var strict := args.has("strict")
	var failed := 0
	for j in jobs:
		var job: Dictionary = j
		var rep := convert_job(job)
		if bool(rep.get("ok", false)) and lint:
			var findings: Array = Lint3D.lint_paths(String(job.get("sidecar", "")), String(job["out"]), String(job.get("rig_glb", "")))
			if strict:
				Lint3D.make_strict(findings)
			rep["lint_errors"] = Lint3D.error_count(findings)
			var nw := 0
			for fw in findings:
				if String(fw["severity"]) == "warning":
					nw += 1
			rep["lint_warnings"] = nw
			for f in findings:
				print(Lint3D.format(f))
			if int(rep["lint_errors"]) > 0:
				failed += 1
		elif not bool(rep.get("ok", false)):
			failed += 1
		print("[glb_to_res] ", JSON.stringify(rep))
	quit(1 if failed > 0 else 0)


## Load a glb with GLTFDocument at 60 fps; returns the generated scene root (caller frees) or null.
static func load_glb(path: String) -> Node:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	st.bake_fps = FPS
	if doc.append_from_file(path, st) != OK:
		return null
	return doc.generate_scene(st, FPS)


static func _skeleton(root: Node) -> Skeleton3D:
	if root == null:
		return null
	return root.find_child("Skeleton3D", true, false) as Skeleton3D


## Rest transforms {bone: Transform3D} of a skeleton.
static func rests(sk: Skeleton3D) -> Dictionary:
	var out := {}
	for i in sk.get_bone_count():
		out[sk.get_bone_name(i)] = sk.get_bone_rest(i)
	return out


## One conversion job {in, out, clip, sidecar?, rig_glb?} -> a report Dictionary (ok, error, tracks, keys, bytes …).
static func convert_job(job: Dictionary) -> Dictionary:
	var rep := {"clip": String(job.get("clip", "")), "ok": false}
	var src := load_glb(String(job["in"]))
	if src == null:
		rep["error"] = "cannot load %s" % job["in"]
		return rep
	var ap := src.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var sk := _skeleton(src)
	if ap == null or sk == null or ap.get_animation_list().is_empty():
		rep["error"] = "no AnimationPlayer / Skeleton3D / animation in %s" % job["in"]
		src.free()
		return rep
	var anim_in := ap.get_animation(ap.get_animation_list()[0])
	var rig_rest := rests(sk)
	var rig_glb := String(job.get("rig_glb", ""))
	if rig_glb != "":
		var rig := load_glb(rig_glb)
		var rsk := _skeleton(rig)
		if rsk == null:
			rep["error"] = "cannot load the rig skeleton %s" % rig_glb
			src.free()
			if rig != null:
				rig.free()
			return rep
		var own := rig_rest
		rig_rest = rests(rsk)
		rig.free()
		var worst_p := 0.0
		var worst_r := 0.0
		var wn := ""
		for b in rig_rest:
			if not own.has(b):
				continue
			var ra: Transform3D = own[b]
			var rr: Transform3D = rig_rest[b]
			var dp := (ra.origin - rr.origin).length()
			var dr := rad_to_deg(ra.basis.get_rotation_quaternion().angle_to(rr.basis.get_rotation_quaternion()))
			if dp > worst_p or dr > worst_r:
				wn = b
			worst_p = maxf(worst_p, dp)
			worst_r = maxf(worst_r, dr)
		rep["rest_diff"] = {"m": snappedf(worst_p, 0.00001), "deg": snappedf(worst_r, 0.001), "bone": wn}
		if worst_p > REST_POS_TOL or worst_r > REST_ROT_TOL:
			rep["error"] = "clip baked on another skeleton: rest differs by %.4f m / %.3f° at %s (re-bake on the current rig)" % [worst_p, worst_r, wn]
			src.free()
			return rep
	var side: Dictionary = {}
	var sc_path := String(job.get("sidecar", ""))
	if sc_path != "" and FileAccess.file_exists(sc_path):
		var p: Variant = JSON.parse_string(FileAccess.get_file_as_string(sc_path))
		if p is Dictionary:
			side = p
	var frames := int(side.get("length", roundi(anim_in.length * FPS)))
	var loop := bool(side.get("loop", false))
	var out := Animation.new()
	out.resource_name = rep["clip"]
	out.length = float(frames) / FPS
	out.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	out.step = 1.0 / FPS
	var ual := Lint3D.ual_bones()
	var have_rot := {}
	var dropped := PackedStringArray()
	var keys := 0
	var anim_root := ap.get_node(ap.root_node)
	var skel_prefix := String(anim_root.get_path_to(sk)) if anim_root != null else SKEL_PATH
	for t in anim_in.get_track_count():
		var tt := anim_in.track_get_type(t)
		var path := String(anim_in.track_get_path(t))
		var bone := path.get_slice(":", 1)
		if not path.contains(":") or path.get_slice(":", 0) != skel_prefix:
			dropped.append(path)
			continue
		if not rig_rest.has(bone):
			dropped.append(path)
			continue
		if tt == Animation.TYPE_SCALE_3D and ual.has(bone):
			continue
		if tt != Animation.TYPE_ROTATION_3D and tt != Animation.TYPE_POSITION_3D and tt != Animation.TYPE_SCALE_3D:
			dropped.append(path)
			continue
		var nt := out.add_track(tt)
		out.track_set_path(nt, NodePath("%s:%s" % [SKEL_PATH, bone]))
		out.track_set_interpolation_type(nt, Animation.INTERPOLATION_LINEAR)
		keys += _copy_reduced(anim_in, t, out, nt, tt, frames)
		if tt == Animation.TYPE_ROTATION_3D:
			have_rot[bone] = true
	for b in rig_rest:
		if ual.has(b) and not have_rot.has(b):
			var nt2 := out.add_track(Animation.TYPE_ROTATION_3D)
			out.track_set_path(nt2, NodePath("%s:%s" % [SKEL_PATH, b]))
			var rr2: Transform3D = rig_rest[b]
			out.rotation_track_insert_key(nt2, 0.0, rr2.basis.get_rotation_quaternion())
			keys += 1
	src.free()
	var dst := String(job["out"])
	DirAccess.make_dir_recursive_absolute(dst.get_base_dir())
	var err := ResourceSaver.save(out, dst)
	if err != OK:
		rep["error"] = "ResourceSaver.save failed (%d) for %s" % [err, dst]
		return rep
	rep["ok"] = true
	rep["frames"] = frames
	rep["loop"] = loop
	rep["tracks"] = out.get_track_count()
	rep["keys"] = keys
	rep["dropped"] = dropped.size()
	rep["bytes"] = FileAccess.open(dst, FileAccess.READ).get_length() if FileAccess.file_exists(dst) else -1
	return rep


## Copy track t of `a` into track nt of `b`, clipped to [0, frames/60], dropping keys that linear interpolation
## reproduces; returns the number of keys written.
static func _copy_reduced(a: Animation, t: int, b: Animation, nt: int, tt: int, frames: int) -> int:
	var n := a.track_get_key_count(t)
	var times: Array[float] = []
	var vals: Array = []
	var end_t := float(frames) / FPS + 0.0005
	for k in n:
		var tm := a.track_get_key_time(t, k)
		if tm > end_t:
			break
		times.append(snappedf(tm, 1.0 / FPS))
		vals.append(a.track_get_key_value(t, k))
	if times.is_empty():
		return 0
	# sign continuity for quaternions
	if tt == Animation.TYPE_ROTATION_3D:
		for k in range(1, vals.size()):
			var q0: Quaternion = vals[k - 1]
			var q1: Quaternion = vals[k]
			if q0.dot(q1) < 0.0:
				vals[k] = -q1
	var keep := PackedInt32Array([0])
	var i := 0
	while i < times.size() - 1:
		var j := i + 1
		while j + 1 < times.size() and _linear_ok(tt, times, vals, i, j + 1):
			j += 1
		keep.append(j)
		i = j
	if keep.size() == 2 and _same(tt, vals[0], vals[vals.size() - 1]) and _linear_ok(tt, times, vals, 0, times.size() - 1):
		keep = PackedInt32Array([0])
	for k2 in keep:
		match tt:
			Animation.TYPE_ROTATION_3D:
				b.rotation_track_insert_key(nt, times[k2], (vals[k2] as Quaternion).normalized())
			Animation.TYPE_POSITION_3D:
				b.position_track_insert_key(nt, times[k2], vals[k2])
			Animation.TYPE_SCALE_3D:
				b.scale_track_insert_key(nt, times[k2], vals[k2])
	return keep.size()


static func _same(tt: int, a: Variant, b: Variant) -> bool:
	if tt == Animation.TYPE_ROTATION_3D:
		return rad_to_deg((a as Quaternion).angle_to(b as Quaternion)) < ROT_EPS
	return ((a as Vector3) - (b as Vector3)).length() < POS_EPS


## True when every key strictly between i and j lies on the linear (slerp) interpolation of keys i and j.
static func _linear_ok(tt: int, times: Array[float], vals: Array, i: int, j: int) -> bool:
	var t0 := times[i]
	var t1 := times[j]
	for k in range(i + 1, j):
		var u := (times[k] - t0) / maxf(1e-9, t1 - t0)
		if tt == Animation.TYPE_ROTATION_3D:
			var q := (vals[i] as Quaternion).slerp(vals[j] as Quaternion, u)
			if rad_to_deg(q.angle_to(vals[k] as Quaternion)) > ROT_EPS:
				return false
		else:
			var v := (vals[i] as Vector3).lerp(vals[j] as Vector3, u)
			if (v - (vals[k] as Vector3)).length() > POS_EPS:
				return false
	return true
