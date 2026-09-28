extends Node
## Carries what one scene needs to tell the next.
##
## Godot replaces the whole scene on a change of scene, so whoever sends
## the player into a duel leaves the particulars here for the arena to find.

## Who the next duel is against. Left empty, the arena uses its own default.
var opponent: Opponent
## Ids of the spells the player brings to the next duel. Left empty, the
## arena offers every novice spell.
var spell_ids: Array[StringName] = []
## The scene to return to when the player leaves the duel.
var return_scene: String = "res://magiteknician/menus/main_menu.tscn"


## Forgets the particulars of the last duel.
func clear() -> void:
	opponent = null
	spell_ids = []
	return_scene = "res://magiteknician/menus/main_menu.tscn"
