@tool
class_name Train  # Distinct from utils.gd/ActionTrain, as this is connected to display content
extends Node2D


func _ready():
	if mode == Util.TrainMode.EXPECTED and bound_runes:
		next_rune.set_transparency(0.1)


@export var mode: Util.TrainMode:
	set(val):
		mode = val
		update_configuration_warnings()

var runes: Array[Rune]:
	get:
		var _runes: Array[Rune]
		_runes.assign(get_children().filter(func (node):
			return node is Rune
		))
		return _runes
	set(new_runes):
		for child in get_children():
			if child is not Rune:
				continue
			# Remove rune children, deleting those not in new list
			remove_child(child)
			if child not in new_runes:
				child.queue_free()
		# Add children to tree
		for rune in new_runes:
			add_child(rune)

var bound_runes: Array[Rune]:
	get:
		var _runes: Array[Rune]
		_runes.assign(get_children().filter(func (node):
			return (node is Rune) and ((node as Rune).is_bound())
		))
		return _runes
	set(new_runes):
		for child in get_children():
			if not child is Rune or not (child as Rune).is_bound():
				continue
			# Only bound runes from here
			remove_child(child)
			if child not in new_runes:
				child.queue_free()

var next_rune: Rune:
	get:
		if mode == Util.TrainMode.EXPECTED:
			if not bound_runes:
				push_warning("Requested next_rune on an 'Expected' train, but no bound_runes.")
				return null
			return bound_runes[0]
		else:
			if not runes:
				push_warning("Requested next_rune on an 'Actual' train, but no runes.")
		return null

func to_action_train():
	var times_us: Array[int] = []
	var location_xs: Array[float] = []
	var location_ys: Array[float] = []
	for rune in runes:
		var pos = rune.position
		location_xs.append(pos[0])
		location_ys.append(pos[1])
		times_us.append(rune.unscaled_ticks)
	
	return Util.ModeToClass[mode].new(times_us, location_xs, location_ys)

func _get_configuration_warnings() -> PackedStringArray:
	var errors = []
	if mode == Util.TrainMode.ACTUAL:
		# Actuals bypass this check.
		return errors
	if not bound_runes:
		errors.append("No runes were found on this train. Please add a rune to make this train valid.")
	# check for timing coherency
	var curr_tick = -1
	for rune in bound_runes:
		if rune.unscaled_ticks <= curr_tick:
			errors.append("Rune [%s] does not pass the coherency check. Prior tick was %d, this one had %d." % [rune.name, curr_tick, rune.unscaled_ticks])
		curr_tick = rune.unscaled_ticks
	return errors

func _to_string() -> String:
	var _ret = "; ".join(runes.map(func (rune):
		return rune._to_string()
	))
	return "{%s}" % [_ret]
