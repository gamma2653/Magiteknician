@tool
extends Train
class_name ExpectedTrain

signal progress
signal reset

var current_tick = 0

func _ready():
	if bound_runes:
		current_rune.set_transparency(0.1)
		current_rune.active = true
	# Attach handlers of runes to actual train
	for rune in bound_runes:
		rune.pressed.connect(_on_rune_pressed)

func next_rune():
	if not bound_runes:
		push_warning("Requested next_rune on an 'Expected' train, but no bound_runes.")
		return null
	bound_runes[current_tick].active = false
	current_tick += 1
	if current_tick >= bound_runes.size():
		current_tick = 0
		reset.emit()
	bound_runes[current_tick].active = true
	print(bound_runes[current_tick])
	return bound_runes[current_tick]

var current_rune:
	get:
		if not bound_runes:
			push_warning("Requested next_rune on an 'Expected' train, but no bound_runes.")
			return null
		return runes[current_tick]


func _get_configuration_warnings() -> PackedStringArray:
	var errors = []
	if not bound_runes:
		errors.append("No runes were found on this train. Please add a rune to make this train valid.")
	# check for timing coherency
	var curr_tick = -1
	for rune in bound_runes:
		if rune.unscaled_ticks <= curr_tick:
			errors.append("Rune [%s] does not pass the coherency check. Prior tick was %d, this one had %d." % [rune.name, curr_tick, rune.unscaled_ticks])
		curr_tick = rune.unscaled_ticks
	return errors

func _on_rune_pressed(rune: Rune, timestamp_us: int, location: Vector2):
	#print("Rune Pressed!")
	if rune != current_rune:
		return
	#print("for real")
	progress.emit(rune, timestamp_us, location)
	rune.set_transparency(0.0)
	var new_rune = next_rune()
	print(rune, new_rune)
	new_rune.set_transparency(0.1)
