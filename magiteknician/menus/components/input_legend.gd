extends Control

#var action_names: Array[StringName]

## How many bindings to put on each line.
@export_range(1, 8) var per_line: int = 1
## Actions left out of the legend. They are matched as patterns, so
## "Spell-*" leaves out every spell slot.
@export var hidden_actions: PackedStringArray = ["Spell-*"]

func _parse_action_desc(action_desc: String):
	# Godot has described physical keys both ways, depending on the version.
	return action_desc.replace(" (Physical)", "").replace(" - Physical", "")

func _describe(action_name: StringName) -> String:
	return _parse_action_desc(InputMap.get_action_description(action_name))

func _is_hidden(action_name: StringName) -> bool:
	if action_name.match("ui_*"):
		return true  # filter out builtins
	for pattern in hidden_actions:
		if action_name.match(pattern):
			return true
	return false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var entries = []
	# Runes first, by their symbol; then whatever else the game binds.
	for action_name in InputMap.get_actions():
		if Rune.ActionIDToRune.has(action_name) and not _is_hidden(action_name):
			entries.append("%s: %s" % [Rune.RuneToID[Rune.ActionIDToRune[action_name]], _describe(action_name)])
	for action_name in InputMap.get_actions():
		if Rune.ActionIDToRune.has(action_name) or _is_hidden(action_name):
			continue
		entries.append("%s: %s" % [String(action_name).replace("-", " "), _describe(action_name)])
	var lines = []
	for start in range(0, entries.size(), per_line):
		lines.append("     ".join(entries.slice(start, start + per_line)))
	self.text = "
".join(lines)
