extends TestCase
## Runes and trains built from spell data.

const FIRE_BOLT := preload("res://magiteknician/spells/fire_bolt.tres")
const SPARK := preload("res://magiteknician/spells/spark.tres")
const INPUT_LEGEND := preload("res://magiteknician/menus/components/InputLegend.tscn")


func test_a_rune_of_every_type_can_be_created() -> void:
	for type in Rune.Type.values():
		var rune := Rune.create(type)
		assert_not_null(rune, Rune.RuneToName[type])
		assert_eq(rune.rune_type, type, "knows its type before entering the tree")
		add_managed(rune)
		assert_eq(rune.rune_type, type)
		assert_eq(rune.action_id, Rune.RuneToActionID[type])
		assert_false(rune.is_bound(), "a new rune is not on any tick")


func test_every_rune_type_has_a_name_a_symbol_a_key_and_a_scene() -> void:
	for type in Rune.Type.values():
		assert_true(Rune.RuneToName.has(type))
		assert_true(Rune.RuneToID.has(type))
		assert_true(Rune.RuneToScene.has(type))
		assert_true(InputMap.has_action(Rune.RuneToActionID[type]))
		assert_true(ResourceLoader.exists(Rune.RuneToScene[type]))
		assert_eq(Rune.ActionIDToRune[Rune.RuneToActionID[type]], type)
		assert_eq(Rune.IDToRune[Rune.RuneToID[type]], type)


func test_a_train_takes_its_runes_from_a_spell() -> void:
	var train: ExpectedTrain = add_managed(ExpectedTrain.new())
	train.load_spell(FIRE_BOLT)
	assert_eq(train.spell, FIRE_BOLT)
	assert_eq(train.ticks, FIRE_BOLT.ticks())
	var runes := train.bound_runes
	assert_eq(runes.size(), FIRE_BOLT.strokes.size())
	for i in runes.size():
		assert_eq(runes[i].rune_type, FIRE_BOLT.strokes[i].rune)
		assert_eq(runes[i].position, FIRE_BOLT.strokes[i].position)
	assert_true(runes[0].active, "the first rune is the one to strike")
	assert_false(runes[1].active)


func test_loading_another_spell_replaces_the_runes() -> void:
	var train: ExpectedTrain = add_managed(ExpectedTrain.new())
	train.load_spell(FIRE_BOLT)
	train.load_spell(SPARK)
	assert_eq(train.ticks, SPARK.ticks())
	assert_eq(train.bound_runes.size(), SPARK.strokes.size())
	assert_true(train.bound_runes[0].active)


func test_a_train_is_followed_one_rune_at_a_time() -> void:
	var train: ExpectedTrain = add_managed(ExpectedTrain.new())
	train.load_spell(SPARK)
	var struck := []
	var finished := []
	train.progress.connect(func (rune, _time, _location): struck.append(rune))
	train.completed.connect(func (): finished.append(true))
	var runes := train.bound_runes
	for i in runes.size():
		assert_eq(train.current_rune, runes[i])
		assert_false(train.is_complete())
		train.advance(1_000_000 + i * 250_000, runes[i].position)
	assert_eq(struck, runes)
	assert_eq(finished.size(), 1)
	assert_true(train.is_complete())
	assert_null(train.current_rune, "nothing is left to strike")
	train.rearm()
	assert_eq(train.current_rune, runes[0])


func test_the_input_legend_needs_no_runes_in_the_scene() -> void:
	var legend: Label = add_managed(INPUT_LEGEND.instantiate())
	for type in Rune.Type.values():
		assert_true(Rune.RuneToID[type] in legend.text, Rune.RuneToName[type])


func test_runes_placed_by_hand_can_be_saved_as_a_spell() -> void:
	var path := "user://test_saved_spell.tres"
	var train: ExpectedTrain = add_managed(ExpectedTrain.new())
	train.load_spell(FIRE_BOLT)
	train.spell_path = path
	assert_eq(train.save_as_spell(), OK)

	var saved := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as Spell
	assert_not_null(saved)
	assert_eq(String(saved.id), "test_saved_spell", "a new spell is named after its file")
	assert_eq(saved.ticks(), FIRE_BOLT.ticks())
	assert_eq(saved.formula(), FIRE_BOLT.formula())
	DirAccess.remove_absolute(path)


func test_saving_over_a_spell_keeps_its_details() -> void:
	var path := "user://test_resaved_spell.tres"
	var existing := Spell.new()
	existing.id = &"kept"
	existing.display_name = "Kept"
	existing.description = "Should survive."
	existing.strokes = SPARK.strokes.duplicate()
	assert_eq(ResourceSaver.save(existing, path), OK)

	var train: ExpectedTrain = add_managed(ExpectedTrain.new())
	train.load_spell(FIRE_BOLT)
	assert_eq(train.save_as_spell(path), OK)

	var saved := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as Spell
	assert_eq(saved.display_name, "Kept")
	assert_eq(saved.description, "Should survive.")
	assert_eq(String(saved.id), "kept")
	assert_eq(saved.ticks(), FIRE_BOLT.ticks(), "only the strokes were replaced")
	DirAccess.remove_absolute(path)


func test_a_train_can_load_the_spell_it_points_at() -> void:
	var train: ExpectedTrain = add_managed(ExpectedTrain.new())
	train.spell_path = "res://magiteknician/spells/spark.tres"
	assert_eq(train.load_from_spell_path(), OK)
	assert_eq(train.ticks, SPARK.ticks())
