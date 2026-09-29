@tool
class_name Campaign
extends Resource
## A run of duels, fought in order.

## Stable name used in save files.
@export var id: StringName = &""
@export var title: String = ""
@export_multiline var introduction: String = ""
## Ids of the spells the player knows at the outset.
@export var starting_spell_ids: Array[StringName] = []
@export var stages: Array[CampaignStage] = []


func stage_count() -> int:
	return stages.size()


## The stage at `index`, or null if there is none.
func stage(index: int) -> CampaignStage:
	if index < 0 or index >= stages.size():
		return null
	return stages[index]


## The index of the stage against the opponent with this id, or -1.
func index_of(opponent_id: StringName) -> int:
	for i in stages.size():
		if stages[i] != null and stages[i].opponent != null and stages[i].opponent.id == opponent_id:
			return i
	return -1


## Every spell the player will know once `stages_cleared` stages are won.
func spell_ids_after(stages_cleared: int) -> Array[StringName]:
	var ids: Array[StringName] = starting_spell_ids.duplicate()
	for i in mini(stages_cleared, stages.size()):
		for id in stages[i].reward_spell_ids:
			if not ids.has(id):
				ids.append(id)
	return ids


## Everything wrong with the campaign as written. Empty when it can be
## played from start to finish.
func problems() -> PackedStringArray:
	var found: PackedStringArray = []
	if id.is_empty():
		found.append("The campaign has no id.")
	if stages.is_empty():
		found.append("The campaign has no stages.")
	if starting_spell_ids.is_empty():
		found.append("The player starts with no spells.")
	var can_attack := false
	for spell_id in starting_spell_ids:
		var spell := SpellLibrary.find(spell_id)
		if spell == null:
			found.append("There is no spell with the id '%s'." % [spell_id])
		elif NpcBrain.damage_of(spell) > 0.0:
			can_attack = true
	if not starting_spell_ids.is_empty() and not can_attack:
		found.append("The player starts with no way to do harm.")

	var seen := {}
	for i in stages.size():
		var label := "Stage %d" % [i + 1]
		var entry := stages[i]
		if entry == null or entry.opponent == null:
			found.append("%s has no opponent." % [label])
			continue
		for problem in entry.opponent.problems():
			found.append("%s: %s" % [label, problem])
		if seen.has(entry.opponent.id):
			found.append("%s: '%s' is fought twice; progress is kept by opponent." % [label, entry.opponent.id])
		seen[entry.opponent.id] = true
		for reward in entry.reward_spell_ids:
			if not SpellLibrary.has_spell(reward):
				found.append("%s: there is no spell with the id '%s'." % [label, reward])
	return found
