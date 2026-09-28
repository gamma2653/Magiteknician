extends TestCase
## The tempo guide and the demonstration: learning a spell's rhythm.

const FIRE_BOLT := preload("res://magiteknician/spells/fire_bolt.tres")
const SPARK := preload("res://magiteknician/spells/spark.tres")
const BEAT := 300_000
const START := 10_000_000

var circle: SpellCircle


func before_each() -> void:
	circle = SpellCircle.new()
	circle.accepts_input = false
	add_managed(circle)
	circle.prepare(FIRE_BOLT)


func _strike(index: int, time: int) -> void:
	var stroke := circle.spell.strokes[index]
	circle.strike(stroke.rune, stroke.position, time)


func _strike_on_beat(index: int) -> void:
	_strike(index, START + circle.spell.strokes[index].tick * BEAT)


func test_there_is_no_guide_before_the_caster_has_a_tempo() -> void:
	assert_true(is_nan(circle.ticks_until_next(START)), "nothing struck")
	_strike_on_beat(0)
	assert_true(is_nan(circle.ticks_until_next(START)), "one stroke is not a tempo")


func test_two_strokes_set_the_tempo() -> void:
	_strike_on_beat(0)
	_strike_on_beat(1)
	# Fire Bolt's third stroke is on tick 3; the second was on tick 1.
	var next_tick := FIRE_BOLT.strokes[2].tick
	assert_almost_eq(circle.ticks_until_next(START + BEAT), float(next_tick - 1), 0.0001)
	assert_almost_eq(circle.ticks_until_next(START + 2 * BEAT), float(next_tick - 2), 0.0001)
	assert_almost_eq(circle.ticks_until_next(START + next_tick * BEAT), 0.0, 0.0001, "due now")


func test_the_guide_goes_negative_once_the_rune_is_overdue() -> void:
	_strike_on_beat(0)
	_strike_on_beat(1)
	var due := START + FIRE_BOLT.strokes[2].tick * BEAT
	assert_almost_eq(circle.ticks_until_next(due + BEAT / 2), -0.5, 0.0001)


func test_the_guide_follows_the_tempo_the_caster_chose() -> void:
	# The same spell, twice as fast: the rune falls due in half the time.
	var fast := BEAT / 2
	_strike(0, START)
	_strike(1, START + fast)
	assert_almost_eq(circle.ticks_until_next(START + fast), 2.0, 0.0001)
	assert_almost_eq(circle.ticks_until_next(START + 3 * fast), 0.0, 0.0001)


func test_following_the_guide_gives_a_perfect_cast() -> void:
	# Whatever the first gap was, striking each later rune as its ring
	# closes keeps the caster on the line they set.
	var odd_tempo := 273_000
	_strike(0, START)
	_strike(1, START + odd_tempo)
	for i in range(2, FIRE_BOLT.strokes.size()):
		var now := START + odd_tempo
		var wait := circle.ticks_until_next(now) * circle.fit_so_far().usec_per_tick
		_strike(i, now + roundi(wait))
	assert_eq(circle.last_result.grade, CastResult.Grade.S)
	assert_almost_eq(circle.last_result.rhythm_score, 1.0, 0.0001)


func test_the_guide_stops_when_the_cast_is_over() -> void:
	for i in FIRE_BOLT.strokes.size():
		_strike_on_beat(i)
	assert_true(is_nan(circle.ticks_until_next(START + 10 * BEAT)))


func test_the_next_rune_shows_the_guide() -> void:
	_strike_on_beat(0)
	_strike_on_beat(1)
	await get_tree().process_frame
	var next := circle.expected.current_rune
	assert_false(is_nan(next.ticks_until_due))
	assert_gt(next.approach_radius(), Rune.RADIUS)
	for ghost in circle.expected.bound_runes:
		if ghost != next:
			assert_true(is_nan(ghost.ticks_until_due), "only the next rune has a ring")


