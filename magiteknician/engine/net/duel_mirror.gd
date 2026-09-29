class_name DuelMirror
extends RefCounted
## The duel as seen from the machine that is not running it.
##
## The host owns the duel and decides what happens in it. The guest keeps
## two duelists of its own to show on its HUD and sets them from the
## snapshots the host sends. It works nothing out for itself.

## A cast took effect on the host. `line` is for the combat log.
signal resolved(line: String, by_me: bool)
## The same, as what the cast did, for it to be shown. The duelists in it
## are the two here.
signal shown(outcome: SpellOutcome)
## My cast came to nothing on the host.
signal cast_lost(spell: Spell, refused: bool)
signal finished(i_won: bool)

## The player on this machine, and the one on the host.
var me: Duelist
var foe: Duelist
var elapsed_seconds: float = 0.0
var is_over: bool = false
var i_won: bool = false


func _init(me_: Duelist, foe_: Duelist) -> void:
	me = me_
	foe = foe_


## Takes a message from the host. Returns false if it could not be acted
## on, in which case nothing has changed.
func receive(contents: Variant) -> bool:
	if not DuelProtocol.problems(contents).is_empty():
		return false
	match contents[DuelProtocol.TYPE]:
		DuelProtocol.SNAPSHOT:
			foe.apply_dict(contents["host"])
			me.apply_dict(contents["guest"])
			elapsed_seconds = float(contents["elapsed"])
		DuelProtocol.RESOLVED:
			var by_me: bool = not contents["by_host"]
			var line: String = contents["line"]
			if by_me:
				line = DuelProtocol.in_second_person(line, me.display_name)
			resolved.emit(line, by_me)
			if not contents.has("entries"):
				pass
			elif by_me:
				shown.emit(SpellOutcome.from_dict(contents, me, foe))
			else:
				shown.emit(SpellOutcome.from_dict(contents, foe, me))
		DuelProtocol.BROKEN:
			cast_lost.emit(SpellLibrary.find(StringName(contents["spell"])), contents["refused"])
		DuelProtocol.FINISHED:
			is_over = true
			i_won = not contents["host_won"]
			finished.emit(i_won)
		_:
			return false
	return true
