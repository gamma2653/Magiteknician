class_name SpellLibrary
extends RefCounted
## Every spell there is, looked up by id: those that ship with the game,
## which are the book, and those the player has made.
##
## Save files and network messages name spells by id; this is where an id
## becomes a Spell again.

const SPELL_DIR := "res://magiteknician/spells"
const DEFAULT_MADE_DIR := "user://spells"

## Where the spells the player has made are kept. Tests point this
## somewhere of their own.
static var made_dir: String = DEFAULT_MADE_DIR:
	set(value):
		made_dir = value
		forget_made()

static var _spells: Dictionary[StringName, Spell] = {}
static var _loaded: bool = false
static var _made: Dictionary[StringName, Spell] = {}
static var _made_loaded: bool = false
# Spells that are neither: lent for as long as something needs them.
static var _lent: Dictionary[StringName, Spell] = {}


## The spell with this id, or null if there is none.
static func find(id: StringName) -> Spell:
	_ensure_loaded()
	if _spells.has(id):
		return _spells[id]
	# What is lent comes before what was made. A recording lends a spell
	# as it was, and the player may have changed it since.
	if _lent.has(id):
		return _lent[id]
	_ensure_made_loaded()
	return _made.get(id)


static func has_spell(id: StringName) -> bool:
	return find(id) != null


## Every spell the player has made, in the order they were made.
static func made() -> Array[Spell]:
	_ensure_made_loaded()
	var spells: Array[Spell] = []
	spells.assign(_made.values())
	return spells


## Every spell there is: the book, and then what the player has made.
static func everything() -> Array[Spell]:
	var spells := all()
	spells.append_array(made())
	return spells


## Reads the spells the player has made again, the next time one is
## wanted.
static func forget_made() -> void:
	_made = {}
	_made_loaded = false


## Has `spell` be found by its id for as long as it is lent, though it is
## in neither the book nor the folder. A recording of a duel lends the
## spells that were made for it, as they were when it was fought.
static func lend(spell: Spell) -> void:
	if spell != null and not spell.id.is_empty():
		_lent[spell.id] = spell


static func take_back(id: StringName) -> void:
	_lent.erase(id)


static func take_back_everything() -> void:
	_lent = {}


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


static func _ensure_made_loaded() -> void:
	if _made_loaded:
		return
	_made_loaded = true
	for spell in SpellForge.all_in(made_dir):
		_made[spell.id] = spell


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
