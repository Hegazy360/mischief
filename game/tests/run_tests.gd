## Zero-dependency GDScript test runner.
##
## Usage (always through the sandbox scripts, never on the shared project):
##   tools/scripts/test_game.sh <sandbox-name> [-- <filter>... ] [--verbose]
## Discovers res://tests/**/test_*.gd (except test_base.gd and fixtures/), each extending
## TestBase, and runs every method named test_* (optional before_each/after_each).
## Filters are substrings matched against "relative/path.gd::method" (any filter matches).
## Flags: --verbose (list every test), --root=res://dir (discover from another root).
## Exit code 1 if any test fails or any test script fails to load, else 0.
## The runner waits one frame before the first test so every autoload has run _ready().
extends SceneTree

const DEFAULT_ROOT := "res://tests"
const SKIP_DIRS := ["fixtures", "golden", ".godot"]

## Captures script/engine errors raised while a test runs (Godot 4.5+ Logger API).
class ErrorCatcher extends Logger:
	var _mutex := Mutex.new()
	var _errors: Array[String] = []
	var _script_errors: int = 0
	var _engine_errors: int = 0

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == Logger.ERROR_TYPE_WARNING or error_type == Logger.ERROR_TYPE_SHADER:
			return
		_mutex.lock()
		var text := code if rationale == "" else "%s: %s" % [code, rationale]
		if error_type == Logger.ERROR_TYPE_SCRIPT:
			_script_errors += 1
			_errors.append("script error: %s (%s:%d in %s)" % [text, file.get_file(), line, function])
		else:
			_engine_errors += 1
			_errors.append("error: %s (%s:%d in %s) [call allow_errors() if expected]" % [text, file.get_file(), line, function])
		_mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func reset() -> void:
		_mutex.lock()
		_errors.clear()
		_script_errors = 0
		_engine_errors = 0
		_mutex.unlock()

	## Returns [script_errors, engine_errors, messages].
	func take() -> Array:
		_mutex.lock()
		var out := [_script_errors, _engine_errors, _errors.duplicate()]
		_mutex.unlock()
		return out


var _root := DEFAULT_ROOT
var _filters: PackedStringArray = []
var _verbose := false
var _passed := 0
var _failed := 0
var _skipped := 0
var _files := 0
var _failure_lines: PackedStringArray = []
var _catcher: ErrorCatcher = null


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--verbose" or a == "-v":
			_verbose = true
		elif a.begins_with("--root="):
			_root = a.trim_prefix("--root=").trim_suffix("/")
		elif a != "" and not a.begins_with("--"):
			_filters.append(a)
	_run_all()


func _run_all() -> void:
	await process_frame   # let autoloads finish _ready() first
	var t0 := Time.get_ticks_msec()
	_catcher = ErrorCatcher.new()
	OS.add_logger(_catcher)
	var paths := _discover(_root)
	paths.sort()
	print("== Mischief tests: %d files%s ==" % [paths.size(),
		"" if _filters.is_empty() else " (filter: %s)" % ", ".join(_filters)])
	for p in paths:
		await _run_file(p)
	OS.remove_logger(_catcher)
	var ms := Time.get_ticks_msec() - t0
	print("")
	if not _failure_lines.is_empty():
		print("---- FAILURES ----")
		for l in _failure_lines:
			print(l)
		print("")
	var total := _passed + _failed + _skipped
	if total == 0:
		print("WARNING: no tests matched.")
	print("== %s: %d passed, %d failed, %d skipped, %d tests in %d files, %d ms ==" % [
		"FAILED" if _failed > 0 else "OK", _passed, _failed, _skipped, total, _files, ms])
	quit(1 if _failed > 0 else 0)


func _discover(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open(dir)
	if d == null:
		return out
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		var full := "%s/%s" % [dir, name]
		if d.current_is_dir():
			if not name.begins_with(".") and not SKIP_DIRS.has(name):
				out.append_array(_discover(full))
		elif name.begins_with("test_") and name.ends_with(".gd") and name != "test_base.gd":
			out.append(full)
		name = d.get_next()
	d.list_dir_end()
	return out


func _rel(path: String) -> String:
	return path.trim_prefix(_root + "/")


func _matches(id: String) -> bool:
	if _filters.is_empty():
		return true
	for f in _filters:
		if id.contains(f):
			return true
	return false


func _record_failure(id: String, lines: Array) -> void:
	_failed += 1
	_failure_lines.append("FAIL %s" % id)
	for l in lines:
		_failure_lines.append("     %s" % l)


func _run_file(path: String) -> void:
	var rel := _rel(path)
	var script: GDScript = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE) as GDScript
	if script == null or not script.can_instantiate():
		if _matches(rel + "::"):
			_files += 1
			_record_failure(rel, ["script failed to load/parse"])
			print("%s: LOAD FAILED" % rel)
		return
	var methods := _test_methods(script)
	var selected: Array[String] = []
	for m in methods:
		if _matches("%s::%s" % [rel, m]):
			selected.append(m)
	if selected.is_empty():
		return
	var probe: Variant = script.new()
	if not (probe is TestBase):
		print("%s: skipped (does not extend TestBase)" % rel)
		return
	_files += 1
	var f0 := _failed
	var t0 := Time.get_ticks_msec()
	for m in selected:
		await _run_test(script, rel, m)
	var status := "ok" if _failed == f0 else "FAILED"
	print("%s: %s (%d tests, %d ms)" % [rel, status, selected.size(), Time.get_ticks_msec() - t0])


func _test_methods(script: GDScript) -> Array[String]:
	var out: Array[String] = []
	for m in script.get_script_method_list():
		var n: String = m.get("name", "")
		if n.begins_with("test_") and not out.has(n):
			out.append(n)
	return out


func _run_test(script: GDScript, rel: String, method: String) -> void:
	var id := "%s::%s" % [rel, method]
	var inst: TestBase = script.new()
	inst.tree = self
	inst._reset_test_state()
	_catcher.reset()
	var t0 := Time.get_ticks_msec()
	await inst.before_each()
	await inst.call(method)
	await inst.after_each()
	var errs: Array = _catcher.take()
	var lines: Array = []
	lines.append_array(inst._failures)
	var script_errors: int = errs[0]
	var engine_errors: int = errs[1]
	if script_errors > 0 or (engine_errors > 0 and not inst._allow_errors):
		lines.append_array(errs[2])
	var ms := Time.get_ticks_msec() - t0
	if not lines.is_empty():
		_record_failure(id, lines)
		if _verbose:
			print("  FAIL %s (%d ms)" % [method, ms])
	elif inst._skip_reason != "":
		_skipped += 1
		print("  skip %s — %s" % [id, inst._skip_reason])
	else:
		_passed += 1
		if _verbose:
			print("  ok   %s (%d asserts, %d ms)" % [method, inst._assert_count, ms])
