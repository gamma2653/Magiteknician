class_name DuelBanter
extends Node
## What an opponent says in the course of a duel.
##
## It watches the duel for the moments an opponent might remark on, and
## when one comes and the opponent has something to say of it, says it.
## Each thing is said once in a duel. What there is to say is written in
## the opponent's file.
##
## It changes nothing. It listens to the duel and has no say in it.

## The opponent has something to say.
signal said(speaker: String, line: String)

## The duel has begun.
const BEGAN := &"began"
## The opponent is down to half their health.
const HURT := &"hurt"
## The player is down to half theirs.
const WINNING := &"winning"
## The opponent's ward was used up.
const WARD_BROKEN := &"ward_broken"
## The opponent's cast was broken.
const CAST_BROKEN := &"cast_broken"
## The player landed a blow as hard as any they have.
const STRUCK_HARD := &"struck_hard"
## The player cast a spell flawlessly.
const FLAWLESS := &"flawless"
## The player has kept a cadence for three casts.
const IN_CADENCE := &"in_cadence"
## The duel has gone on long enough that blows land harder.
const ESCALATED := &"escalated"

const MOMENTS: Array[StringName] = [
	BEGAN, HURT, WINNING, WARD_BROKEN, CAST_BROKEN, STRUCK_HARD, FLAWLESS, IN_CADENCE, ESCALATED,
]
## What each moment is, for whoever is writing an opponent's lines.
const MOMENT_MEANS: Dictionary[StringName, String] = {
	BEGAN: "The duel has begun.",
	HURT: "They are down to half their health.",
	WINNING: "The player is down to half theirs.",
	WARD_BROKEN: "Their ward was used up.",
	CAST_BROKEN: "Their cast was broken.",
	STRUCK_HARD: "The player landed a hard blow.",
	FLAWLESS: "The player cast a spell flawlessly.",
	IN_CADENCE: "The player has kept a cadence for three casts.",
	ESCALATED: "The duel has gone on for a minute.",
}
## A blow of this much is a hard one.
const HARD_BLOW := 20.0
## The least time between one remark and the next, in seconds. An
## opponent who remarks on everything is not listened to.
const BREATH_SECONDS := 6.0
## How many casts in a row make a cadence worth remarking on.
const CADENCE_WORTH_REMARKING := 2

var opponent: Opponent
var duel: Duel
## The moments that have been remarked on, in order.
var spoken: Array[StringName] = []

var _last_spoke_at: float = -INF


## Listens to `duel_`, in which `opponent_` is the opponent.
func watch(duel_: Duel, opponent_: Opponent) -> void:
	duel = duel_
	opponent = opponent_
	duel.began.connect(remark.bind(BEGAN, true))
	duel.escalated.connect(remark.bind(ESCALATED))
	duel.spell_resolved.connect(_on_spell_resolved)
	duel.opponent.health_changed.connect(_on_opponent_health_changed)
	duel.player.health_changed.connect(_on_player_health_changed)
	duel.opponent.ward_ended.connect(_on_opponent_ward_ended)
	duel.opponent.interrupted.connect(func (_spell): remark(CAST_BROKEN))


## Says what the opponent has to say of `moment`, if they have anything,
## have not said it, and have drawn breath since they last spoke.
## `at_once` says it whether they have drawn breath or not. Returns true
## if it was said.
func remark(moment: StringName, at_once: bool = false) -> bool:
	if opponent == null or duel == null or duel.is_over() or spoken.has(moment):
		return false
	var line := opponent.remark_on(moment)
	if line.is_empty():
		return false
	if not at_once and duel.elapsed_seconds - _last_spoke_at < BREATH_SECONDS:
		return false
	spoken.append(moment)
	_last_spoke_at = duel.elapsed_seconds
	said.emit(opponent.display_name, line)
	return true


func _on_spell_resolved(outcome: SpellOutcome) -> void:
	if outcome.caster != duel.player or outcome.fizzled:
		return
	if outcome.damage_dealt() >= HARD_BLOW and remark(STRUCK_HARD):
		return
	if outcome.result.cadence_links >= CADENCE_WORTH_REMARKING and remark(IN_CADENCE):
		return
	if outcome.result.grade == CastResult.Grade.S:
		remark(FLAWLESS)


func _on_opponent_health_changed(health: float, max_health: float) -> void:
	if health > 0.0 and health <= max_health / 2.0:
		remark(HURT)


func _on_player_health_changed(health: float, max_health: float) -> void:
	if health > 0.0 and health <= max_health / 2.0:
		remark(WINNING)


func _on_opponent_ward_ended(broken: bool) -> void:
	if broken:
		remark(WARD_BROKEN)
