extends Node
## Runs every `test_*.gd` under res://tests and exits with a status code.
##
##   godot --headless --path . res://tests/test_runner.tscn
##   godot --headless --path . res://tests/test_runner.tscn -- --only=rhythm
##
## `--only=<text>` keeps the scripts and test methods whose path or name
## contains <text>. The exit code is 0 when everything passed, 1 otherwise.

const TEST_ROOT := "res://tests"
const SCRIPT_PREFIX := "test_"
const METHOD_PREFIX := "test_"

var _catcher := TestErrorCatcher.new()
var _only := ""
var _passed := 0
var _failed: Array[String] = []


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--only="):
			_only = argument.trim_prefix("--only=")
	OS.add_logger(_catcher)
	await _run_all()
	OS.remove_logger(_catcher)
	_report()
	get_tree().quit(0 if _failed.is_empty() and _passed > 0 else 1)


func _run_all() -> void:
	var scripts := _find_test_scripts(TEST_ROOT)
	scripts.sort()
	for path in scripts:
		await _run_script(path)


func _find_test_scripts(directory: String) -> Array[String]:
	var found: Array[String] = []
	var dir := DirAccess.open(directory)
	if dir == null:
		push_error("Could not open %s" % [directory])
		return found
	for subdirectory in dir.get_directories():
		found.append_array(_find_test_scripts(directory.path_join(subdirectory)))
	for file in dir.get_files():
		if file.begins_with(SCRIPT_PREFIX) and file.ends_with(".gd") and file != "test_runner.gd":
			found.append(directory.path_join(file))
	return found


func _run_script(path: String) -> void:
	var script := load(path) as GDScript
	if script == null or not script.can_instantiate():
		_failed.append("%s: could not be loaded" % [path])
		_catcher.take_errors()
		return
	var instance: Variant = script.new()
	if instance is not TestCase:
		_failed.append("%s: does not extend TestCase" % [path])
		if instance is Node:
			instance.free()
		return
	var test := instance as TestCase
	add_child(test)
	var label := path.trim_prefix(TEST_ROOT + "/")
	for method in script.get_script_method_list():
		var method_name: String = method["name"]
		if not method_name.begins_with(METHOD_PREFIX):
			continue
		if not _only.is_empty() and not (_only in path or _only in method_name):
			continue
		await _run_test(test, label, method_name)
	remove_child(test)
	test.queue_free()


func _run_test(test: TestCase, label: String, method_name: String) -> void:
	test.reset_state()
	_catcher.take_errors()
	test.before_each()
	await test.call(method_name)
	test.after_each()
	test.free_managed()
	# Let queued frees and deferred calls settle before the next test.
	await get_tree().process_frame

	var problems: Array[String] = test.failures.duplicate()
	var errors := _catcher.take_errors()
	if not test.allow_errors:
		for error in errors:
			problems.append("engine error: %s" % [error])
	if test.checks == 0:
		problems.append("made no checks")

	var full_name := "%s::%s" % [label, method_name]
	if problems.is_empty():
		_passed += 1
		print("  pass  %s" % [full_name])
		return
	print("  FAIL  %s" % [full_name])
	for problem in problems:
		print("          %s" % [problem])
		_failed.append("%s: %s" % [full_name, problem])


func _report() -> void:
	print("")
	if _passed == 0 and _failed.is_empty():
		print("No tests were found.")
		return
	var failed_tests := {}
	for entry in _failed:
		failed_tests[entry.get_slice(": ", 0)] = true
	print("%d passed, %d failed" % [_passed, failed_tests.size()])
