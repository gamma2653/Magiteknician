extends TestCase
## SaveGame: progress as it is written to disk.

const PATH := "user://test_save_game.json"


func after_each() -> void:
	DirAccess.remove_absolute(PATH)


func _save() -> SaveGame:
	var save := SaveGame.new()
	save.campaign_id = &"a_campaign"
	save.stages_cleared = 3
	save.spell_ids = [&"spark", &"fire_bolt", &"ward", &"mend"]
	save.record_win(&"training_sphere", 0.91, 31.5)
	save.record_win(&"underclassman", 0.74, 58.0)
	return save


func test_a_save_survives_being_written_and_read() -> void:
	assert_eq(_save().write(PATH), OK)
	var read := SaveGame.read(PATH)
	assert_not_null(read)
	assert_eq(read.campaign_id, &"a_campaign")
	assert_eq(read.stages_cleared, 3)
	assert_eq(read.spell_ids, [&"spark", &"fire_bolt", &"ward", &"mend"])
	assert_almost_eq(read.best_against(&"training_sphere")["quality"], 0.91)
	assert_almost_eq(read.best_against(&"training_sphere")["seconds"], 31.5)
	assert_almost_eq(read.best_against(&"underclassman")["quality"], 0.74)


func test_the_file_is_json_a_person_can_read() -> void:
	_save().write(PATH)
	var text := FileAccess.get_file_as_string(PATH)
	assert_true("\n" in text, "one thing to a line")
	var data: Dictionary = JSON.parse_string(text)
	assert_eq(int(data["version"]), SaveGame.VERSION)
	assert_eq(data["spell_ids"], ["spark", "fire_bolt", "ward", "mend"])


func test_there_is_nothing_to_read_where_nothing_was_written() -> void:
	assert_null(SaveGame.read(PATH))


func test_a_file_that_is_not_a_save_is_ignored() -> void:
	allow_errors = true
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("{ this is not json")
	file.close()
	assert_null(SaveGame.read(PATH))

	file = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("[1, 2, 3]")
	file.close()
	assert_null(SaveGame.read(PATH))


func test_a_save_with_parts_missing_is_filled_in() -> void:
	var save := SaveGame.from_dict({"campaign_id": "a_campaign"})
	assert_eq(save.stages_cleared, 0)
	assert_eq(save.spell_ids.size(), 0)
	assert_eq(save.best.size(), 0)


func test_a_save_with_nonsense_in_it_is_tidied() -> void:
	var save := SaveGame.from_dict({
		"stages_cleared": -4,
		"spell_ids": "spark",
		"best": {"sphere": "quick", "student": {"quality": 0.5}},
	})
	assert_eq(save.stages_cleared, 0)
	assert_eq(save.spell_ids.size(), 0)
	assert_false(save.best.has("sphere"))
	assert_almost_eq(save.best_against(&"student")["quality"], 0.5)
	assert_almost_eq(save.best_against(&"student")["seconds"], 0.0)


func test_a_better_win_replaces_the_best() -> void:
	var save := SaveGame.new()
	assert_true(save.record_win(&"sphere", 0.7, 40.0), "the first win is the best so far")
	assert_true(save.record_win(&"sphere", 0.8, 50.0), "cleaner, though slower")
	assert_almost_eq(save.best_against(&"sphere")["quality"], 0.8)
	assert_false(save.record_win(&"sphere", 0.75, 20.0), "faster, but not as clean")
	assert_almost_eq(save.best_against(&"sphere")["seconds"], 50.0)
	assert_true(save.record_win(&"sphere", 0.8, 45.0), "as clean, and faster")
	assert_almost_eq(save.best_against(&"sphere")["seconds"], 45.0)


func test_there_is_no_best_against_someone_never_beaten() -> void:
	assert_true(SaveGame.new().best_against(&"nobody").is_empty())
