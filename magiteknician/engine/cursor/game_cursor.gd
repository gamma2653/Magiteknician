extends Node
## The mouse cursor, and what it looks like at the moment.
##
## The cursor is drawn by the operating system, not by the game. That way
## it is where the hand is at every instant, and never a frame behind,
## which in a game about striking on the beat is the thing that matters
## about a cursor. The game's part is to hand the system a picture.
##
## Whatever wants the reticle asks for it with aim(), and gives it back
## with point() when it is done.
##
## The player can have the brush the game began with in place of both, by
## asking for it in the options. It is a picture and not drawn, it looks
## the same in a menu as over a rune, and it aims with the tip of its
## bristles, in its bottom left corner.
##
## The cursor is one colour whatever it is over. It was tried in the colour
## of the rune to strike next, and that is the one colour it must not be:
## it is on that rune, and cannot be seen, at the moment of the stroke.

enum Look {
	## A drop of sap that comes to a point. For menus.
	POINTER,
	## A ring with a dot in it. For aiming at runes.
	RETICLE,
}

## The tip of the brush's bristles.
const BRUSH_HOTSPOT := Vector2(0, 60)

var look: Look = Look.POINTER
## True while a rune's key is held down.
var pressed: bool = false
## Who asked for the reticle, so that nobody else gives it back for them.
var aimer: Object

# Pictures already drawn, by what they are of.
var _drawn: Dictionary = {}


func _ready() -> void:
	Settings.changed.connect(_show)
	_show()


func _exit_tree() -> void:
	# The system has been handed a picture. Take it back before the game
	# goes, or the picture outlives what it was drawn with.
	Input.set_custom_mouse_cursor(null)
	_drawn.clear()


## Shows the reticle, on behalf of `whom`.
func aim(whom: Object) -> void:
	aimer = whom
	if look == Look.RETICLE:
		return
	look = Look.RETICLE
	_show()


## Goes back to the pointer, if `whom` is who asked for the reticle.
func point(whom: Object = null) -> void:
	if whom != null and whom != aimer:
		return
	aimer = null
	pressed = false
	if look == Look.POINTER:
		return
	look = Look.POINTER
	_show()


## Shows the cursor pressed down, or let up.
func press(down: bool) -> void:
	if pressed == down:
		return
	pressed = down
	if look == Look.RETICLE:
		_show()


## The colour of the rune of this type, which is the colour of its disc
## in the colours the player has chosen.
func ink_of(type: Rune.Type) -> Color:
	return RunePalette.colour_of(type, Settings.palette)


## The colour most of `image` is, leaving out what is see-through and what
## is nearly black. A rune is a disc of one colour with a black letter and
## a black edge, so this is the colour of the disc.
##
## "Nearly black" goes by the strongest of red, green and blue, and not by
## how bright the colour looks. A deep blue looks dark and is not black.
static func commonest_colour(image: Image) -> Color:
	return RunePalette.commonest_colour(image)


## The picture the cursor is showing.
func picture() -> Texture2D:
	var down := pressed and look == Look.RETICLE
	if is_brush():
		return Loader.RESOURCES["img"]["cursor"]["brush_down" if down else "brush"]
	var key := "%d %s" % [look, down]
	if not _drawn.has(key):
		var image := CursorArt.pointer() if look == Look.POINTER else CursorArt.reticle(CursorArt.SAP, pressed)
		_drawn[key] = ImageTexture.create_from_image(image)
	return _drawn[key]


func hotspot() -> Vector2:
	if is_brush():
		return BRUSH_HOTSPOT
	return CursorArt.pointer_hotspot() if look == Look.POINTER else CursorArt.reticle_hotspot()


## True if the player has asked for the brush.
func is_brush() -> bool:
	return Settings.cursor == Settings.Cursor.BRUSH


func _show() -> void:
	Input.set_custom_mouse_cursor(picture(), Input.CURSOR_ARROW, hotspot())
