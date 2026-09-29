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
## The first rune was struck but the gate would not let the cast begin.
signal cast_refused(spell: Spell)
## A stroke was made, whatever came of it. This is said before anything
## does come of it, so that whoever is writing strokes down has written
## this one down by the time it ends a duel.
signal struck(rune_type: Rune.Type, location: Vector2, timestamp_us: int)
## A stroke landed on the rune it was meant for.
signal stroke_landed(index: int, rune: Rune, timestamp_us: int)
## A stroke landed on nothing, or on the wrong rune, during a cast.
signal stroke_strayed(rune_type: Rune.Type, location: Vector2)
## The last rune was struck and the cast has been judged.
signal cast_finished(spell: Spell, result: CastResult)
## The caster gave up part-way through.
signal cast_abandoned(spell: Spell)
## So long has gone by since the last cast that the next cannot follow
## it. Said by a circle that the player casts on, which keeps the time of
## day; a circle that is cast on by an NPC keeps the NPC's time.
signal cadence_lapsed
## The demonstration sounded the rune at `index`.
signal demonstrated(index: int)
## The demonstration reached the end of the spell, or was cut short.
signal demonstration_ended(completed: bool)

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
	## The stroke would have begun a cast, and the gate refused it.
	REFUSED,
}

const ABANDON_ACTION := &"Cast-Abandon"
const LISTEN_ACTION := &"Cast-Listen"
## Tempo the demonstration plays at, unless told otherwise.
const DEMONSTRATION_USEC_PER_TICK := 330_000
## The tempo guide needs this many strokes before it knows the tempo.
const GUIDE_MIN_STROKES := 2
const STRAY_COLOR := Color(1.0, 0.35, 0.35)
const STRAY_SECONDS := 0.5
const STRAY_SIZE := 9.0
const BOUNDARY_COLOR := Color(0.75, 0.9, 1.0, 0.18)

## The spell to lay out when the circle enters the tree.
@export var spell: Spell
## How strictly casts are judged. Left empty, the default tuning is used.
@export var tuning: CastTuning
## Whether the circle listens to the keyboard and mouse. Turn it off for a
## circle that is driven by something other than the player.
@export var accepts_input: bool = true:
	set(value):
		accepts_input = value
		_update_cursor()
## Whether the spell is laid out again as soon as a cast of it finishes.
@export var rearm_after_cast: bool = true
## Whether a ring closes on the next rune to show when it falls due at the
## tempo the caster has set. It appears from the third stroke on; the first
## two are what set the tempo.
@export var show_tempo_guide: bool = true

## Asked, with the spell, whether a cast of it may begin. A duel uses this
## to refuse casts the caster has not the chi for. Left unset, every cast
## may begin.
var gate: Callable = Callable()

var state: State = State.EMPTY:
	set(value):
		state = value
		_update_cursor()
var expected: ExpectedTrain
var actual: ActualTrain
## The ink the cursor leaves behind it, on a circle the player casts on.
var trail: InkTrail
## Strokes that have missed during the cast in progress.
var strays: int = 0
## The verdict on the most recently finished cast.
var last_result: CastResult
## The beat that is kept from one cast on this circle to the next.
var cadence := Cadence.new()

