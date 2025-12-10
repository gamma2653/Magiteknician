@tool
class_name Level
extends Node2D

@onready var expected: ExpectedTrain = $Expected
var actual: ActualTrain

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if not expected:
		push_warning("Could not find expected train")
	if not actual:
		actual = ActualTrain.new()
		add_child(actual)
	# Connect expected progresion to actual train.
	expected.progress.connect(actual._on_expected)
	expected.reset.connect(actual._on_completed)
	

func _get_configuration_warnings() -> PackedStringArray:
	var errors = []
	var expected_found = false
	for child in get_children():
		if child is ExpectedTrain:
			expected_found = true
			break
	if not expected_found:
		errors.append("No `expected` trains found. Add a train set to the `Expected` mode to reslove this error.")
	return errors
	

#func load_from_json()
