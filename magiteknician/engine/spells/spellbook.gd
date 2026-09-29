@tool
class_name Spellbook
extends Resource
## The spells a caster knows, in the order they keep them.
##
## The order matters: it decides which number key selects which spell.

## The most spells that can be selected with the number keys.
const MAX_SLOTS := 9

@export var spells: Array[Spell] = []


## The spell with this id, or null if it is not in the book.
func find(id: StringName) -> Spell:
	for spell in spells:
		if spell != null and spell.id == id:
			return spell
	return null


func knows(id: StringName) -> bool:
	return find(id) != null


## Adds `spell` to the end of the book. Returns false, and changes nothing,
## if it is already there.
func learn(spell: Spell) -> bool:
	if spell == null or knows(spell.id):
		return false
	spells.append(spell)
	emit_changed()
	return true


func ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for spell in spells:
		if spell != null:
			result.append(spell.id)
	return result


## A book holding the library's spells with these ids, in this order.
## Ids the library doesn't know are skipped with a warning.
static func of(spell_ids: Array) -> Spellbook:
	var book := Spellbook.new()
	for id in spell_ids:
		var spell := SpellLibrary.find(StringName(id))
		if spell == null:
			push_warning("There is no spell with the id '%s'." % [id])
			continue
		book.learn(spell)
	return book


## A book holding every spell in the library.
static func complete() -> Spellbook:
	var book := Spellbook.new()
	for spell in SpellLibrary.all():
		book.learn(spell)
	return book


## A book holding every spell there is: the library's, and then those
## the player has made.
static func with_what_was_made() -> Spellbook:
	var book := complete()
	for spell in SpellLibrary.made():
		book.learn(spell)
	return book
