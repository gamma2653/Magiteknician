class_name LoadoutPanel
extends Control
## A card over a menu, on which the spells to bring are chosen.
##
## It covers the menu under it while it is open, so that nothing under it
## can be pressed.

## The spells to bring have changed.
signal changed(chosen: Array[StringName])
signal closed

const TITLE := "Your spells"
const SCREEN := Vector2(1152, 648)
const CARD_COLOUR := Color(0.09, 0.09, 0.13)
const CARD_EDGE := Color(0.75, 0.9, 1.0, 0.25)

var picker: LoadoutPicker
var done: Button

var _shade: ColorRect


func _ready() -> void:
	position = Vector2.ZERO
	size = SCREEN
	visible = false

	_shade = ColorRect.new()
	_shade.color = Color(0.0, 0.0, 0.0, 0.6)
	_shade.size = SCREEN
	add_child(_shade)

	var card := PanelContainer.new()
	card.position = Vector2(256, 96)
	card.custom_minimum_size = Vector2(640, 0)
	# A panel lets what is under it show through, and what is under this
	# one is a menu full of writing.
	var face := StyleBoxFlat.new()
	face.bg_color = CARD_COLOUR
	face.border_color = CARD_EDGE
	face.set_border_width_all(1)
	face.set_corner_radius_all(4)
	card.add_theme_stylebox_override("panel", face)
	add_child(card)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	card.add_child(margin)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 14)
	margin.add_child(rows)

	var title := Label.new()
	title.text = TITLE
	title.add_theme_font_size_override("font_size", 24)
	rows.add_child(title)
	picker = LoadoutPicker.new()
	picker.changed.connect(func (chosen): changed.emit(chosen))
	rows.add_child(picker)
	done = Button.new()
	done.text = "Done"
	done.custom_minimum_size = Vector2(160, 44)
	done.size_flags_horizontal = Control.SIZE_SHRINK_END
	done.pressed.connect(close)
	rows.add_child(done)


## Opens the card on `known`, with `chosen` brought to begin with.
func open(known: Array[Spell], chosen: Array) -> void:
	picker.offer(known, chosen)
	visible = true


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


## What a button that opens the card should say, e.g. "Spells: 4 of 6".
static func summary(chosen: Array) -> String:
	return "Spells: %d of %d" % [chosen.size(), Loadout.SIZE]
