extends TestCase
## Cadence: the beat that is kept from one cast to the next.

const FIRE_BOLT := preload("res://magiteknician/spells/fire_bolt.tres")
const SPARK := preload("res://magiteknician/spells/spark.tres")
const WARD := preload("res://magiteknician/spells/ward.tres")
const LIGHTNING := preload("res://magiteknician/spells/lightning.tres")
const BEAT := 300_000
const START := 10_000_000

var circle: SpellCircle
var tuning: CastTuning


func before_each() -> void:
	forget_progress()
	forget_settings()
	tuning = CastScorer.default_tuning()
	circle = SpellCircle.new()
	circle.accepts_input = false
	add_managed(circle)


func after_each() -> void:
	forget_progress()
	forget_settings()


## Casts `spell` on the beat, with its first stroke at `first_usec`, and
## returns the verdict.
func _cast(spell: Spell, first_usec: int, beat: int = BEAT, on: SpellCircle = circle) -> CastResult:
	on.prepare(spell)
	for stroke in spell.strokes:
		on.strike(stroke.rune, stroke.position, first_usec + stroke.tick * beat)
	return on.last_result


## When the first stroke of a cast falls that begins `rest` beats after
## the last stroke of a cast of `spell` begun at `first_usec`.
func _after(spell: Spell, first_usec: int, rest: float, beat: int = BEAT) -> int:
	return first_usec + roundi((spell.strokes[-1].tick + rest) * beat)


# What follows and what does not

func test_the_first_cast_has_nothing_to_follow() -> void:
	var result := _cast(FIRE_BOLT, START)
	assert_eq(circle.cadence.verdict, Cadence.Verdict.FIRST)
	assert_eq(result.cadence_links, 0)
	assert_almost_eq(result.cadence_bonus, 0.0)
	assert_almost_eq(result.potency, 1.0)
	assert_true(circle.cadence.is_alive(), "and leaves a beat for the next")


func test_a_cast_that_begins_on_the_beat_follows() -> void:
	_cast(FIRE_BOLT, START)
	var result := _cast(FIRE_BOLT, _after(FIRE_BOLT, START, 2.0))
	assert_eq(circle.cadence.verdict, Cadence.Verdict.FOLLOWED)
	assert_eq(result.cadence_links, 1)
	assert_almost_eq(result.cadence_bonus, tuning.cadence_bonus_per_link)
	assert_almost_eq(result.potency, 1.0 + tuning.cadence_bonus_per_link)
	assert_eq(circle.cadence.rest, 2)
	assert_almost_eq(circle.cadence.entry, 0.0, 0.001)


func test_it_can_begin_on_the_very_next_beat() -> void:
	_cast(FIRE_BOLT, START)
	_cast(FIRE_BOLT, _after(FIRE_BOLT, START, 1.0))
	assert_eq(circle.cadence.verdict, Cadence.Verdict.FOLLOWED)
	assert_eq(circle.cadence.rest, 1)


func test_a_cast_that_begins_between_beats_does_not() -> void:
	_cast(FIRE_BOLT, START)
	var result := _cast(FIRE_BOLT, _after(FIRE_BOLT, START, 2.5))
	assert_eq(circle.cadence.verdict, Cadence.Verdict.OFF_THE_BEAT)
	assert_eq(result.cadence_links, 0)
	assert_almost_eq(result.potency, 1.0)
	assert_almost_eq(absf(circle.cadence.entry), 0.5, 0.001)


func test_a_little_off_the_beat_is_near_enough() -> void:
	_cast(FIRE_BOLT, START)
	_cast(FIRE_BOLT, _after(FIRE_BOLT, START, 2.0 + tuning.cadence_entry_window * 0.9))
	assert_eq(circle.cadence.verdict, Cadence.Verdict.FOLLOWED)
	circle.cadence.drop()
	_cast(FIRE_BOLT, START)
	_cast(FIRE_BOLT, _after(FIRE_BOLT, START, 2.0 - tuning.cadence_entry_window * 0.9))
	assert_eq(circle.cadence.verdict, Cadence.Verdict.FOLLOWED, "early as well as late")
	assert_lt(circle.cadence.entry, 0.0)
	circle.cadence.drop()
	_cast(FIRE_BOLT, START)
	_cast(FIRE_BOLT, _after(FIRE_BOLT, START, 2.0 + tuning.cadence_entry_window * 1.2))
	assert_eq(circle.cadence.verdict, Cadence.Verdict.OFF_THE_BEAT)


