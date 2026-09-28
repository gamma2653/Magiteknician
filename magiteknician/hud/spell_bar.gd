class_name SpellBar
extends HBoxContainer
## A row of spell slots. Click one, or press its number, to choose a spell.

signal spell_chosen(spell: Spell)

const SLOT_ACTION_PATTERN := "Spell-%d"
const SLOT_MIN_SIZE := Vector2(116, 64)
const UNAFFORDABLE_COLOR := Color(1.0, 0.6, 0.6, 0.55)

## Whether each slot says what its spell does and costs, in place of the
## runes it is made of. A duel wants the first; the circle shows the second.
var show_costs: bool = false:
	set(value):
		show_costs = value
		_rebuild()

var spellbook: Spellbook:
	set(value):
		spellbook = value
		_rebuild()

## The spell of the slot that is currently chosen, or null.
var chosen: Spell

var _group := ButtonGroup.new()
var _slots: Array[Button] = []


func _ready() -> void:
	_rebuild()


## Chooses the spell in slot `index`, counting from 0. Returns false if
## there is no such slot.
func choose(index: int) -> bool:
	if index < 0 or index >= _slots.size():
		return false
	# Through the property, not set_pressed_no_signal: the button group only
	# releases the previous slot when it hears about the change.
	_slots[index].button_pressed = true
	chosen = spellbook.spells[index]
	spell_chosen.emit(chosen)
	return true


## Chooses `spell` if it is in the book.
func choose_spell(spell: Spell) -> bool:
	if spellbook == null:
		return false
	return choose(spellbook.spells.find(spell))


func slot_count() -> int:
	return _slots.size()


## Dims the slots whose spells cost more than `chi`. They can still be
## chosen: a caster may want a spell laid out while the chi for it comes in.
func show_affordable(chi: float) -> void:
	for i in _slots.size():
		var affordable := spellbook.spells[i].chi_cost <= chi
		_slots[i].modulate = Color.WHITE if affordable else UNAFFORDABLE_COLOR


func is_shown_affordable(index: int) -> bool:
	return _slots[index].modulate == Color.WHITE


func _rebuild() -> void:
	if not is_node_ready():
		return
	for slot in _slots:
		remove_child(slot)
		slot.queue_free()
	_slots = []
	chosen = null
	if spellbook == null:
		return
	for i in mini(spellbook.spells.size(), Spellbook.MAX_SLOTS):
		var spell := spellbook.spells[i]
		var slot := Button.new()
		slot.toggle_mode = true
		slot.button_group = _group
		slot.custom_minimum_size = SLOT_MIN_SIZE
		# Slots must never hold keyboard focus: a focused button answers to
		# Space and Enter, which belong to the game.
		slot.focus_mode = Control.FOCUS_NONE
		var detail := SpellInfo.effect_text(spell) if show_costs else spell.formula()
		slot.text = "%d  %s\n%s" % [i + 1, spell.display_name, detail]
		slot.tooltip_text = spell.description
		slot.pressed.connect(choose.bind(i))
		add_child(slot)
		_slots.append(slot)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	for i in _slots.size():
		var action := SLOT_ACTION_PATTERN % [i + 1]
		if InputMap.has_action(action) and event.is_action_pressed(action):
			choose(i)
			get_viewport().set_input_as_handled()
			return
