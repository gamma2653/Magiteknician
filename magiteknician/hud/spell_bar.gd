class_name SpellBar
extends HBoxContainer
## A row of spell slots. Click one, or press its number, to choose a spell.
##
## A book of more spells than there are number keys is shown a page at a
## time. The last slot of a page turns to the next.

signal spell_chosen(spell: Spell)

const SLOT_ACTION_PATTERN := "Spell-%d"
const SLOT_MIN_SIZE := Vector2(116, 64)
const UNAFFORDABLE_COLOR := Color(1.0, 0.6, 0.6, 0.55)
const TURN_TEXT := "More"

## Whether each slot says what its spell costs, in place of the runes it
## is made of. A duel wants the first; the circle shows the second.
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
## Which page of the book is showing, counting from 0.
var page: int = 0

var _group := ButtonGroup.new()
var _slots: Array[Button] = []
# The slot that turns the page, where there is more than one.
var _turn: Button
var _chi: float = INF


func _ready() -> void:
	_rebuild()


## Chooses the spell at `index` in the book, counting from 0, turning to
## its page if need be. Returns false if there is no such spell.
func choose(index: int) -> bool:
	if spellbook == null or index < 0 or index >= spellbook.spells.size():
		return false
	var its_page := index / spells_to_a_page()
	if its_page != page:
		page = its_page
		_lay_out()
	# Through the property, not set_pressed_no_signal: the button group only
	# releases the previous slot when it hears about the change.
	_slots[index - _first_on_page()].button_pressed = true
	chosen = spellbook.spells[index]
	spell_chosen.emit(chosen)
	return true


## Chooses `spell` if it is in the book.
func choose_spell(spell: Spell) -> bool:
	if spellbook == null:
		return false
	return choose(spellbook.spells.find(spell))


## How many spells are on the page that is showing.
func slot_count() -> int:
	return _slots.size()


## How many spells are in the book.
func spell_count() -> int:
	return 0 if spellbook == null else spellbook.spells.size()


func page_count() -> int:
	return maxi(ceili(float(spell_count()) / spells_to_a_page()), 1)


## How many spells a page holds: as many as there are number keys, or one
## fewer where the last key is wanted for turning the page.
func spells_to_a_page() -> int:
	if spell_count() <= Spellbook.MAX_SLOTS:
		return Spellbook.MAX_SLOTS
	return Spellbook.MAX_SLOTS - 1


## Turns to the next page, and from the last to the first.
func turn_page() -> void:
	page = (page + 1) % page_count()
	_lay_out()


## Dims the slots whose spells cost more than `chi`. They can still be
## chosen: a caster may want a spell laid out while the chi for it comes in.
func show_affordable(chi: float) -> void:
	_chi = chi
	for i in _slots.size():
		var affordable := spellbook.spells[_first_on_page() + i].chi_cost <= chi
		_slots[i].modulate = Color.WHITE if affordable else UNAFFORDABLE_COLOR


## True if the spell at `index` in the book is on the page that is showing
## and is shown as one that can be afforded.
func is_shown_affordable(index: int) -> bool:
	var slot := index - _first_on_page()
	return slot >= 0 and slot < _slots.size() and _slots[slot].modulate == Color.WHITE


func _first_on_page() -> int:
	return page * spells_to_a_page()


# The book has changed, or how it is shown.
func _rebuild() -> void:
	page = 0
	chosen = null
	_lay_out()


# Shows the page that `page` says.
func _lay_out() -> void:
	if not is_node_ready():
		return
	for slot in _slots:
		remove_child(slot)
		slot.queue_free()
	_slots = []
	if _turn != null:
		remove_child(_turn)
		_turn.queue_free()
		_turn = null
	if spellbook == null:
		return
	var first := _first_on_page()
	for i in mini(spellbook.spells.size() - first, spells_to_a_page()):
		var spell := spellbook.spells[first + i]
		var slot := _new_slot()
		slot.toggle_mode = true
		slot.button_group = _group
		var detail := SpellInfo.cost_text(spell) if show_costs else spell.formula()
		slot.text = "%d  %s\n%s" % [i + 1, spell.display_name, detail]
		slot.tooltip_text = "%s\n%s" % [spell.description, SpellInfo.effect_text(spell)]
		slot.pressed.connect(choose.bind(first + i))
		if spell == chosen:
			slot.set_pressed_no_signal(true)
		add_child(slot)
		_slots.append(slot)
	if page_count() > 1:
		_turn = _new_slot()
		_turn.text = "%d  %s\n%d of %d" % [Spellbook.MAX_SLOTS, TURN_TEXT, page + 1, page_count()]
		_turn.pressed.connect(turn_page)
		add_child(_turn)
	if _chi < INF:
		show_affordable(_chi)


func _new_slot() -> Button:
	var slot := Button.new()
	slot.custom_minimum_size = SLOT_MIN_SIZE
	# Slots must never hold keyboard focus: a focused button answers to
	# Space and Enter, which belong to the game.
	slot.focus_mode = Control.FOCUS_NONE
	# Nine slots have to fit across the screen whatever they say.
	slot.clip_text = true
	return slot


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	for i in _slots.size():
		var action := SLOT_ACTION_PATTERN % [i + 1]
		if InputMap.has_action(action) and event.is_action_pressed(action):
			choose(_first_on_page() + i)
			get_viewport().set_input_as_handled()
			return
	var turn := SLOT_ACTION_PATTERN % [Spellbook.MAX_SLOTS]
	if _turn != null and InputMap.has_action(turn) and event.is_action_pressed(turn):
		turn_page()
		get_viewport().set_input_as_handled()