func test_a_cast_at_another_tempo_does_not_follow() -> void:
	_cast(FIRE_BOLT, START)
	var result := _cast(FIRE_BOLT, _after(FIRE_BOLT, START, 2.0), roundi(BEAT * 1.3))
	assert_eq(circle.cadence.verdict, Cadence.Verdict.CHANGED_TEMPO)
	assert_eq(result.cadence_links, 0)
	assert_almost_eq(circle.cadence.tempo_ratio, 1.3, 0.001)


func test_the_tempo_can_drift_a_little() -> void:
	_cast(FIRE_BOLT, START)
	var quicker := roundi(BEAT * (1.0 - tuning.cadence_tempo_window * 0.8))
	_cast(FIRE_BOLT, _after(FIRE_BOLT, START, 2.0), quicker)
	assert_eq(circle.cadence.verdict, Cadence.Verdict.FOLLOWED)
	assert_almost_eq(circle.cadence.usec_per_tick, float(quicker), 1.0, "and the beat is now the quicker one")


func test_a_cast_after_too_long_a_rest_does_not_follow() -> void:
	_cast(FIRE_BOLT, START)
	var result := _cast(FIRE_BOLT, _after(FIRE_BOLT, START, tuning.cadence_max_rest + 1.0))
	assert_eq(circle.cadence.verdict, Cadence.Verdict.RESTED_TOO_LONG)
	assert_eq(result.cadence_links, 0)
	circle.cadence.drop()
	_cast(FIRE_BOLT, START)
	_cast(FIRE_BOLT, _after(FIRE_BOLT, START, float(tuning.cadence_max_rest)))
	assert_eq(circle.cadence.verdict, Cadence.Verdict.FOLLOWED, "the longest rest there is, is allowed")


func test_a_cast_that_does_not_follow_can_be_followed() -> void:
	_cast(FIRE_BOLT, START)
	var second := _after(FIRE_BOLT, START, 2.5)
	_cast(FIRE_BOLT, second)
	assert_eq(circle.cadence.links, 0)
	var result := _cast(FIRE_BOLT, _after(FIRE_BOLT, second, 2.0))
	assert_eq(circle.cadence.verdict, Cadence.Verdict.FOLLOWED, "it is the beat of the last cast that counts")
	assert_eq(result.cadence_links, 1)


func test_it_does_not_matter_how_fast() -> void:
	for beat in [90_000, 300_000, 800_000]:
		circle.cadence.drop()
		_cast(FIRE_BOLT, START, beat)
		var result := _cast(FIRE_BOLT, _after(FIRE_BOLT, START, 3.0, beat), beat)
		assert_eq(result.cadence_links, 1, "%d ms a tick" % [beat / 1000.0])


func test_the_spell_can_change_and_the_beat_go_on() -> void:
	_cast(FIRE_BOLT, START)
	var second := _after(FIRE_BOLT, START, 2.0)
	var warded := _cast(WARD, second)
	assert_eq(warded.cadence_links, 1)
	var third := _after(WARD, second, 3.0)
	var struck := _cast(LIGHTNING, third)
	assert_eq(struck.cadence_links, 2)


# What it is worth

func test_each_cast_that_follows_is_worth_a_little_more() -> void:
	var first := START
	_cast(SPARK, first)
	for link in range(1, tuning.cadence_max_links + 1):
		first = _after(SPARK, first, 2.0)
		var result := _cast(SPARK, first)
		assert_eq(result.cadence_links, link)
		assert_almost_eq(result.cadence_bonus, link * tuning.cadence_bonus_per_link)
		assert_almost_eq(result.potency, 1.0 + link * tuning.cadence_bonus_per_link)


