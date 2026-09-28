class_name TestErrorCatcher
extends Logger
## Collects engine and script errors raised while a test runs.
##
## GDScript doesn't throw: a script error prints a message and abandons the
## function it happened in. Without this, a test that blew up after its
## first passing check would be reported as a pass.

var _mutex := Mutex.new()
var _errors: Array[String] = []


## Returns the errors seen since the last call and forgets them.
func take_errors() -> Array[String]:
	_mutex.lock()
	var taken := _errors
	_errors = []
	_mutex.unlock()
	return taken


# Loggers can be called from any thread, hence the mutex.
func _log_error(
	function: String,
	file: String,
	line: int,
	code: String,
	rationale: String,
	_editor_notify: bool,
	error_type: int,
	_script_backtraces: Array[ScriptBacktrace]
) -> void:
	if error_type == ERROR_TYPE_WARNING:
		return
	var description := rationale if not rationale.is_empty() else code
	_mutex.lock()
	_errors.append("%s (%s:%d in %s)" % [description, file, line, function])
	_mutex.unlock()
