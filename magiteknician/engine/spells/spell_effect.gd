@tool
class_name SpellEffect
extends Resource
## One thing a spell does when it is cast.
##
## The amount written here is what a flawless cast delivers. What a given
## cast delivers is that amount scaled by the cast's potency.

enum Kind {
	## Harms the foe. Their ward takes it first.
	DAMAGE,
	## Raises a ward on the caster that soaks up damage until it is used up
	## or lapses.
	WARD,
	## Restores the caster's health.
	HEAL,
	## Wears down the foe's ward and does nothing to the foe behind it.
	## A ward arrests momentum until it has no more to give; this is
	## momentum and nothing else.
	BATTER,
	## Breaks the cast the foe is part-way through. Their chi stays spent.
	## A ward keeps it out.
	INTERRUPT,
	## Chills the foe for a time. While chilled, their strokes are judged
	## more strictly: the amount is the share taken off their tolerance.
	CHILL,
	## Makes the caster's ward turn back a share of what it soaks up onto
	## whoever struck it. The amount is the share. It goes with the ward.
	REFLECT,
}

const KIND_NAMES: Dictionary[Kind, String] = {
	Kind.DAMAGE: "Damage",
	Kind.WARD: "Ward",
	Kind.HEAL: "Heal",
	Kind.BATTER: "Batter",
	Kind.INTERRUPT: "Interrupt",
	Kind.CHILL: "Chill",
	Kind.REFLECT: "Reflect",
}

@export var kind: Kind = Kind.DAMAGE
## How much, at full potency.
@export_range(0.0, 200.0, 0.5, "or_greater") var amount: float = 10.0
## How long it lasts, in seconds, for effects that last. Potency does not
## change it.
@export_range(0.0, 60.0, 0.5, "or_greater") var duration: float = 0.0


static func make(kind_: Kind, amount_: float, duration_: float = 0.0) -> SpellEffect:
	var effect := SpellEffect.new()
	effect.kind = kind_
	effect.amount = amount_
	effect.duration = duration_
	return effect


## True when the effect lands on the caster rather than on their foe.
func is_on_self() -> bool:
	return kind == Kind.WARD or kind == Kind.HEAL or kind == Kind.REFLECT


## What the effect does, in a few words, at the given potency.
func describe(potency: float = 1.0) -> String:
	var scaled := roundi(amount * potency)
	match kind:
		Kind.DAMAGE:
			return "%d damage" % [scaled]
		Kind.WARD:
			return "ward of %d for %ss" % [scaled, String.num(duration, 1).trim_suffix(".0")]
		Kind.HEAL:
			return "heals %d" % [scaled]
		Kind.BATTER:
			return "batters a ward for %d" % [scaled]
		Kind.INTERRUPT:
			return "breaks a cast"
		Kind.CHILL:
			return "chills for %ss" % [String.num(duration, 1).trim_suffix(".0")]
		Kind.REFLECT:
			return "turns back %d%%" % [roundi(amount * potency * 100.0)]
	return ""
