class_name Loadout
extends RefCounted
## The spells a caster brings to a duel: some of those they know, in the
## order they are to be had under the number keys.
##
## A caster knows more spells than they can bring. Which to bring is
## decided before the first stroke, and is part of the duel.
##
## A loadout is a list of spell ids and nothing else. These are the rules
## for making one and keeping it in order.

## The most spells that can be brought. It is as many number keys as the
## hand that strikes the runes can reach without leaving them.
const SIZE := 6
## What is brought to a duel between players by one who has not chosen.
const STANDARD: Array[StringName] = [&"fire_bolt", &"spark", &"ward", &"mend", &"gust", &"flinch"]
## The spells there were before a game said which spells it has. A player
## who does not say is taken to have these.
const LEGACY: Array[StringName] = [
	&"spark", &"gust", &"flinch", &"ward", &"fire_bolt", &"frost_bolt", &"mend", &"bulwark", &"lightning",
]


## `chosen` made fit to bring, by a caster who knows `known`: what they
## do not know is left out, what is there twice is there once, and what is
## over the limit is left behind. If nothing is left, it is the first few
## of what they know.
static func tidy(chosen: Array, known: Array) -> Array[StringName]:
	var fit: Array[StringName] = []
	for id: Variant in chosen:
		var spell_id := StringName(str(id))
		if fit.size() >= SIZE:
			break
		if _has(known, spell_id) and not fit.has(spell_id):
			fit.append(spell_id)
	if fit.is_empty():
		for id: Variant in known:
			if fit.size() >= SIZE:
				break
			fit.append(StringName(str(id)))
	return fit


## `chosen` with `id` put in if it was out and taken out if it was in.
## It is not put in where there is no room, nor taken out if it is the
## last.
static func toggled(chosen: Array, id: StringName) -> Array[StringName]:
	var changed: Array[StringName] = []
	changed.assign(chosen)
	if changed.has(id):
		if changed.size() > 1:
			changed.erase(id)
	elif changed.size() < SIZE:
		changed.append(id)
	return changed


## `chosen` with `id` added, if there is room for it.
static func with_learned(chosen: Array, id: StringName) -> Array[StringName]:
	var changed: Array[StringName] = []
	changed.assign(chosen)
	if not changed.has(id) and changed.size() < SIZE:
		changed.append(id)
	return changed


static func has_room(chosen: Array) -> bool:
	return chosen.size() < SIZE


## True if any of the spells does harm. A caster who brings none cannot
## win.
static func does_harm(chosen: Array) -> bool:
	for id: Variant in chosen:
		if NpcBrain.damage_of(SpellLibrary.find(StringName(str(id)))) > 0.0:
			return true
	return false


## The spells of `mine` that are also in `theirs`, in the order of `mine`.
## Two players can only duel with spells that both their games have.
static func in_common(mine: Array, theirs: Array) -> Array[StringName]:
	var common: Array[StringName] = []
	for id: Variant in mine:
		var spell_id := StringName(str(id))
		if _has(theirs, spell_id) and not common.has(spell_id):
			common.append(spell_id)
	return common


## The ids of every spell in the library, in the library's order.
static func every_spell() -> Array[StringName]:
	var ids: Array[StringName] = []
	for spell in SpellLibrary.all():
		ids.append(spell.id)
	return ids


static func _has(ids: Array, id: StringName) -> bool:
	for known: Variant in ids:
		if StringName(str(known)) == id:
			return true
	return false
