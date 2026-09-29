class_name LoadoutPicker
extends VBoxContainer
## Chooses which spells to bring to a duel from those that are known.
##
## Every spell that is known is a button. One that is to be brought says
## which number key it will be under. Pressing a button puts its spell in
## or takes it out, and a choice takes hold as it is made.
##
## There can be more spells than there is room for. A few rows are shown,
## and the rest are scrolled to.

## The spells to bring have changed.
signal changed(chosen: Array[StringName])

const COLUMNS := 3
## No more rows than this are shown at once.
const ROWS_SHOWN := 5
const SLOT_MIN_SIZE := Vector2(188, 58)
const BETWEEN_SLOTS := 8
const LEFT_BEHIND := "–"
const HARMLESS_WARNING := "None of these does harm. A duel cannot be won with them."

## The spells that are to be brought, in the order of their keys.
var chosen: Array[StringName] = []

var _known: Array[Spell] = []
var _count: Label
var _warning: Label
var _scroll: ScrollContainer
var _grid: GridContainer
var _buttons: Dictionary[StringName, Button] = {}


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	_count = Label.new()
	add_child(_count)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", BETWEEN_SLOTS)
	_grid.add_theme_constant_override("v_separation", BETWEEN_SLOTS)
	_scroll.add_child(_grid)
	_warning = Label.new()
	_warning.modulate = Color(1.0, 0.62, 0.3)
	_warning.text = HARMLESS_WARNING
	add_child(_warning)
	_rebuild()


## Offers `known` to choose from, with `chosen_` brought to begin with.
func offer(known: Array[Spell], chosen_: Array) -> void:
	_known = known
	var ids: Array[StringName] = []
	for spell in known:
		ids.append(spell.id)
	chosen = Loadout.tidy(chosen_, ids)
	_rebuild()


## Puts the spell with this id in, or takes it out.
func toggle(id: StringName) -> void:
	var before := chosen
	chosen = Loadout.toggled(chosen, id)
	_show()
	if chosen != before:
		changed.emit(chosen)


func button_of(id: StringName) -> Button:
	return _buttons.get(id)


## How many rows of spells there are, and how many of them are shown at
## once.
func row_count() -> int:
	return ceili(_known.size() / float(COLUMNS))


func rows_shown() -> int:
	return mini(row_count(), ROWS_SHOWN)


## How high `rows` rows of spells are.
static func height_of(rows: int) -> float:
	return rows * SLOT_MIN_SIZE.y + maxi(rows - 1, 0) * BETWEEN_SLOTS


## What is said above the spells, e.g. "Bring up to 6 spells. 4 chosen."
func count_text() -> String:
	var text := "Bring up to %d spells. %d chosen." % [Loadout.SIZE, chosen.size()]
	if not Loadout.has_room(chosen):
		text += " Take one out to put another in."
	return text


func _rebuild() -> void:
	if not is_node_ready():
		return
	for button: Button in _buttons.values():
		_grid.remove_child(button)
		button.queue_free()
	_buttons = {}
	for spell in _known:
		var button := Button.new()
		button.toggle_mode = true
		button.custom_minimum_size = SLOT_MIN_SIZE
		button.clip_text = true
		button.tooltip_text = "%s\n%s" % [spell.description, SpellInfo.effect_text(spell)]
		button.pressed.connect(toggle.bind(spell.id))
		_grid.add_child(button)
		_buttons[spell.id] = button
	_scroll.custom_minimum_size.y = height_of(rows_shown())
	_scroll.scroll_vertical = 0
	_show()


func _show() -> void:
	if not is_node_ready():
		return
	_count.text = count_text()
	_warning.visible = not Loadout.does_harm(chosen)
	for spell in _known:
		var button := _buttons[spell.id]
		var slot := chosen.find(spell.id)
		button.set_pressed_no_signal(slot >= 0)
		# The cost is beside the name, where it is not cut off by a long
		# formula under it.
		button.text = "%s  %s · %s\n%s" % [
			str(slot + 1) if slot >= 0 else LEFT_BEHIND,
			spell.display_name, SpellInfo.cost_text(spell), spell.formula(),
		]
		# One that is out cannot be put in while there is no room, and the
		# last that is in cannot be taken out.
		button.disabled = (slot < 0 and not Loadout.has_room(chosen)) or (slot >= 0 and chosen.size() <= 1)
