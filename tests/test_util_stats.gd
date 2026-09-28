extends TestCase
## Util's statistics helpers.


func test_sum_adds_every_element() -> void:
	assert_eq(Util.sum([1, 2, 3, 4]), 10)
	assert_eq(Util.sum([]), 0, "empty arrays sum to zero")


func test_avg_of_integers_is_not_truncated() -> void:
	assert_almost_eq(Util.avg([1, 2]), 1.5)
	assert_almost_eq(Util.avg([2, 4, 6]), 4.0)
	assert_eq(Util.avg([]), 0, "empty arrays average to zero")


func test_median_of_odd_count_is_the_middle_value() -> void:
	assert_almost_eq(Util.median([5, 1, 3]), 3.0)
	assert_almost_eq(Util.median([7]), 7.0)


func test_median_of_even_count_is_the_mean_of_the_middle_pair() -> void:
	assert_almost_eq(Util.median([4, 1, 3, 2]), 2.5)


func test_median_does_not_reorder_its_input() -> void:
	var values := [3, 1, 2]
	Util.median(values)
	assert_eq(values, [3, 1, 2])


func test_variance_is_the_mean_squared_deviation() -> void:
	# Mean 5, deviations -3 -1 -1 -1 0 0 2 4, squares sum to 32.
	assert_almost_eq(Util.variance([2, 4, 4, 4, 5, 5, 7, 9]), 4.0)
	assert_almost_eq(Util.variance([3, 3, 3]), 0.0)
	assert_eq(Util.variance([]), 0, "empty arrays have no variance")


func test_variance_accepts_a_precomputed_mean() -> void:
	assert_almost_eq(Util.variance([1, 3], 2.0), 1.0)
	# A mean of exactly zero must be used, not mistaken for "not given".
	assert_almost_eq(Util.variance([-1, 1], 0.0), 1.0)


func test_time_stats_summarises_the_differences() -> void:
	var expected: Array[int] = [0, 10, 20]
	var actual: Array[int] = [1, 13, 20]
	var stats: Dictionary = Util.time_stats(expected, actual)
	assert_eq(stats["_diffs"], [1.0, 3.0, 0.0])
	assert_almost_eq(stats["avg"], 4.0 / 3.0)
	assert_almost_eq(stats["median"], 1.0)
	assert_almost_eq(stats["min"], 0.0)
	assert_almost_eq(stats["max"], 3.0)


func test_pos_stats_measures_distance_between_points() -> void:
	var expected: Array[Vector2] = [Vector2(0, 0), Vector2(10, 10)]
	var actual: Array[Vector2] = [Vector2(3, 4), Vector2(10, 10)]
	var stats: Dictionary = Util.pos_stats(expected, actual)
	assert_eq(stats["_distances"], [5.0, 0.0])
	assert_almost_eq(stats["avg"], 2.5)
	assert_almost_eq(stats["max"], 5.0)
