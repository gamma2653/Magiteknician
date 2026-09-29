extends Node2D
## The options: which cursor to play with, which colours the runes are,
## how loud the game is, how closely the keys are read, and which keys
## they are.
##
## A choice takes hold as it is made, and is kept. There is nothing to
## confirm. The cursor in the player's hand is the preview of the one,
## and a rune's chime, sounded as the slider is let go, of another.

## What is sounded to say how loud the game now is: the lowest of the
## runes' chimes.
const SAMPLE := preload("res://magiteknician/assets/audio/runes/analog_chime/C2.ogg")

const RING_NOTE := "A ring that aims with its centre while there is a rune to strike, and a drop of sap the rest of the time."
const BRUSH_NOTE := "The brush the game began with. It aims with the tip of its bristles."
const PRECISE_NOTE := "Reads the keys %d times a second while there is a rune to strike. A fast cast is judged fairly, and the machine works harder."
const FRAME_NOTE := "Reads the keys once a frame. It is easy on the machine, and a fast cast is judged as less steady than it was."
const PAINTED_NOTE := "The runes as they were painted. Two are green and two are blue."
const DISTINCT_NOTE := "Seven colours that can be told apart by an eye that does not see red, or green, or blue."
const PRESS_A_KEY := "Press a key"
const KEYS_NOTE := "Press a key's button and then the key it is to be. A key that is in use changes places with it. Escape leaves it as it was."
const KEY_REFUSED := "%s cannot be used. It chooses a spell, or does nothing by itself."

var going_back = false
## The action a key is being chosen for, or "" if none is.
var choosing_for: StringName = &""

@onready var ring: Button = %Ring
@onready var brush: Button = %Brush
@onready var cursor_note: Label = %CursorNote
@onready var painted: Button = %Painted
@onready var distinct: Button = %Distinct
@onready var palette_note: Label = %PaletteNote
@onready var volume: HSlider = %Volume
@onready var volume_text: Label = %VolumeText
@onready var sample: AudioStreamPlayer = %Sample
@onready var precise: CheckButton = %Precise
@onready var timing_note: Label = %TimingNote
@onready var keys: GridContainer = %Keys
@onready var keys_note: Label = %KeysNote
@onready var reset_keys: Button = %ResetKeys

var _is_dragging: bool = false
var _key_buttons: Dictionary[StringName, Button] = {}


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var cursors := ButtonGroup.new()
	ring.button_group = cursors
	brush.button_group = cursors
	brush.icon = Loader.RESOURCES["img"]["cursor"]["brush"]
	ring.icon = _picture_of_the_ring(brush.icon.get_size())
	ring.pressed.connect(Settings.choose_cursor.bind(Settings.Cursor.DRAWN))
	brush.pressed.connect(Settings.choose_cursor.bind(Settings.Cursor.BRUSH))

	var palettes := ButtonGroup.new()
	painted.button_group = palettes
	distinct.button_group = palettes
	painted.icon = RunePalette.swatches(RunePalette.Choice.PAINTED)
	distinct.icon = RunePalette.swatches(RunePalette.Choice.DISTINCT)
	painted.pressed.connect(Settings.choose_palette.bind(RunePalette.Choice.PAINTED))
	distinct.pressed.connect(Settings.choose_palette.bind(RunePalette.Choice.DISTINCT))

	sample.stream = SAMPLE
	volume.value_changed.connect(_on_volume_changed)
	volume.drag_started.connect(func (): _is_dragging = true)
	volume.drag_ended.connect(_on_volume_let_go)
	precise.toggled.connect(Settings.choose_precise_timing)

	for action in KeyBindings.REBINDABLE:
		var label := Label.new()
		label.text = KeyBindings.label_of(action)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		keys.add_child(label)
		var button := Button.new()
		button.custom_minimum_size = Vector2(150, 34)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(choose_key_for.bind(action))
		keys.add_child(button)
		_key_buttons[action] = button
	reset_keys.pressed.connect(_on_reset_keys_pressed)

	Settings.changed.connect(_show_choices)
	_show_choices()
	$FadeTransition.end_transition()


