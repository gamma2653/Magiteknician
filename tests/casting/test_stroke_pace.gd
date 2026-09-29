extends TestCase
## StrokePace: how often the game looks at the keys, and why.

const LIGHTNING := preload("res://magiteknician/spells/lightning.tres")
const FIRE_BOLT := preload("res://magiteknician/spells/fire_bolt.tres")
const ARENA := preload("res://magiteknician/levels/duel_arena.tscn")
const PRACTICE := preload("res://magiteknician/levels/practice_range.tscn")
const MAIN_MENU := preload("res://magiteknician/menus/main_menu.tscn")
const CASTS := 300

var rng := RandomNumberGenerator.new()


func before_each() -> void:
	forget_progress()
	forget_settings()
	rng.seed = 20260928


func after_each() -> void:
	forget_progress()
	forget_settings()


func _circle(accepts_input: bool = true) -> SpellCircle:
	var circle := SpellCircle.new()
	circle.accepts_input = accepts_input
	add_managed(circle)
	return circle


## The share of casts of Lightning that are graded S, by a hand that is
## off the beat by `hand` ticks, when the keys are read `per_second` times
## a second. Zero times a second is for a game that hears of a stroke as
## it is struck.
func _flawless(per_second: float, usec_per_tick: float, hand: float) -> float:
	var period := 1_000_000.0 / per_second if per_second > 0.0 else 0.0
	var flawless := 0
	for cast in CASTS:
		var phase := rng.randf() * period
		var times: Array[int] = []
		for stroke in LIGHTNING.strokes:
			var struck := 1_000_000.0 + (stroke.tick + rng.randfn(0.0, hand)) * usec_per_tick
			times.append(int(StrokePace.heard_at(struck, period, phase)))
		if CastScorer.score(LIGHTNING.ticks(), times).grade == CastResult.Grade.S:
			flawless += 1
	return float(flawless) / CASTS


# Why

func test_a_stroke_is_heard_of_when_the_game_next_comes_round() -> void:
	assert_almost_eq(StrokePace.heard_at(1000.0, 16_667.0), 16_667.0)
	assert_almost_eq(StrokePace.heard_at(16_667.0, 16_667.0), 16_667.0)
	assert_almost_eq(StrokePace.heard_at(16_668.0, 16_667.0), 33_334.0)
	assert_almost_eq(StrokePace.heard_at(1000.0, 16_667.0, 5000.0), 5000.0, 1e-6, "the game came round at 5000")
	assert_almost_eq(StrokePace.heard_at(1234.0, 0.0), 1234.0, 1e-6, "a game that is always listening")


func test_a_stroke_is_never_heard_of_before_it_is_struck() -> void:
	for i in 200:
		var struck := rng.randf_range(0.0, 1_000_000.0)
		var period := rng.randf_range(1000.0, 20_000.0)
		var heard := StrokePace.heard_at(struck, period, rng.randf() * period)
		assert_gt(heard, struck - 0.01)
		assert_lt(heard - struck, period + 0.01, "nor later than the next time round")


func test_being_late_by_the_same_amount_every_time_costs_nothing() -> void:
	var on_time: Array[int] = []
	var late: Array[int] = []
	for stroke in LIGHTNING.strokes:
		on_time.append(1_000_000 + stroke.tick * 100_000)
		late.append(1_000_000 + stroke.tick * 100_000 + 16_000)
	assert_almost_eq(CastScorer.score(LIGHTNING.ticks(), late).quality, CastScorer.score(LIGHTNING.ticks(), on_time).quality)


func test_read_once_a_frame_a_good_hand_loses_the_best_grade_when_it_casts_fast() -> void:
	# A hand that is off by a fiftieth of a tick earns the best grade every
	# time, if the game hears of each stroke as it is struck.
	assert_gt(_flawless(0.0, 125_000.0, 0.02), 0.97)
	# Heard of once a frame, it does not.
	assert_lt(_flawless(60.0, 125_000.0, 0.02), 0.75)


func test_read_closely_it_keeps_it() -> void:
	for usec_per_tick in [80_000.0, 125_000.0, 250_000.0]:
		assert_gt(_flawless(StrokePace.QUICK_PER_SECOND, usec_per_tick, 0.02), 0.97, "%d ms a tick" % [usec_per_tick / 1000.0])


