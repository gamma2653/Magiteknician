extends TestCase
## The level wires its trains together so that completing the expected
## train yields a scored cast.

const LEVEL := preload("res://magiteknician/levels/level1.tscn")
const BEAT := 300_000

var level: Level


func before_each() -> void:
	level = add_managed(LEVEL.instantiate())


## Strikes every rune of the expected train in order. `nudges_in_ticks`
## moves individual strokes off the beat.
func _cast(nudges_in_ticks: Array = [], start_usec: int = 5_000_000) -> void:
	var runes := level.expected.bound_runes
	for i in runes.size():
		var nudge: float = nudges_in_ticks[i] if i < nudges_in_ticks.size() else 0.0
		var time := start_usec + int((runes[i].unscaled_ticks + nudge) * BEAT)
		level.expected._on_rune_pressed(runes[i], time, runes[i].position)


func test_completing_the_train_scores_the_cast() -> void:
	var results := []
	level.actual.scored.connect(func (result): results.append(result))
	_cast()
	assert_eq(results.size(), 1)
	var result: CastResult = results[0]
	assert_eq(result.stroke_count, level.expected.bound_runes.size())
	assert_eq(result.grade, CastResult.Grade.S)
	assert_almost_eq(result.usec_per_tick, BEAT, 0.001)
	assert_eq(level.actual.last_result, result)


func test_an_uneven_cast_scores_lower() -> void:
	_cast()
	var steady := level.actual.last_result
	_cast([0.0, 0.3, 0.0])
	var uneven := level.actual.last_result
	assert_lt(uneven.quality, steady.quality)


func test_each_cast_is_scored_on_its_own_strokes() -> void:
	_cast()
	_cast([], 60_000_000)
	assert_eq(level.actual.last_result.stroke_count, level.expected.bound_runes.size())
	assert_eq(level.actual.runes.size(), level.expected.bound_runes.size())
