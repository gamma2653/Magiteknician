class_name SpellResolver
extends RefCounted
## Applies a finished cast to the duelists.
##
## The cast's potency scales every amount, so how well the spell was cast
## decides how much it does. A cast that fizzled does nothing.


## Applies `spell`, cast by `caster` with the verdict `result`, to `caster`
## and `target`, and reports what happened.
static func resolve(spell: Spell, result: CastResult, caster: Duelist, target: Duelist) -> SpellOutcome:
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
				var ward_before := on.ward
				entry["through"] = on.take_damage(amount)
				entry["absorbed"] = minf(ward_before, amount)
			SpellEffect.Kind.WARD:
				on.raise_ward(amount, effect.duration)
			SpellEffect.Kind.HEAL:
				entry["amount"] = on.heal(amount)
		outcome.entries.append(entry)
	return outcome