func test_the_guide_can_be_turned_off() -> void:
	circle.show_tempo_guide = false
	_strike_on_beat(0)
	_strike_on_beat(1)
	await get_tree().process_frame
	assert_true(is_nan(circle.expected.current_rune.ticks_until_due))


func test_the_ring_closes_as_the_rune_falls_due() -> void:
	var rune := Rune.create(Rune.Type.FLOW)
	add_managed(rune)
	rune.ticks_until_due = 2.0
	var far := rune.approach_radius()
	rune.ticks_until_due = 1.0
	var near := rune.approach_radius()
	rune.ticks_until_due = 0.0
	var due := rune.approach_radius()
	rune.ticks_until_due = -3.0
	var overdue := rune.approach_radius()
	assert_gt(far, near)
	assert_gt(near, due)
	assert_almost_eq(overdue, due, 0.0001, "an overdue ring waits at the rune's edge")
	assert_between(due, Rune.RADIUS, Rune.RADIUS + 4.0)
	rune.ticks_until_due = 50.0
	assert_almost_eq(rune.approach_radius(), far, 0.0001, "and never starts further out than two ticks")


func test_the_demonstration_plays_every_rune_in_order() -> void:
	var played := []
	var endings := []
	circle.demonstrated.connect(func (index): played.append(index))
	circle.demonstration_ended.connect(func (completed): endings.append(completed))
	assert_true(circle.demonstrate(20_000))
	assert_true(circle.is_demonstrating())
	await get_tree().create_timer(0.4).timeout
	assert_eq(played, [0, 1, 2, 3, 4])
	assert_eq(endings, [true])
	assert_false(circle.is_demonstrating())
	assert_eq(circle.state, SpellCircle.State.READY, "listening is not casting")
	assert_eq(circle.expected.current_index, 0)


func test_the_demonstration_keeps_the_rhythm_of_the_spell() -> void:
	var times := []
	circle.demonstrated.connect(func (_index): times.append(Time.get_ticks_usec()))
	circle.demonstrate(60_000)
	await get_tree().create_timer(0.7).timeout
	assert_eq(times.size(), FIRE_BOLT.strokes.size())
	if times.size() == FIRE_BOLT.strokes.size():
		var fit := RhythmFit.fit(FIRE_BOLT.ticks(), times)
		# Frames are about 17 ms apart, so allow for one either way.
		assert_between(fit.usec_per_tick, 50_000.0, 70_000.0)


func test_starting_to_cast_cuts_the_demonstration_short() -> void:
	var played := []
	var endings := []
	circle.demonstrated.connect(func (index): played.append(index))
	circle.demonstration_ended.connect(func (completed): endings.append(completed))
	circle.demonstrate(200_000)
	await get_tree().process_frame
	_strike_on_beat(0)
	assert_false(circle.is_demonstrating())
	assert_eq(endings, [false])
	await get_tree().create_timer(0.3).timeout
	assert_eq(played, [0], "nothing more was played")


func test_choosing_another_spell_cuts_the_demonstration_short() -> void:
	circle.demonstrate(200_000)
	circle.prepare(SPARK)
	assert_false(circle.is_demonstrating())


func test_there_is_nothing_to_demonstrate_during_a_cast() -> void:
	_strike_on_beat(0)
	assert_false(circle.demonstrate())
	circle.prepare(null)
	assert_false(circle.demonstrate(), "or on an empty circle")


func test_the_listen_action_starts_the_demonstration() -> void:
	circle.accepts_input = true
	assert_true(InputMap.has_action(SpellCircle.LISTEN_ACTION))
	var event := InputEventAction.new()
	event.action = SpellCircle.LISTEN_ACTION
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await get_tree().process_frame
	assert_true(circle.is_demonstrating())
	circle.stop_demonstration()
	var release := InputEventAction.new()
	release.action = SpellCircle.LISTEN_ACTION
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	await get_tree().process_frame
