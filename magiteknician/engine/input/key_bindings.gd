class_name KeyBindings
extends RefCounted
## Which key does what, and the changing of it.
##
## The keys the game comes with are in the project's input map. What the
## player has chosen in their place is a dictionary of keys by action,
## kept with the options. This puts the one over the other.
##
## Keys are known by where they are on the keyboard and not by what is
## printed on them, so that the runes are under the same fingers on any
## layout.

## The actions whose keys can be chosen: the seven runes, and what is
## done to a cast.
const REBINDABLE: Array[StringName] = [
	&"Rune-Dev", &"Rune-Refrac", &"Rune-Persist", &"Rune-Decay", &"Rune-Flow", &"Rune-Equiv", &"Rune-Var",
	&"Cast-Listen", &"Cast-Abandon",
]
const LABELS: Dictionary[StringName, String] = {
	&"Cast-Listen": "Hear the spell",
	&"Cast-Abandon": "Give up a cast",
}
## Pressing this while a key is being chosen chooses nothing.
const CANCEL := KEY_ESCAPE

static var _came_with: Dictionary[StringName, int] = {}


## The keys the game comes with, by action.
static func came_with() -> Dictionary[StringName, int]:
	if _came_with.is_empty():
		# Read from the project, and not from the input map as it is now,
		# which may have the player's choices in it already.
		for action in REBINDABLE:
			var setting: Variant = ProjectSettings.get_setting("input/%s" % [action])
			if setting is Dictionary:
				for event: Variant in setting.get("events", []):
					if event is InputEventKey:
						_came_with[action] = int(event.physical_keycode)
						break
	return _came_with.duplicate()


## The key that does `action` now, or 0 if none does.
static func key_of(action: StringName) -> int:
	if not InputMap.has_action(action):
		return 0
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return int(event.physical_keycode)
	return 0


## Has `keycode` do `action`, in place of whatever key did. What is not a
## key, the mouse button that gives up a cast, is left as it is.
static func bind(action: StringName, keycode: int) -> void:
	if not InputMap.has_action(action):
		return
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			InputMap.action_erase_event(action, event)
	var key := InputEventKey.new()
	key.physical_keycode = keycode as Key
	InputMap.action_add_event(action, key)


## Puts `keys` over the keys the game comes with. An action that `keys`
## says nothing of, or nothing that can be used, has the key it came with.
static func apply(keys: Dictionary) -> void:
	var fit := tidy(keys)
	for action in REBINDABLE:
		bind(action, fit[action])


## `keys` made fit to use: every action has a key, no key that cannot be
## chosen is chosen, and no two actions have the same key.
static func tidy(keys: Dictionary) -> Dictionary[StringName, int]:
	var fit := came_with()
	for action in REBINDABLE:
		var chosen: Variant = keys.get(action, keys.get(String(action)))
		if (chosen is int or chosen is float) and can_be_chosen(int(chosen)):
			fit = with_key(fit, action, int(chosen))
	return fit


## `keys` with `keycode` doing `action`. If the key did something else,
## that has the key `action` had: the two change places, and nothing is
## left without a key.
static func with_key(keys: Dictionary, action: StringName, keycode: int) -> Dictionary[StringName, int]:
	var changed: Dictionary[StringName, int] = {}
	for known in REBINDABLE:
		changed[known] = int(keys.get(known, came_with().get(known, 0)))
	if action not in REBINDABLE or not can_be_chosen(keycode):
		return changed
	var had := changed[action]
	for other in REBINDABLE:
		if other != action and changed[other] == keycode:
			changed[other] = had
	changed[action] = keycode
	return changed


## True if `keycode` is a key that can be chosen. The keys that choose a
## spell cannot, nor can a key that only changes what another key does.
static func can_be_chosen(keycode: int) -> bool:
	if keycode <= 0:
		return false
	if keycode in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META, KEY_CAPSLOCK, KEY_NUMLOCK, KEY_SCROLLLOCK]:
		return false
	for action in InputMap.get_actions():
		if action in REBINDABLE or String(action).begins_with("ui_"):
			continue
		for event in InputMap.action_get_events(action):
			if event is InputEventKey and int(event.physical_keycode) == keycode:
				return false
	return true


## True if `keys` are the keys the game comes with.
static func are_as_they_came(keys: Dictionary) -> bool:
	return tidy(keys) == came_with()


## What the key is called, e.g. "W" or "Space".
static func name_of(keycode: int) -> String:
	if keycode <= 0:
		return "none"
	return OS.get_keycode_string(keycode as Key)


## What `action` is called, e.g. "ρ Flow" or "Hear the spell".
static func label_of(action: StringName) -> String:
	if Rune.ActionIDToRune.has(action):
		var rune: Rune.Type = Rune.ActionIDToRune[action]
		return "%s  %s" % [Rune.RuneToID[rune], Rune.RuneToName[rune]]
	return LABELS.get(action, String(action).replace("-", " "))
