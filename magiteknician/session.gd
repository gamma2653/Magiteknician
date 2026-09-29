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
const VERSUS_MENU_SCENE := "res://magiteknician/menus/versus_menu.tscn"
const VERSUS_ARENA_SCENE := "res://magiteknician/levels/versus_arena.tscn"
const REPLAYS_SCENE := "res://magiteknician/menus/replays_menu.tscn"
const REPLAY_ARENA_SCENE := "res://magiteknician/levels/replay_arena.tscn"
const DEFAULT_SAVE_PATH := "user://save.json"
const DEFAULT_REPLAY_DIR := "user://replays"
const WORKSHOP_SCENE := "res://magiteknician/levels/workshop.tscn"
const PRACTICE_SCENE := "res://magiteknician/levels/practice_range.tscn"

## Who the next duel is against. Left empty, the arena uses its own default.
var opponent: Opponent
## Ids of the spells the player brings to the next duel. Left empty, the
## arena offers every novice spell.
var spell_ids: Array[StringName] = []
## The scene to return to when the player leaves the duel.
var return_scene: String = MAIN_MENU_SCENE

## The name the player goes by in duels against other players.
var versus_name: String = ""
## The name of the player at the other end of the next such duel.
var versus_foe_name: String = ""
## Ids of the spells the player brings to the next such duel. Left empty,
## they bring what they chose in the versus menu.
var versus_spells: Array[StringName] = []
## Ids of the spells they bring. Left empty, they bring every spell, which
## is what a player on a version from before loadouts does.
var versus_foe_spells: Array[StringName] = []
## Whether this machine runs that duel.
var versus_is_host: bool = true

var campaign: Campaign = DEFAULT_CAMPAIGN
## Where progress is kept. Tests point this somewhere of their own.
var save_path: String = DEFAULT_SAVE_PATH
## The player's progress, once a game has been started or continued.
var save: SaveGame
## Where duels are recorded. Tests point this somewhere of their own.
var replay_dir: String = DEFAULT_REPLAY_DIR
## The recording to watch next.
var replay: DuelRecording
## The spell that the practice range, or the workshop, is to open on.
var spell_to_practise: Spell
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
	save.loadout = save.bring()
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
		save.learn(id)
	return true


## Chooses the spells to bring to the campaign's duels, and keeps the
## choice. Returns what was chosen, made fit to bring.
func choose_loadout(chosen: Array) -> Array[StringName]:
	if save == null:
		return []
	save.loadout = Loadout.tidy(chosen, ids_to_bring())
	write_save()
	return save.loadout


## The spells the player brings to the campaign's duels: those they
## chose, of those they can bring.
func brought() -> Array[StringName]:
	if save == null:
		return []
	return Loadout.tidy(save.loadout, ids_to_bring())


## The spells the player knows, in the campaign: those they have
## learned.
func known_spells() -> Array[Spell]:
	var known: Array[Spell] = []
	if save == null:
		return known
	for id in save.spell_ids:
		var spell := SpellLibrary.find(id)
		if spell != null:
			known.append(spell)
	return known


## The spells the player can bring to a duel of the campaign: those they
## have learned, and those they have made of what they have learned.
func spells_to_bring() -> Array[Spell]:
	var learned := known_spells()
	var can := learned.duplicate()
	for spell in SpellLibrary.made():
		if SpellForge.can_be_brought(spell, learned):
			can.append(spell)
	return can


## The ids of spells_to_bring().
func ids_to_bring() -> Array[StringName]:
	var ids: Array[StringName] = []
	for spell in spells_to_bring():
		ids.append(spell.id)
	return ids


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
	spell_ids = brought()
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
			if save.learn(spell.id):
				learned.append(spell)
	write_save()
	return learned
