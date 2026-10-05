class_name ErrorTrap extends Logger
## Every error the engine reports while a driver runs - OS.add_logger() it
## first thing, and check `errors` is empty last. A script error stops only the
## function it happens in, so without this a drive sails on past one with every
## check still passing: a new game's toolkit, opened from its first calendar,
## did exactly that.

var errors: Array[String] = []
var _lock := Mutex.new()

func _log_error(function: String, file: String, line: int, code: String,
		rationale: String, _editor_notify: bool, error_type: int,
		_script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type == ERROR_TYPE_WARNING:
		return
	_lock.lock()
	errors.append("%s at %s:%d in %s()" % [rationale if rationale != "" else code,
		file.get_file(), line, function])
	_lock.unlock()
