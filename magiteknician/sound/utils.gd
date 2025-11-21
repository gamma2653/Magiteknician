#This houses functions for analyzing user inputs and computing scores
extends Node
class_name SoundUtil

static func sum(iter):
	var acc = 0.0
	for i in iter:
		acc += i
	return acc

static func avg(iter):
	return sum(iter)/iter.size()

static func median(iter: Array):
	var odd = bool(iter.size() % 2)
	if not odd:
		# Simple case
		return iter[iter.size()/2]
	else:
		return avg([iter[iter.size()], iter[iter.size()+1]])

static func time_difference(times1: Array[int], times2: Array[int]):
	if not times1 or not times2:
		return []
	# Index by the shorter of the two.
	var indexing_by = times1 if times1.size() <= times2.size() else times2
	var other = times2 if times1.size() <= times2.size() else times1
	var differences: Array[float] = []
	for anchor_idx in indexing_by.size():
		differences.append(abs(indexing_by[anchor_idx] - other[anchor_idx]) as float)
	# Finish for other times for uneven arrays
	for additional_idx in other.size()-indexing_by.size():
		var idx = indexing_by.size()+additional_idx
		differences.append(abs(indexing_by[-1] - other[idx]))
	return differences

static func time_var(time_differences):
	return pow(sum(time_differences), 2)


static func time_stats(times1: Array[int], times2: Array[int]):
	var time_diffs = time_difference(times1, times2)
	return {
		"avg": avg(time_diffs),
		"median": median(time_diffs),
		"var": time_var(time_diffs),
		"min": min(time_diffs),
		"max": max(time_diffs),
		"_diffs": time_diffs
	}

@abstract class ActionTrain:
	var times: Array[int] = []
	var location_xs: Array[float] = []
	var location_ys: Array[float] = []
	
	func compare_to(train: ActionTrain):
		
		pass

class ExpectedActionTrain extends ActionTrain:
	pass

class RealActionTrain extends ActionTrain:
	pass
# Schema:
	
