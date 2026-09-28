extends TestCase
## CastScorer: from strokes to quality, grade and potency.

const BEAT := 400_000
const TICKS := [0, 1, 2, 4, 5]


func _times(nudges_in_ticks: Array = [], usec_per_tick: int = BEAT) -> Array:
	var times := []
	for i in TICKS.size():
		var nudge: float = nudges_in_ticks[i] if i < nudges_in_ticks.size() else 0.0
		times.append(int((TICKS[i] + nudge) * usec_per_tick))
	return times


func test_a_flawless_cast_has_full_quality_and_potency() -> void:
	var result := CastScorer.score(TICKS, _times())
	assert_almost_eq(result.rhythm_score, 1.0)
	assert_almost_eq(result.aim_score, 1.0)
	assert_almost_eq(result.quality, 1.0)
	assert_eq(result.grade, CastResult.Grade.S)
	assert_almost_eq(result.potency, CastScorer.default_tuning().potency_at_best)
	assert_false(result.fizzled)
	assert_eq(result.count_of(CastResult.Judgement.PERFECT), TICKS.size())
	assert_eq(result.duration_usec, 5 * BEAT)


func test_speed_alone_does_not_change_the_score() -> void:
	var nudges := [0.0, 0.06, -0.04, 0.1, -0.02]
	var slow := CastScorer.score(TICKS, _times(nudges, 1_000_000))
	var fast := CastScorer.score(TICKS, _times(nudges, 150_000))
	assert_almost_eq(slow.quality, fast.quality, 0.0001)
	assert_eq(slow.grade, fast.grade)
	assert_gt(slow.duration_usec, fast.duration_usec, "but the fast cast is over sooner")


func test_the_further_off_the_beat_the_weaker_the_spell() -> void:
	var previous := CastScorer.score(TICKS, _times())
	for wobble in [0.05, 0.1, 0.2, 0.4]:
		var result := CastScorer.score(TICKS, _times([0.0, wobble, -wobble, wobble, -wobble]))
		assert_lt(result.quality, previous.quality, "wobble %s" % [wobble])
		assert_true(result.potency <= previous.potency, "wobble %s" % [wobble])
		previous = result


func test_a_badly_mistimed_cast_fizzles() -> void:
	var result := CastScorer.score(TICKS, _times([0.0, 0.45, -0.45, 0.45, -0.45]))
	assert_true(result.fizzled)
	assert_eq(result.grade, CastResult.Grade.FIZZLE)
	assert_almost_eq(result.potency, 0.0)


func test_strokes_are_judged_individually() -> void:
	var result := CastScorer.score(TICKS, _times([0.0, 0.0, 0.0, 0.3, 0.0]))
	var worst := 0
	for i in result.judgements.size():
		if absf(result.deviations[i]) > absf(result.deviations[worst]):
			worst = i
	assert_eq(worst, 3, "the late stroke stands out")
	assert_gt(result.deviations[3], 0.0)
	assert_true(result.judgements[3] > result.judgements[0], "and is judged worse than the first")


func test_sloppy_aim_costs_quality_but_less_than_rhythm() -> void:
	var tuning := CastScorer.default_tuning()
	var centred := CastScorer.score(TICKS, _times())
	var edges := CastScorer.score(TICKS, _times(), [1.0, 1.0, 1.0, 1.0, 1.0])
	assert_almost_eq(edges.aim_score, tuning.aim_edge_score)
	assert_almost_eq(edges.rhythm_score, 1.0)
	assert_lt(edges.quality, centred.quality)
	assert_almost_eq(edges.quality, lerpf(1.0, tuning.aim_edge_score, tuning.aim_weight))
	assert_false(edges.fizzled, "aim alone cannot ruin a well-timed cast")


func test_aim_errors_beyond_the_edge_are_clamped() -> void:
	var result := CastScorer.score(TICKS, _times(), [5.0, 5.0, 5.0, 5.0, 5.0])
	assert_almost_eq(result.aim_score, CastScorer.default_tuning().aim_edge_score)


func test_each_stray_stroke_costs_quality() -> void:
	var tuning := CastScorer.default_tuning()
	var clean := CastScorer.score(TICKS, _times())
	var one := CastScorer.score(TICKS, _times(), [], 1)
	var three := CastScorer.score(TICKS, _times(), [], 3)
	assert_almost_eq(one.quality, clean.quality - tuning.stray_penalty)
	assert_almost_eq(three.quality, clean.quality - 3 * tuning.stray_penalty)
	assert_eq(three.strays, 3)


