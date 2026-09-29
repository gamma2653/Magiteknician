class_name DuelRecorder
extends RefCounted
## Watches a duel and writes down what is done in it.
##
## It listens to the two spell circles, and not to the keyboard or to an
## NPC's mind. Whoever is casting, what reaches the circle is what is
## recorded, and it is what decides the duel.

## The duel is over and `recording` is the whole of it.
signal finished(recording: DuelRecording)

var recording := DuelRecording.new()
var duel: Duel

# What each side's strokes are timed from, by the clock they are timed by.
var _clock_began: Array[int] = [-1, -1]


## Records `duel` from now. Call it once the duel is set up and before it
## begins. `occasion` is what kind of duel it is, and `opponent_title` is
## what goes under the opponent's name.
func watch(duel_: Duel, occasion: String = "duel", opponent_title: String = "") -> void:
	duel = duel_
	recording.game_version = SelfCheck.version()
	recording.recorded_at = Time.get_datetime_string_from_system(false, false)
	recording.occasion = occasion
	recording.describe_side(DuelRecording.PLAYER, duel.player)
	recording.describe_side(DuelRecording.OPPONENT, duel.opponent, opponent_title)
	for side in [DuelRecording.PLAYER, DuelRecording.OPPONENT]:
		var circle := _circle(side)
		# A spell that was laid out before anybody was watching.
		if circle.spell != null:
			_on_prepared(circle.spell, side)
		circle.prepared.connect(_on_prepared.bind(side))
		circle.struck.connect(_on_struck.bind(side))
		circle.cast_abandoned.connect(_on_abandoned.bind(side))
	duel.finished.connect(_on_finished)


## The recording as far as the duel has got, for a duel that is left
## before it is over.
func so_far() -> DuelRecording:
	recording.seconds = duel.elapsed_seconds
	recording.mean_quality = duel.player_mean_quality()
	return recording


func _circle(side: int) -> SpellCircle:
	return duel.player_circle if side == DuelRecording.PLAYER else duel.opponent_circle


func _note(side: int, kind: DuelRecording.Kind, more: Dictionary = {}) -> void:
	if duel.is_over():
		return
	var event := {"t": duel.elapsed_seconds, "side": side, "kind": int(kind)}
	event.merge(more)
	recording.events.append(event)


func _on_prepared(spell: Spell, side: int) -> void:
	_note(side, DuelRecording.Kind.PREPARE, {"spell": String(spell.id)})


func _on_struck(rune_type: Rune.Type, location: Vector2, timestamp_us: int, side: int) -> void:
	if _clock_began[side] < 0:
		_clock_began[side] = timestamp_us
	_note(side, DuelRecording.Kind.STRIKE, {
		"rune": int(rune_type),
		"x": location.x,
		"y": location.y,
		"usec": timestamp_us - _clock_began[side] + DuelRecording.CLOCK_STARTS,
	})


func _on_abandoned(_spell: Spell, side: int) -> void:
	_note(side, DuelRecording.Kind.ABANDON)


func _on_finished(winner: Duelist, _loser: Duelist) -> void:
	recording.winner = DuelRecording.PLAYER if winner == duel.player else DuelRecording.OPPONENT
	finished.emit(so_far())