## The ring in the middle of a picture of `size`, which is the size of
## the picture beside it, so that the two buttons line up.
func _picture_of_the_ring(size: Vector2i) -> ImageTexture:
	var reticle := CursorArt.reticle()
	size = size.max(reticle.get_size())
	var image := Image.create_empty(size.x, size.y, false, reticle.get_format())
	image.blit_rect(reticle, Rect2i(Vector2i.ZERO, reticle.get_size()), (size - reticle.get_size()) / 2)
	return ImageTexture.create_from_image(image)


func key_button_of(action: StringName) -> Button:
	return _key_buttons.get(action)


func _show_choices() -> void:
	var is_brush := Settings.cursor == Settings.Cursor.BRUSH
	brush.set_pressed_no_signal(is_brush)
	ring.set_pressed_no_signal(not is_brush)
	cursor_note.text = BRUSH_NOTE if is_brush else RING_NOTE
	var is_distinct := Settings.palette == RunePalette.Choice.DISTINCT
	distinct.set_pressed_no_signal(is_distinct)
	painted.set_pressed_no_signal(not is_distinct)
	palette_note.text = DISTINCT_NOTE if is_distinct else PAINTED_NOTE
	volume.set_value_no_signal(Settings.volume * volume.max_value)
	volume_text.text = "Off" if Settings.volume <= 0.0 else "%d%%" % [roundi(Settings.volume * 100.0)]
	precise.set_pressed_no_signal(Settings.precise_timing)
	timing_note.text = PRECISE_NOTE % [StrokePace.QUICK_PER_SECOND] if Settings.precise_timing else FRAME_NOTE
	for action in _key_buttons:
		_key_buttons[action].text = PRESS_A_KEY if action == choosing_for else KeyBindings.name_of(Settings.keys[action])
	reset_keys.disabled = KeyBindings.are_as_they_came(Settings.keys)


func _on_volume_changed(value: float) -> void:
	# A slider that is being dragged changes many times a second. What it
	# comes to rest on is what is kept.
	Settings.choose_volume(value / volume.max_value, not _is_dragging)
	if not _is_dragging:
		sample.play()


func _on_volume_let_go(_changed: bool) -> void:
	_is_dragging = false
	Settings.keep()
	sample.play()


## Waits for a key, to have it do `action`.
func choose_key_for(action: StringName) -> void:
	choosing_for = action
	keys_note.text = KEYS_NOTE
	_show_choices()


## Takes `keycode` as the key that was pressed while one was waited for.
func take_key(keycode: int) -> void:
	if choosing_for.is_empty():
		return
	var action := choosing_for
	choosing_for = &""
	if keycode == KeyBindings.CANCEL:
		pass
	elif not KeyBindings.can_be_chosen(keycode):
		keys_note.text = KEY_REFUSED % [KeyBindings.name_of(keycode)]
	else:
		Settings.choose_key(action, keycode)
	_show_choices()


func _input(event: InputEvent) -> void:
	if choosing_for.is_empty() or event is not InputEventKey or not event.pressed or event.is_echo():
		return
	take_key(int((event as InputEventKey).physical_keycode))
	get_viewport().set_input_as_handled()


func _on_reset_keys_pressed() -> void:
	choosing_for = &""
	keys_note.text = KEYS_NOTE
	Settings.reset_keys()
	_show_choices()


func _on_fade_transition_timeout() -> void:
	if going_back:
		going_back = false
		get_tree().change_scene_to_packed(Loader.LEVELS["menu"]["main_menu"].call())


func _on_back_pressed() -> void:
	choosing_for = &""
	Settings.keep()
	$FadeTransition.start_transition()
	going_back = true