func test_mashing_keys_fizzles_the_spell() -> void:
	var result := CastScorer.score(TICKS, _times(), [], 40)
	assert_almost_eq(result.quality, 0.0)
	assert_true(result.fizzled)


func test_an_unfinished_cast_fizzles() -> void:
	var result := CastScorer.score(TICKS, [0, BEAT, 2 * BEAT])
	assert_true(result.fizzled)
	assert_almost_eq(result.potency, 0.0)
	assert_eq(result.stroke_count, 0)


func test_short_spells_are_judged_on_aim_and_strays_only() -> void:
	var result := CastScorer.score([0, 1], [0, 987_654], [0.0, 1.0])
	assert_false(result.rhythm_was_measured)
	assert_almost_eq(result.rhythm_score, 1.0)
	assert_lt(result.quality, 1.0)
	assert_false(result.fizzled)


func test_a_custom_tuning_changes_the_verdict() -> void:
	var strict := CastTuning.new()
	strict.rhythm_tolerance = 0.03
	var nudges := [0.0, 0.08, -0.08, 0.08, -0.08]
	var lenient_result := CastScorer.score(TICKS, _times(nudges))
	var strict_result := CastScorer.score(TICKS, _times(nudges), [], 0, strict)
	assert_lt(strict_result.quality, lenient_result.quality)


func test_potency_rises_with_quality_and_is_zero_below_the_fizzle_line() -> void:
	var tuning := CastTuning.new()
	assert_almost_eq(tuning.potency(tuning.fizzle_below - 0.01), 0.0)
	assert_almost_eq(tuning.potency(tuning.fizzle_below), tuning.potency_at_worst)
	assert_almost_eq(tuning.potency(1.0), tuning.potency_at_best)
	assert_gt(tuning.potency(0.8), tuning.potency(0.6))


func test_judgement_windows() -> void:
	var tuning := CastTuning.new()
	assert_eq(tuning.judge(0.0), CastResult.Judgement.PERFECT)
	assert_eq(tuning.judge(-tuning.perfect_window), CastResult.Judgement.PERFECT)
	assert_eq(tuning.judge(tuning.great_window), CastResult.Judgement.GREAT)
	assert_eq(tuning.judge(-tuning.good_window), CastResult.Judgement.GOOD)
	assert_eq(tuning.judge(tuning.poor_window), CastResult.Judgement.POOR)
	assert_eq(tuning.judge(tuning.poor_window + 0.01), CastResult.Judgement.MISS)


func test_grades_follow_quality() -> void:
	var tuning := CastTuning.new()
	assert_eq(tuning.grade(1.0), CastResult.Grade.S)
	assert_eq(tuning.grade(tuning.grade_a), CastResult.Grade.A)
	assert_eq(tuning.grade(tuning.grade_b), CastResult.Grade.B)
	assert_eq(tuning.grade(tuning.grade_c), CastResult.Grade.C)
	assert_eq(tuning.grade(tuning.fizzle_below), CastResult.Grade.D)
	assert_eq(tuning.grade(0.0), CastResult.Grade.FIZZLE)


func test_a_result_survives_a_round_trip_through_a_dictionary() -> void:
	var original := CastScorer.score(TICKS, _times([0.0, 0.07, -0.12, 0.02, 0.2]), [0.1, 0.9, 0.3, 0.0, 0.5], 2)
	# Through JSON as well, since that is how it will be saved and sent.
	var restored := CastResult.from_dict(JSON.parse_string(JSON.stringify(original.to_dict())))
	assert_eq(restored.judgements, original.judgements)
	assert_eq(restored.strays, original.strays)
	assert_eq(restored.grade, original.grade)
	assert_eq(restored.duration_usec, original.duration_usec)
	assert_eq(restored.rhythm_was_measured, original.rhythm_was_measured)
	assert_almost_eq(restored.quality, original.quality)
	assert_almost_eq(restored.potency, original.potency)
	assert_almost_eq(restored.usec_per_tick, original.usec_per_tick, 0.001)
	for i in original.stroke_count:
		assert_almost_eq(restored.deviations[i], original.deviations[i])
		assert_almost_eq(restored.aim_errors[i], original.aim_errors[i])