func test_a_slow_cast_never_had_much_to_lose() -> void:
	assert_gt(_flawless(60.0, 330_000.0, 0.02), 0.9)


func test_the_faster_the_cast_the_more_a_frame_is_worth() -> void:
	# A sixtieth of a second, as a share of a tick.
	var frame := StrokePace.unsteadiness(60.0)
	assert_almost_eq(frame, 0.00481, 0.0001, "a little under five thousandths of a second")
	assert_gt(frame / 0.08, 0.04, "which at 80 ms a tick is more than the width of a perfect stroke")
	assert_lt(StrokePace.unsteadiness(StrokePace.QUICK_PER_SECOND) / 0.08, 0.01)
	assert_lt(StrokePace.unsteadiness(500.0), StrokePace.unsteadiness(144.0))
	assert_almost_eq(StrokePace.unsteadiness(0.0), 0.0)


# The pace

func test_the_game_keeps_its_usual_pace_until_it_is_asked() -> void:
	assert_false(StrokePace.is_quick)
	assert_false(StrokePace.is_wanted())


func test_whoever_asks_has_the_keys_read_closely() -> void:
	var usual := Engine.max_fps
	StrokePace.quicken(self)
	assert_true(StrokePace.is_quick)
	assert_true(StrokePace.is_wanted())
	assert_eq(Engine.max_fps, StrokePace.QUICK_PER_SECOND)
	assert_eq(StrokePace.vsync, DisplayServer.VSYNC_DISABLED, "the game does not wait for the screen")
	StrokePace.settle_now()
	assert_false(StrokePace.is_quick)
	assert_eq(Engine.max_fps, usual)
	assert_ne(StrokePace.vsync, DisplayServer.VSYNC_DISABLED)


func test_the_game_does_not_go_back_at_once() -> void:
	# Changing pace makes the screen stall, and a circle is done and
	# wants again between one cast and the next.
	StrokePace.quicken(self)
	StrokePace.settle(self)
	assert_false(StrokePace.is_wanted())
	assert_true(StrokePace.is_quick)
	StrokePace.advance(StrokePace.SETTLE_SECONDS - 0.1)
	assert_true(StrokePace.is_quick)
	StrokePace.advance(0.2)
	assert_false(StrokePace.is_quick)


func test_asking_again_in_time_keeps_the_pace() -> void:
	StrokePace.quicken(self)
	StrokePace.settle(self)
	StrokePace.advance(StrokePace.SETTLE_SECONDS - 0.1)
	StrokePace.quicken(self)
	StrokePace.advance(10.0)
	assert_true(StrokePace.is_quick, "for as long as it is wanted")
	StrokePace.settle(self)
	StrokePace.advance(StrokePace.SETTLE_SECONDS - 0.1)
	assert_true(StrokePace.is_quick, "and then for the whole of the wait, counted from the last of them")


func test_the_pace_is_kept_while_anyone_wants_it() -> void:
	var other := RefCounted.new()
	StrokePace.quicken(self)
	StrokePace.quicken(other)
	StrokePace.quicken(other)
	StrokePace.settle(self)
	StrokePace.advance(5.0)
	assert_true(StrokePace.is_quick)
	StrokePace.settle(other)
	StrokePace.advance(5.0)
	assert_false(StrokePace.is_quick)


func test_an_asker_that_is_gone_no_longer_wants_anything() -> void:
	var asker := Node.new()
	StrokePace.quicken(asker)
	asker.free()
	assert_false(StrokePace.is_wanted())
	StrokePace.advance(5.0)
	assert_false(StrokePace.is_quick)


func test_the_usual_pace_is_whatever_it_was() -> void:
	Engine.max_fps = 90
	StrokePace.quicken(self)
	assert_eq(Engine.max_fps, StrokePace.QUICK_PER_SECOND)
	StrokePace.settle_now()
	assert_eq(Engine.max_fps, 90)
	Engine.max_fps = 0


# The option

func test_the_keys_are_read_closely_unless_the_player_says_not() -> void:
	assert_true(Settings.precise_timing)
	assert_true(Settings.DEFAULT_PRECISE_TIMING)


func test_with_the_option_off_the_game_keeps_its_usual_pace() -> void:
	Settings.choose_precise_timing(false)
	StrokePace.quicken(self)
	assert_true(StrokePace.is_wanted())
	assert_false(StrokePace.is_quick)


