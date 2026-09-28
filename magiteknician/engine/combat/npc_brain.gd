class_name NpcBrain
extends RefCounted
## Decides which spell an NPC reaches for next.
##
## Each spell the NPC can afford is given a weight for the situation, and
## one is drawn at random in proportion. The weights make the NPC sensible;
## the draw keeps it from being predictable.

const ATTACK_BASE_WEIGHT := 1.0
## Damage that doubles an attack's weight.
const ATTACK_REFERENCE_DAMAGE := 20.0
## An attack is worth this much less against a foe who is warded.
const ATTACK_INTO_WARD_FACTOR := 0.6
const WARD_IDLE_WEIGHT := 0.25
const WARD_THREAT_WEIGHT := 5.0
const HEAL_URGENT_WEIGHT := 6.0
const HEAL_IDLE_WEIGHT := 0.15


## The spell `me` should cast against `foe`, or null if there is nothing it
## can afford. `foe_spell` is the spell the foe is part-way through casting,
## if the NPC can see one.
static func choose(
	me: Duelist,
	foe: Duelist,
	foe_spell: Spell,
	profile: CasterProfile,
	rng: RandomNumberGenerator
) -> Spell:
	var candidates: Array[Spell] = []
	var weights: Array[float] = []
	var total := 0.0
	for spell in me.spellbook.spells:
		if spell == null or not me.can_afford(spell):
			continue
		var weight := weigh(spell, me, foe, foe_spell, profile)
		if weight <= 0.0:
			continue
		candidates.append(spell)
		weights.append(weight)
		total += weight
	if candidates.is_empty():
		return null
	var draw := rng.randf() * total
	for i in candidates.size():
		draw -= weights[i]
		if draw <= 0.0:
			return candidates[i]
	return candidates[-1]


## How much `me` wants to cast `spell` just now. Zero means not at all.
static func weigh(spell: Spell, me: Duelist, foe: Duelist, foe_spell: Spell, profile: CasterProfile) -> float:
	var weight := 0.0
	for effect in spell.effects:
		if effect == null:
			continue
		match effect.kind:
			SpellEffect.Kind.DAMAGE:
				var attack := ATTACK_BASE_WEIGHT + effect.amount / ATTACK_REFERENCE_DAMAGE
				if foe.is_warded():
					attack *= ATTACK_INTO_WARD_FACTOR
				weight += attack
			SpellEffect.Kind.WARD:
				if me.ward >= effect.amount:
					continue
				var threat := damage_of(foe_spell)
				if threat > 0.0:
					weight += WARD_THREAT_WEIGHT * profile.caution * (threat / ATTACK_REFERENCE_DAMAGE)
				else:
					weight += WARD_IDLE_WEIGHT * profile.caution
			SpellEffect.Kind.HEAL:
				var health_share := me.health / me.max_health
				if health_share < profile.heal_below:
					weight += HEAL_URGENT_WEIGHT * (1.0 - health_share)
				elif me.health < me.max_health - effect.amount:
					weight += HEAL_IDLE_WEIGHT
	return weight


## The damage `spell` would do at full potency. Zero for no spell.
static func damage_of(spell: Spell) -> float:
	if spell == null:
		return 0.0
	var damage := 0.0
	for effect in spell.effects:
		if effect != null and effect.kind == SpellEffect.Kind.DAMAGE:
			damage += effect.amount
	return damage
