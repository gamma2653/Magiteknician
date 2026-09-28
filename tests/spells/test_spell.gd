extends TestCase
## Spell and RuneStroke: spells as data.

const SPELL_DIR := "res://magiteknician/spells"
const LEVEL := preload("res://magiteknician/levels/level1.tscn")

const FLOW := Rune.Type.FLOW
const DEV := Rune.Type.DEVELOPMENT
const DECAY := Rune.Type.DECAY


func _spell(strokes: Array) -> Spell:
	var spell := Spell.new()
	spell.id = &"test"
	for entry in strokes:
		spell.strokes.append(RuneStroke.make(entry[0], entry[1], entry[2]))
	return spell


func _fire_bolt() -> Spell:
	return _spell([
		[DEV, 0, Vector2(-100, 0)],
		[FLOW, 1, Vector2(-50, 0)],
		[FLOW, 3, Vector2(0, 0)],
		[DECAY, 4, Vector2(50, 0)],
		[FLOW, 6, Vector2(100, 0)],
	])


func test_ticks_are_the_rhythm_of_the_spell() -> void:
	var spell := _fire_bolt()
	assert_eq(spell.ticks(), [0, 1, 3, 4, 6])
	assert_eq(spell.span_ticks(), 6)
	assert_eq(Spell.new().span_ticks(), 0, "a spell with no strokes spans nothing")


func test_formula_counts_runes_in_order_of_appearance() -> void:
	assert_eq(_fire_bolt().formula(), "δ + ρ ×3 + λ")
	assert_eq(_spell([[FLOW, 0, Vector2.ZERO]]).formula(), "ρ")


func test_a_well_formed_spell_has_no_problems() -> void:
	assert_eq(_fire_bolt().problems().size(), 0)
	assert_true(_fire_bolt().is_castable())


func test_problems_are_reported() -> void:
	assert_false(Spell.new().is_castable(), "no id and no strokes")

	var late_start := _spell([[FLOW, 2, Vector2.ZERO], [FLOW, 3, Vector2.ZERO]])
	assert_eq(late_start.problems().size(), 1, "does not start on tick 0")

	var out_of_order := _spell([[FLOW, 0, Vector2.ZERO], [FLOW, 2, Vector2.ZERO], [FLOW, 2, Vector2.ZERO]])
	assert_eq(out_of_order.problems().size(), 1, "two strokes on the same tick")

	var off_the_circle := _spell([[FLOW, 0, Vector2(Spell.CIRCLE_RADIUS + 1, 0)]])
	assert_eq(off_the_circle.problems().size(), 1, "a rune outside the circle")


func test_a_stroke_survives_a_round_trip_through_json() -> void:
	var original := RuneStroke.make(DECAY, 7, Vector2(-12.5, 80))
	var restored := RuneStroke.from_dict(JSON.parse_string(JSON.stringify(original.to_dict())))
	assert_eq(restored.rune, DECAY)
	assert_eq(restored.tick, 7)
	assert_eq(restored.position, Vector2(-12.5, 80))


func test_a_spell_can_be_read_off_a_hand_placed_train() -> void:
	var level: Level = add_managed(LEVEL.instantiate())
	var spell := Spell.from_train(level.expected)
	assert_eq(spell.ticks(), level.expected.ticks)
	assert_eq(spell.strokes.size(), level.expected.bound_runes.size())
	for i in spell.strokes.size():
		var rune := level.expected.bound_runes[i]
		assert_eq(spell.strokes[i].rune, rune.rune_type)
		assert_eq(spell.strokes[i].position, rune.position)


func test_reading_a_train_can_recentre_it() -> void:
	var level: Level = add_managed(LEVEL.instantiate())
	var centre := Vector2(400, 300)
	var spell := Spell.from_train(level.expected, centre)
	assert_eq(spell.strokes[0].position, level.expected.bound_runes[0].position - centre)


func test_every_spell_in_the_game_is_castable() -> void:
	var files := DirAccess.get_files_at(SPELL_DIR)
	var checked := 0
	for file in files:
		if not file.ends_with(".tres"):
			continue
		var spell := load(SPELL_DIR.path_join(file)) as Spell
		assert_not_null(spell, file)
		if spell == null:
			continue
		checked += 1
		assert_eq(spell.problems(), PackedStringArray(), file)
		assert_eq(String(spell.id), file.get_basename(), "%s: id matches the file name" % [file])
		assert_false(spell.display_name.is_empty(), "%s has a name" % [file])
		assert_false(spell.description.is_empty(), "%s has a description" % [file])
		assert_true(
			spell.strokes.size() >= RhythmFit.MIN_MEASURABLE_STROKES,
			"%s has enough strokes for its rhythm to be judged" % [file]
		)
	assert_gt(checked, 0, "found spells to check")
