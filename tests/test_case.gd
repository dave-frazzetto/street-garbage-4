class_name TestCase
extends Node
## Tiny test harness. Subclasses define test_* methods; results print and the process exits with 0 or 1.
## A run without the final "DONE" line is a failure.

var _failures: int = 0
var _checks: int = 0
var _current: String = ""


func check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("  FAIL [%s] %s" % [_current, message])


func check_eq(actual: Variant, expected: Variant, message: String) -> void:
	var ok: bool = actual == expected
	if typeof(actual) == TYPE_FLOAT or typeof(expected) == TYPE_FLOAT:
		ok = is_equal_approx(float(actual), float(expected))
	check(ok, "%s (expected %s, got %s)" % [message, str(expected), str(actual)])


## Runs every method starting with test_ (awaiting coroutines), then quits.
func run_all() -> void:
	var started: int = Time.get_ticks_msec()
	for m: Dictionary in get_method_list():
		var method_name: String = m["name"]
		if method_name.begins_with("test_"):
			_current = method_name
			print("- ", method_name)
			await call(method_name)
	var elapsed: float = (Time.get_ticks_msec() - started) / 1000.0
	if _failures == 0:
		print("DONE: %s passed (%d checks, %.1fs)" % [name, _checks, elapsed])
	else:
		printerr("DONE: %s FAILED %d of %d checks (%.1fs)" % [name, _failures, _checks, elapsed])
	get_tree().quit(1 if _failures > 0 else 0)


func wait_frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func wait_seconds(s: float) -> void:
	await get_tree().create_timer(s, true, true).timeout
