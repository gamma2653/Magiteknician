class_name Caster
extends Node
## Something that casts on a spell circle in place of a player at the
## keyboard: an NPC, or a player on another machine.
##
## A duel does not care which. It tells a caster when to begin and when to
## stop, feeds it time, tells it what its foe is casting, and breaks its
## cast when an interruption lands.

## The circle this caster makes its strokes on.
var circle: SpellCircle
## The duelist this caster casts for, and the one it casts against.
var me: Duelist
var foe: Duelist
## The spell the foe is part-way through casting, if it can be seen.
var foe_spell: Spell


## Starts the caster casting.
func begin() -> void:
	pass


## Stops the caster for good, abandoning any cast in progress.
func halt() -> void:
	pass


## Breaks the cast in progress, if there is one. Returns true if a cast
## was broken.
func interrupt() -> bool:
	return false


## Lets `seconds` pass for this caster.
func advance(_seconds: float) -> void:
	pass
