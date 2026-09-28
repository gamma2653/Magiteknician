@tool
extends Train
class_name ActualTrain

var completed = false
var expected_train = null

func _init(expected: ExpectedTrain):
	self.expected_train = expected

func _on_expected(rune: Rune, timestamp_us: int, location: Vector2):
	if completed:
		clear_runes()
		completed = false
	# Create permanent rune marker at location
	var actual_rune = rune.duplicate()
	actual_rune.position = location
	actual_rune.unscaled_ticks = timestamp_us
	add_child(actual_rune)
	actual_rune.set_transparency(1.0)

func _on_completed():
	completed = true
	# Calculate stats
	print(Util.compare(expected_train, self))
	
