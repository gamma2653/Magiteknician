extends Node2D
## The options. There is one so far: which cursor to play with.
##
## A choice takes hold as it is made, and is kept. There is nothing to
## confirm, and the cursor in the player's hand is the preview.

const RING_NOTE := "A ring that aims with its centre while there is a rune to strike, and a drop of sap the rest of the time."
const BRUSH_NOTE := "The brush the game began with. It aims with the tip of its bristles."

var going_back = false

@onready var ring: Button = %Ring
@onready var brush: Button = %Brush
@onready var cursor_note: Label = %CursorNote


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var cursors := ButtonGroup.new()
	ring.button_group = cursors
	brush.button_group = cursors
	brush.icon = Loader.RESOURCES["img"]["cursor"]["brush"]
	ring.icon = _picture_of_the_ring(brush.icon.get_size())
	ring.pressed.connect(Settings.choose_cursor.bind(Settings.Cursor.DRAWN))
	brush.pressed.connect(Settings.choose_cursor.bind(Settings.Cursor.BRUSH))
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


func _on_fade_transition_timeout() -> void:
	if going_back:
		going_back = false
		get_tree().change_scene_to_packed(Loader.LEVELS["menu"]["main_menu"].call())


func _on_back_pressed() -> void:
	$FadeTransition.start_transition()
	going_back = true