var _aim_errors: Array[float] = []
# Where the mouse was last seen, in the circle's own coordinates.
var _cursor: Vector2 = Vector2.ZERO
var _cursor_known: bool = false
# A spell drawn in the editor is laid out for its own scene and is free to
# ignore the circle's boundary.
var _drawn_in_editor: bool = false
# True once the circle has its trains and its trail. Its state and whether
# it accepts input are both set before then, as the scene is loaded.
var _has_its_parts: bool = false
var _demonstrating: bool = false
var _demonstration_started_usec: int = 0
var _demonstration_usec_per_tick: int = DEMONSTRATION_USEC_PER_TICK
var _demonstration_index: int = 0
# Where strokes recently went astray, as [location, timestamp_usec].
var _stray_marks: Array = []
# True once it has been said that the cadence has lapsed.
var _lapse_was_told: bool = false


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
	# Last, so that it is drawn over the runes.
	trail = InkTrail.new()
	trail.name = "Trail"
	add_child(trail)
	_has_its_parts = true

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
	stop_demonstration()
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
	struck.emit(rune_type, location, timestamp_us)
	var target := expected.current_rune
	var on_target := target != null \
		and target.rune_type == rune_type \
		and target.contains(location)
	if not on_target:
		if state != State.CASTING:
			# Nothing has been started, so there is nothing to spoil.
			return Outcome.IGNORED
		strays += 1
		_stray_marks.append([location, Time.get_ticks_usec()])
		stroke_strayed.emit(rune_type, location)
		return Outcome.STRAY

	if state == State.READY and gate.is_valid() and not gate.call(spell):
		cast_refused.emit(spell)
		return Outcome.REFUSED

	stop_demonstration()
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
	if accepts_input:
		trail.splash(location, GameCursor.ink_of(rune_type))
	expected.advance(timestamp_us, location)
	_update_cursor()
	stroke_landed.emit(index, target, timestamp_us)
	if expected.is_complete():
		_finish()
	return Outcome.HIT


## Gives up on the cast in progress. The spell stays on the circle.
func abandon() -> void:
	stop_demonstration()
	if state != State.CASTING:
		return
	# A cast that is given up is not one the next can follow.
	cadence.drop()
	actual.clear_runes()
	_reset_record()
	expected.mute_audio()
	expected.rearm()
	state = State.READY
	cast_abandoned.emit(spell)


## The tempo of the cast in progress, fitted to the strokes so far.
func fit_so_far() -> RhythmFit:
	return RhythmFit.fit(expected.ticks, actual.ticks)


## How strictly casts on this circle are judged.
func tuning_in_use() -> CastTuning:
	return tuning if tuning != null else CastScorer.default_tuning()


## Ticks until the next rune falls due at the caster's own tempo, as of
## `now_usec`. Negative once it is overdue; NAN while there is no cast in
## progress or too few strokes to know the tempo.
##
## Between casts it is the ticks until the next beat of the last cast,
## for as long as the next cast could still follow it.
func ticks_until_next(now_usec: int) -> float:
	if state == State.READY and cadence.is_alive() and not cadence.has_lapsed(now_usec, tuning_in_use()):
		return cadence.ticks_until_beat(now_usec)
	if state != State.CASTING:
		return NAN
	var next := expected.current_rune
	var fit := fit_so_far()
	if next == null or fit.stroke_count < GUIDE_MIN_STROKES or fit.usec_per_tick <= 0.0:
		return NAN
	return (fit.predict_usec(next.unscaled_ticks) - now_usec) / fit.usec_per_tick


## Plays the spell through, sounding each rune on its tick, so its rhythm
## can be heard before it is attempted. Returns false if there is nothing
## to play or a cast is under way.
func demonstrate(usec_per_tick: int = DEMONSTRATION_USEC_PER_TICK) -> bool:
	if state != State.READY or usec_per_tick <= 0:
		return false
	stop_demonstration()
	_demonstrating = true
	_demonstration_usec_per_tick = usec_per_tick
	_demonstration_started_usec = Time.get_ticks_usec()
	_demonstration_index = 0
	return true


func is_demonstrating() -> bool:
	return _demonstrating


func stop_demonstration() -> void:
	if not _demonstrating:
		return
	_demonstrating = false
	if expected != null:
		expected.mute_audio()
	demonstration_ended.emit(false)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _demonstrating:
		_advance_demonstration(now)
	var next := expected.current_rune
	if next != null:
		next.ticks_until_due = ticks_until_next(now) if show_tempo_guide else NAN
	if accepts_input and not _lapse_was_told and cadence.is_alive() and state == State.READY \
			and cadence.has_lapsed(now, tuning_in_use()):
		_lapse_was_told = true
		cadence_lapsed.emit()
	if not _stray_marks.is_empty():
		_stray_marks = _stray_marks.filter(func (mark):
			return now - mark[1] < STRAY_SECONDS * 1_000_000
		)
		queue_redraw()


