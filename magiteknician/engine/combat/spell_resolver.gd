class_name SpellResolver
extends RefCounted
## Applies a finished cast to the duelists.
##
## The cast's potency scales every amount, so how well the spell was cast
## decides how much it does. A cast that fizzled does nothing.


## Applies `spell`, cast by `caster` with the verdict `result`, to `caster`
## and `target`, and reports what happened. `damage_scale` multiplies the
## damage done, and nothing else.
static func resolve(
	spell: Spell,
	result: CastResult,
	caster: Duelist,
	target: Duelist,
	damage_scale: float = 1.0
) -> SpellOutcome:
	var outcome := SpellOutcome.new()
	outcome.spell = spell
	outcome.result = result
	outcome.caster = caster
	outcome.target = target
	if spell == null or outcome.fizzled:
		return outcome

	for effect in spell.effects:
		if effect == null:
			continue
		var amount := effect.amount * result.potency
		var on := caster if effect.is_on_self() else target
		var entry := {"kind": effect.kind, "on": on, "amount": amount}
		match effect.kind:
			SpellEffect.Kind.DAMAGE:
				amount *= damage_scale
				entry["amount"] = amount
				var ward_before := on.ward
				# Read before the blow lands: a ward that breaks takes
				# its reflection with it, but still turns this blow back.
				var share := on.ward_reflect
				entry["through"] = on.take_damage(amount)
				entry["absorbed"] = minf(ward_before, amount)
				entry["broke_ward"] = ward_before > 0.0 and not on.is_warded()
				entry["reflected"] = 0.0
				if share > 0.0 and entry["absorbed"] > 0.0:
					# What is turned back is not turned back again.
					var returned: float = entry["absorbed"] * share
					var reflect_before := caster.ward_reflect
					caster.ward_reflect = 0.0
					caster.take_damage(returned)
					if caster.is_warded():
						caster.ward_reflect = reflect_before
					entry["reflected"] = returned
			SpellEffect.Kind.WARD:
				entry["landed"] = on.raise_ward(amount, effect.duration)
			SpellEffect.Kind.HEAL:
				entry["amount"] = on.heal(amount)
			SpellEffect.Kind.BATTER:
				entry["amount"] = on.batter(amount)
				entry["landed"] = entry["amount"] > 0.0
				entry["broke_ward"] = entry["landed"] and not on.is_warded()
			SpellEffect.Kind.INTERRUPT:
				entry["broke"] = on.interrupt()
				entry["landed"] = entry["broke"] != null
			SpellEffect.Kind.CHILL:
				on.apply_chill(amount, effect.duration)
			SpellEffect.Kind.REFLECT:
				entry["landed"] = on.make_ward_reflect(amount)
		outcome.entries.append(entry)
	return outcome
