extends TestCase
## Opponent: the definition an NPC duelist is made from.

const OPPONENT_DIR := "res://magiteknician/opponents"


func _opponent() -> Opponent:
	var opponent := Opponent.new()
	opponent.id = &"tester"
	opponent.display_name = "Tester"
	opponent.max_health = 80.0
	opponent.max_chi = 60.0
	opponent.chi_per_second = 4.0
	opponent.spell_ids = [&"spark", &"ward"]
	opponent.profile = CasterProfile.new()
	return opponent


func test_an_opponent_makes_a_duelist_at_full_strength() -> void:
	var duelist := _opponent().make_duelist()
	assert_eq(duelist.display_name, "Tester")
	assert_almost_eq(duelist.health, 80.0)
	assert_almost_eq(duelist.max_health, 80.0)
	assert_almost_eq(duelist.chi, 60.0)
	assert_almost_eq(duelist.chi_per_second, 4.0)
	assert_eq(duelist.spellbook.ids(), [&"spark", &"ward"])


func test_each_duelist_is_a_fresh_one() -> void:
	var opponent := _opponent()
	var first := opponent.make_duelist()
	first.take_damage(50.0)
	assert_almost_eq(opponent.make_duelist().health, 80.0)


func test_a_sound_opponent_has_no_problems() -> void:
	assert_eq(_opponent().problems(), PackedStringArray())


func test_problems_are_reported() -> void:
	var opponent := _opponent()
	opponent.profile = null
	assert_eq(opponent.problems().size(), 1, "no profile")

	opponent = _opponent()
	opponent.spell_ids = [&"ward", &"mend"]
	assert_eq(opponent.problems().size(), 1, "no way to do harm")

	opponent = _opponent()
	opponent.spell_ids = [&"spark", &"no_such_spell"]
	assert_eq(opponent.problems().size(), 1, "an unknown spell")

	opponent = _opponent()
	opponent.max_chi = 20.0
	opponent.spell_ids = [&"spark", &"lightning"]
	assert_eq(opponent.problems().size(), 1, "a spell it could never afford")

	assert_gt(Opponent.new().problems().size(), 2)


func test_every_opponent_in_the_game_can_duel() -> void:
	var checked := 0
	for file in ResourceLoader.list_directory(OPPONENT_DIR):
		if not file.ends_with(".tres"):
			continue
		var opponent := load(OPPONENT_DIR.path_join(file)) as Opponent
		assert_not_null(opponent, file)
		if opponent == null:
			continue
		checked += 1
		assert_eq(opponent.problems(), PackedStringArray(), file)
		assert_eq(String(opponent.id), file.get_basename(), "%s: id matches the file name" % [file])
	assert_gt(checked, 0, "found opponents to check")
