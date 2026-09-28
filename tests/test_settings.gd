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


func test_the_options_are_kept_apart_from_progress() -> void:
	forget_progress()
	Settings.choose_cursor(Settings.Cursor.BRUSH)
	Session.new_game()
	assert_ne(Settings.path, Session.save_path)
	assert_true(Settings.read())
	assert_eq(Settings.cursor, Settings.Cursor.BRUSH, "starting over does not put the options back")
	forget_progress()
