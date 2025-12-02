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
	return iter.reduce(add_)

static func avg(iter):
	return sum(iter) as Array[float]/iter.size()

static func median(iter: Array):
	var odd = bool(iter.size() % 2)
	if not odd:
		# Simple case
		@warning_ignore("integer_division")  # (yes gdscript, we know. It's an idx)
		return iter[iter.size()/2]
		# alternatively:
		#return iter[(iter.size() as float/2.0) as int]
	else:
		return avg([iter[iter.size()], iter[iter.size()+1]])

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
	if not avg_:
		avg_ = avg(arr)
	# Eh, optimize later
	var mean = init_array(arr.size(), avg_)
	return pow(array_difference(arr, mean), 2) / arr.size()

static func time_stats(times1: Array[int], times2: Array[int]):
	var time_diffs = array_difference(times1, times2)
	var avg_time = avg(time_diffs)
	return {
		"avg": avg_time,
		"median": median(time_diffs),
		"var": variance(time_diffs, avg_time),
		"min": min(time_diffs),
		"max": max(time_diffs),
		"_diffs": time_diffs
	}

static func pos_stats(posx1: Array, posy1: Array, posx2: Array, posy2: Array):
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
		"min": min(distances),
		"max": max(distances),
		"_distances": distances
	}


@abstract class ActionTrain extends GDScript:
	var unscaled_ticks: Array[int] = []
	var location_xs: Array[float] = []
	var location_ys: Array[float] = []
	
	func compare_to(train: ActionTrain):
		var timing_stats = Util.time_stats(self.unscaled_ticks, train.unscaled_ticks)
		var distance_stats = Util.pos_stats(
			self.location_xs, self.location_ys, train.location_xs, train.location_ys
		)
		print(timing_stats)
		print(distance_stats)
	
	func _init(times_us_: Array[int], location_xs_: Array[float], location_ys_: Array[float]):
		self.times_us = times_us_
		self.location_xs = location_xs_
		self.location_ys = location_ys_

enum TrainMode {
	EXPECTED,
	ACTUAL
}

class ExpectedActionTrain extends ActionTrain:
	pass

class RealActionTrain extends ActionTrain:
	pass
	#func normalize_to(train: ExpectedActionTrain):
		#


const ModeToClass: Dictionary[TrainMode, ActionTrain] = {
	TrainMode.EXPECTED: ExpectedActionTrain,
	TrainMode.ACTUAL: RealActionTrain
}
