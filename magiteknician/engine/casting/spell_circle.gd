class_name SpellCircle
extends Node2D
## Where a spell is cast: the ghosts of its runes, the strokes that have
## landed on them, and the rules for getting from one to a verdict.
##
## Every stroke, whoever made it, arrives through strike(). The player's
## arrive from the keyboard and mouse; a test, an NPC or a remote opponent
## can call strike() with strokes of their own and be judged identically.
##
## Put runes under a child ExpectedTrain named "Expected" to cast a spell
## drawn in the editor, or set `spell` to cast one from a file.

## The circle has a spell on it and is waiting for the first stroke.
signal prepared(spell: Spell)
## The first rune of the spell was struck.
signal cast_started(spell: Spell)
## A stroke landed on the rune it was meant for.
signal stroke_landed(index: int, rune: Rune, timestamp_us: int)
## A stroke landed on nothing, or on the wrong rune, during a cast.
signal stroke_strayed(rune_type: Rune.Type, location: Vector2)
## The last rune was struck and the cast has been judged.
signal cast_finished(spell: Spell, result: CastResult)
## The caster gave up part-way through.
signal cast_abandoned(spell: Spell)

enum State {
	## No spell on the circle.
	EMPTY,
	## A spell is laid out; nothing has been struck yet.
	READY,
	## The first rune has been struck and the last has not.
	CASTING,
	## The cast is over and the circle was told not to lay the spell out again.
	SPENT,
}
enum Outcome {
	## The stroke did not count for or against anything.
	IGNORED,
	HIT,
	STRAY,
}

const ABANDON_ACTION := &"Cast-Abandon"
const BOUNDARY_COLOR := Color(0.75, 0.9, 1.0, 0.18)
const CURSOR_HOTSPOT := Vector2(0, 60)

## The spell to lay out when the circle enters the tree.
@export var spell: Spell
## How strictly casts are judged. Left empty, the default tuning is used.
@export var tuning: CastTuning
## Whether the circle listens to the keyboard and mouse. Turn it off for a
## circle that is driven by something other than the player.
@export var accepts_input: bool = true
## Whether the spell is laid out again as soon as a cast of it finishes.
@export var rearm_after_cast: bool = true

var state: State = State.EMPTY
var expected: ExpectedTrain
var actual: ActualTrain
## Strokes that have missed during the cast in progress.
var strays: int = 0
## The verdict on the most recently finished cast.
var last_result: CastResult

var _aim_errors: Array[float] = []
# Where the mouse was last seen, in the circle's own coordinates.
var _cursor: Vector2 = Vector2.ZERO
var _cursor_known: bool = false
# A spell drawn in the editor is laid out for its own scene and is free to
# ignore the circle's boundary.
var _drawn_in_editor: bool = false


func _ready() -> void:
	expected = get_node_or_null("Expected") as ExpectedTrain
	if expected == null:
		expected = ExpectedTrain.new()
		expected.name = "Expected"
		add_child(expected)
	actual = get_node_or_null("Actual") as ActualTrain
	if actual == null:
		actual = ActualTrain.new()
		actual.name = "Actual"
		add_child(actual)

	if spell == null and not expected.bound_runes.is_empty():
		# The spell was drawn in the editor. Read it off, so that from here
		# on there is one way of laying a spell out, not two.
		spell = Spell.from_train(expected)
		spell.id = &"drawn"
		spell.display_name = String(name)
		_drawn_in_editor = true
	if spell != null:
		prepare(spell)


## Lays `new_spell` out on the circle, dropping any cast in progress.
func prepare(new_spell: Spell) -> void:
	spell = new_spell
	actual.clear_runes()
	_reset_record()
	if spell == null:
		expected.load_spell(null)
		state = State.EMPTY
		queue_redraw()
		return
	for problem in spell.problems(not _drawn_in_editor):
		push_warning("%s: %s" % [spell.display_name, problem])
	expected.load_spell(spell)
	state = State.READY
	queue_redraw()
	prepared.emit(spell)


## Takes a stroke of `rune_type` made at `location`, in the circle's own
## coordinates, at `timestamp_us`.
func strike(rune_type: Rune.Type, location: Vector2, timestamp_us: int) -> Outcome:
	if state != State.READY and state != State.CASTING:
		return Outcome.IGNORED
	var target := expected.current_rune
	var on_target := target != null \
		and target.rune_type == rune_type \
		and target.contains(location)
	if not on_target:
		if state != State.CASTING:
			# Nothing has been started, so there is nothing to spoil.
			return Outcome.IGNORED
		strays += 1
		stroke_strayed.emit(rune_type, location)
		return Outcome.STRAY

	if state == State.READY:
		# Whatever is left of the previous cast's marks goes now.
		actual.clear_runes()
		_reset_record()
		state = State.CASTING
		cast_started.emit(spell)

	var index: int = expected.current_index
	_aim_errors.append(target.aim_error(location))
	actual.record(target, timestamp_us, location)
	target.strike(timestamp_us, location)
	expected.advance(timestamp_us, location)
	stroke_landed.emit(index, target, timestamp_us)
	if expected.is_complete():
		_finish()
	return Outcome.HIT


## Gives up on the cast in progress. The spell stays on the circle.
func abandon() -> void:
	if state != State.CASTING:
		return
	actual.clear_runes()
	_reset_record()
	expected.mute_audio()
	expected.rearm()
	state = State.READY
	cast_abandoned.emit(spell)


## The tempo of the cast in progress, fitted to the strokes so far.
func fit_so_far() -> RhythmFit:
	return RhythmFit.fit(expected.ticks, actual.ticks)


func _finish() -> void:
	last_result = Util.compare(expected, actual, _aim_errors, strays, tuning)
	actual.show_judgements(last_result)
	actual.fade_out()
	if rearm_after_cast:
		expected.rearm()
		state = State.READY
	else:
		state = State.SPENT
	cast_finished.emit(spell, last_result)


func _reset_record() -> void:
	strays = 0
	_aim_errors = []


func _input(event: InputEvent) -> void:
	# Remember where the mouse is from the events themselves. They say where
	# the cursor was when the key went down; asking the window afterwards
	# says where it has got to since.
	if event is InputEventMouse:
		_cursor = make_input_local(event).position
		_cursor_known = true


func _unhandled_input(event: InputEvent) -> void:
	if not accepts_input or event.is_echo():
		return
	if InputMap.has_action(ABANDON_ACTION) and event.is_action_pressed(ABANDON_ACTION):
		abandon()
		return
	for rune_type in Rune.Type.values():
		var action: StringName = Rune.RuneToActionID[rune_type]
		if event.is_action_pressed(action):
			var timestamp_us := Time.get_ticks_usec()
			_set_brush_down(true)
			strike(rune_type, cursor_position(), timestamp_us)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_released(action):
			_set_brush_down(false)
			return


## Where the cursor is, in the circle's own coordinates.
func cursor_position() -> Vector2:
	if _cursor_known:
		return _cursor
	return get_local_mouse_position()


func _set_brush_down(down: bool) -> void:
	var image: Texture2D = Loader.RESOURCES["img"]["mouse"]["brush_down" if down else "brush"]
	Input.set_custom_mouse_cursor(image, Input.CursorShape.CURSOR_ARROW, CURSOR_HOTSPOT)


func _draw() -> void:
	if spell == null or not spell.fits_circle():
		return
	draw_arc(Vector2.ZERO, Spell.CIRCLE_RADIUS + Rune.RADIUS, 0.0, TAU, 96, BOUNDARY_COLOR, 2.0, true)
