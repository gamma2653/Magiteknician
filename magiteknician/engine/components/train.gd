@tool
class_name Train  # Distinct from utils.gd/ActionTrain, as this is connected to display content
extends Node2D

@export var mode: Util.TrainMode:
	set(val):
		mode = val
		update_configuration_warnings()

#Ahh, love me some caching
var _runes: Array[Rune] = []
var _bound_runes: Array[Rune] = []
var _runes_dirty: bool = true  # Prompt a refresh on first read
var _ignore_child_updates: bool = false

func _mark_runes_dirty():
	if not _ignore_child_updates:
		_runes_dirty = true
	update_configuration_warnings()

func _ready():
	self.child_order_changed.connect(_mark_runes_dirty)

## Does a full reset of the internal `_runes` and `_bound_runes` buffers, 
## reloading from tree.
func _get_runes():
	_runes.clear()
	_bound_runes.clear()
	for child in get_children():
		if child is Rune:
			_runes.append(child)
			if child.is_bound():
				_bound_runes.append(child)
	_runes_dirty = false
	update_configuration_warnings()
	return _runes

func clear_runes():
	var old_val = _ignore_child_updates
	_ignore_child_updates = true
	for rune in runes:
		remove_child(rune)
	_ignore_child_updates = old_val
	## courtesy update from tree
	#_get_runes()
#
func clear_bound_runes():
	var old_val = _ignore_child_updates
	_ignore_child_updates = true
	for rune in bound_runes:
		remove_child(rune)
	_ignore_child_updates = old_val
	## courtesy update from tree
	#_get_runes()


var runes: Array[Rune]:
	get:
		if _runes_dirty: # or Engine.is_editor_hint():
			_get_runes()
		return _runes
	set(rune_arr):
		var old_ignore_val = _ignore_child_updates
		_ignore_child_updates = true
		clear_runes()
		for rune in rune_arr:
			add_child(rune)
		_ignore_child_updates = old_ignore_val
		# courtesy update from tree
		_get_runes()
#
var bound_runes: Array[Rune]:
	get:
		if _runes_dirty: # or Engine.is_editor_hint():
			_get_runes()
		return _bound_runes
	set(rune_arr):
		var old_ignore_val = _ignore_child_updates
		_ignore_child_updates = true
		clear_bound_runes()
		for rune in rune_arr:
			add_child(rune)
		_ignore_child_updates = old_ignore_val
		# courtesy update from tree
		_get_runes()

func to_action_train():
	var times_us: Array[int] = []
	var location_xs: Array[float] = []
	var location_ys: Array[float] = []
	for rune in runes:
		var pos = rune.position
		location_xs.append(pos[0])
		location_ys.append(pos[1])
		times_us.append(rune.time_us)
	
	return Util.ModeToClass[mode].new(times_us, location_xs, location_ys)

func _detect_runes(errors = null):
	if errors == null:
		errors = []
	if mode == Util.TrainMode.ACTUAL:
		# Actuals bypass this check.
		return
	if not bound_runes:
		errors.append("No runes were found on this train. Please add a rune to make this train valid.")
	# check for timing coherency
	var curr_tick = -1
	for rune in bound_runes:
		if rune.unscaled_ticks <= curr_tick:
			errors.append("Rune [%s] does not pass the coherency check. Prior tick was %d, this one had %d." % [rune.name, curr_tick, rune.unscaled_ticks])
		curr_tick = rune.unscaled_ticks
	#print(runes)
	#print(bound_runes)
	return

func _get_configuration_warnings() -> PackedStringArray:
	var errors = []
	_detect_runes(errors)
	return errors
	
