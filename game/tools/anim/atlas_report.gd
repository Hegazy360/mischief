## Atlas report — texture memory of a rig's atlases (s2-rig §4.3): the base set RigPlayer
## builds at setup and every residue look page built on demand, at an art scale.
##   tools/scripts/sandbox.sh <sb> -s res://tools/anim/atlas_report.gd -- --rig=bellows [--scale=2] [--skin=pip]
## Prints pages, MP and MB (RGBA8, + a third for mipmaps when AtlasBuilder.mipmaps) per set.
extends SceneTree


func _initialize() -> void:
	var rig_id := "bellows"
	var scale := 2.0
	var skin := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--rig="):
			rig_id = a.substr(6)
		elif a.begins_with("--scale="):
			scale = float(a.substr(8))
		elif a.begins_with("--skin="):
			skin = a.substr(7)
	var r := RigDef.for_id(rig_id)
	if r == null:
		printerr("no rig %s" % rig_id)
		quit(1)
		return
	var all := r.all_texture_paths(skin)
	var base := r.base_texture_paths(skin)
	print("[atlas] %s%s at %.1f×: %d textures, base %d, look-only %d" % [rig_id, (":" + skin) if skin != "" else "", scale, all.size(), base.size(), all.size() - base.size()])
	_line("all (Stage 1)", AtlasBuilder.build("report:all", all, scale, {}, r.core_texture_paths(skin).size()))
	_line("base (setup)", AtlasBuilder.build("report:base", base, scale, {}, r.base_core_count(skin)))
	var kinds := PackedStringArray(r.residues.keys())
	kinds.sort()
	for k in kinds:
		var lp := r.look_texture_paths(k, skin)
		if lp.is_empty():
			print("  %-26s (no extra textures)" % k)
			continue
		_line("look %s" % k, AtlasBuilder.build("report:look:" + k, lp, scale))
	quit(0)


func _line(label: String, s: AtlasSet) -> void:
	var px := s.page_px()
	var mb := float(px) * 4.0 / 1048576.0 * (4.0 / 3.0 if AtlasBuilder.mipmaps else 1.0)
	var sizes := PackedStringArray()
	for ps in s.page_sizes:
		sizes.append("%dx%d" % [ps.x, ps.y])
	print("  %-26s %d page(s) [%s], %.2f MP, %.1f MB%s, %.0f %% packed" % [label, s.pages.size(), ", ".join(sizes), float(px) / 1.0e6,
		mb, " (mipmaps)" if AtlasBuilder.mipmaps else "", s.pack_ratio() * 100.0])
