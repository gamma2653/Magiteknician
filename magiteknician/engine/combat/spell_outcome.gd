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
	if parts.is_empty():
		return "%s cast %s (%s) to no effect." % [who, what, result.grade_name]
	return "%s cast %s (%s): %s." % [who, what, result.grade_name, ", ".join(parts)]
