extends Node
## Carries what one scene needs to tell the next, and keeps the player's
## progress through the campaign.
##
## Godot replaces the whole scene on a change of scene, so whoever sends
## the player into a duel leaves the particulars here for the arena to find.

const DEFAULT_CAMPAIGN := preload("res://magiteknician/campaigns/sparring_at_gratiswiesel.tres")
const MAIN_MENU_SCENE := "res://magiteknician/menus/main_menu.tscn"
const CAMPAIGN_SCENE := "res://magiteknician/menus/campaign_menu.tscn"
const ARENA_SCENE := "res://magiteknician/levels/duel_arena.tscn"
const DEFAULT_SAVE_PATH := "user://save.json"

## Who the next duel is against. Left empty, the arena uses its own default.
var opponent: Opponent
## Ids of the spells the player brings to the next duel. Left empty, the
## arena offers every novice spell.
var spell_ids: Array[StringName] = []
## The scene to return to when the player leaves the duel.
var return_scene: String = MAIN_MENU_SCENE

var campaign: Campaign = DEFAULT_CAMPAIGN
## Where progress is kept. Tests point this somewhere of their own.
var save_path: String = DEFAULT_SAVE_PATH
## The player's progress, once a game has been started or continued.
var save: SaveGame
## Index of the campaign stage being fought, or -1 when the duel is not
## part of the campaign.
var stage_index: int = -1


## Forgets the particulars of the last duel. Progress is kept.
func clear() -> void:
	opponent = null
	spell_ids = []
	return_scene = MAIN_MENU_SCENE
	stage_index = -1


## True if there is progress on disk to continue from.
func has_save() -> bool:
	var found := SaveGame.read(save_path)
	return found != null and found.campaign_id == campaign.id


## Starts the campaign afresh, replacing any progress on disk.
func new_game() -> void:
	clear()
	save = SaveGame.new()
	save.campaign_id = campaign.id
	save.spell_ids = campaign.starting_spell_ids.duplicate()
	write_save()


## Picks the campaign up from the progress on disk. Returns false, and
## changes nothing, if there is none.
func continue_game() -> bool:
	var found := SaveGame.read(save_path)
	if found == null or found.campaign_id != campaign.id:
		return false
	clear()
	save = found
	# A stage may have gained a reward since the save was written.
	save.stages_cleared = mini(save.stages_cleared, campaign.stage_count())
	for id in campaign.spell_ids_after(save.stages_cleared):
		if not save.spell_ids.has(id):
			save.spell_ids.append(id)
	return true


func write_save() -> Error:
	if save == null:
		return ERR_UNCONFIGURED
	var error := save.write(save_path)
	if error != OK:
		push_warning("Progress could not be saved to %s: %s" % [save_path, error_string(error)])
	return error


## True if the player may fight the stage at `index`: it exists, and every
## stage before it has been won.
func is_unlocked(index: int) -> bool:
	return save != null and campaign.stage(index) != null and index <= save.stages_cleared


func is_cleared(index: int) -> bool:
	return save != null and index >= 0 and index < save.stages_cleared


func is_campaign_complete() -> bool:
	return save != null and save.stages_cleared >= campaign.stage_count()


## Sets the next duel up as the campaign stage at `index`. Returns false,
## and changes nothing, if the stage is locked.
func enter_stage(index: int) -> bool:
	if not is_unlocked(index):
		return false
	stage_index = index
	opponent = campaign.stage(index).opponent
	spell_ids = save.spell_ids.duplicate()
	return_scene = CAMPAIGN_SCENE
	return true


## Takes the result of a campaign duel. If the player won, their progress
## moves on and is saved. Returns the spells they learned by it.
func report_duel(duel: Duel) -> Array[Spell]:
	var learned: Array[Spell] = []
	var stage := campaign.stage(stage_index)
	if save == null or stage == null or not duel.player_won():
		return learned
	save.record_win(stage.opponent.id, duel.player_mean_quality(), duel.elapsed_seconds)
	if stage_index == save.stages_cleared:
		save.stages_cleared += 1
		for spell in stage.rewards():
			if not save.spell_ids.has(spell.id):
				save.spell_ids.append(spell.id)
				learned.append(spell)
	write_save()
	return learned
