@tool
class_name Spell
extends Resource
## A spell: the runes to strike, the rhythm to strike them in, and where
## they sit on the spell circle.
##
## A spell is data and nothing else. The same resource is what the player
## casts from, what an NPC casts from, and what gets named across the
## network, so it holds no nodes and no state.

enum School {
	ABJURATION,
	CONJURATION,
	EVOCATION,
	ENCHANTMENT,
	TRANSMUTATION,
	ILLUSION,
	NECROMANCY,
	DIVINATION,
}
enum Rank { NOVICE, APPRENTICE, ADEPT, EXPERT, MASTER }

const SCHOOL_NAMES: Dictionary[School, String] = {
	School.ABJURATION: "Abjuration",
	School.CONJURATION: "Conjuration",
	School.EVOCATION: "Evocation",
	School.ENCHANTMENT: "Enchantment",
	School.TRANSMUTATION: "Transmutation",
	School.ILLUSION: "Illusion",
	School.NECROMANCY: "Necromancy",
	School.DIVINATION: "Divination",
}
const RANK_NAMES: Dictionary[Rank, String] = {
	Rank.NOVICE: "Novice",
	Rank.APPRENTICE: "Apprentice",
	Rank.ADEPT: "Adept",
	Rank.EXPERT: "Expert",
	Rank.MASTER: "Master",
}

## Runes further than this from the centre of the circle are off the part
## of the screen set aside for casting.
const CIRCLE_RADIUS := 230.0

## Stable name used in save files and, later, network messages.
@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var school: School = School.EVOCATION
@export var rank: Rank = Rank.NOVICE
## The runes of the spell, in the order they are struck.
@export var strokes: Array[RuneStroke] = []


## The spell's rhythm: the tick of each stroke, in order.
func ticks() -> Array[int]:
	var result: Array[int] = []
	for stroke in strokes:
		result.append(stroke.tick)
	return result


## Ticks from the first stroke to the last. Multiplied by a caster's tempo,
## this is how long the spell takes them to cast.
func span_ticks() -> int:
	if strokes.is_empty():
		return 0
	return strokes[-1].tick - strokes[0].tick


## How many times each rune appears, keyed by rune type.
func rune_counts() -> Dictionary[Rune.Type, int]:
	var counts: Dictionary[Rune.Type, int] = {}
	for stroke in strokes:
		counts[stroke.rune] = counts.get(stroke.rune, 0) + 1
	return counts


## The spell's runes in the notation of the runebook, e.g. "δ + ρ ×3 + λ".
## Runes are listed in the order they first appear.
func formula() -> String:
	var counts := rune_counts()
	var parts: PackedStringArray = []
	for rune in counts:
		if counts[rune] == 1:
			parts.append(Rune.RuneToID[rune])
		else:
			parts.append("%s ×%d" % [Rune.RuneToID[rune], counts[rune]])
	return " + ".join(parts)


## Everything wrong with the spell as written. Empty when it can be cast.
func problems() -> PackedStringArray:
	var found: PackedStringArray = []
	if id.is_empty():
		found.append("The spell has no id.")
	if strokes.is_empty():
		found.append("The spell has no strokes.")
		return found
	var previous_tick := -1
	for i in strokes.size():
		var stroke := strokes[i]
		if stroke == null:
			found.append("Stroke %d is empty." % [i + 1])
			continue
		if i == 0 and stroke.tick != 0:
			found.append("The first stroke is on tick %d; a spell starts on tick 0." % [stroke.tick])
		if i > 0 and stroke.tick <= previous_tick:
			found.append(
				"Stroke %d is on tick %d, which is not after tick %d of the stroke before it."
				% [i + 1, stroke.tick, previous_tick]
			)
		previous_tick = stroke.tick
		if stroke.position.length() > CIRCLE_RADIUS:
			found.append(
				"Stroke %d is %d px from the centre; the circle's radius is %d px."
				% [i + 1, roundi(stroke.position.length()), roundi(CIRCLE_RADIUS)]
			)
	return found


func is_castable() -> bool:
	return problems().is_empty()


## Reads a spell off a train whose runes were placed in the editor.
## Positions are taken relative to `centre`, in the train's own space.
static func from_train(train: Train, centre: Vector2 = Vector2.ZERO) -> Spell:
	var spell := Spell.new()
	for rune in train.bound_runes:
		spell.strokes.append(RuneStroke.make(rune.rune_type, rune.unscaled_ticks, rune.position - centre))
	return spell


func _to_string() -> String:
	var name_ := display_name if not display_name.is_empty() else String(id)
	return "<Spell %s: %s>" % [name_, " ".join(strokes.map(func (stroke): return str(stroke)))]