func _advance_demonstration(now_usec: int) -> void:
	var ghosts := expected.bound_runes
	var elapsed := now_usec - _demonstration_started_usec
	while _demonstration_index < ghosts.size():
		var ghost := ghosts[_demonstration_index]
		var first_tick: int = ghosts[0].unscaled_ticks
		if elapsed < (ghost.unscaled_ticks - first_tick) * _demonstration_usec_per_tick:
			return
		ghost.chime()
		ghost.flash()
		demonstrated.emit(_demonstration_index)
		_demonstration_index += 1
	_demonstrating = false
	demonstration_ended.emit(true)


func _finish() -> void:
	last_result = Util.compare(expected, actual, _aim_errors, strays, tuning)
	cadence.take(last_result, expected.ticks, tuning_in_use())
	_lapse_was_told = false
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
		if _is_aiming():
			trail.follow(_cursor)


func _unhandled_input(event: InputEvent) -> void:
	if not accepts_input or event.is_echo():
		return
	if InputMap.has_action(ABANDON_ACTION) and event.is_action_pressed(ABANDON_ACTION):
		abandon()
		return
	if InputMap.has_action(LISTEN_ACTION) and event.is_action_pressed(LISTEN_ACTION):
		demonstrate()
		get_viewport().set_input_as_handled()
		return
	for rune_type in Rune.Type.values():
		var action: StringName = Rune.RuneToActionID[rune_type]
		if event.is_action_pressed(action):
			var timestamp_us := Time.get_ticks_usec()
			GameCursor.press(true)
			strike(rune_type, cursor_position(), timestamp_us)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_released(action):
			GameCursor.press(false)
			return


## Where the cursor is, in the circle's own coordinates.
func cursor_position() -> Vector2:
	if _cursor_known:
		return _cursor
	return get_local_mouse_position()


# True while the player could strike a rune on this circle.
func _is_aiming() -> bool:
	return accepts_input and is_inside_tree() and (state == State.READY or state == State.CASTING)


# Gives the cursor the look that goes with what the circle is doing: the
# reticle while the player could strike a rune, and the pointer the rest of
# the time. The ink it trails is the colour of the rune to strike next.
func _update_cursor() -> void:
	if not _has_its_parts:
		return
	if not _is_aiming():
		GameCursor.point(self)
		StrokePace.settle(self)
		trail.clear()
		return
	var next := expected.current_rune
	trail.ink = GameCursor.ink_of(next.rune_type) if next != null else CursorArt.SAP
	GameCursor.aim(self)
	# And the keys are read closely, since the next stroke is timed.
	StrokePace.quicken(self)


func _exit_tree() -> void:
	GameCursor.point(self)
	StrokePace.settle(self)


func _draw() -> void:
	if spell != null and spell.fits_circle():
		draw_arc(Vector2.ZERO, Spell.CIRCLE_RADIUS + Rune.RADIUS, 0.0, TAU, 96, BOUNDARY_COLOR, 2.0, true)
	# A cross wherever a stroke went astray, fading as it ages.
	var now := Time.get_ticks_usec()
	for mark in _stray_marks:
		var age: float = (now - mark[1]) / (STRAY_SECONDS * 1_000_000)
		var color := STRAY_COLOR
		color.a = clampf(1.0 - age, 0.0, 1.0)
		var at: Vector2 = mark[0]
		var arm := Vector2(STRAY_SIZE, STRAY_SIZE)
		draw_line(at - arm, at + arm, color, 3.0, true)
		draw_line(at + Vector2(-arm.x, arm.y), at + Vector2(arm.x, -arm.y), color, 3.0, true)
