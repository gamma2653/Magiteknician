class_name SpellOutcome
extends RefCounted
## What a cast did once it was resolved. Made by SpellResolver.

var spell: Spell
var result: CastResult
var caster: Duelist
var target: Duelist
## One entry for each effect of the spell, in order. Each is a dictionary:
##   "kind": SpellEffect.Kind
##   "on": the Duelist it landed on
##   "amount": what was delivered, after scaling by potency
##   "absorbed": for damage, the part a ward soaked up
##   "through": for damage, the part that reached health
##   "reflected": for damage, the part the ward turned back on the caster
##   "broke_ward": true if it used up the ward it landed on
##   "broke": for an interruption, the Spell it broke, or null
##   "landed": false for an effect that found nothing to act on
var entries: Array[Dictionary] = []

var fizzled: bool:
	get:
		return result == null or result.fizzled


## Total of `field` across entries of `kind`.
func total(kind: SpellEffect.Kind, field: String = "amount") -> float:
	var sum := 0.0
	for entry in entries:
		if entry["kind"] == kind:
			sum += float(entry.get(field, 0.0))
	return sum


func damage_dealt() -> float:
	return total(SpellEffect.Kind.DAMAGE, "through")


func damage_absorbed() -> float:
	return total(SpellEffect.Kind.DAMAGE, "absorbed")


func damage_reflected() -> float:
	return total(SpellEffect.Kind.DAMAGE, "reflected")


## The spell this cast broke, or null.
func spell_broken() -> Spell:
	for entry in entries:
		if entry["kind"] == SpellEffect.Kind.INTERRUPT and entry.get("broke") != null:
			return entry["broke"]
	return null


## The outcome as plain numbers and strings, to be sent to another
## machine. Who cast the spell and at whom is not in it: the two machines
## have different duelists for the same two players, and whoever sends it
## says whose cast it was.
func to_dict() -> Dictionary:
	var plain: Array = []
	for entry in entries:
		var broke: Spell = entry.get("broke")
		plain.append({
			"kind": int(entry["kind"]),
			"on_caster": entry.get("on") == caster,
			"amount": float(entry.get("amount", 0.0)),
			"absorbed": float(entry.get("absorbed", 0.0)),
			"through": float(entry.get("through", 0.0)),
			"reflected": float(entry.get("reflected", 0.0)),
			"landed": bool(entry.get("landed", true)),
			"broke": String(broke.id) if broke != null else "",
			"broke_ward": bool(entry.get("broke_ward", false)),
		})
	return {
		"spell": String(spell.id) if spell != null else "",
		"grade": int(result.grade) if result != null else int(CastResult.Grade.FIZZLE),
		"quality": result.quality if result != null else 0.0,
		"potency": result.potency if result != null else 0.0,
		"cadence_links": result.cadence_links if result != null else 0,
		"entries": plain,
	}


## The outcome that to_dict() made on another machine, as a cast by
## `caster_` at `target_`. It has what is needed to show the cast and to
## describe it. The strokes of the cast are not in it.
static func from_dict(data: Dictionary, caster_: Duelist, target_: Duelist) -> SpellOutcome:
	var outcome := SpellOutcome.new()
	outcome.caster = caster_
	outcome.target = target_
	outcome.spell = SpellLibrary.find(StringName(str(data.get("spell", ""))))
	outcome.result = CastResult.new()
	outcome.result.grade = clampi(int(data.get("grade", CastResult.Grade.FIZZLE)), 0, CastResult.Grade.size() - 1) as CastResult.Grade
	outcome.result.quality = float(data.get("quality", 0.0))
	outcome.result.potency = float(data.get("potency", 0.0))
	outcome.result.cadence_links = maxi(int(data.get("cadence_links", 0)), 0)
	var plain: Variant = data.get("entries", [])
	if plain is not Array:
		return outcome
	for entry: Variant in plain:
		if entry is not Dictionary:
			continue
		var kind := int(entry.get("kind", -1))
		if kind not in SpellEffect.Kind.values():
			continue
		var broke := str(entry.get("broke", ""))
		outcome.entries.append({
			"kind": kind as SpellEffect.Kind,
			"on": caster_ if entry.get("on_caster", false) else target_,
			"amount": float(entry.get("amount", 0.0)),
			"absorbed": float(entry.get("absorbed", 0.0)),
			"through": float(entry.get("through", 0.0)),
			"reflected": float(entry.get("reflected", 0.0)),
			"landed": bool(entry.get("landed", true)),
			"broke": null if broke.is_empty() else SpellLibrary.find(StringName(broke)),
			"broke_ward": bool(entry.get("broke_ward", false)),
		})
	return outcome


## The outcome in a line, for a combat log.
func describe() -> String:
	var who := caster.display_name if caster != null else "Someone"
	var whose := caster.possessive if caster != null else "Someone's"
	var what := spell.display_name if spell != null else "a spell"
	if fizzled:
		return "%s %s fizzled." % [whose, what]
	var parts: PackedStringArray = []
	for entry in entries:
		match entry["kind"]:
			SpellEffect.Kind.DAMAGE:
				var line := "%d damage" % [roundi(entry["through"])]
				if entry["absorbed"] > 0.0:
					line += " (%d warded)" % [roundi(entry["absorbed"])]
				if entry.get("reflected", 0.0) > 0.0:
					line += ", %d turned back" % [roundi(entry["reflected"])]
				parts.append(line)
			SpellEffect.Kind.WARD:
				parts.append("a ward of %d" % [roundi(entry["amount"])])
			SpellEffect.Kind.HEAL:
				parts.append("%d healed" % [roundi(entry["amount"])])
			SpellEffect.Kind.BATTER:
				if entry["landed"]:
					parts.append("%d off the ward" % [roundi(entry["amount"])])
			SpellEffect.Kind.INTERRUPT:
				if entry["broke"] != null:
					parts.append("broke %s" % [entry["broke"].display_name])
			SpellEffect.Kind.CHILL:
				parts.append("chilled")
			SpellEffect.Kind.REFLECT:
				if entry["landed"]:
					parts.append("turning back %d%%" % [roundi(entry["amount"] * 100.0)])
	var how := result.grade_name
	if result.cadence_links > 0:
		how = "%s, %d in cadence" % [how, result.cadence_links + 1]
	if parts.is_empty():
		return "%s cast %s (%s) to no effect." % [who, what, how]
	return "%s cast %s (%s): %s." % [who, what, how, ", ".join(parts)]
