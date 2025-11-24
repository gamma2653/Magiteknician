@tool
class_name Train  # Distinct from utils.gd/ActionTrain, as this is connected to display content
extends Node2D

@export var mode: Util.TrainMode

#Ahh, love me some caching
var _runes: Array[Rune] = []
var _bound_runes: Array[BoundRune] = []
var _runes_dirty: bool = false
var _ignore_child_updates: bool = false

func _ready():
	var mark_runes_dirty = func():
		if not _ignore_child_updates:
			_runes_dirty = true
	self.child_order_changed.connect(mark_runes_dirty)

## Does a full reset of the internal `_runes` and `_bound_runes` buffers, 
## reloading from tree.
func _get_runes():
	_runes.clear()
	_bound_runes.clear()
	for child in get_children():
		if child is Rune:
			_runes.append(child)
		if child is BoundRune:
			_bound_runes.append(child)
	return _runes

func clear_runes():
	var old_val = _ignore_child_updates
	_ignore_child_updates = true
	for rune in runes:
		remove_child(rune)
	_ignore_child_updates = old_val
	# courtesy update from tree
	_get_runes()
#
func clear_bound_runes():
	var old_val = _ignore_child_updates
	_ignore_child_updates = true
	for rune in bound_runes:
		remove_child(rune)
	_ignore_child_updates = old_val
	# courtesy update from tree
	_get_runes()


var runes: Array[Rune]:
	get:
		if not _runes_dirty:
			return _runes
		return _get_runes()
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
var bound_runes: Array[BoundRune]:
	get:
		if _runes_dirty:
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
		return errors
	if not bound_runes:
		errors.append("No runes were found on this train. Please add a rune to make this train valid.")
	#else:
		#var callback = func(v: Rune):
			#return Rune.RuneToID[v.rune_type]
		#errors.append(_runes.map(callback))

func _get_configuration_warnings() -> PackedStringArray:
	var errors = []
	_detect_runes(errors)
	print(errors)
	return errors
	