func test_the_option_takes_hold_as_it_is_chosen() -> void:
	StrokePace.quicken(self)
	assert_true(StrokePace.is_quick)
	Settings.choose_precise_timing(false)
	assert_false(StrokePace.is_quick, "at once, in the middle of a duel if need be")
	Settings.choose_precise_timing(true)
	assert_true(StrokePace.is_quick, "and back, since it is still wanted")


func test_the_option_changes_nothing_while_nobody_wants_the_keys() -> void:
	Settings.choose_precise_timing(false)
	Settings.choose_precise_timing(true)
	assert_false(StrokePace.is_quick)


func test_the_option_is_kept() -> void:
	Settings.choose_precise_timing(false)
	var on_disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Settings.path))
	assert_eq(on_disk["precise_timing"], false)
	Settings.reset()
	assert_true(Settings.precise_timing)
	Settings.read()
	assert_false(Settings.precise_timing)


func test_an_option_that_is_not_yes_or_no_is_ignored() -> void:
	var file := FileAccess.open(Settings.path, FileAccess.WRITE)
	file.store_string('{"version": 1, "precise_timing": "sometimes"}')
	file.close()
	assert_true(Settings.read())
	assert_true(Settings.precise_timing)


# The spell circle

func test_a_circle_with_a_rune_to_strike_wants_the_keys_read_closely() -> void:
	var circle := _circle()
	assert_false(StrokePace.is_quick, "an empty circle has nothing to time")
	circle.prepare(FIRE_BOLT)
	assert_true(StrokePace.is_quick)
	circle.prepare(null)
	assert_false(StrokePace.is_wanted())


func test_the_pace_is_kept_from_one_cast_to_the_next() -> void:
	var circle := _circle()
	circle.prepare(FIRE_BOLT)
	for stroke in FIRE_BOLT.strokes:
		circle.strike(stroke.rune, stroke.position, 1_000_000 + stroke.tick * 250_000)
	assert_eq(circle.state, SpellCircle.State.READY, "the spell is laid out again")
	assert_true(StrokePace.is_wanted())
	assert_true(StrokePace.is_quick)


func test_a_circle_nobody_casts_on_by_hand_leaves_the_pace_alone() -> void:
	var theirs := _circle(false)
	theirs.prepare(FIRE_BOLT)
	assert_false(StrokePace.is_wanted())
	assert_false(StrokePace.is_quick)


func test_a_circle_that_is_freed_no_longer_wants_anything() -> void:
	var circle := _circle()
	circle.prepare(FIRE_BOLT)
	remove_child(circle)
	circle.free()
	assert_false(StrokePace.is_wanted())


func test_a_circle_that_stops_listening_no_longer_wants_anything() -> void:
	var circle := _circle()
	circle.prepare(FIRE_BOLT)
	circle.accepts_input = false
	assert_false(StrokePace.is_wanted())
	circle.accepts_input = true
	assert_true(StrokePace.is_wanted())


# In the game

func test_a_menu_keeps_the_usual_pace() -> void:
	add_managed(MAIN_MENU.instantiate())
	assert_false(StrokePace.is_wanted())
	assert_false(StrokePace.is_quick)


func test_the_practice_range_reads_the_keys_closely() -> void:
	add_managed(PRACTICE.instantiate())
	assert_true(StrokePace.is_quick)


func test_a_duel_reads_the_keys_closely_from_when_it_begins_to_when_it_ends() -> void:
	var arena: Node = add_managed(ARENA.instantiate())
	arena.duel.set_process(false)
	assert_false(StrokePace.is_quick, "there is only a button to press")
	arena.overlay.confirm.pressed.emit()
	assert_true(StrokePace.is_quick)

	arena.npc.halt()
	arena.duel.opponent.health = 1.0
	var spark := SpellLibrary.find(&"spark")
	arena.spell_bar.choose_spell(spark)
	for stroke in spark.strokes:
		arena.player_circle.strike(stroke.rune, stroke.position, 1_000_000 + stroke.tick * 250_000)
	assert_true(arena.duel.is_over())
	assert_false(StrokePace.is_wanted())
	StrokePace.advance(StrokePace.SETTLE_SECONDS + 0.1)
	assert_false(StrokePace.is_quick)
