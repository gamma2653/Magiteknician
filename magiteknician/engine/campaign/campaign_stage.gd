@tool
class_name CampaignStage
extends Resource
## One duel of a campaign: who it is against and what winning it teaches.

@export var opponent: Opponent
## Ids of the spells the player learns by winning, in the library.
@export var reward_spell_ids: Array[StringName] = []
## What happens before the duel, told to the player.
@export_multiline var prologue: String = ""
## What happens after the player wins.
@export_multiline var victory_text: String = ""
## What happens after the player loses.
@export_multiline var defeat_text: String = ""


## The spells the player learns by winning.
func rewards() -> Array[Spell]:
	var spells: Array[Spell] = []
	for id in reward_spell_ids:
		var spell := SpellLibrary.find(id)
		if spell != null:
			spells.append(spell)
	return spells
