extends TestCase
## Settings: what the player has chosen in the options, and the keeping of it.


func before_each() -> void:
	forget_settings()


func after_each() -> void:
	forget_settings()


func _write(text: String) -> void:
	var file := FileAccess.open(Settings.path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _on_disk() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(Settings.path))


func test_the_tests_keep_their_options_apart_from_the_players() -> void:
	assert_ne(Settings.path, Settings.DEFAULT_PATH)


func test_the_game_comes_with_the_drawn_cursor() -> void:
	assert_eq(Settings.cursor, Settings.Cursor.DRAWN)
	assert_eq(Settings.DEFAULT_CURSOR, Settings.Cursor.DRAWN)


func test_a_choice_is_kept() -> void:
	Settings.choose_cursor(Settings.Cursor.BRUSH)
	assert_eq(Settings.cursor, Settings.Cursor.BRUSH)
	assert_true(FileAccess.file_exists(Settings.path))
	Settings.reset()
	assert_eq(Settings.cursor, Settings.Cursor.DRAWN)
	assert_true(Settings.read())
	assert_eq(Settings.cursor, Settings.Cursor.BRUSH)


func test_a_choice_is_written_by_name() -> void:
	Settings.choose_cursor(Settings.Cursor.BRUSH)
	assert_eq(_on_disk()["cursor"], "brush")
	Settings.choose_cursor(Settings.Cursor.DRAWN)
	assert_eq(_on_disk()["cursor"], "drawn")
	assert_eq(int(_on_disk()["version"]), Settings.VERSION)


func test_every_cursor_has_a_name_of_its_own() -> void:
	var names := {}
	for which in Settings.Cursor.values():
		assert_true(Settings.CURSOR_NAMES.has(which))
		names[Settings.CURSOR_NAMES[which]] = true
	assert_eq(names.size(), Settings.Cursor.size())


func test_a_choice_says_that_it_was_made() -> void:
	var heard := [0]
	var listen := func () -> void: heard[0] += 1
	Settings.changed.connect(listen)
	Settings.choose_cursor(Settings.Cursor.BRUSH)
	assert_eq(heard[0], 1)
	Settings.choose_cursor(Settings.Cursor.BRUSH)
	assert_eq(heard[0], 1, "choosing what is already chosen changes nothing")
	Settings.changed.disconnect(listen)


func test_choosing_what_is_already_chosen_writes_nothing() -> void:
	Settings.choose_cursor(Settings.Cursor.DRAWN)
	assert_false(FileAccess.file_exists(Settings.path))


func test_with_no_file_the_options_are_as_the_game_comes() -> void:
	Settings.cursor = Settings.Cursor.BRUSH
	assert_false(Settings.read())
	assert_eq(Settings.cursor, Settings.Cursor.DRAWN)


func test_a_file_that_cannot_be_read_is_ignored() -> void:
	allow_errors = true
	_write("{ this is not json")
	Settings.cursor = Settings.Cursor.BRUSH
	assert_false(Settings.read())
	assert_eq(Settings.cursor, Settings.Cursor.DRAWN)
	_write("[1, 2, 3]")
	assert_false(Settings.read())


func test_a_cursor_the_game_does_not_know_is_ignored() -> void:
	_write('{"version": 1, "cursor": "quill"}')
	assert_true(Settings.read())
	assert_eq(Settings.cursor, Settings.Cursor.DRAWN)
	_write('{"version": 1, "cursor": 1}')
	assert_true(Settings.read())
	assert_eq(Settings.cursor, Settings.Cursor.DRAWN, "a cursor goes by its name, not its number")
	_write('{"version": 1}')
	assert_true(Settings.read())
	assert_eq(Settings.cursor, Settings.Cursor.DRAWN)


# How loud

func _bus() -> int:
	return AudioServer.get_bus_index(Settings.BUS)


func test_the_game_comes_as_loud_as_its_sounds_were_made() -> void:
	assert_almost_eq(Settings.volume, 1.0)
	assert_almost_eq(AudioServer.get_bus_volume_db(_bus()), 0.0, 0.001)
	assert_false(AudioServer.is_bus_mute(_bus()))


