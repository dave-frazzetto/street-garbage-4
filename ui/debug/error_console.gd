class_name ErrorConsole
extends CanvasLayer
## Shows engine and script errors on screen, so problems on devices without a dev console (phones in a browser)
## can be read off a screenshot. Enabled on web builds by default; hidden until the first error arrives.

## Show on every platform, not only on the web (tests, debugging).
@export var always_enabled: bool = false
@export_range(1, 50) var max_lines: int = 12

@onready var _label: Label = %Text
@onready var _panel: Control = %Panel

var _lines: PackedStringArray = []
var _logger: ConsoleLogger


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel.visible = false
	if always_enabled or OS.has_feature("web"):
		_logger = ConsoleLogger.new()
		_logger.console = weakref(self)
		OS.add_logger(_logger)


func _exit_tree() -> void:
	if _logger != null:
		OS.remove_logger(_logger)
		_logger = null


## Adds a line (also used for non-error diagnostics, e.g. which graphics profile is active).
func add_line(text: String) -> void:
	_lines.append(text)
	while _lines.size() > max_lines:
		_lines.remove_at(0)
	_label.text = "\n".join(_lines)
	_panel.visible = true


func line_count() -> int:
	return _lines.size()


## Forwards engine log calls to the console. May be called from any thread, so it defers to the main thread.
class ConsoleLogger extends Logger:
	var console: WeakRef

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		var kind: String = "WARNING" if error_type == ERROR_TYPE_WARNING else "ERROR"
		var what: String = rationale if rationale != "" else code
		_post("%s: %s (%s:%d %s)" % [kind, what, file.get_file(), line, function])

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func _post(text: String) -> void:
		var target: ErrorConsole = console.get_ref() as ErrorConsole if console != null else null
		if target != null:
			target.add_line.call_deferred(text)
