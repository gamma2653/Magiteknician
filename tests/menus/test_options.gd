extends TestCase
## The options menu.

const OPTIONS := preload("res://magiteknician/menus/options.tscn")


func before_each() -> void:
	forget_settings()
	GameCursor.point()


func after_each() -> void:
	forget_settings()
	GameCursor.point()


func _open() -> Node:
	return add_managed(OPTIONS.instantiate())


func test_the_options_offer_both_cursors() -> void:
	var options := _open()
	assert_eq(options.ring.text, "Ring")
	assert_eq(options.brush.text, "Brush")
	assert_not_null(options.ring.icon, "with a picture of each")
	assert_eq(options.brush.icon, Loader.RESOURCES["img"]["cursor"]["brush"])
	assert_eq(options.ring.icon.get_size(), options.brush.icon.get_size(), "of one size, so that they line up")
	var ring: Image = options.ring.icon.get_image()
	var middle: Vector2i = ring.get_size() / 2
	assert_gt(ring.get_pixelv(middle).a, 0.9, "the ring's dot is in the middle of its picture")
	assert_almost_eq(ring.get_pixel(0, 0).a, 0.0, 0.001)


func test_the_options_open_on_what_is_chosen() -> void:
	var options := _open()
	assert_true(options.ring.button_pressed)
	assert_false(options.brush.button_pressed)
	assert_eq(options.cursor_note.text, options.RING_NOTE)
	remove_child(options)
	options.free()

	Settings.choose_cursor(Settings.Cursor.BRUSH)
	options = _open()
	assert_true(options.brush.button_pressed)
	assert_false(options.ring.button_pressed)
	assert_eq(options.cursor_note.text, options.BRUSH_NOTE)


func test_choosing_the_brush_changes_the_cursor_and_is_kept() -> void:
	var options := _open()
	options.brush.pressed.emit()
	assert_eq(Settings.cursor, Settings.Cursor.BRUSH)
	assert_eq(GameCursor.picture(), Loader.RESOURCES["img"]["cursor"]["brush"], "there and then")
	assert_true(options.brush.button_pressed)
	assert_false(options.ring.button_pressed)
	assert_eq(options.cursor_note.text, options.BRUSH_NOTE)
	Settings.reset()
	Settings.read()
	assert_eq(Settings.cursor, Settings.Cursor.BRUSH, "and it is on disk")


func test_the_ring_can_be_chosen_again() -> void:
	Settings.choose_cursor(Settings.Cursor.BRUSH)
	var options := _open()
	options.ring.pressed.emit()
	assert_eq(Settings.cursor, Settings.Cursor.DRAWN)
	assert_false(GameCursor.is_brush())
	assert_true(options.ring.button_pressed)
	assert_eq(options.cursor_note.text, options.RING_NOTE)


func test_one_cursor_is_always_chosen() -> void:
	var options := _open()
	assert_not_null(options.ring.button_group)
	assert_eq(options.ring.button_group, options.brush.button_group)
	assert_false(options.ring.button_group.allow_unpress)
	# Pressing the one that is chosen leaves it chosen.
	options.ring.pressed.emit()
	assert_true(options.ring.button_pressed)
	assert_eq(Settings.cursor, Settings.Cursor.DRAWN)


func test_a_menu_that_has_closed_stops_listening() -> void:
	var options := _open()
	remove_child(options)
	options.free()
	Settings.choose_cursor(Settings.Cursor.BRUSH)
	assert_eq(Settings.cursor, Settings.Cursor.BRUSH)


func test_back_goes_back() -> void:
	var options := _open()
	options._on_back_pressed()
	assert_true(options.going_back)
