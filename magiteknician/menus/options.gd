extends Node2D
## The options: which cursor to play with, and how loud the game is.
##
## A choice takes hold as it is made, and is kept. There is nothing to
## confirm. The cursor in the player's hand is the preview of the one,
## and a rune's chime, sounded as the slider is let go, of the other.

## What is sounded to say how loud the game now is: the lowest of the
## runes' chimes.
const SAMPLE := preload("res://magiteknician/assets/audio/runes/analog_chime/C2.ogg")

const RING_NOTE := "A ring that aims with its centre while there is a rune to strike, and a drop of sap the rest of the time."
const BRUSH_NOTE := "The brush the game began with. It aims with the tip of its bristles."

var going_back = false

@onready var ring: Button = %Ring
@onready var brush: Button = %Brush
@onready var cursor_note: Label = %CursorNote
@onready var volume: HSlider = %Volume
@onready var volume_text: Label = %VolumeText
@onready var sample: AudioStreamPlayer = %Sample

var _is_dragging: bool = false


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var cursors := ButtonGroup.new()
	ring.button_group = cursors
	brush.button_group = cursors
	brush.icon = Loader.RESOURCES["img"]["cursor"]["brush"]
	ring.icon = _picture_of_the_ring(brush.icon.get_size())
	ring.pressed.connect(Settings.choose_cursor.bind(Settings.Cursor.DRAWN))
	brush.pressed.connect(Settings.choose_cursor.bind(Settings.Cursor.BRUSH))
	sample.stream = SAMPLE
	volume.value_changed.connect(_on_volume_changed)
	volume.drag_started.connect(func (): _is_dragging = true)
	volume.drag_ended.connect(_on_volume_let_go)
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


func _show_choices() -> void:
	var is_brush := Settings.cursor == Settings.Cursor.BRUSH
	brush.set_pressed_no_signal(is_brush)
	ring.set_pressed_no_signal(not is_brush)
	cursor_note.text = BRUSH_NOTE if is_brush else RING_NOTE
	volume.set_value_no_signal(Settings.volume * volume.max_value)
	volume_text.text = "Off" if Settings.volume <= 0.0 else "%d%%" % [roundi(Settings.volume * 100.0)]


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


func _on_fade_transition_timeout() -> void:
	if going_back:
		going_back = false
		get_tree().change_scene_to_packed(Loader.LEVELS["menu"]["main_menu"].call())


func _on_back_pressed() -> void:
	Settings.keep()
	$FadeTransition.start_transition()
	going_back = true
