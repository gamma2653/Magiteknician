extends TestCase
## SpellCircle: a cast from its first stroke to its verdict.

const FIRE_BOLT := preload("res://magiteknician/spells/fire_bolt.tres")
const SPARK := preload("res://magiteknician/spells/spark.tres")
const BEAT := 300_000
const START := 10_000_000

var circle: SpellCircle
var events: Array


func before_each() -> void:
	circle = SpellCircle.new()
	circle.accepts_input = false
	add_managed(circle)
	events = []
	circle.prepared.connect(func (_spell): events.append("prepared"))
	circle.cast_started.connect(func (_spell): events.append("started"))
	circle.stroke_landed.connect(func (index, _rune, _time): events.append("landed %d" % [index]))
	circle.stroke_strayed.connect(func (_type, _location): events.append("strayed"))
	circle.cast_finished.connect(func (_spell, result): events.append("finished %s" % [result.grade_name]))
	circle.cast_abandoned.connect(func (_spell): events.append("abandoned"))


## Strikes stroke `index` of the circle's spell, on the beat unless nudged.
func _strike(index: int, nudge_in_ticks: float = 0.0, offset: Vector2 = Vector2.ZERO) -> SpellCircle.Outcome:
	var stroke := circle.spell.strokes[index]
	var time := START + int((stroke.tick + nudge_in_ticks) * BEAT)
	return circle.strike(stroke.rune, stroke.position + offset, time)


func _cast_all(nudges_in_ticks: Array = []) -> void:
	for i in circle.spell.strokes.size():
		_strike(i, nudges_in_ticks[i] if i < nudges_in_ticks.size() else 0.0)


func test_an_empty_circle_ignores_strokes() -> void:
	assert_eq(circle.state, SpellCircle.State.EMPTY)
	assert_eq(circle.strike(Rune.Type.FLOW, Vector2.ZERO, START), SpellCircle.Outcome.IGNORED)
	assert_eq(events, [])


func test_preparing_a_spell_lays_out_its_ghosts() -> void:
	circle.prepare(FIRE_BOLT)
	assert_eq(circle.state, SpellCircle.State.READY)
	assert_eq(events, ["prepared"])
	var ghosts := circle.expected.bound_runes
	assert_eq(ghosts.size(), FIRE_BOLT.strokes.size())
	assert_eq(ghosts[0].look, Rune.Look.NEXT, "the first rune is marked as next")
	for i in range(1, ghosts.size()):
		assert_eq(ghosts[i].look, Rune.Look.GHOST)


func test_a_clean_cast_runs_from_start_to_verdict() -> void:
	circle.prepare(SPARK)
	_cast_all()
	assert_eq(events, ["prepared", "started", "landed 0", "landed 1", "landed 2", "finished S"])
	assert_not_null(circle.last_result)
	assert_eq(circle.last_result.stroke_count, 3)
	assert_almost_eq(circle.last_result.usec_per_tick, BEAT, 0.001)
	assert_eq(circle.last_result.strays, 0)


func test_the_next_rune_advances_with_each_stroke() -> void:
	circle.prepare(FIRE_BOLT)
	_strike(0)
	_strike(1)
	var ghosts := circle.expected.bound_runes
	assert_eq(circle.state, SpellCircle.State.CASTING)
	assert_eq(ghosts[0].look, Rune.Look.STRUCK)
	assert_eq(ghosts[1].look, Rune.Look.STRUCK)
	assert_eq(ghosts[2].look, Rune.Look.NEXT)
	assert_eq(ghosts[3].look, Rune.Look.GHOST)
	assert_eq(circle.actual.runes.size(), 2, "one mark for each stroke so far")


func test_the_wrong_rune_is_a_stray() -> void:
	circle.prepare(FIRE_BOLT)
	_strike(0)
	var next := FIRE_BOLT.strokes[1]
	assert_ne(next.rune, Rune.Type.PERSISTENCE)
	var outcome := circle.strike(Rune.Type.PERSISTENCE, next.position, START + BEAT)
	assert_eq(outcome, SpellCircle.Outcome.STRAY)
	assert_eq(circle.strays, 1)
	assert_eq(circle.expected.current_index, 1, "the cast has not moved on")


func test_the_right_rune_in_the_wrong_place_is_a_stray() -> void:
	circle.prepare(FIRE_BOLT)
	_strike(0)
	var outcome := _strike(1, 0.0, Vector2(Rune.RADIUS + 1.0, 0))
	assert_eq(outcome, SpellCircle.Outcome.STRAY)
	assert_eq(_strike(1, 0.0, Vector2(Rune.RADIUS - 1.0, 0)), SpellCircle.Outcome.HIT, "just inside still counts")


func test_striking_a_later_rune_early_is_a_stray() -> void:
	circle.prepare(FIRE_BOLT)
	_strike(0)
	assert_eq(_strike(3), SpellCircle.Outcome.STRAY)


func test_strokes_before_the_cast_begins_are_ignored() -> void:
	circle.prepare(FIRE_BOLT)
	assert_eq(circle.strike(Rune.Type.PERSISTENCE, Vector2(999, 999), START), SpellCircle.Outcome.IGNORED)
	assert_eq(circle.strays, 0)
	assert_eq(circle.state, SpellCircle.State.READY)


