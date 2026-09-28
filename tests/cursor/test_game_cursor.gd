extends TestCase
## GameCursor, the ink trail, and the spell circle's use of both.

const FIRE_BOLT := preload("res://magiteknician/spells/fire_bolt.tres")
const ARENA := preload("res://magiteknician/levels/duel_arena.tscn")
const PRACTICE := preload("res://magiteknician/levels/practice_range.tscn")
const LEVEL := preload("res://magiteknician/levels/level1.tscn")
const BEAT := 250_000
const START := 5_000_000


func before_each() -> void:
	forget_progress()
	GameCursor.point()


func after_each() -> void:
	forget_progress()
	GameCursor.point()


func _circle(accepts_input: bool = true) -> SpellCircle:
	var circle := SpellCircle.new()
	circle.accepts_input = accepts_input
	add_managed(circle)
	return circle


func _strike(circle: SpellCircle, index: int) -> void:
	var stroke := circle.spell.strokes[index]
	circle.strike(stroke.rune, stroke.position, START + stroke.tick * BEAT)


func _send(event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await get_tree().process_frame


func _key(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	await _send(event)


func _move_mouse(to: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = to
	motion.global_position = to
	await _send(motion)


# The cursor

func test_the_cursor_is_a_pointer_to_begin_with() -> void:
	assert_eq(GameCursor.look, GameCursor.Look.POINTER)
	assert_eq(GameCursor.hotspot(), CursorArt.pointer_hotspot())
	assert_eq(GameCursor.picture().get_width(), CursorArt.POINTER_SIZE)


func test_whoever_asks_for_the_reticle_gets_it() -> void:
	GameCursor.aim(self)
	assert_eq(GameCursor.look, GameCursor.Look.RETICLE)
	assert_eq(GameCursor.aimer, self)
	assert_eq(GameCursor.hotspot(), CursorArt.reticle_hotspot())
	assert_eq(GameCursor.picture().get_width(), CursorArt.RETICLE_SIZE)


func test_only_whoever_asked_can_give_it_back() -> void:
	var somebody_else := RefCounted.new()
	GameCursor.aim(self)
	GameCursor.point(somebody_else)
	assert_eq(GameCursor.look, GameCursor.Look.RETICLE, "it was not theirs to give")
	GameCursor.point(self)
	assert_eq(GameCursor.look, GameCursor.Look.POINTER)
	assert_null(GameCursor.aimer)


func test_the_reticle_can_be_taken_back_by_anyone_who_names_nobody() -> void:
	GameCursor.aim(self)
	GameCursor.point()
	assert_eq(GameCursor.look, GameCursor.Look.POINTER)


func test_the_reticle_shows_when_it_is_pressed() -> void:
	GameCursor.aim(self)
	var up := GameCursor.picture()
	GameCursor.press(true)
	assert_true(GameCursor.pressed)
	var down := GameCursor.picture()
	assert_ne(down, up)
	GameCursor.press(false)
	assert_eq(GameCursor.picture(), up, "and is let up again")


func test_the_pointer_looks_the_same_pressed_or_not() -> void:
	var up := GameCursor.picture()
	GameCursor.press(true)
	assert_eq(GameCursor.picture(), up)
	GameCursor.press(false)


func test_going_back_to_the_pointer_lets_the_cursor_up() -> void:
	GameCursor.aim(self)
	GameCursor.press(true)
	GameCursor.point(self)
	assert_false(GameCursor.pressed)


func test_each_picture_is_drawn_once() -> void:
	var first := GameCursor.picture()
	GameCursor.aim(self)
	GameCursor.point(self)
	assert_eq(GameCursor.picture(), first)


# The colours of the runes

func test_every_rune_has_an_ink_of_its_own() -> void:
	var seen := {}
	for type in Rune.Type.values():
		var ink := GameCursor.ink_of(type)
		assert_false(ink.is_equal_approx(CursorArt.SAP), "%s has a colour" % [Rune.RuneToName[type]])
		assert_false(seen.has(ink.to_html()), "%s is not the colour of another rune" % [Rune.RuneToName[type]])
		seen[ink.to_html()] = true
	assert_eq(seen.size(), Rune.Type.size())


func test_a_runes_ink_is_the_colour_of_its_disc() -> void:
	var flow := GameCursor.ink_of(Rune.Type.FLOW)
	assert_gt(flow.g, flow.r, "flow is green")
	assert_gt(flow.g, flow.b)
	var refraction := GameCursor.ink_of(Rune.Type.REFRACTION)
	assert_gt(refraction.b, refraction.r, "refraction is blue")
	assert_gt(refraction.b, refraction.g)
	assert_gt(refraction.b, 0.5, "a deep blue, and not mistaken for black")


func test_the_commonest_colour_leaves_out_black_and_nothing() -> void:
	var image := Image.create_empty(20, 20, false, Image.FORMAT_RGBA8)
	var teal := Color(0.1, 0.7, 0.7)
	for y in 20:
		for x in 20:
			if x < 4:
				continue  # see-through
			image.set_pixel(x, y, Color.BLACK if y < 9 else teal)
	# More of it is black than is teal, and teal is still the answer.
	var found := GameCursor.commonest_colour(image)
	assert_almost_eq(found.r, teal.r, 0.02)
	assert_almost_eq(found.g, teal.g, 0.02)
	assert_almost_eq(found.b, teal.b, 0.02)


func test_a_picture_of_nothing_has_the_colour_of_sap() -> void:
	assert_eq(GameCursor.commonest_colour(null), CursorArt.SAP)
	assert_eq(GameCursor.commonest_colour(Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)), CursorArt.SAP)


# The ink trail

func test_the_trail_follows_the_cursor() -> void:
	var trail: InkTrail = add_managed(InkTrail.new())
	trail.follow(Vector2(0, 0), START)
	trail.follow(Vector2(20, 0), START + 10_000)
	trail.follow(Vector2(40, 0), START + 20_000)
	assert_eq(trail.point_count(), 3)


func test_the_trail_does_not_gain_a_point_for_every_twitch() -> void:
	var trail: InkTrail = add_managed(InkTrail.new())
	trail.follow(Vector2(0, 0), START)
	trail.follow(Vector2(1, 0), START + 1_000)
	trail.follow(Vector2(2, 1), START + 2_000)
	assert_eq(trail.point_count(), 1)


func test_the_trail_fades_away() -> void:
	var trail: InkTrail = add_managed(InkTrail.new())
	trail.set_process(false)
	trail.follow(Vector2(0, 0), START)
	trail.follow(Vector2(50, 0), START + 100_000)
	var lifetime := int(InkTrail.TRAIL_SECONDS * 1_000_000)
	trail.age(START + lifetime - 1_000)
	assert_eq(trail.point_count(), 2)
	trail.age(START + lifetime + 1_000)
	assert_eq(trail.point_count(), 1, "the older point has gone")
	trail.age(START + 100_000 + lifetime + 1_000)
	assert_eq(trail.point_count(), 0)


func test_a_splash_opens_and_is_gone() -> void:
	var trail: InkTrail = add_managed(InkTrail.new())
	trail.set_process(false)
	trail.splash(Vector2(10, 10), Color.RED, START)
	assert_eq(trail.splash_count(), 1)
	trail.age(START + int(InkTrail.SPLASH_SECONDS * 1_000_000) + 1_000)
	assert_eq(trail.splash_count(), 0)


func test_the_trail_can_be_wiped() -> void:
	var trail: InkTrail = add_managed(InkTrail.new())
	trail.follow(Vector2(0, 0), START)
	trail.splash(Vector2(10, 10), Color.RED, START)
	trail.clear()
	assert_eq(trail.point_count(), 0)
	assert_eq(trail.splash_count(), 0)


func test_the_trail_cleans_up_after_itself() -> void:
	var trail: InkTrail = add_managed(InkTrail.new())
	trail.follow(Vector2(0, 0))
	trail.follow(Vector2(50, 0))
	trail.splash(Vector2(10, 10))
	await get_tree().create_timer(InkTrail.SPLASH_SECONDS + 0.15).timeout
	assert_eq(trail.point_count(), 0)
	assert_eq(trail.splash_count(), 0)


# The spell circle and the cursor

func test_a_circle_with_a_spell_on_it_takes_the_reticle() -> void:
	var circle := _circle()
	assert_eq(GameCursor.look, GameCursor.Look.POINTER, "an empty circle has nothing to aim at")
	circle.prepare(FIRE_BOLT)
	assert_eq(GameCursor.look, GameCursor.Look.RETICLE)
	assert_eq(GameCursor.aimer, circle)


func test_the_trail_is_the_colour_of_the_rune_to_strike_next() -> void:
	var circle := _circle()
	circle.prepare(FIRE_BOLT)
	assert_eq(circle.trail.ink, GameCursor.ink_of(FIRE_BOLT.strokes[0].rune))
	_strike(circle, 0)
	assert_eq(circle.trail.ink, GameCursor.ink_of(FIRE_BOLT.strokes[1].rune))
	assert_ne(FIRE_BOLT.strokes[0].rune, FIRE_BOLT.strokes[1].rune, "the test wants two different runes")


func test_the_trail_goes_back_to_the_first_rune_when_the_cast_is_over() -> void:
	var circle := _circle()
	circle.prepare(FIRE_BOLT)
	for i in FIRE_BOLT.strokes.size():
		_strike(circle, i)
	assert_eq(circle.trail.ink, GameCursor.ink_of(FIRE_BOLT.strokes[0].rune))
	assert_eq(GameCursor.look, GameCursor.Look.RETICLE, "the spell is laid out again, so there is still something to aim at")


func test_a_circle_that_stops_listening_gives_the_reticle_back() -> void:
	var circle := _circle()
	circle.prepare(FIRE_BOLT)
	circle.accepts_input = false
	assert_eq(GameCursor.look, GameCursor.Look.POINTER)
	circle.accepts_input = true
	assert_eq(GameCursor.look, GameCursor.Look.RETICLE)


func test_a_circle_with_no_spell_gives_the_reticle_back() -> void:
	var circle := _circle()
	circle.prepare(FIRE_BOLT)
	circle.prepare(null)
	assert_eq(GameCursor.look, GameCursor.Look.POINTER)


func test_a_spent_circle_gives_the_reticle_back() -> void:
	var circle := _circle()
	circle.rearm_after_cast = false
	circle.prepare(FIRE_BOLT)
	for i in FIRE_BOLT.strokes.size():
		_strike(circle, i)
	assert_eq(circle.state, SpellCircle.State.SPENT)
	assert_eq(GameCursor.look, GameCursor.Look.POINTER)


func test_a_circle_that_is_freed_gives_the_reticle_back() -> void:
	var circle := _circle()
	circle.prepare(FIRE_BOLT)
	remove_child(circle)
	circle.free()
	assert_eq(GameCursor.look, GameCursor.Look.POINTER)


func test_a_circle_nobody_casts_on_by_hand_leaves_the_cursor_alone() -> void:
	var theirs := _circle(false)
	theirs.prepare(FIRE_BOLT)
	assert_eq(GameCursor.look, GameCursor.Look.POINTER)
	_strike(theirs, 0)
	assert_eq(theirs.trail.splash_count(), 0, "and leaves no ink")

	# Nor does it take the reticle from a circle that has it.
	var mine := _circle()
	mine.prepare(FIRE_BOLT)
	theirs.prepare(null)
	theirs.prepare(FIRE_BOLT)
	assert_eq(GameCursor.aimer, mine)
	assert_eq(GameCursor.look, GameCursor.Look.RETICLE)


func test_a_circle_given_its_spell_as_it_loads_takes_the_reticle() -> void:
	var level: Node = add_managed(LEVEL.instantiate())
	assert_eq(level.circle.state, SpellCircle.State.READY)
	assert_eq(GameCursor.look, GameCursor.Look.RETICLE)
	assert_eq(GameCursor.aimer, level.circle)


func test_a_stroke_that_lands_leaves_a_splash() -> void:
	var circle := _circle()
	circle.prepare(FIRE_BOLT)
	_strike(circle, 0)
	assert_eq(circle.trail.splash_count(), 1)
	circle.strike(Rune.Type.PERSISTENCE, Vector2(500, 500), START)
	assert_eq(circle.trail.splash_count(), 1, "a stray leaves a cross, not a splash")


func test_the_trail_follows_the_mouse_over_the_circle() -> void:
	var circle := _circle()
	circle.position = Vector2(400, 300)
	circle.prepare(FIRE_BOLT)
	await _move_mouse(Vector2(400, 300))
	await _move_mouse(Vector2(440, 330))
	assert_eq(circle.trail.point_count(), 2)


func test_there_is_no_trail_when_there_is_nothing_to_aim_at() -> void:
	var circle := _circle()
	circle.position = Vector2(400, 300)
	await _move_mouse(Vector2(400, 300))
	await _move_mouse(Vector2(440, 330))
	assert_eq(circle.trail.point_count(), 0)


func test_a_runes_key_presses_the_cursor_down() -> void:
	var circle := _circle()
	circle.prepare(FIRE_BOLT)
	var action: StringName = Rune.RuneToActionID[FIRE_BOLT.strokes[0].rune]
	await _key(action, true)
	assert_true(GameCursor.pressed)
	await _key(action, false)
	assert_false(GameCursor.pressed)


# In the game

func test_the_practice_range_aims() -> void:
	add_managed(PRACTICE.instantiate())
	assert_eq(GameCursor.look, GameCursor.Look.RETICLE)


func test_a_duel_points_until_it_begins_and_after_it_ends() -> void:
	var arena: Node = add_managed(ARENA.instantiate())
	arena.duel.set_process(false)
	assert_eq(GameCursor.look, GameCursor.Look.POINTER, "there is a button to press")
	arena.overlay.confirm.pressed.emit()
	assert_eq(GameCursor.look, GameCursor.Look.RETICLE)
	assert_eq(GameCursor.aimer, arena.player_circle, "and it is the player's circle that has it")

	arena.npc.halt()
	arena.duel.opponent.health = 1.0
	var spark := SpellLibrary.find(&"spark")
	arena.spell_bar.choose_spell(spark)
	for stroke in spark.strokes:
		arena.player_circle.strike(stroke.rune, stroke.position, START + stroke.tick * BEAT)
	assert_true(arena.duel.is_over())
	assert_eq(GameCursor.look, GameCursor.Look.POINTER, "there are buttons to press again")


func test_the_old_cursor_is_gone() -> void:
	assert_false(Loader.RESOURCES["img"].has("mouse"))
	assert_eq(str(ProjectSettings.get_setting("display/mouse_cursor/custom_image", "")), "")
