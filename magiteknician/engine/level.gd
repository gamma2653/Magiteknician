@tool
class_name Level
extends Node2D
## A scene with a spell circle in it.

@onready var circle: SpellCircle = $SpellCircle

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if not circle:
		push_warning("Could not find the spell circle")
		return
	circle.cast_finished.connect(_on_cast_finished)

func _on_cast_finished(_spell: Spell, result: CastResult) -> void:
	print(result)

func _get_configuration_warnings() -> PackedStringArray:
	var errors = []
	var circle_found = false
	for child in get_children():
		if child is SpellCircle:
			circle_found = true
			break
	if not circle_found:
		errors.append("No spell circle found. Add a `SpellCircle` to resolve this error.")
	return errors
