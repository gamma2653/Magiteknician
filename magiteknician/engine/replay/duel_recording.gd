class_name DuelRecording
extends RefCounted
## A duel, written down so that it can be played again.
##
## A duel is decided by what was cast and when. So a recording is the two
## duelists as they began, and everything that was done on either spell
## circle with the time it was done: a spell laid out, a stroke made, a
## cast given up. Nothing that followed from those is written down. Played
## back through the same rules, the same things follow.
##
## The file is JSON, as the save is.

enum Kind {
	## A spell was laid out on the circle.
	PREPARE,
	## A stroke was made, on target or not.
	STRIKE,
	## The cast in progress was given up.
	ABANDON,
}

## Bumped when a recording changes shape.
const VERSION := 1
const PLAYER := 0
const OPPONENT := 1
## No more than this many recordings are kept. The oldest go first.
const KEEP := 30
## A recording begins its strokes' clocks here, in microseconds. Where
## they began in the duel is nobody's business.
const CLOCK_STARTS := 1_000_000

## The version of the game the duel was fought in.
var game_version: String = ""
## When it was fought, as "2026-09-28T21:30:05".
var recorded_at: String = ""
## What kind of duel it was: "campaign", "versus" or "duel".
var occasion: String = "duel"
## The two duelists as they began: the player, and then the opponent.
## Each is a dictionary with "name", "title", "max_health", "max_chi",
## "chi_per_second" and "spells", which is the ids of what they brought.
var sides: Array[Dictionary] = [{}, {}]
## Everything that was done, in order. Each is a dictionary:
##   "t": seconds into the duel
##   "side": PLAYER or OPPONENT
##   "kind": Kind
##   "spell": for a spell laid out, its id
##   "rune", "x", "y": for a stroke, which rune and where on the circle
##   "usec": for a stroke, when, by the clock the caster's strokes are
##     timed by. It is what the cast is judged on.
var events: Array[Dictionary] = []
## How long the duel lasted, in seconds.
var seconds: float = 0.0
## Who won: PLAYER, OPPONENT, or -1 if the duel was never finished.
var winner: int = -1
## Mean quality of the casts the player finished.
var mean_quality: float = 0.0
## The spells either duelist brought that were made and are not from the
## book, as they were when the duel was fought, each as SpellForge writes
## it. The player may change a spell, or throw it away, and the recording
## is of the spell that was cast.
var made: Array[Dictionary] = []


## Writes `duelist` down as the one on `side`.
func describe_side(side: int, duelist: Duelist, title: String = "") -> void:
	sides[side] = {
		"name": duelist.display_name,
		"title": title,
		"max_health": duelist.max_health,
		"max_chi": duelist.max_chi,
		"chi_per_second": duelist.chi_per_second,
		"spells": duelist.spellbook.ids().map(func (id): return String(id)),
	}
	for spell in duelist.spellbook.spells:
		if SpellForge.is_made(spell) and not _has_made(spell.id):
			made.append(SpellForge.to_dict(spell))


## Lends the library the spells that were made for this duel, so that
## they can be found by their ids while it is played. Take them back
## when it is over.
func lend_spells() -> void:
	for written in made:
		SpellLibrary.lend(SpellForge.from_dict(written))


func take_back_spells() -> void:
	for written in made:
		SpellLibrary.take_back(StringName(str(written.get("id", ""))))


## The names of the spells the duelist on `side` brought.
func spell_names(side: int) -> PackedStringArray:
	var names: PackedStringArray = []
	var ids: Variant = sides[side].get("spells", [])
	if ids is not Array:
		return names
	for id: Variant in ids:
		var spell := SpellLibrary.find(StringName(str(id)))
		for written in made:
			if str(written.get("id", "")) == str(id):
				spell = SpellForge.from_dict(written)
		if spell != null:
			names.append(spell.display_name)
	return names


func _has_made(id: StringName) -> bool:
	for written in made:
		if str(written.get("id", "")) == String(id):
			return true
	return false


## The duelist on `side`, as they began.
func duelist(side: int) -> Duelist:
	var written: Dictionary = sides[side]
	var made := Duelist.new(str(written.get("name", "")), float(written.get("max_health", 100.0)), float(written.get("max_chi", 100.0)))
	made.chi_per_second = float(written.get("chi_per_second", made.chi_per_second))
	made.spellbook = Spellbook.of(_known(written.get("spells", [])))
	return made


func name_of(side: int) -> String:
	return str(sides[side].get("name", ""))


func title_of(side: int) -> String:
	return str(sides[side].get("title", ""))


func player_won() -> bool:
	return winner == PLAYER


## The recording in a line, e.g. "Victory against Rizzle Dram".
func title() -> String:
	var against := name_of(OPPONENT)
	match winner:
		PLAYER:
			return "Victory against %s" % [against]
		OPPONENT:
			return "Defeat against %s" % [against]
	return "A duel against %s, not finished" % [against]


## What else there is to say of it, e.g. "28 September 2026 at 21:30 · 48 s".
func subtitle() -> String:
	var parts: PackedStringArray = []
	var when := Time.get_datetime_dict_from_datetime_string(recorded_at, false)
	if not when.is_empty() and int(when.get("year", 0)) > 0:
		const MONTHS := ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
		parts.append("%d %s %d at %02d:%02d" % [when["day"], MONTHS[clampi(int(when["month"]) - 1, 0, 11)], when["year"], when["hour"], when["minute"]])
	parts.append("%d s" % [roundi(seconds)])
	if mean_quality > 0.0:
		parts.append("%d%% mean quality" % [roundi(mean_quality * 100.0)])
	return " · ".join(parts)