func test_there_is_a_most_that_it_is_worth() -> void:
	var first := START
	_cast(SPARK, first)
	var result: CastResult
	for link in tuning.cadence_max_links + 3:
		first = _after(SPARK, first, 2.0)
		result = _cast(SPARK, first)
	assert_eq(result.cadence_links, tuning.cadence_max_links + 3, "the casts are still counted")
	assert_almost_eq(result.cadence_bonus, tuning.cadence_max_links * tuning.cadence_bonus_per_link)
	assert_almost_eq(Cadence.bonus_for(100, tuning), 0.2, 1e-6, "a fifth stronger, and no more")
	assert_almost_eq(Cadence.bonus_for(0, tuning), 0.0)
	assert_almost_eq(Cadence.bonus_for(-3, tuning), 0.0)


func test_it_is_worth_more_of_a_cast_that_was_worth_more() -> void:
	# The bonus multiplies what the cast earned by its rhythm.
	_cast(FIRE_BOLT, START)
	var first := _after(FIRE_BOLT, START, 2.0)
	circle.prepare(FIRE_BOLT)
	for i in FIRE_BOLT.strokes.size():
		var stroke := FIRE_BOLT.strokes[i]
		var off := 0.09 * BEAT * (1.0 if i % 2 == 0 else -1.0)
		circle.strike(stroke.rune, stroke.position, first + stroke.tick * BEAT + roundi(off))
	var result := circle.last_result
	assert_lt(result.quality, 0.95)
	assert_false(result.fizzled)
	assert_eq(result.cadence_links, 1)
	assert_almost_eq(result.potency, tuning.potency(result.quality) * (1.0 + tuning.cadence_bonus_per_link), 1e-6)
	assert_lt(result.potency, 1.0, "a poor cast in cadence is still a poor cast")


func test_the_grade_is_for_the_cast_and_not_for_the_cadence() -> void:
	_cast(FIRE_BOLT, START)
	var result := _cast(FIRE_BOLT, _after(FIRE_BOLT, START, 2.0))
	assert_almost_eq(result.quality, 1.0)
	assert_eq(result.grade, CastResult.Grade.S)


# What ends it

func test_a_fizzle_ends_it() -> void:
	_cast(FIRE_BOLT, START)
	var second := _after(FIRE_BOLT, START, 2.0)
	circle.prepare(FIRE_BOLT)
	for i in FIRE_BOLT.strokes.size():
		var stroke := FIRE_BOLT.strokes[i]
		var off := 0.45 * BEAT * (1.0 if i % 2 == 0 else -1.0)
		circle.strike(stroke.rune, stroke.position, second + stroke.tick * BEAT + roundi(off))
	assert_true(circle.last_result.fizzled)
	assert_eq(circle.cadence.verdict, Cadence.Verdict.FIZZLED)
	assert_false(circle.cadence.is_alive())
	assert_almost_eq(circle.last_result.potency, 0.0)
	_cast(FIRE_BOLT, _after(FIRE_BOLT, second, 2.0))
	assert_eq(circle.cadence.verdict, Cadence.Verdict.FIRST, "and the cast after it begins again")


func test_giving_up_a_cast_ends_it() -> void:
	_cast(FIRE_BOLT, START)
	var second := _after(FIRE_BOLT, START, 2.0)
	circle.prepare(FIRE_BOLT)
	circle.strike(FIRE_BOLT.strokes[0].rune, FIRE_BOLT.strokes[0].position, second)
	circle.abandon()
	assert_false(circle.cadence.is_alive())
	assert_eq(circle.cadence.links, 0)


func test_choosing_another_spell_does_not_end_it() -> void:
	_cast(FIRE_BOLT, START)
	circle.prepare(WARD)
	circle.prepare(SPARK)
	assert_true(circle.cadence.is_alive())
	circle.abandon()
	assert_true(circle.cadence.is_alive(), "there was no cast to give up")


