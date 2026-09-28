@tool
extends Train
class_name ExpectedTrain

signal progress
signal reset

## Spells can be drawn in the editor: place runes under this train, set
## their ticks, and save them to the file named here. The train's own origin
## is the centre of the spell circle.
@export_group("Spell authoring")
@export_file("*.tres") var spell_path: String = ""
@export_tool_button("Save runes to spell file", "Save") var _save_action = save_as_spell
@export_tool_button("Load runes from spell file", "Load") var _load_action = load_from_spell_path

var current_tick = 0
## The spell this train was last built from. Null for a train whose runes
## were placed by hand in the editor.
var spell: Spell

func _ready():
	# Attach handlers of runes to actual train
	for rune in bound_runes:
		rune.pressed.connect(_on_rune_pressed)
	_arm_first_rune()

func _arm_first_rune():
	current_tick = 0
	if bound_runes:
		current_rune.set_transparency(0.1)
		current_rune.active = true

## Replaces the runes on this train with the strokes of `new_spell`.
func load_spell(new_spell: Spell):
	clear_runes()
	spell = new_spell
	if spell == null:
		return
	for stroke in spell.strokes:
		var rune = Rune.create(stroke.rune)
		rune.unscaled_ticks = stroke.tick
		rune.position = stroke.position
		add_child(rune)
		if Engine.is_editor_hint():
			# Without an owner the rune would neither show in the scene
			# dock nor be saved with the scene.
			rune.owner = get_tree().edited_scene_root
			continue
		rune.pressed.connect(_on_rune_pressed)
	if not Engine.is_editor_hint():
		_arm_first_rune()

## Writes the runes on this train to `path` as a Spell. If a spell is
## already saved there, its name, description and other details are kept
## and only its strokes are replaced.
func save_as_spell(path: String = spell_path) -> Error:
	if path.is_empty():
		push_warning("Set a spell path before saving the runes on this train.")
		return ERR_FILE_BAD_PATH
	var saved: Spell = null
	if ResourceLoader.exists(path):
		saved = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE) as Spell
	if saved == null:
		saved = Spell.new()
		saved.id = path.get_file().get_basename()
	saved.strokes = Spell.from_train(self).strokes
	for problem in saved.problems():
		push_warning("%s: %s" % [path, problem])
	return ResourceSaver.save(saved, path)

## Replaces the runes on this train with those of the spell at `spell_path`.
func load_from_spell_path() -> Error:
	if not ResourceLoader.exists(spell_path):
		push_warning("There is no spell at '%s'." % [spell_path])
		return ERR_FILE_NOT_FOUND
	var loaded = ResourceLoader.load(spell_path, "", ResourceLoader.CACHE_MODE_REPLACE) as Spell
	if loaded == null:
		push_warning("'%s' is not a spell." % [spell_path])
		return ERR_INVALID_DATA
	load_spell(loaded)
	return OK

func mute_audio():
	for rune in bound_runes:
		rune.audio_player.stop()

func emit_reset():
	reset.emit()
	mute_audio()
	

func next_rune():
	if not bound_runes:
		push_warning("Requested next_rune on an 'Expected' train, but no bound_runes.")
		return null
	bound_runes[current_tick].active = false
	current_tick += 1
	if current_tick >= bound_runes.size():
		current_tick = 0
		emit_reset()
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
