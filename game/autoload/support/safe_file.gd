## SafeFile — crash-safe writes for small user:// state files (settings, save).
##
## Godot only safe-saves inside the editor, so a kill during ConfigFile.save / store_string
## leaves a torn file. Every write goes to `<path>.tmp` first, is flushed, then renamed over
## `<path>`; the previous good copy is kept as `<path>.bak` and the loaders fall back to it.
class_name SafeFile
extends RefCounted


## Write `text` to `path` crash-safely. Returns true on success.
static func write_text(path: String, text: String) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.flush()
	f.close()
	return _commit(tmp, path)


## ConfigFile.save via temp + rename.
static func save_config(cfg: ConfigFile, path: String) -> Error:
	var tmp := path + ".tmp"
	var err := cfg.save(tmp)
	if err != OK:
		return err
	return OK if _commit(tmp, path) else ERR_FILE_CANT_WRITE


## Load `path` into `cfg`, falling back to `<path>.bak` when the main file is missing or
## unreadable. Returns the error of the last attempt.
static func load_config(cfg: ConfigFile, path: String) -> Error:
	var err: Error = ERR_FILE_NOT_FOUND
	for p in [path, path + ".bak"]:
		if not FileAccess.file_exists(p):
			continue
		cfg.clear()
		err = cfg.load(p)
		if err == OK:
			return OK
	return err


## Text of `path` ("" when missing).
static func read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path)


## Delete `path` with its temp and backup copies.
static func remove(path: String) -> void:
	for p in [path, path + ".tmp", path + ".bak"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


static func _commit(tmp: String, path: String) -> bool:
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, path + ".bak")
	if DirAccess.rename_absolute(tmp, path) == OK:
		return true
	# rename over an existing file can fail on some platforms: remove, then rename
	DirAccess.remove_absolute(path)
	return DirAccess.rename_absolute(tmp, path) == OK
