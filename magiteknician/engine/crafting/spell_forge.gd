class_name SpellForge
extends RefCounted
## Makes a spell of the player's own, and keeps those that are made.
##
## A spell that is made is its name, and its runes with when and where
## each is struck. What it does and what it costs are not kept. They are
## worked out by RuneGrammar each time the spell is read, so a spell's
## file cannot say that three runes do a hundred harm, and a change to
## the grammar is a change to every spell that was made by it.
##
## The files are JSON, one to a spell, in a folder of the game's own.

## What the id of every spell that was made begins with. No spell in the
## book has an id that does.
const PREFIX := "made_"
## No more spells than this are kept.
const MOST := 8
const MAX_NAME_LENGTH := 24
const UNNAMED := "A spell"
## Bumped when a file changes shape.
const VERSION := 1


## True if `spell` was made, and is not from the book.
static func is_made(spell: Spell) -> bool:
	return spell != null and String(spell.id).begins_with(PREFIX)


## A spell called `spell_name` of `strokes`, with what it does and costs
## worked out. `id` is the id it is to have. Left empty, it has none yet.
static func make(spell_name: String, strokes: Array, id: StringName = &"", grammar: RuneGrammar = null) -> Spell:
	if grammar == null:
		grammar = RuneGrammar.usual()
	var spell := Spell.new()
	spell.id = id
	spell.display_name = tidy_name(spell_name)
	var copied: Array[RuneStroke] = []
	for stroke: RuneStroke in strokes:
		copied.append(RuneStroke.make(stroke.rune, stroke.tick, stroke.position))
	spell.strokes = copied
	spell.effects = grammar.effects_of(copied)
	spell.chi_cost = grammar.cost_of(copied) if not spell.effects.is_empty() else 0.0
	spell.rank = RuneGrammar.rank_of(copied)
	spell.school = RuneGrammar.school_of(spell.effects)
	spell.description = "A spell of your own making, %s to cast." % [RuneGrammar.difficulty_name(grammar.difficulty_of(copied))]
	return spell


## `spell_name` made fit to show: trimmed, cut to length, and never empty.
static func tidy_name(spell_name: String) -> String:
	var tidy := spell_name.strip_edges().replace("\n", " ").left(MAX_NAME_LENGTH).strip_edges()
	return UNNAMED if tidy.is_empty() else tidy


## Everything that stops `spell` being kept. Empty when it can be.
static func problems(spell: Spell, grammar: RuneGrammar = null) -> PackedStringArray:
	if grammar == null:
		grammar = RuneGrammar.usual()
	if spell == null:
		return PackedStringArray(["There is no spell."])
	return grammar.problems(spell.strokes)


static func to_dict(spell: Spell) -> Dictionary:
	return {
		"version": VERSION,
		"id": String(spell.id),
		"name": spell.display_name,
		"strokes": spell.strokes.map(func (stroke): return stroke.to_dict()),
	}


## The spell that to_dict() wrote, or null if `data` is not one: it is of
## another version, or is not a spell that could have been made.
static func from_dict(data: Dictionary, grammar: RuneGrammar = null) -> Spell:
	if int(data.get("version", 0)) != VERSION:
		return null
	var id := str(data.get("id", ""))
	var written: Variant = data.get("strokes")
	if not id.begins_with(PREFIX) or id.length() > 64 or not id.is_valid_filename() or written is not Array:
		return null
	var strokes: Array[RuneStroke] = []
	for stroke: Variant in written:
		if stroke is not Dictionary or int(stroke.get("rune", -1)) not in Rune.Type.values():
			return null
		var read := RuneStroke.from_dict(stroke)
		if not (is_finite(read.position.x) and is_finite(read.position.y)):
			return null
		strokes.append(read)
	var spell := make(str(data.get("name", "")), strokes, StringName(id), grammar)
	if not problems(spell, grammar).is_empty():
		return null
	return spell


## An id for a spell that is to be kept in `directory`, that no spell
## there has.
static func new_id(directory: String) -> StringName:
	var taken := {}
	for spell in all_in(directory):
		taken[spell.id] = true
	var number := 1
	while taken.has(StringName("%s%d" % [PREFIX, number])):
		number += 1
	return StringName("%s%d" % [PREFIX, number])


static func path_of(id: StringName, directory: String) -> String:
	return directory.path_join("%s.json" % [id])


## Keeps `spell` in `directory`. It is given an id if it has none.
## Returns FAILED if it is not a spell, or there is no room for another.
static func keep(spell: Spell, directory: String) -> Error:
	if not problems(spell).is_empty():
		return FAILED
	if spell.id.is_empty():
		if all_in(directory).size() >= MOST:
			return FAILED
		spell.id = new_id(directory)
	if not is_made(spell):
		return FAILED
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(path_of(spell.id, directory), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(to_dict(spell), "\t"))
	file.close()
	SpellLibrary.forget_made()
	return OK


## Throws away the spell with this id in `directory`.
static func discard(id: StringName, directory: String) -> void:
	if String(id).begins_with(PREFIX) and String(id).is_valid_filename():
		DirAccess.remove_absolute(path_of(id, directory))
	SpellLibrary.forget_made()


## Reads the spell at `path`, or null if what is there is not one.
static func read(path: String) -> Spell:
	if not FileAccess.file_exists(path):
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or json.data is not Dictionary:
		return null
	var spell := from_dict(json.data)
	# A file is the spell it is named for, and no other.
	if spell != null and path.get_file() != "%s.json" % [spell.id]:
		return null
	return spell


## Every spell kept in `directory`, in the order they were made.
static func all_in(directory: String) -> Array[Spell]:
	var found: Array[Spell] = []
	var dir := DirAccess.open(directory)
	if dir == null:
		return found
	var files: Array = Array(dir.get_files()).filter(func (file): return file.ends_with(".json"))
	files.sort_custom(func (a, b): return a.naturalnocasecmp_to(b) < 0)
	for file: String in files:
		var spell := read(directory.path_join(file))
		if spell != null and found.size() < MOST:
			found.append(spell)
	return found


## True if `spell` can be brought to a duel of the campaign by a caster
## who knows `known`: every rune in it is in a spell they know, and it is
## no longer than the longest spell they know. A caster makes spells of
## what they have learned.
static func can_be_brought(spell: Spell, known: Array) -> bool:
	return why_not_brought(spell, known).is_empty()


## Why `spell` cannot be brought by a caster who knows `known`, or "".
static func why_not_brought(spell: Spell, known: Array) -> String:
	var runes := {}
	var longest := 0
	for other: Spell in known:
		if other == null or is_made(other):
			continue
		longest = maxi(longest, other.strokes.size())
		for stroke in other.strokes:
			runes[stroke.rune] = true
	for stroke in spell.strokes:
		if not runes.has(stroke.rune):
			return "You have not learned a spell with %s in it." % [Rune.RuneToID[stroke.rune]]
	if spell.strokes.size() > longest:
		return "It has %d strokes, and the longest spell you have learned has %d." % [spell.strokes.size(), longest]
	return ""
