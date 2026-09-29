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
		if effect.kind == SpellEffect.Kind.ECHO:
			_echo(effect, outcome, damage_scale)
		else:
			outcome.entries.append(_apply(effect, result.potency, caster, target, damage_scale))
	return outcome


# Casts again the last spell of the target's that took effect, as the
# caster's own and at a share of this cast's potency.
static func _echo(effect: SpellEffect, outcome: SpellOutcome, damage_scale: float) -> void:
	var share := clampf(effect.amount * outcome.result.potency, 0.0, 1.0)
	var echoed := outcome.target.last_spell
	outcome.entries.append({
		"kind": effect.kind,
		"on": outcome.caster,
		"amount": share,
		"echoed": echoed,
		"landed": echoed != null,
	})
	if echoed == null:
		return
	for again in echoed.effects:
		# An echo of an echo would be an echo of nothing in particular.
		if again == null or again.kind == SpellEffect.Kind.ECHO:
			continue
		var entry := _apply(again, share, outcome.caster, outcome.target, damage_scale)
		entry["echo"] = true
		outcome.entries.append(entry)


# Applies one effect at `potency`, and says what it did.
static func _apply(effect: SpellEffect, potency: float, caster: Duelist, target: Duelist, damage_scale: float) -> Dictionary:
	var amount := effect.amount * potency
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
		SpellEffect.Kind.TRANSMUTE:
			entry["amount"] = on.transmute(amount)
			entry["landed"] = entry["amount"] > 0.0
		SpellEffect.Kind.EXCHANGE:
			# The caster has the target's ward, or as much of it as the
			# cast was good for, and the target has the caster's.
			var share := clampf(amount, 0.0, 1.0)
			var mine := caster.ward_as_it_is()
			var theirs := target.ward_as_it_is()
			entry["landed"] = mine["ward"] > 0.0 or theirs["ward"] > 0.0
			if entry["landed"]:
				caster.have_ward(theirs["ward"] * share, theirs["seconds"], theirs["reflect"])
				target.have_ward(mine["ward"], mine["seconds"], mine["reflect"])
			entry["amount"] = caster.ward
			entry["gave"] = target.ward
			entry["took_ward"] = theirs["ward"] > 0.0
	return entry
