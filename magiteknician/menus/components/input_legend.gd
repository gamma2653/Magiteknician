extends Control

#var action_names: Array[StringName]

func _parse_action_desc(action_desc: String):
	return action_desc.replace(" (Physical)", "")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	self.text = "\n".join(InputMap.get_actions().filter(func (action_name: StringName):
		return not action_name.match("ui_*")  # filter out builtins
	).map(func (action_name):
		return "%s: %s" % [Rune.RuneToID[Rune.ActionIDToRune[action_name]], _parse_action_desc(InputMap.get_action_description(action_name))]
	))
	print(self.text)