func test_the_volume_is_heard_at_once_and_kept() -> void:
	Settings.choose_volume(0.5)
	assert_almost_eq(Settings.volume, 0.5)
	assert_almost_eq(AudioServer.get_bus_volume_db(_bus()), linear_to_db(0.25), 0.001)
	assert_almost_eq(_on_disk()["volume"], 0.5)
	Settings.reset()
	assert_almost_eq(AudioServer.get_bus_volume_db(_bus()), 0.0, 0.001)
	assert_true(Settings.read())
	assert_almost_eq(Settings.volume, 0.5)
	assert_almost_eq(AudioServer.get_bus_volume_db(_bus()), linear_to_db(0.25), 0.001, "and is heard again when it is read")


func test_half_way_is_about_half_as_loud() -> void:
	# Ten decibels less is about half as loud to the ear.
	assert_almost_eq(linear_to_db(Settings.strength_at(0.5)), -12.0, 0.1)
	assert_almost_eq(Settings.strength_at(1.0), 1.0)
	assert_almost_eq(Settings.strength_at(0.0), 0.0)
	assert_gt(Settings.strength_at(0.75), Settings.strength_at(0.5))
	assert_almost_eq(Settings.strength_at(7.0), 1.0)
	assert_almost_eq(Settings.strength_at(-1.0), 0.0)


func test_no_volume_is_silence() -> void:
	Settings.choose_volume(0.0)
	assert_true(AudioServer.is_bus_mute(_bus()))
	Settings.choose_volume(0.05)
	assert_false(AudioServer.is_bus_mute(_bus()))
	assert_lt(AudioServer.get_bus_volume_db(_bus()), -40.0)


func test_the_volume_is_kept_between_nothing_and_everything() -> void:
	Settings.choose_volume(3.0)
	assert_almost_eq(Settings.volume, 1.0)
	Settings.choose_volume(-2.0)
	assert_almost_eq(Settings.volume, 0.0)


func test_a_slider_that_is_being_dragged_writes_nothing_until_it_is_let_go() -> void:
	Settings.choose_volume(0.8, false)
	Settings.choose_volume(0.6, false)
	assert_almost_eq(Settings.volume, 0.6)
	assert_almost_eq(AudioServer.get_bus_volume_db(_bus()), linear_to_db(0.36), 0.001, "it is heard as it goes")
	assert_false(FileAccess.file_exists(Settings.path))
	Settings.keep()
	assert_almost_eq(_on_disk()["volume"], 0.6)


func test_keeping_when_nothing_has_changed_writes_nothing() -> void:
	Settings.keep()
	assert_false(FileAccess.file_exists(Settings.path))
	Settings.choose_volume(1.0)
	assert_false(FileAccess.file_exists(Settings.path), "it was that loud already")


func test_a_change_of_volume_says_that_it_was_made() -> void:
	var heard := [0]
	var listen := func () -> void: heard[0] += 1
	Settings.changed.connect(listen)
	Settings.choose_volume(0.4)
	Settings.choose_volume(0.4)
	assert_eq(heard[0], 1)
	Settings.changed.disconnect(listen)


func test_a_volume_that_is_not_a_number_is_ignored() -> void:
	_write('{"version": 1, "cursor": "brush", "volume": "eleven"}')
	assert_true(Settings.read())
	assert_almost_eq(Settings.volume, 1.0, 1e-6, "and the game is not silenced by a file that was mended badly")
	assert_eq(Settings.cursor, Settings.Cursor.BRUSH, "the rest of the file is still read")
	_write('{"version": 1, "volume": 40}')
	assert_true(Settings.read())
	assert_almost_eq(Settings.volume, 1.0, 1e-6, "too much is as much as there is")


func test_a_file_from_before_there_was_a_volume_is_read() -> void:
	_write('{"version": 1, "cursor": "brush"}')
	assert_true(Settings.read())
	assert_almost_eq(Settings.volume, 1.0)
	assert_eq(Settings.cursor, Settings.Cursor.BRUSH)


func test_the_cursor_and_the_volume_are_kept_together() -> void:
	Settings.choose_cursor(Settings.Cursor.BRUSH)
	Settings.choose_volume(0.3)
	assert_eq(_on_disk()["cursor"], "brush")
	assert_almost_eq(_on_disk()["volume"], 0.3)


func test_the_options_are_kept_apart_from_progress() -> void:
	forget_progress()
	Settings.choose_cursor(Settings.Cursor.BRUSH)
	Session.new_game()
	assert_ne(Settings.path, Session.save_path)
	assert_true(Settings.read())
	assert_eq(Settings.cursor, Settings.Cursor.BRUSH, "starting over does not put the options back")
	forget_progress()
