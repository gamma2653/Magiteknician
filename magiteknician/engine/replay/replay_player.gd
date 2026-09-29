class_name ReplayPlayer
extends Node
## Plays a recording of a duel.
##
## It fights the duel again. There is a real duel, with real duelists and
## the rules as they are, and the strokes that were recorded are made on
## its spell circles at the times they were made. What follows from them
## is worked out afresh, and comes out as it did.
##
## Time is let pass exactly up to each thing that was done, and then the
## thing is done. So it does not matter how long a frame is, nor how fast
## the recording is played.

## The recording has been played to its end.
signal finished

const SPEEDS: Array[float] = [0.25, 0.5, 1.0, 2.0, 4.0]

var recording: DuelRecording
var duel: Duel
var player_circle: SpellCircle
var opponent_circle: SpellCircle
## How fast it is played: 1 is as fast as it was fought.
var speed: float = 1.0
var is_paused: bool = false

var _next: int = 0
var _has_finished: bool = false


## Makes ready to play `recording_` on the two circles. Nothing happens
## until begin().
func setup(recording_: DuelRecording, player_circle_: SpellCircle, opponent_circle_: SpellCircle) -> void:
	recording = recording_
	player_circle = player_circle_
	opponent_circle = opponent_circle_
	_make_duel()


func begin() -> void:
	duel.begin()


## Goes back to the beginning.
func restart() -> void:
	_make_duel()
	duel.begin()


func is_over() -> bool:
	return _has_finished


## How far through the recording it is, from 0 to 1.
func progress() -> float:
	if recording == null or recording.seconds <= 0.0:
		return 0.0
	return clampf(duel.elapsed_seconds / recording.seconds, 0.0, 1.0)


## Plays the next speed faster, or slower if `faster` is false. Returns
## the speed it is now played at.
func change_speed(faster: bool) -> float:
	var at := SPEEDS.find(speed)
	if at < 0:
		at = SPEEDS.find(1.0)
	speed = SPEEDS[clampi(at + (1 if faster else -1), 0, SPEEDS.size() - 1)]
	return speed


func _process(delta: float) -> void:
	if not is_paused:
		advance(delta * speed)


## Lets `seconds` of the duel pass, doing whatever was done in them.
func advance(seconds: float) -> void:
	if duel == null or _has_finished or seconds <= 0.0:
		return
	var until := duel.elapsed_seconds + seconds
	while _next < recording.events.size() and not duel.is_over():
		var event := recording.events[_next]
		if float(event["t"]) > until:
			break
		duel.advance(float(event["t"]) - duel.elapsed_seconds)
		_next += 1
		_do(event)
	if not duel.is_over():
		duel.advance(until - duel.elapsed_seconds)
	if duel.is_over() or (_next >= recording.events.size() and duel.elapsed_seconds >= recording.seconds):
		_has_finished = true
		finished.emit()


func _do(event: Dictionary) -> void:
	var circle := player_circle if int(event["side"]) == DuelRecording.PLAYER else opponent_circle
	match int(event["kind"]):
		DuelRecording.Kind.PREPARE:
			circle.prepare(SpellLibrary.find(StringName(str(event["spell"]))))
		DuelRecording.Kind.STRIKE:
			circle.strike(int(event["rune"]) as Rune.Type, Vector2(float(event["x"]), float(event["y"])), int(event["usec"]))
		DuelRecording.Kind.ABANDON:
			circle.abandon()


func _make_duel() -> void:
	if duel != null:
		remove_child(duel)
		duel.queue_free()
	_next = 0
	_has_finished = false
	for circle: SpellCircle in [player_circle, opponent_circle]:
		circle.prepare(null)
		circle.cadence.drop()
	duel = Duel.new()
	duel.name = "Duel"
	add_child(duel)
	# This feeds the duel its time.
	duel.set_process(false)
	var casters: Array[ReplayCaster] = []
	for circle: SpellCircle in [player_circle, opponent_circle]:
		var caster := ReplayCaster.new()
		duel.add_child(caster)
		casters.append(caster)
	duel.setup(
		recording.duelist(DuelRecording.PLAYER), recording.duelist(DuelRecording.OPPONENT),
		player_circle, opponent_circle, casters[1], casters[0]
	)
