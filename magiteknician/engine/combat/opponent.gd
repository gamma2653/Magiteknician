@tool
class_name Opponent
extends Resource
## Someone to duel: who they are, what they know, and how they cast.

## Stable name used in save files.
@export var id: StringName = &""
@export var display_name: String = ""
## A few words under the name, e.g. where they are from.
@export var title: String = ""
## Said of them before the duel.
@export_multiline var introduction: String = ""

@export_group("Voice")
## What they say as the duel is about to begin.
@export_multiline var greeting: String = ""
## What they say when they have won.
@export_multiline var on_winning: String = ""
## What they say when they have lost.
@export_multiline var on_losing: String = ""
## What they say in the course of the duel, by the moment they say it
## at. The moments are DuelBanter's. One with nothing to say of a moment
## says nothing.
@export var remarks: Dictionary[StringName, String] = {}

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


## What they say of `moment`, or "" if they have nothing to say of it.
func remark_on(moment: StringName) -> String:
	return str(remarks.get(moment, "")).strip_edges()


## `line` as something that was said, by them: in quotation marks, with
## their name after it. Empty if there is no line.
func quoted(line: String) -> String:
	if line.strip_edges().is_empty():
		return ""
	return "“%s”\n— %s" % [line.strip_edges(), display_name]


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
	for moment in remarks:
		if moment not in DuelBanter.MOMENTS:
			found.append("They have something to say of '%s', which is not a moment there is." % [moment])
	if not spell_ids.is_empty() and not can_attack:
		found.append("The opponent has no way to do harm, so the duel could never end.")
	return found
