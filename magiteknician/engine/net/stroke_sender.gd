class_name StrokeSender
extends Node
## Watches a spell circle and says, in messages, what is being cast on it.
##
## Give the messages to a RemoteCaster on another machine and its circle
## will show the same cast, stroke for stroke.

## A message is ready to be sent.
signal message(contents: Dictionary)

var circle: SpellCircle:
	set(value):
		if circle != null:
			circle.cast_started.disconnect(_on_cast_started)
			circle.stroke_landed.disconnect(_on_stroke_landed)
			circle.stroke_strayed.disconnect(_on_stroke_strayed)
			circle.cast_abandoned.disconnect(_on_cast_abandoned)
		circle = value
		if circle != null:
			circle.cast_started.connect(_on_cast_started)
			circle.stroke_landed.connect(_on_stroke_landed)
			circle.stroke_strayed.connect(_on_stroke_strayed)
			circle.cast_abandoned.connect(_on_cast_abandoned)

# When the first stroke of the cast in progress landed, by the clock the
# strokes are stamped with. Offsets are counted from here.
var _started_usec: int = 0
var _has_started: bool = false


func _on_cast_started(spell: Spell) -> void:
	_has_started = false
	message.emit(DuelProtocol.begin(spell))


func _on_stroke_landed(index: int, rune: Rune, timestamp_us: int) -> void:
	if not _has_started:
		_has_started = true
		_started_usec = timestamp_us
	# The mark is where the stroke landed; the rune is where it was meant to.
	var location: Vector2 = circle.actual.runes[index].position
	message.emit(DuelProtocol.stroke(rune.rune_type, location, timestamp_us - _started_usec))


func _on_stroke_strayed(rune_type: Rune.Type, location: Vector2) -> void:
	# A stray has no time that matters: it is counted, not scored. It is
	# sent with the time of the stroke before it.
	var offset: int = 0
	if _has_started and not circle.actual.runes.is_empty():
		offset = circle.actual.ticks[-1] - _started_usec
	message.emit(DuelProtocol.stroke(rune_type, location, offset))


func _on_cast_abandoned(_spell: Spell) -> void:
	_has_started = false
	message.emit(DuelProtocol.abandon())
