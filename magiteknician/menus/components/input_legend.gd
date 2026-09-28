extends Control

#var action_names: Array[StringName]

func _parse_action_desc(action_desc: String):
	# Godot has described physical keys both ways, depending on the version.
	return action_desc.replace(" (Physical)", "").replace(" - Physical", "")

func _describe(action_name: StringName) -> String:
	return _parse_action_desc(InputMap.get_action_description(action_name))

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var lines = []
	# Runes first, by their symbol; then whatever else the game binds.
	for action_name in InputMap.get_actions():
		if Rune.ActionIDToRune.has(action_name):
			lines.append("%s: %s" % [Rune.RuneToID[Rune.ActionIDToRune[action_name]], _describe(action_name)])
	for action_name in InputMap.get_actions():
		if action_name.match("ui_*") or Rune.ActionIDToRune.has(action_name):
			continue  # filter out builtins
		lines.append("%s: %s" % [String(action_name).replace("-", " "), _describe(action_name)])
	self.text = "
".join(lines)
