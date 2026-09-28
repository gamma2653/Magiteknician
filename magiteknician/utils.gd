#This houses functions for analyzing user inputs and computing scores
extends Node
class_name Util

## Time-scale control
#static var start_time_us = Time.get_ticks_usec()
#static func reset_start_time_us():
	#start_time_us = Time.get_ticks_usec()

static func init_array(size: int = 10, default_value: Variant = 0):
	var arr = []
	arr.resize(size)
	arr.fill(default_value)
	return arr

static func add_(x, y):
	return x+y

static func sum(iter: Array):
	if iter.is_empty():
		return 0
	return iter.reduce(add_)

static func avg(iter: Array):
	if iter.is_empty():
		return 0
	# float() first: an array of ints would otherwise divide as integers.
	return float(sum(iter))/iter.size()

static func median(iter: Array):
	if iter.is_empty():
		return 0
	var sorted_ = iter.duplicate()
	sorted_.sort()
	@warning_ignore("integer_division")  # (yes gdscript, we know. It's an idx)
	var middle = sorted_.size()/2
	var odd = bool(sorted_.size() % 2)
	if odd:
		# Simple case
		return sorted_[middle]
	else:
		return avg([sorted_[middle-1], sorted_[middle]])

static func apply(func_: Callable, iterable: Array, inplace = false):
	if not func_.is_valid():
		return []
	if inplace:
		for i in iterable.size():
			iterable[i] = func_.call(iterable[i])
		return iterable
	else:
		var result = []
		for el in iterable:
			result.append(func_.call(el))
		return result

enum BinPolicy {
	## Indicates that the binary accumulator should include all elements.
	## If one array is longer than the other, apply the operation on the last
	## element of the shorter array, and complete the longer one to get an array
	## of the same length as the longer one.
	COMPLETE,
	## Indicates the binary accumulator should include all up to the shorter of
	## the two arrays, not processing elements past the largest index of the
	## shorter array.
	PARTIAL
}
const DEFAULT_POLICY = BinPolicy.COMPLETE


static func bin_apply(func_: Callable, iterable1: Array, iterable2: Array, policy: BinPolicy = DEFAULT_POLICY):
	if not func_.is_valid() or not iterable1 or not iterable2:
		return []
	var indexing_by = iterable1 if iterable1.size() <= iterable2.size() else iterable2
	var other = iterable2 if iterable1.size() <= iterable2.size() else iterable1
	var acc: Array = []
	for anchor_idx in indexing_by.size():
		acc.append(func_.call(indexing_by[anchor_idx], other[anchor_idx]))
	if policy == BinPolicy.COMPLETE:
		# Finish the indices of the longer array
		for additional_idx in other.size()-indexing_by.size():
			var idx = indexing_by.size()+additional_idx
			acc.append(abs(indexing_by[-1] - other[idx]))
	return acc

static func diff_(el1, el2):
	return abs(el1 - el2) as float

static func array_difference(arr1: Array, arr2: Array, policy: BinPolicy = DEFAULT_POLICY):
	return bin_apply(diff_, arr1, arr2, policy)

static func variance(arr: Array, avg_: Variant = null):
	if arr.is_empty():
		return 0
	if avg_ == null:
		avg_ = avg(arr)
	var squared_deviations = arr.map(func (el):
		return pow(el - avg_, 2)
	)
	return sum(squared_deviations) / arr.size()

static func time_stats(times1: Array[int], times2: Array[int]):
	var time_diffs = array_difference(times1, times2)
	var avg_time = avg(time_diffs)
	return {
		"avg": avg_time,
		"median": median(time_diffs),
		"var": variance(time_diffs, avg_time),
		"min": time_diffs.min(),
		"max": time_diffs.max(),
		"_diffs": time_diffs
	}

static func _pos_stats(posx1: Array, posy1: Array, posx2: Array, posy2: Array):
	var x_diff = array_difference(posx1, posx2)
	var y_diff = array_difference(posy1, posy2)
	# Calculate distance score
	var distance_callback = func(el1, el2):
		return pow((el1**2 + el2**2), 0.5)
	var distances = bin_apply(distance_callback, x_diff, y_diff)
	# Now stats of distances
	return {
		"avg": avg(distances),
		"median": median(distances),
		"var": variance(distances),
		"min": distances.min(),
		"max": distances.max(),
		"_distances": distances
	}

# TODO: not this
static func pos_stats(pos1: Array[Vector2], pos2: Array[Vector2]):
	# First, unzip the arrays
	var min_size = min(pos1.size(), pos2.size())
	if (pos1.size() != min_size):
		push_warning("position1 supplied to pos_stats is a different length.")
	if (pos2.size() != min_size):
		push_warning("position2 supplied to pos_stats is a different length.")
	var posx1: Array[float] = []
	var posy1: Array[float] = []
	var posx2: Array[float] = []
	var posy2: Array[float] = []
	for i in range(min_size):
		posx1.append(pos1[i].x)
		posy1.append(pos1[i].y)
		posx2.append(pos2[i].x)
		posy2.append(pos2[i].y)
	return _pos_stats(posx1, posy1, posx2, posy2)

## Scores how well the `actual` train followed the `expected` one.
## The expected train's ticks are unscaled; the actual train's are the
## timestamps its strokes landed at. See CastScorer for how they are compared.
static func compare(expected: Train, actual: Train) -> CastResult:
	var expected_locations = expected.locations
	var actual_locations = actual.locations
	var aim_errors: Array[float] = []
	for i in min(expected_locations.size(), actual_locations.size()):
		var distance = expected_locations[i].distance_to(actual_locations[i])
		aim_errors.append(distance / Rune.RADIUS)
	return CastScorer.score(expected.ticks, actual.ticks, aim_errors)
