@tool
extends EditorPlugin
## MND Export: adds raw copies of every art SVG the game rasterises at runtime.
##
## Imported files (every .svg) are exported only as their `.import` remap + `.ctex`, and an
## `include_filter` cannot change that for imported resources. But HiResTex / AtlasBuilder
## re-rasterise every rig part, prop, room, FX and UI SVG at 2× from its source (TECH §5.3) and
## read the SVG header for its 1× size; without the source they get nothing (rig atlases come out
## empty on the phone). This plugin puts the source bytes into the pack at the same res:// path
## (FileAccess sees them; `load()` still uses the remap). `_src` / dot folders are skipped.

var _export_plugin: MndRawSvgExport


func _enter_tree() -> void:
	_export_plugin = MndRawSvgExport.new()
	add_export_plugin(_export_plugin)


func _exit_tree() -> void:
	if _export_plugin != null:
		remove_export_plugin(_export_plugin)
	_export_plugin = null


class MndRawSvgExport extends EditorExportPlugin:
	const RAW_DIRS: Array[String] = ["res://art", "res://ui"]

	func _get_name() -> String:
		return "MndRawSvg"

	func _export_begin(_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
		var n := 0
		for p in raw_paths():
			var bytes := FileAccess.get_file_as_bytes(p)
			if bytes.is_empty():
				push_warning("MndRawSvg: %s missing or empty" % p)
				continue
			add_file(p, bytes, false)
			n += 1
		print("MndRawSvg: shipped %d raw SVG sources" % n)

	static func raw_paths() -> PackedStringArray:
		var out := PackedStringArray()
		for d in RAW_DIRS:
			_collect(d, out, 0)
		return out

	static func _collect(d: String, out: PackedStringArray, depth: int) -> void:
		if depth > 6 or not DirAccess.dir_exists_absolute(d):
			return
		for f in DirAccess.get_files_at(d):
			if f.get_extension().to_lower() == "svg":
				out.append(d.path_join(f))
		for sub in DirAccess.get_directories_at(d):
			if not sub.begins_with("_") and not sub.begins_with(".") and sub != "demo":
				_collect(d.path_join(sub), out, depth + 1)
