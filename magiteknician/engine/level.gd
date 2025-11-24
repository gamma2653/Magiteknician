@tool
class_name Level
extends Node2D

var expected: Train
var actual: Train

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.
	
func _detect_trains(errors = null):
	if errors == null:
		errors = []
	var expected_found = false
	var actual_found = false
	for child in get_children():
		#errors.append("%s" % [sibling])
		print("child:")
		print(child)
		print(child is Train)
		print(child is Control)
		print(child is Node2D)
		print(type_string(typeof((child))))
		if child is Train:
			print("train:")
			print(child)
			if child.mode == Util.TrainMode.EXPECTED:
				expected_found = true
				expected = child
			elif child.mode == Util.TrainMode.ACTUAL:
				actual_found = true
				actual = child
		if expected_found and actual_found:
			break
	if not expected_found:
		errors.append("No `expected` trains found. Add a train set to the `Expected` mode to reslove this error.")
	if not actual_found:
		errors.append("No `actual` trains found. Add a train set to the `Actual` mode to resolve this error.")
	return errors

func _get_configuration_warnings() -> PackedStringArray:
	var errors = []
	_detect_trains(errors)
	return errors
	

#func load_from_json()
