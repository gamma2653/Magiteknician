class_name SpellLibrary
extends RefCounted
## Every spell that ships with the game, looked up by id.
##
## Save files and network messages name spells by id; this is where an id
## becomes a Spell again.

const SPELL_DIR := "res://magiteknician/spells"

static var _spells: Dictionary[StringName, Spell] = {}
static var _loaded: bool = false


## The spell with this id, or null if there is none.
static func find(id: StringName) -> Spell:
	_ensure_loaded()
	return _spells.get(id)


static func has_spell(id: StringName) -> bool:
	_ensure_loaded()
	return _spells.has(id)


## Every spell, easiest rank first and by name within a rank.
static func all() -> Array[Spell]:
	_ensure_loaded()
	var spells: Array[Spell] = []
	spells.assign(_spells.values())
	spells.sort_custom(func (a: Spell, b: Spell):
		if a.rank != b.rank:
			return a.rank < b.rank
		return a.display_name.naturalnocasecmp_to(b.display_name) < 0
	)
	return spells


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	# list_directory, unlike DirAccess, sees through the renaming that an
	# exported game applies to its resources.
	for file in ResourceLoader.list_directory(SPELL_DIR):
		if not file.ends_with(".tres"):
			continue
		var spell := load(SPELL_DIR.path_join(file)) as Spell
		if spell == null:
			push_warning("%s is in the spell directory but is not a spell." % [file])
			continue
		if _spells.has(spell.id):
			push_warning("Two spells share the id '%s'; keeping the first." % [spell.id])
			continue
		_spells[spell.id] = spell
