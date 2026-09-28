@tool
class_name Opponent
extends Resource
## Someone to duel: who they are, what they know, and how they cast.

## Stable name used in save files.
@export var id: StringName = &""
@export var display_name: String = ""
## A few words under the name, e.g. where they are from.
@export var title: String = ""
## Said before the duel.
@export_multiline var introduction: String = ""

@export_group("Body")
@export_range(10.0, 500.0, 5.0) var max_health: float = 100.0
@export_range(10.0, 300.0, 5.0) var max_chi: float = 100.0
@export_range(0.0, 30.0, 0.5) var chi_per_second: float = 7.0

@export_group("Casting")
## Ids of the spells they know, in the library.
@export var spell_ids: Array[StringName] = []
@export var profile: CasterProfile


## A fresh duelist for this opponent, at full health and chi.
func make_duelist() -> Duelist:
	var duelist := Duelist.new(display_name, max_health, max_chi)
	duelist.chi_per_second = chi_per_second
	duelist.spellbook = Spellbook.of(spell_ids)
	return duelist


## Everything wrong with the opponent as written. Empty when they can duel.
func problems() -> PackedStringArray:
	var found: PackedStringArray = []
	if id.is_empty():
		found.append("The opponent has no id.")
	if display_name.is_empty():
		found.append("The opponent has no name.")
	if profile == null:
		found.append("The opponent has no casting profile.")
	if spell_ids.is_empty():
		found.append("The opponent knows no spells.")
	var can_attack := false
	for spell_id in spell_ids:
		var spell := SpellLibrary.find(spell_id)
		if spell == null:
			found.append("There is no spell with the id '%s'." % [spell_id])
			continue
		if spell.chi_cost > max_chi:
			found.append("%s costs more chi than the opponent can hold." % [spell.display_name])
		if NpcBrain.damage_of(spell) > 0.0:
			can_attack = true
	if not spell_ids.is_empty() and not can_attack:
		found.append("The opponent has no way to do harm, so the duel could never end.")
	return found
