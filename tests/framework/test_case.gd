class_name TestCase
extends Node
## Base class for a headless test script.
##
## Put a script named `test_*.gd` anywhere under `res://tests/`, extend
## TestCase, and give it methods whose names start with `test_`. The runner
## (tests/test_runner.tscn) adds the script to the scene tree, so tests can
## create nodes, await frames, and use autoloads exactly like game code.
##
## Checks record a failure and carry on rather than aborting, so one run
## reports every broken expectation in a test instead of only the first.

## Failure messages recorded by the test that is currently running.
var failures: Array[String] = []
## Number of checks the running test has made. A test that makes none fails,
## which catches tests that stopped early because of a script error.
var checks: int = 0
## Set to true inside a test that deliberately triggers engine errors.
var allow_errors: bool = false


## Called before every test method.
func before_each() -> void:
	pass


## Called after every test method, even one that failed.
func after_each() -> void:
	pass


func reset_state() -> void:
	failures = []
	checks = 0
	allow_errors = false


func fail(message: String) -> void:
	checks += 1
	failures.append(message)


func assert_true(condition: bool, message: String = "") -> void:
	_check(condition, "expected true", message)


func assert_false(condition: bool, message: String = "") -> void:
	_check(not condition, "expected false", message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	_check(_same(actual, expected), "expected %s, got %s" % [_show(expected), _show(actual)], message)


func assert_ne(actual: Variant, unexpected: Variant, message: String = "") -> void:
	_check(not _same(actual, unexpected), "expected anything but %s" % [_show(unexpected)], message)


func assert_almost_eq(actual: float, expected: float, tolerance: float = 1e-6, message: String = "") -> void:
	_check(
		absf(actual - expected) <= tolerance,
		"expected %s ± %s, got %s" % [expected, tolerance, actual],
		message
	)


func assert_gt(actual: Variant, limit: Variant, message: String = "") -> void:
	_check(actual > limit, "expected %s > %s" % [_show(actual), _show(limit)], message)


func assert_lt(actual: Variant, limit: Variant, message: String = "") -> void:
	_check(actual < limit, "expected %s < %s" % [_show(actual), _show(limit)], message)


func assert_between(actual: float, low: float, high: float, message: String = "") -> void:
	_check(
		actual >= low and actual <= high,
		"expected %s within [%s, %s]" % [actual, low, high],
		message
	)


func assert_null(actual: Variant, message: String = "") -> void:
	_check(actual == null, "expected null, got %s" % [_show(actual)], message)


func assert_not_null(actual: Variant, message: String = "") -> void:
	_check(actual != null, "expected a value, got null", message)


## Adds `node` to the tree under this test and frees it when the test ends.
func add_managed(node: Node) -> Node:
	add_child(node)
	return node


## Throws away the campaign progress the game has, in memory and on disk,
## as if it had never been played. The runner has already pointed the game
## at a save file of the tests' own.
func forget_progress() -> void:
	Session.clear()
	Session.save = null
	DirAccess.remove_absolute(Session.save_path)


## Throws away what has been chosen in the options, in memory and on disk,
## which makes the game as loud as it is before anything is chosen.
## The runner has already pointed the game at a file of the tests' own.
func forget_settings() -> void:
	DirAccess.remove_absolute(Settings.path)
	Settings.reset()
	StrokePace.settle_now()


## Frees every node the test added to itself.
func free_managed() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()


func _check(passed: bool, reason: String, message: String) -> void:
	checks += 1
	if passed:
		return
	failures.append(reason if message.is_empty() else "%s (%s)" % [message, reason])


## `==` raises a script error when the operand types can't be compared, so
## mismatched types are reported as "not equal" before it gets that far.
static func _same(a: Variant, b: Variant) -> bool:
	var type_a := typeof(a)
	var type_b := typeof(b)
	if type_a != type_b:
		var numbers := [TYPE_INT, TYPE_FLOAT]
		var strings := [TYPE_STRING, TYPE_STRING_NAME]
		var compatible := (type_a in numbers and type_b in numbers) \
			or (type_a in strings and type_b in strings)
		if not compatible:
			return false
	return a == b


static func _show(value: Variant) -> String:
	if value is String or value is StringName:
		return "\"%s\"" % [value]
	return str(value)
