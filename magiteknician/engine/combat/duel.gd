class_name Duel
extends Node
## A duel between two casters.
##
## The duel owns the rules that involve both sides: chi is paid when a
## cast begins, a finished cast is resolved against the two duelists, and
## the first to run out of health loses. Both sides cast in real time and
## nothing takes turns, so finishing a spell sooner is its own reward.

## The duel is under way.
signal began
## A cast finished and took effect, or fizzled.
signal spell_resolved(outcome: SpellOutcome)
## `caster` tried to begin `spell` without the chi for it.
signal cast_refused(caster: Duelist, spell: Spell)
signal finished(winner: Duelist, loser: Duelist)
## The duel has gone on long enough that blows now land harder.
signal escalated

enum State { WAITING, RUNNING, OVER }

## A duel that lasts this long, in seconds, begins to escalate.
const ESCALATION_STARTS := 60.0
## How much harder blows land for each further second, as a share.
const ESCALATION_PER_SECOND := 1.0 / 60.0

var state: State = State.WAITING
var player: Duelist
var opponent: Duelist
var player_circle: SpellCircle
var opponent_circle: SpellCircle
## Whoever casts for the opponent: an NPC, or a player on another machine.
var opponent_caster: Caster
## Whoever casts for the player's side, if it is not the player at the
## keyboard. With an NPC here a duel plays itself, which is how the balance
## of an opponent is tried.
var player_caster: Caster
var winner: Duelist
## How casts are judged when nothing is interfering. A chilled duelist is
## judged by a stricter copy of it.
var tuning: CastTuning = CastScorer.default_tuning()
## Seconds the duel has been running.
var elapsed_seconds: float = 0.0
## The verdict on every cast the player finished, in order.
var player_casts: Array[CastResult] = []
## Everything that has taken effect, in order.
var outcomes: Array[SpellOutcome] = []


## Brings the two sides together. Nothing happens until begin().
## Pass `player_caster_` to have an NPC cast for the player's side.
func setup(
	player_: Duelist,
	opponent_: Duelist,
	player_circle_: SpellCircle,
	opponent_circle_: SpellCircle,
	opponent_caster_: Caster,
	player_caster_: Caster = null
) -> void:
	player = player_
	opponent = opponent_
	player_circle = player_circle_
	opponent_circle = opponent_circle_
	opponent_caster = opponent_caster_
	player_caster = player_caster_

	player_circle.accepts_input = false
	player_circle.gate = player.can_afford
	player_circle.cast_started.connect(_on_cast_started.bind(player))
	player_circle.cast_refused.connect(_on_cast_refused.bind(player))
	player_circle.cast_finished.connect(_on_cast_finished.bind(player, opponent))
	player_circle.cast_abandoned.connect(_on_player_cast_ended)

	opponent_circle.accepts_input = false
	opponent_circle.rearm_after_cast = false
	opponent_circle.show_tempo_guide = false
	opponent_circle.gate = opponent.can_afford
	opponent_circle.cast_started.connect(_on_cast_started.bind(opponent))
	opponent_circle.cast_refused.connect(_on_cast_refused.bind(opponent))
	opponent_circle.cast_finished.connect(_on_cast_finished.bind(opponent, player))

	for side in [[player, player_circle], [opponent, opponent_circle]]:
		var duelist: Duelist = side[0]
		var circle: SpellCircle = side[1]
		circle.tuning = tuning
		duelist.precision_changed.connect(_on_precision_changed.bind(circle))
		duelist.interrupted.connect(_on_interrupted.bind(duelist))
		circle.cast_abandoned.connect(func (_spell): duelist.casting = null)

	opponent_caster.circle = opponent_circle
	opponent_caster.me = opponent
	opponent_caster.foe = player
	# The duel feeds the NPC its time, so the two never drift apart.
	opponent_caster.set_process(false)

	if player_caster != null:
		player_circle.show_tempo_guide = false
		opponent_circle.cast_abandoned.connect(_on_opponent_cast_ended)
		player_caster.circle = player_circle
		player_caster.me = player
		player_caster.foe = opponent
		player_caster.set_process(false)


