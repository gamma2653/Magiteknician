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


# How loud

func test_the_slider_is_where_the_volume_is() -> void:
	var options := _open()
	assert_almost_eq(options.volume.value, 100.0)
	assert_eq(options.volume_text.text, "100%")
	remove_child(options)
	options.free()

	Settings.choose_volume(0.35)
	options = _open()
	assert_almost_eq(options.volume.value, 35.0)
	assert_eq(options.volume_text.text, "35%")


func test_moving_the_slider_changes_how_loud_the_game_is() -> void:
	var options := _open()
	options.volume.value = 60.0
	assert_almost_eq(Settings.volume, 0.6)
	assert_eq(options.volume_text.text, "60%")
	var bus := AudioServer.get_bus_index(Settings.BUS)
	assert_almost_eq(AudioServer.get_bus_volume_db(bus), linear_to_db(0.36), 0.001)
	Settings.reset()
	Settings.read()
	assert_almost_eq(Settings.volume, 0.6, 1e-6, "a slider moved by the keys is kept as it moves")


func test_a_slider_being_dragged_is_kept_when_it_is_let_go() -> void:
	var options := _open()
	options.volume.drag_started.emit()
	options.volume.value = 80.0
	options.volume.value = 45.0
	assert_almost_eq(Settings.volume, 0.45)
	assert_false(FileAccess.file_exists(Settings.path))
	assert_false(options.sample.playing, "and it is quiet while it is dragged")
	options.volume.drag_ended.emit(true)
	assert_true(FileAccess.file_exists(Settings.path))
	Settings.reset()
	Settings.read()
	assert_almost_eq(Settings.volume, 0.45)


func test_letting_the_slider_go_sounds_a_chime() -> void:
	var options := _open()
	assert_eq(options.sample.stream, options.SAMPLE)
	options.volume.drag_started.emit()
	options.volume.value = 50.0
	options.volume.drag_ended.emit(true)
	assert_true(options.sample.playing)


func test_the_slider_goes_all_the_way_down() -> void:
	var options := _open()
	options.volume.value = 0.0
	assert_almost_eq(Settings.volume, 0.0)
	assert_eq(options.volume_text.text, "Off")
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index(Settings.BUS)))


func test_going_back_keeps_what_was_not_yet_kept() -> void:
	var options := _open()
	options.volume.drag_started.emit()
	options.volume.value = 25.0
	options._on_back_pressed()
	Settings.reset()
	Settings.read()
	assert_almost_eq(Settings.volume, 0.25)


func test_choosing_a_cursor_leaves_the_volume_alone() -> void:
	Settings.choose_volume(0.7)
	var options := _open()
	options.brush.pressed.emit()
	assert_almost_eq(Settings.volume, 0.7)
	assert_almost_eq(options.volume.value, 70.0)


func test_back_goes_back() -> void:
	var options := _open()
	options._on_back_pressed()
	assert_true(options.going_back)
