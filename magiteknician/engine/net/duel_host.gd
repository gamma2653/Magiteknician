class_name DuelHost
extends Node
## The side of a two-machine duel that runs it.
##
## The host owns the duel and decides what happens in it. Its own player
## casts at the keyboard; the guest's strokes arrive as messages and are
## put through a spell circle here. Everything the guest needs to know
## comes out of `outgoing`, and everything the guest sends goes into
## receive(). What carries the messages between the two is somebody
## else's business.

## A message is ready to be sent to the guest.
signal outgoing(contents: Dictionary)

## Seconds between one snapshot and the next while nothing is happening.
## A snapshot is also sent whenever a cast takes effect.
const SNAPSHOT_SECONDS := 0.25

var duel: Duel
var remote: RemoteCaster
var sender: StrokeSender

var _since_snapshot: float = 0.0


## Brings the duel together. `host_circle` is the one the player here
## casts on; `guest_circle` shows the guest's casts.
func setup(host: Duelist, guest: Duelist, host_circle: SpellCircle, guest_circle: SpellCircle) -> void:
	duel = Duel.new()
	add_child(duel)
	# This node feeds the duel its time, so that snapshots keep step with it.
	duel.set_process(false)
	remote = RemoteCaster.new()
	add_child(remote)
	sender = StrokeSender.new()
	add_child(sender)

	duel.setup(host, guest, host_circle, guest_circle, remote)
	sender.circle = host_circle
	sender.message.connect(func (contents): outgoing.emit(contents))
	remote.cast_lost.connect(func (spell, refused): outgoing.emit(DuelProtocol.broken(spell, refused)))
	duel.spell_resolved.connect(_on_spell_resolved)
	duel.finished.connect(_on_finished)


func begin() -> void:
	duel.begin()
	send_snapshot()


## Takes a message from the guest.
func receive(contents: Variant, arrival_usec: int = Time.get_ticks_usec()) -> void:
	remote.receive(contents, arrival_usec)


func _process(delta: float) -> void:
	advance(delta)


## Lets `seconds` pass in the duel.
func advance(seconds: float) -> void:
	if duel == null or duel.state != Duel.State.RUNNING:
		return
	duel.advance(seconds)
	_since_snapshot += seconds
	if _since_snapshot >= SNAPSHOT_SECONDS:
		send_snapshot()


func send_snapshot() -> void:
	_since_snapshot = 0.0
	outgoing.emit(duel.snapshot())


func _on_spell_resolved(outcome: SpellOutcome) -> void:
	outgoing.emit(DuelProtocol.resolved(outcome, outcome.caster == duel.player))
	send_snapshot()


func _on_finished(winner: Duelist, _loser: Duelist) -> void:
	send_snapshot()
	outgoing.emit(DuelProtocol.finished(winner == duel.player))
