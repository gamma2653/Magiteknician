extends TestCase
## SpellCircle fed by real input events rather than by calls to strike().

const SPARK := preload("res://magiteknician/spells/spark.tres")
const CENTRE := Vector2(500, 300)

var circle: SpellCircle


func before_each() -> void:
	circle = SpellCircle.new()
	circle.position = CENTRE
	add_managed(circle)
	circle.prepare(SPARK)


func _move_mouse_to(point_in_circle: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = CENTRE + point_in_circle
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	await _delivered()


func _press(action: StringName) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		await _delivered()


func _delivered() -> void:
	Input.flush_buffered_events()
	await get_tree().process_frame


func _cast_with_input() -> void:
	for stroke in SPARK.strokes:
		await _move_mouse_to(stroke.position)
		await _press(Rune.RuneToActionID[stroke.rune])


func test_keys_pressed_over_the_runes_cast_the_spell() -> void:
	var results := []
	circle.cast_finished.connect(func (_spell, result): results.append(result))
	await _cast_with_input()
	assert_eq(results.size(), 1)
	assert_eq(results[0].stroke_count, SPARK.strokes.size())
	assert_eq(results[0].strays, 0)
	assert_almost_eq(results[0].aim_score, 1.0, 0.001, "the cursor was dead centre each time")


func test_the_stroke_lands_where_the_cursor_is() -> void:
	var first := SPARK.strokes[0]
	var offset := Vector2(10, -5)
	await _move_mouse_to(first.position + offset)
	await _press(Rune.RuneToActionID[first.rune])
	assert_eq(circle.actual.runes.size(), 1)
	assert_eq(circle.actual.runes[0].position, first.position + offset)


func test_a_key_pressed_away_from_the_rune_is_a_stray() -> void:
	var first := SPARK.strokes[0]
	await _move_mouse_to(first.position)
	await _press(Rune.RuneToActionID[first.rune])
	await _move_mouse_to(Vector2(0, 200))
	await _press(Rune.RuneToActionID[SPARK.strokes[1].rune])
	assert_eq(circle.strays, 1)
	assert_eq(circle.expected.current_index, 1)


func test_the_abandon_action_gives_up_the_cast() -> void:
	var first := SPARK.strokes[0]
	await _move_mouse_to(first.position)
	await _press(Rune.RuneToActionID[first.rune])
	assert_eq(circle.state, SpellCircle.State.CASTING)
	await _press(SpellCircle.ABANDON_ACTION)
	assert_eq(circle.state, SpellCircle.State.READY)
	assert_eq(circle.actual.runes.size(), 0)


func test_a_circle_that_does_not_accept_input_ignores_the_keyboard() -> void:
	circle.accepts_input = false
	await _cast_with_input()
	assert_eq(circle.state, SpellCircle.State.READY)
	assert_null(circle.last_result)


func test_the_abandon_action_is_bound() -> void:
	assert_true(InputMap.has_action(SpellCircle.ABANDON_ACTION))
	assert_gt(InputMap.action_get_events(SpellCircle.ABANDON_ACTION).size(), 0)
