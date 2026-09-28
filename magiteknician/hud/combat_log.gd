class_name CombatLog
extends Label
## The last few things that happened in the duel, newest at the bottom.

## How many lines are kept.
@export_range(1, 20) var capacity: int = 6

var lines: PackedStringArray = []


func _ready() -> void:
	text = ""


func add(line: String) -> void:
	lines.append(line)
	while lines.size() > capacity:
		lines.remove_at(0)
	text = "\n".join(lines)


func clear() -> void:
	lines = []
	text = ""
