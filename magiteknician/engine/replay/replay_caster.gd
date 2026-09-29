class_name ReplayCaster
extends Caster
## Stands where a caster stands while a recording is played.
##
## It casts nothing of its own accord. The ReplayPlayer makes the strokes
## that were recorded, when they were made. This is here for the duel to
## have somebody to tell, and so that a cast that the duel breaks is broken.


func interrupt() -> bool:
	if circle == null or circle.state != SpellCircle.State.CASTING:
		return false
	circle.abandon()
	return true


func halt() -> void:
	if circle != null:
		circle.abandon()
