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
## Ids of the spells the player knows, in the order they keep them.
var spell_ids: Array[StringName] = []
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


func to_dict() -> Dictionary:
	return {
		"version": VERSION,
		"campaign_id": String(campaign_id),
		"stages_cleared": stages_cleared,
		"spell_ids": spell_ids.map(func (id): return String(id)),
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