func test_strays_weaken_the_cast() -> void:
	circle.prepare(SPARK)
	_cast_all()
	var clean := circle.last_result
	_strike(0)
	circle.strike(Rune.Type.PERSISTENCE, Vector2(999, 999), START)
	circle.strike(Rune.Type.PERSISTENCE, Vector2(999, 999), START)
	_strike(1)
	_strike(2)
	assert_eq(circle.last_result.strays, 2)
	assert_lt(circle.last_result.quality, clean.quality)


func test_striking_off_centre_weakens_the_cast() -> void:
	circle.prepare(SPARK)
	_cast_all()
	var centred := circle.last_result
	for i in SPARK.strokes.size():
		_strike(i, 0.0, Vector2(Rune.RADIUS * 0.9, 0))
	assert_lt(circle.last_result.aim_score, centred.aim_score)
	assert_lt(circle.last_result.quality, centred.quality)
	assert_almost_eq(circle.last_result.rhythm_score, 1.0, 0.0001, "the rhythm was untouched")


func test_the_spell_is_laid_out_again_after_a_cast() -> void:
	circle.prepare(SPARK)
	_cast_all()
	assert_eq(circle.state, SpellCircle.State.READY)
	assert_eq(circle.expected.current_index, 0)
	assert_eq(circle.actual.runes.size(), 3, "the marks linger to show the verdict")
	_strike(0)
	assert_eq(circle.actual.runes.size(), 1, "and are cleared when the next cast begins")
	assert_eq(circle.strays, 0)


func test_a_circle_can_be_told_not_to_lay_the_spell_out_again() -> void:
	circle.rearm_after_cast = false
	circle.prepare(SPARK)
	_cast_all()
	assert_eq(circle.state, SpellCircle.State.SPENT)
	assert_eq(_strike(0), SpellCircle.Outcome.IGNORED)


func test_every_cast_is_judged_on_its_own() -> void:
	circle.prepare(FIRE_BOLT)
	_cast_all([0.0, 0.3, -0.3, 0.3, 0.0])
	var rough := circle.last_result
	_cast_all()
	assert_gt(circle.last_result.quality, rough.quality)
	assert_eq(circle.last_result.grade, CastResult.Grade.S)


func test_marks_show_their_judgement() -> void:
	circle.prepare(FIRE_BOLT)
	_strike(0)
	assert_null(circle.actual.runes[0].judgement, "nothing is judged until the cast is over")
	for i in range(1, FIRE_BOLT.strokes.size()):
		_strike(i, 0.35 if i == 2 else 0.0)
	var marks := circle.actual.runes
	assert_eq(marks.size(), circle.last_result.stroke_count)
	for i in marks.size():
		assert_eq(marks[i].judgement, circle.last_result.judgements[i])


func test_marks_fade_away_after_the_verdict() -> void:
	circle.prepare(SPARK)
	_cast_all()
	assert_eq(circle.actual.runes.size(), 3)
	var wait := ActualTrain.LINGER_SECONDS + ActualTrain.FADE_SECONDS + 0.3
	await get_tree().create_timer(wait).timeout
	assert_eq(circle.actual.runes.size(), 0)


func test_abandoning_a_cast_starts_the_spell_over() -> void:
	circle.prepare(FIRE_BOLT)
	_strike(0)
	_strike(1)
	circle.strike(Rune.Type.PERSISTENCE, Vector2(999, 999), START)
	circle.abandon()
	assert_eq(circle.state, SpellCircle.State.READY)
	assert_eq(circle.expected.current_index, 0)
	assert_eq(circle.actual.runes.size(), 0)
	assert_eq(circle.strays, 0)
	assert_eq(events[-1], "abandoned")
	assert_null(circle.last_result, "an abandoned cast is not judged")


func test_abandoning_when_nothing_is_being_cast_does_nothing() -> void:
	circle.prepare(FIRE_BOLT)
	circle.abandon()
	assert_eq(events, ["prepared"])


func test_preparing_another_spell_drops_the_cast_in_progress() -> void:
	circle.prepare(FIRE_BOLT)
	_strike(0)
	circle.prepare(SPARK)
	assert_eq(circle.state, SpellCircle.State.READY)
	assert_eq(circle.expected.bound_runes.size(), SPARK.strokes.size())
	assert_eq(circle.actual.runes.size(), 0)
	_cast_all()
	assert_eq(circle.last_result.stroke_count, SPARK.strokes.size())


func test_the_tempo_can_be_read_part_way_through() -> void:
	circle.prepare(FIRE_BOLT)
	_strike(0)
	_strike(1)
	_strike(2)
	var fit := circle.fit_so_far()
	assert_eq(fit.stroke_count, 3)
	assert_almost_eq(fit.usec_per_tick, BEAT, 0.001)
	var next_tick := FIRE_BOLT.strokes[3].tick
	assert_almost_eq(fit.predict_usec(next_tick), START + next_tick * BEAT, 1.0)


func test_a_spell_drawn_in_the_editor_is_cast_like_any_other() -> void:
	var level: Level = add_managed(load("res://magiteknician/levels/level1.tscn").instantiate())
	var drawn := level.circle
	assert_eq(drawn.state, SpellCircle.State.READY)
	assert_eq(drawn.spell.ticks(), [0, 1, 3])
	drawn.accepts_input = false
	for stroke in drawn.spell.strokes:
		drawn.strike(stroke.rune, stroke.position, START + stroke.tick * BEAT)
	assert_not_null(drawn.last_result)
	assert_eq(drawn.last_result.grade, CastResult.Grade.S)
