## E2eLogger — counts script / engine errors raised while an e2e scenario runs (Godot 4.5+ Logger API,
## the same catcher as tests/run_tests.gd). Warnings are ignored.
class_name E2eLogger
extends Logger

var _mutex := Mutex.new()
var _errors: Array = []
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
	else:
		_engine_errors += 1
	if _errors.size() < 50:
		_errors.append("%s (%s:%d in %s)" % [text, file.get_file(), line, function])
	_mutex.unlock()


func _log_message(_message: String, _error: bool) -> void:
	pass


## [script_errors, engine_errors, messages]
func take() -> Array:
	_mutex.lock()
	var out := [_script_errors, _engine_errors, _errors.duplicate()]
	_mutex.unlock()
	return out
