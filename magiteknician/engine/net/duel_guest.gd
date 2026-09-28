class_name DuelGuest
extends Node
## The side of a two-machine duel that does not run it.
##
## The guest casts at the keyboard and sends its strokes to the host. What
## becomes of them is for the host to say. Meanwhile the guest shows the
## host's casts on a circle of its own, and keeps its HUD in step with the
## snapshots the host sends.

## A message is ready to be sent to the host.
signal outgoing(contents: Dictionary)

var mirror: DuelMirror
## The circle the player here casts on, and the one that shows the host.
var my_circle: SpellCircle
var foe_circle: SpellCircle
var sender: StrokeSender
## Drives `foe_circle` from the strokes the host sends.
var display: RemoteCaster
## How casts are judged when nothing is interfering. It should match the
## host's, or the verdict shown here will differ from the one that counts.
var tuning: CastTuning = CastScorer.default_tuning()


func setup(me: Duelist, foe: Duelist, my_circle_: SpellCircle, foe_circle_: SpellCircle) -> void:
	mirror = DuelMirror.new(me, foe)
	my_circle = my_circle_
	foe_circle = foe_circle_

	my_circle.accepts_input = false
	my_circle.tuning = tuning
	# The host will refuse a cast that can't be afforded. Refusing it here
	# as well saves the player from starting one that is bound to be lost.
	my_circle.gate = me.can_afford
	my_circle.cast_started.connect(_on_cast_started)
	me.precision_changed.connect(_on_precision_changed)

	foe_circle.accepts_input = false
	foe_circle.rearm_after_cast = false
	foe_circle.show_tempo_guide = false

	sender = StrokeSender.new()
	add_child(sender)
	sender.circle = my_circle
	sender.message.connect(func (contents): outgoing.emit(contents))

	display = RemoteCaster.new()
	add_child(display)
	display.circle = foe_circle

	mirror.cast_lost.connect(func (_spell, _refused): my_circle.abandon())
	mirror.finished.connect(_on_finished)


func begin() -> void:
	my_circle.accepts_input = true
	display.begin()


## Takes a message from the host.
func receive(contents: Variant, arrival_usec: int = Time.get_ticks_usec()) -> void:
	if contents is Dictionary and contents.get(DuelProtocol.TYPE) in [
		DuelProtocol.BEGIN, DuelProtocol.STROKE, DuelProtocol.ABANDON
	]:
		display.receive(contents, arrival_usec)
	else:
		mirror.receive(contents)


func _on_cast_started(spell: Spell) -> void:
	# Take the chi at once, so the bar does not wait for the host to agree.
	# The next snapshot says what it really is.
	mirror.me.pay_for(spell)


func _on_precision_changed(precision: float) -> void:
	my_circle.tuning = tuning if is_equal_approx(precision, 1.0) else tuning.stricter(precision)


func _on_finished(_i_won: bool) -> void:
	my_circle.accepts_input = false
	my_circle.abandon()
	display.halt()
