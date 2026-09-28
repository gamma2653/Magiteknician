@tool
extends Train
class_name ExpectedTrain
## The train a caster is meant to follow: the ghosts of a spell's runes,
## joined in order by flow lines.
##
## It knows which rune comes next and draws the spell. It does not read
## input or keep time; a SpellCircle does that and tells it to advance.

## Emitted with (rune, timestamp_us, location) when a rune is struck.
signal progress
## Emitted when the train goes back to its first rune.
signal reset
## Emitted when the last rune has been struck.
signal completed

const FLOW_LINE_COLOR = Color(0.75, 0.9, 1.0, 0.3)
const FLOW_LINE_DONE_COLOR = Color(1.0, 0.95, 0.75, 0.8)
const FLOW_LINE_WIDTH = 2.0
## Radius of the pip drawn for each tick of rest between two runes.
const REST_PIP_RADIUS = 4.0

## Spells can be drawn in the editor: place runes under this train, set
## their ticks, and save them to the file named here. The train's own origin
## is the centre of the spell circle.
@export_group("Spell authoring")
@export_file("*.tres") var spell_path: String = ""
@export_tool_button("Save runes to spell file", "Save") var _save_action = save_as_spell
@export_tool_button("Load runes from spell file", "Load") var _load_action = load_from_spell_path

## Index, among the bound runes, of the rune to strike next.
var current_index = 0
## The spell this train was last built from. Null for a train whose runes
## were placed by hand in the editor.
var spell: Spell

func _ready():
	rearm()

func _process(_delta):
	# Runes get dragged around in the editor; keep the flow lines with them.
	if Engine.is_editor_hint():
		queue_redraw()

## Replaces the runes on this train with the strokes of `new_spell`.
func load_spell(new_spell: Spell):
	clear_runes()
	spell = new_spell
	if spell == null:
		rearm()
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
	rearm()

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

## Goes back to the first rune, ready for the spell to be cast again.
func rearm():
	current_index = 0
	_refresh_looks()
	reset.emit()

## The rune to strike next, or null once the train is complete.
var current_rune: Rune:
	get:
		var bound = bound_runes
		if current_index >= bound.size():
			return null
		return bound[current_index]

func is_complete() -> bool:
	return not bound_runes.is_empty() and current_index >= bound_runes.size()

## Moves on from the current rune, which was struck at `timestamp_us` with
## the cursor at `location`.
func advance(timestamp_us: int, location: Vector2):
	var struck = current_rune
	if struck == null:
		push_warning("Asked to advance an 'Expected' train that has no rune left to strike.")
		return
	current_index += 1
	_refresh_looks()
	progress.emit(struck, timestamp_us, location)
	if is_complete():
		completed.emit()

func _refresh_looks():
	var bound = bound_runes
	for i in bound.size():
		var rune = bound[i]
		rune.active = i == current_index
		if i < current_index:
			rune.look = Rune.Look.STRUCK
		elif i == current_index:
			rune.look = Rune.Look.NEXT
		else:
			rune.look = Rune.Look.GHOST
	queue_redraw()

func _draw():
	var bound = bound_runes
	for i in range(1, bound.size()):
		var from = bound[i - 1]
		var to = bound[i]
		var length = from.position.distance_to(to.position)
		if length <= 2 * Rune.RADIUS:
			# The runes touch or overlap; there is no room for a line.
			continue
		var direction = (to.position - from.position) / length
		var start = from.position + direction * Rune.RADIUS
		var end = to.position - direction * Rune.RADIUS
		var color = FLOW_LINE_DONE_COLOR if i < current_index else FLOW_LINE_COLOR
		draw_line(start, end, color, FLOW_LINE_WIDTH, true)
		# One pip for each tick of rest, spaced as the ticks are in time.
		var gap = to.unscaled_ticks - from.unscaled_ticks
		for rest in range(1, gap):
			draw_circle(start.lerp(end, float(rest) / gap), REST_PIP_RADIUS, color, true, -1.0, true)

func _get_configuration_warnings() -> PackedStringArray:
	var errors = []
	if not bound_runes and spell_path.is_empty():
		errors.append("No runes were found on this train. Please add a rune to make this train valid.")
	# check for timing coherency
	var curr_tick = -1
	for rune in bound_runes:
		if rune.unscaled_ticks <= curr_tick:
			errors.append("Rune [%s] does not pass the coherency check. Prior tick was %d, this one had %d." % [rune.name, curr_tick, rune.unscaled_ticks])
		curr_tick = rune.unscaled_ticks
	return errors