## Everything wrong with the recording. Empty when it can be played.
func problems() -> PackedStringArray:
	var found: PackedStringArray = []
	for side in [PLAYER, OPPONENT]:
		if name_of(side).is_empty():
			found.append("The recording does not say who the %s was." % ["player" if side == PLAYER else "opponent"])
	if events.is_empty():
		found.append("Nothing happened in the duel.")
	var before := 0.0
	for event in events:
		if float(event["t"]) < before:
			found.append("The recording is out of order.")
			break
		before = float(event["t"])
		if int(event["kind"]) == Kind.PREPARE and not _can_find(str(event.get("spell", ""))):
			found.append("There is no spell with the id '%s'." % [event.get("spell", "")])
			break
	return found


# True if there is a spell with this id, in the library or among the
# spells that were made for this duel.
func _can_find(id: String) -> bool:
	if _has_made(StringName(id)):
		for written in made:
			if str(written.get("id", "")) == id:
				return SpellForge.from_dict(written) != null
	return SpellLibrary.has_spell(StringName(id))


func to_dict() -> Dictionary:
	return {
		"version": VERSION,
		"game_version": game_version,
		"recorded_at": recorded_at,
		"occasion": occasion,
		"sides": sides.duplicate(true),
		"events": events.duplicate(true),
		"seconds": seconds,
		"winner": winner,
		"mean_quality": mean_quality,
		"made": made.duplicate(true),
	}


## The recording that to_dict() made, or null if `data` is not one that
## this version of the game can read.
static func from_dict(data: Dictionary) -> DuelRecording:
	if int(data.get("version", 0)) != VERSION:
		return null
	var written_sides: Variant = data.get("sides")
	var written_events: Variant = data.get("events")
	if written_sides is not Array or written_sides.size() != 2 or written_events is not Array:
		return null
	var recording := DuelRecording.new()
	recording.game_version = str(data.get("game_version", ""))
	recording.recorded_at = str(data.get("recorded_at", ""))
	recording.occasion = str(data.get("occasion", "duel"))
	recording.seconds = float(data.get("seconds", 0.0))
	recording.winner = clampi(int(data.get("winner", -1)), -1, OPPONENT)
	recording.mean_quality = float(data.get("mean_quality", 0.0))
	var written_made: Variant = data.get("made", [])
	if written_made is Array:
		for written: Variant in written_made:
			if written is Dictionary:
				recording.made.append(written.duplicate(true))
	for side in 2:
		if written_sides[side] is not Dictionary:
			return null
		recording.sides[side] = written_sides[side].duplicate(true)
	for written: Variant in written_events:
		if written is not Dictionary:
			return null
		var kind := int(written.get("kind", -1))
		var side := int(written.get("side", -1))
		if kind not in Kind.values() or side not in [PLAYER, OPPONENT]:
			return null
		# JSON has one kind of number. What has to be whole is made whole.
		var event := {"t": float(written.get("t", 0.0)), "side": side, "kind": kind}
		match kind:
			Kind.PREPARE:
				event["spell"] = str(written.get("spell", ""))
			Kind.STRIKE:
				var rune := int(written.get("rune", -1))
				if rune not in Rune.Type.values():
					return null
				event["rune"] = rune
				event["x"] = float(written.get("x", 0.0))
				event["y"] = float(written.get("y", 0.0))
				event["usec"] = int(written.get("usec", 0))
		recording.events.append(event)
	return recording


func write(path: String) -> Error:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(to_dict()))
	file.close()
	return OK


## Reads the recording at `path`. Returns null if there is none, or if
## what is there cannot be read.
static func read(path: String) -> DuelRecording:
	if not FileAccess.file_exists(path):
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or json.data is not Dictionary:
		return null
	return from_dict(json.data)


## Writes the recording into `directory` under a name made of when it was
## fought and against whom, and throws away the oldest recordings there
## if there are now too many. Returns where it was written, or "".
func keep_in(directory: String) -> String:
	var against := name_of(OPPONENT).to_snake_case().validate_filename()
	var path := directory.path_join("%s_%s.json" % [recorded_at.replace(":", "-"), against])
	if write(path) != OK:
		push_warning("The duel could not be recorded at %s." % [path])
		return ""
	var kept := paths_in(directory)
	for old in kept.slice(KEEP):
		DirAccess.remove_absolute(old)
	return path


## Where the recordings in `directory` are, the newest first.
static func paths_in(directory: String) -> Array[String]:
	var found: Array[String] = []
	var dir := DirAccess.open(directory)
	if dir == null:
		return found
	for file in dir.get_files():
		if file.ends_with(".json"):
			found.append(directory.path_join(file))
	# They are named by when they were fought, so this is by age.
	found.sort()
	found.reverse()
	return found


## The recordings in `directory` that can be read, the newest first.
static func all_in(directory: String) -> Array[DuelRecording]:
	var found: Array[DuelRecording] = []
	for path in paths_in(directory):
		var recording := read(path)
		if recording != null:
			found.append(recording)
	return found


static func _known(ids: Variant) -> Array[StringName]:
	var known: Array[StringName] = []
	if ids is Array:
		for id: Variant in ids:
			if SpellLibrary.has_spell(StringName(str(id))):
				known.append(StringName(str(id)))
	return known