func begin() -> void:
	if state != State.WAITING:
		return
	state = State.RUNNING
	if player_caster != null:
		player_caster.begin()
	else:
		player_circle.accepts_input = true
	opponent_caster.begin()
	began.emit()


func _process(delta: float) -> void:
	advance(delta)


## Lets `seconds` pass for everyone in the duel.
func advance(seconds: float) -> void:
	if state != State.RUNNING or seconds <= 0.0:
		return
	var was_escalated := has_escalated()
	elapsed_seconds += seconds
	if has_escalated() and not was_escalated:
		escalated.emit()
	player.advance(seconds)
	opponent.advance(seconds)
	opponent_caster.advance(seconds)
	if player_caster != null and state == State.RUNNING:
		player_caster.advance(seconds)


func is_over() -> bool:
	return state == State.OVER


## The state of the duel as a message for the other machine, on which the
## opponent here is the player.
func snapshot() -> Dictionary:
	return DuelProtocol.snapshot(player, opponent, elapsed_seconds)


## What damage is multiplied by at this point in the duel. It is 1 for the
## first minute and climbs after it, doubling by the end of the second.
## Two careful casters could otherwise ward and mend for ever.
func damage_scale() -> float:
	return 1.0 + maxf(elapsed_seconds - ESCALATION_STARTS, 0.0) * ESCALATION_PER_SECOND


func has_escalated() -> bool:
	return elapsed_seconds > ESCALATION_STARTS


func player_won() -> bool:
	return state == State.OVER and winner == player


## Mean quality of the casts the player finished, or 0 if there were none.
func player_mean_quality() -> float:
	if player_casts.is_empty():
		return 0.0
	var total := 0.0
	for cast in player_casts:
		total += cast.quality
	return total / player_casts.size()


func _on_precision_changed(precision: float, circle: SpellCircle) -> void:
	circle.tuning = tuning if is_equal_approx(precision, 1.0) else tuning.stricter(precision)


func _on_interrupted(_spell: Spell, duelist: Duelist) -> void:
	if duelist == opponent:
		opponent_caster.interrupt()
	elif player_caster != null:
		player_caster.interrupt()
	else:
		player_circle.abandon()


func _on_cast_started(spell: Spell, caster: Duelist) -> void:
	caster.pay_for(spell)
	caster.casting = spell
	if caster == player:
		# What the player is casting can be read off their circle, and the
		# NPC is allowed to read it.
		opponent_caster.foe_spell = spell
	elif player_caster != null:
		player_caster.foe_spell = spell


func _on_cast_refused(spell: Spell, caster: Duelist) -> void:
	cast_refused.emit(caster, spell)


func _on_player_cast_ended(_spell: Spell) -> void:
	opponent_caster.foe_spell = null


func _on_opponent_cast_ended(_spell: Spell) -> void:
	if player_caster != null:
		player_caster.foe_spell = null


func _on_cast_finished(spell: Spell, result: CastResult, caster: Duelist, target: Duelist) -> void:
	caster.casting = null
	if state != State.RUNNING:
		return
	if caster == player:
		opponent_caster.foe_spell = null
		player_casts.append(result)
	elif player_caster != null:
		player_caster.foe_spell = null
	var outcome := SpellResolver.resolve(spell, result, caster, target, damage_scale())
	outcomes.append(outcome)
	spell_resolved.emit(outcome)
	if target.is_defeated():
		_finish(caster, target)
	elif caster.is_defeated():
		_finish(target, caster)


func _finish(winner_: Duelist, loser: Duelist) -> void:
	state = State.OVER
	winner = winner_
	opponent_caster.halt()
	if player_caster != null:
		player_caster.halt()
	player_circle.accepts_input = false
	player_circle.abandon()
	finished.emit(winner, loser)