func test_a_chill_narrows_the_beat_as_it_does_the_strokes() -> void:
	var strict := tuning.stricter(0.5)
	assert_almost_eq(strict.cadence_entry_window, tuning.cadence_entry_window * 0.5)
	assert_almost_eq(strict.cadence_tempo_window, tuning.cadence_tempo_window, 1e-6, "the tempo is left alone")
	circle.tuning = strict
	_cast(FIRE_BOLT, START)
	_cast(FIRE_BOLT, _after(FIRE_BOLT, START, 2.0 + tuning.cadence_entry_window * 0.8))
	assert_eq(circle.cadence.verdict, Cadence.Verdict.OFF_THE_BEAT)


# The beat between casts

func test_the_beat_goes_on_between_casts() -> void:
	_cast(FIRE_BOLT, START)
	var last := START + FIRE_BOLT.strokes[-1].tick * BEAT
	assert_eq(circle.state, SpellCircle.State.READY)
	assert_almost_eq(circle.ticks_until_next(last + BEAT / 4), 0.75, 0.001)
	assert_almost_eq(circle.ticks_until_next(last + BEAT - 1000), 1000.0 / BEAT, 0.001)
	assert_almost_eq(circle.ticks_until_next(last + BEAT + BEAT / 2), 0.5, 0.001, "and round again")


func test_the_beat_stops_when_the_next_cast_could_no_longer_follow() -> void:
	_cast(FIRE_BOLT, START)
	var last := START + FIRE_BOLT.strokes[-1].tick * BEAT
	assert_false(is_nan(circle.ticks_until_next(last + tuning.cadence_max_rest * BEAT)))
	assert_true(is_nan(circle.ticks_until_next(last + (tuning.cadence_max_rest + 1) * BEAT)))
	assert_false(circle.cadence.has_lapsed(last + 3 * BEAT, tuning))
	assert_true(circle.cadence.has_lapsed(last + 20 * BEAT, tuning))


func test_there_is_no_beat_before_the_first_cast() -> void:
	circle.prepare(FIRE_BOLT)
	assert_true(is_nan(circle.ticks_until_next(START)))
	assert_true(circle.cadence.has_lapsed(START, tuning))
	assert_true(is_nan(circle.cadence.ticks_until_beat(START)))


func test_the_next_beat_is_never_the_one_the_last_stroke_fell_on() -> void:
	_cast(FIRE_BOLT, START)
	var last := START + FIRE_BOLT.strokes[-1].tick * BEAT
	assert_almost_eq(circle.cadence.next_beat_after(last - 5 * BEAT), float(last + BEAT), 1.0)
	assert_almost_eq(circle.cadence.next_beat_after(last + 10), float(last + BEAT), 1.0)
	assert_almost_eq(circle.cadence.next_beat_after(last + BEAT + 10), float(last + 2 * BEAT), 1.0)


func test_a_circle_the_player_casts_on_says_when_the_cadence_has_lapsed() -> void:
	circle.accepts_input = true
	var lapses := [0]
	circle.cadence_lapsed.connect(func (): lapses[0] += 1)
	# Cast a moment ago by the clock on the wall, so fast that every beat
	# there could be has gone by.
	var quick := 2_000
	_cast(SPARK, Time.get_ticks_usec() - 200_000, quick)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(lapses[0], 1, "once, and not every frame")


func test_a_circle_an_npc_casts_on_does_not() -> void:
	# It keeps the NPC's time, and the clock on the wall says nothing about it.
	var lapses := [0]
	circle.cadence_lapsed.connect(func (): lapses[0] += 1)
	_cast(SPARK, 1_000, 2_000)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(lapses[0], 0)


# Saying so

