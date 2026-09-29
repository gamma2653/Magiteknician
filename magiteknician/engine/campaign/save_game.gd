class_name SaveGame
extends RefCounted
## How far the player has got, as it is written to disk.
##
## The file is JSON: it can be read, and mended, in a text editor. Spells
## and opponents are named by id, so a save outlives changes to either.

const VERSION := 1

## The campaign this save belongs to.
var campaign_id: StringName = &""
## How many stages have been won. Stages are won in order, so this is also
## the index of the next one.
var stages_cleared: int = 0
## Ids of the spells the player knows, in the order they learned them.
var spell_ids: Array[StringName] = []
## Ids of the spells the player brings to a duel, in the order of their
## keys. See Loadout.
var loadout: Array[StringName] = []
## The best win against each opponent, keyed by opponent id. Each is a
## dictionary with "quality" (mean cast quality, 0 to 1) and "seconds".
var best: Dictionary = {}


## Notes a win against `opponent_id`. Returns true if it is a new best,
## which is judged on quality first and on time if the quality is equal.
func record_win(opponent_id: StringName, quality: float, seconds: float) -> bool:
	var key := String(opponent_id)
	var previous: Dictionary = best.get(key, {})
	var is_better := previous.is_empty() \
		or quality > float(previous.get("quality", 0.0)) \
		or (is_equal_approx(quality, float(previous.get("quality", 0.0))) \
			and seconds < float(previous.get("seconds", INF)))
	if is_better:
		best[key] = {"quality": quality, "seconds": seconds}
	return is_better


## The best win against `opponent_id`, or an empty dictionary.
func best_against(opponent_id: StringName) -> Dictionary:
	return best.get(String(opponent_id), {})


## The spells the player brings to a duel: those they chose, made fit
## to bring. A spell they made is one they can bring if the session says
## so, which knows what they have made. Here it is taken on trust.
func bring() -> Array[StringName]:
	var can := spell_ids.duplicate()
	for id in loadout:
		if String(id).begins_with(SpellForge.PREFIX) and not can.has(id):
			can.append(id)
	return Loadout.tidy(loadout, can)


## Learns the spell with this id, and brings it if there is room. Returns
## false, and changes nothing, if it is known already.
func learn(id: StringName) -> bool:
	if spell_ids.has(id):
		return false
	# What is brought is settled before the spell is known, so that a
	# player who has chosen nothing brings the spells in the order they
	# learned them.
	var brought := bring()
	spell_ids.append(id)
	loadout = Loadout.with_learned(brought, id)
	return true


func to_dict() -> Dictionary:
	return {
		"version": VERSION,
		"campaign_id": String(campaign_id),
		"stages_cleared": stages_cleared,
		"spell_ids": spell_ids.map(func (id): return String(id)),
		"loadout": bring().map(func (id): return String(id)),
		"best": best.duplicate(true),
	}


static func from_dict(data: Dictionary) -> SaveGame:
	var save := SaveGame.new()
	save.campaign_id = StringName(str(data.get("campaign_id", "")))
	save.stages_cleared = maxi(int(data.get("stages_cleared", 0)), 0)
	var ids: Variant = data.get("spell_ids", [])
	if ids is Array:
		for id in ids:
			save.spell_ids.append(StringName(str(id)))
	# A save from before there were loadouts has none, and brings the
	# first few spells that were learned.
	var brought: Variant = data.get("loadout", [])
	save.loadout = []
	if brought is Array:
		for id: Variant in brought:
			save.loadout.append(StringName(str(id)))
	save.loadout = save.bring()
	var best_: Variant = data.get("best", {})
	if best_ is Dictionary:
		for key in best_:
			var entry: Variant = best_[key]
			if entry is Dictionary:
				save.best[str(key)] = {
					"quality": float(entry.get("quality", 0.0)),
					"seconds": float(entry.get("seconds", 0.0)),
				}
	return save


## Writes the save to `path`.
func write(path: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(to_dict(), "\t"))
	file.close()
	return OK


## Reads the save at `path`. Returns null if there is none, or if what is
## there cannot be read.
static func read(path: String) -> SaveGame:
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	if json.parse(text) != OK or json.data is not Dictionary:
		push_warning("The save at %s could not be read and will be ignored." % [path])
		return null
	return from_dict(json.data)
