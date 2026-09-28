extends TestCase
## RhythmFit: recovering the caster's tempo and their deviation from it.

const HALF_SECOND := 500_000


## Timestamps for `ticks` played at a steady tempo, each stroke then nudged
## by the matching entry of `nudges_usec`.
func _play(ticks: Array, usec_per_tick: int, start_usec: int = 0, nudges_usec: Array = []) -> Array:
	var times := []
	for i in ticks.size():
		var nudge: int = nudges_usec[i] if i < nudges_usec.size() else 0
		times.append(start_usec + ticks[i] * usec_per_tick + nudge)
	return times


func test_a_steady_cast_has_no_deviation() -> void:
	var ticks := [0, 1, 2, 3]
	var fit := RhythmFit.fit(ticks, _play(ticks, HALF_SECOND))
	assert_true(fit.is_measurable)
	assert_almost_eq(fit.usec_per_tick, HALF_SECOND, 0.001)
	for deviation in fit.deviations:
		assert_almost_eq(deviation, 0.0)


func test_uneven_gaps_are_part_of_the_rhythm() -> void:
	# The last gap is twice the first. Played that way, it is on the beat.
	var ticks := [0, 1, 3]
	var fit := RhythmFit.fit(ticks, _play(ticks, HALF_SECOND))
	assert_almost_eq(fit.usec_per_tick, HALF_SECOND, 0.001)
	for deviation in fit.deviations:
		assert_almost_eq(deviation, 0.0)


func test_playing_uneven_gaps_evenly_is_off_the_beat() -> void:
	var fit := RhythmFit.fit([0, 1, 3], [0, HALF_SECOND, 2 * HALF_SECOND])
	var worst := 0.0
	for deviation in fit.deviations:
		worst = maxf(worst, absf(deviation))
	assert_gt(worst, 0.1)


func test_the_tempo_is_whatever_the_caster_chose() -> void:
	var ticks := [0, 2, 3, 6]
	var slow := RhythmFit.fit(ticks, _play(ticks, 900_000))
	var fast := RhythmFit.fit(ticks, _play(ticks, 120_000))
	assert_almost_eq(slow.usec_per_tick, 900_000.0, 0.001)
	assert_almost_eq(fast.usec_per_tick, 120_000.0, 0.001)
	assert_almost_eq(slow.ticks_per_minute(), 60_000_000.0 / 900_000.0, 0.001)


func test_deviation_is_the_same_at_any_tempo() -> void:
	# The same mistakes, as a share of a tick, at two very different speeds.
	var ticks := [0, 1, 2, 3, 4]
	var nudges_in_ticks := [0.0, 0.1, -0.05, 0.2, -0.1]
	var slow_nudges := nudges_in_ticks.map(func (n): return int(n * 800_000))
	var fast_nudges := nudges_in_ticks.map(func (n): return int(n * 200_000))
	var slow := RhythmFit.fit(ticks, _play(ticks, 800_000, 0, slow_nudges))
	var fast := RhythmFit.fit(ticks, _play(ticks, 200_000, 0, fast_nudges))
	for i in ticks.size():
		assert_almost_eq(slow.deviations[i], fast.deviations[i], 0.0001)


func test_when_the_cast_started_does_not_matter() -> void:
	var ticks := [0, 1, 2, 4]
	var nudges := [0, 30_000, -20_000, 10_000]
	var early := RhythmFit.fit(ticks, _play(ticks, HALF_SECOND, 0, nudges))
	# About eleven days of uptime.
	var late := RhythmFit.fit(ticks, _play(ticks, HALF_SECOND, 1_000_000_000_000, nudges))
	assert_almost_eq(early.usec_per_tick, late.usec_per_tick, 0.01)
	for i in ticks.size():
		assert_almost_eq(early.deviations[i], late.deviations[i], 0.0001)


func test_a_late_stroke_deviates_positively() -> void:
	var ticks := [0, 1, 2, 3, 4]
	var fit := RhythmFit.fit(ticks, _play(ticks, HALF_SECOND, 0, [0, 0, 100_000, 0, 0]))
	assert_gt(fit.deviations[2], 0.0)
	var early := RhythmFit.fit(ticks, _play(ticks, HALF_SECOND, 0, [0, 0, -100_000, 0, 0]))
	assert_lt(early.deviations[2], 0.0)


func test_rushing_the_whole_cast_is_a_tempo_not_a_mistake() -> void:
	# Every gap 10% shorter than some reference: simply a faster cast.
	var ticks := [0, 1, 2, 3]
	var fit := RhythmFit.fit(ticks, _play(ticks, 450_000))
	for deviation in fit.deviations:
		assert_almost_eq(deviation, 0.0)


func test_two_strokes_cannot_be_off_the_beat() -> void:
	var fit := RhythmFit.fit([0, 3], [0, 1_234_567])
	assert_false(fit.is_measurable)
	assert_almost_eq(fit.usec_per_tick, 1_234_567.0 / 3.0, 0.001)
	assert_eq(fit.deviations, [0.0, 0.0])


func test_one_stroke_has_no_tempo() -> void:
	var fit := RhythmFit.fit([0], [42])
	assert_false(fit.is_measurable)
	assert_almost_eq(fit.usec_per_tick, 0.0)
	assert_almost_eq(fit.ticks_per_minute(), 0.0)
	assert_eq(fit.deviations, [0.0])


func test_no_strokes_is_an_empty_fit() -> void:
	var fit := RhythmFit.fit([], [])
	assert_false(fit.is_measurable)
	assert_eq(fit.stroke_count, 0)
	assert_eq(fit.deviations, [])


func test_a_cast_in_progress_is_fitted_on_the_strokes_so_far() -> void:
	var ticks := [0, 1, 2, 3, 4]
	var fit := RhythmFit.fit(ticks, [0, HALF_SECOND, 2 * HALF_SECOND])
	assert_eq(fit.stroke_count, 3)
	assert_almost_eq(fit.usec_per_tick, HALF_SECOND, 0.001)
	assert_almost_eq(fit.predict_usec(3), 3.0 * HALF_SECOND, 0.001)
	assert_almost_eq(fit.predict_usec(4), 4.0 * HALF_SECOND, 0.001)