func test_what_became_of_a_cast_is_said_in_words() -> void:
	_cast(FIRE_BOLT, START)
	assert_eq(circle.cadence.describe(tuning), "", "the first cast has nothing to be said of it")
	var second := _after(FIRE_BOLT, START, 2.0)
	_cast(FIRE_BOLT, second)
	assert_eq(circle.cadence.describe(tuning), "In cadence, 2 in a row: 5% stronger.")
	_cast(FIRE_BOLT, _after(FIRE_BOLT, second, 2.3))
	assert_eq(circle.cadence.describe(tuning), "Out of cadence: it began 0.30 of a tick late.")

	circle.cadence.drop()
	_cast(FIRE_BOLT, START)
	_cast(FIRE_BOLT, _after(FIRE_BOLT, START, 1.75))
	assert_eq(circle.cadence.describe(tuning), "Out of cadence: it began 0.25 of a tick early.")

	circle.cadence.drop()
	_cast(FIRE_BOLT, START)
	_cast(FIRE_BOLT, _after(FIRE_BOLT, START, 2.0), roundi(BEAT * 0.8))
	assert_eq(circle.cadence.describe(tuning), "Out of cadence: it was cast 20% faster than the last.")

	circle.cadence.drop()
	_cast(FIRE_BOLT, START)
	_cast(FIRE_BOLT, _after(FIRE_BOLT, START, 12.0))
	assert_eq(circle.cadence.describe(tuning), "Out of cadence: 12 beats went by, and 8 is the most.")


func test_the_verdict_survives_being_written_down() -> void:
	_cast(FIRE_BOLT, START)
	var result := _cast(FIRE_BOLT, _after(FIRE_BOLT, START, 2.0))
	var copy := CastResult.from_dict(JSON.parse_string(JSON.stringify(result.to_dict())))
	assert_eq(copy.cadence_links, 1)
	assert_almost_eq(copy.cadence_bonus, result.cadence_bonus)
	assert_almost_eq(copy.potency, result.potency)
	assert_almost_eq(copy.origin_usec, result.origin_usec, 1.0)


func test_the_practice_panel_says_what_the_cadence_was_worth() -> void:
	_cast(FIRE_BOLT, START)
	assert_eq(ResultPanel.summary_text(circle.last_result), "Quality 100%, cast at 100% potency.")
	var result := _cast(FIRE_BOLT, _after(FIRE_BOLT, START, 2.0))
	assert_eq(ResultPanel.summary_text(result), "Quality 100%, cast at 105% potency.\nIn cadence, 2 in a row: 5% of that is for keeping the beat.")


# The beat is fitted, as the tempo is

func test_the_beat_is_where_the_cast_was_and_not_where_its_first_stroke_was() -> void:
	# A first stroke that is late, in a cast that is otherwise on the beat,
	# is one stroke off and not the whole cast.
	_cast(LIGHTNING, START)
	var second := _after(LIGHTNING, START, 2.0)
	circle.prepare(LIGHTNING)
	for i in LIGHTNING.strokes.size():
		var stroke := LIGHTNING.strokes[i]
		var late := roundi(0.3 * BEAT) if i == 0 else 0
		circle.strike(stroke.rune, stroke.position, second + stroke.tick * BEAT + late)
	assert_eq(circle.cadence.verdict, Cadence.Verdict.FOLLOWED)
	assert_lt(absf(circle.cadence.entry), 0.15, "where a cast judged by its first stroke would be 0.3 off")


func test_a_cast_begun_with_no_thought_for_the_beat_seldom_follows() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var followed := 0
	var casts := 400
	for cast in casts:
		circle.cadence.drop()
		_cast(FIRE_BOLT, START)
		_cast(FIRE_BOLT, _after(FIRE_BOLT, START, rng.randf_range(1.0, 6.0)))
		if circle.cadence.verdict == Cadence.Verdict.FOLLOWED:
			followed += 1
	assert_between(float(followed) / casts, 0.2, 0.4, "three in ten, by the width of the window")
	# And to do it twice running is rarer, which is why the first link is
	# worth little and the later ones are worth more.
	assert_lt(pow(2.0 * tuning.cadence_entry_window, 3.0), 0.03)
