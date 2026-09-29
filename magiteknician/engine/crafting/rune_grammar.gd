@tool
class_name RuneGrammar
extends Resource
## What a spell does, worked out from the runes it is made of.
##
## The spells in the book were each written by hand: what Fire Bolt does
## is in Fire Bolt's file. A spell the player makes has no file but the
## runes they chose, so what it does has to follow from those, by rules.
## These are the rules.
##
## Each rune does in a spell what the notes say it does in the world:
##
##   ρ Flow          sends the spell at the foe, with force
##   δ Development   builds: the blow if the spell is sent, the caster
##                   if it is kept
##   λ Decay         breaks down: it harms what it is sent at, and chills
##   θ Refraction    turns aside: a cast that is sent at, or a blow
##                   that lands on a ward
##   κ Persistence   makes last: a ward round the caster, or the chill
##                   on the foe
##   σ Variability   centres the spell on what was meant, so that all
##                   of it does a little more
##   φ Equivalence   has one state be another: a ward be health, two
##                   wards change hands, the foe's spell be the caster's
##
## A spell with ρ in it is sent. One without is kept, and is the
## caster's own.
##
## What a spell costs follows from what it does, and from how hard it is
## to cast: a rhythm that is harder to keep, over runes that are further
## apart, costs less.
##
## The numbers are all here, to be changed. None of this is from the
## notes but what each rune is for.

const MIN_STROKES := 3
const MAX_STROKES := 9
## Runes nearer than this, centre to centre, are on top of each other.
const MIN_APART := Rune.RADIUS * 2.0 + 6.0
const MAX_GAP := 5
const MAX_SPAN := 16

@export_group("Sent at the foe")
## Damage for each ρ, δ and λ in a spell that carries something.
@export var damage_per_flow: float = 3.0
@export var damage_per_development: float = 4.5
@export var damage_per_decay: float = 2.0
## A spell of ρ and nothing to carry is momentum alone. It wears a ward
## down by this much for each ρ, and does this much harm.
@export var batter_per_flow: float = 7.0
@export var bare_damage_per_flow: float = 1.5
## How hard λ chills for each, and the hardest it can.
@export var chill_per_decay: float = 0.12
@export var chill_at_most: float = 0.6
## How long a chill lasts, and how much longer for each κ.
@export var chill_seconds: float = 4.0
@export var chill_seconds_per_persistence: float = 2.0

@export_group("Kept")
@export var heal_per_development: float = 5.5
@export var ward_per_persistence: float = 6.5
## How long a ward lasts, and how much longer for each κ.
@export var ward_seconds: float = 5.0
@export var ward_seconds_per_persistence: float = 1.5
## The share a ward turns back for each θ, and the most it can.
@export var reflect_per_refraction: float = 0.15
@export var reflect_at_most: float = 0.6

@export_group("Equivalence")
@export var transmute_per_equivalence: float = 6.0
@export var transmute_per_development: float = 3.0
@export var exchange_share: float = 0.4
@export var exchange_per_equivalence: float = 0.2
@export var echo_share: float = 0.45
@export var echo_per_equivalence: float = 0.15

@export_group("Variability")
## How much more the whole spell does for each σ, as a share, and how
## many σ count.
@export var focus_per_variability: float = 0.08
@export var variability_at_most: int = 4

@export_group("Cost")
## Chi for each point, or each whole share, of what a spell does.
@export var cost_of_damage: float = 1.0
@export var cost_of_batter: float = 0.45
@export var cost_of_heal: float = 1.6
@export var cost_of_ward: float = 1.1
@export var cost_of_transmute: float = 0.4
@export var cost_of_interrupt: float = 9.0
@export var cost_of_chill: float = 8.0
@export var cost_of_chill_second: float = 0.25
@export var cost_of_reflect: float = 30.0
@export var cost_of_echo: float = 22.0
@export var cost_of_exchange: float = 18.0
## A spell of the player's own making costs this much more than its
## like from the book would, as a share. The book's spells were written
## with care, and are meant to be worth having.
@export var surcharge: float = 0.1
## How much less a spell costs for each stroke over three. A long spell
## takes long to cast, and the foe is not waiting.
@export var discount_per_stroke: float = 0.03
## How much more the easiest spell costs than a middling one, and how
## much less the hardest, as a share.
@export var swing_for_difficulty: float = 0.15
## The least any spell costs.
@export var least_cost: float = 4.0
## Runes this far apart, from each to the next, are as far apart as
## counts, in pixels.
@export var far_apart: float = 220.0

static var _usual: RuneGrammar


## The grammar the game uses.
static func usual() -> RuneGrammar:
	if _usual == null:
		_usual = RuneGrammar.new()
	return _usual


## How many of each rune there are in `strokes`.
static func count(strokes: Array) -> Dictionary[Rune.Type, int]:
	var counts: Dictionary[Rune.Type, int] = {}
	for type in Rune.Type.values():
		counts[type] = 0
	for stroke: RuneStroke in strokes:
		if stroke != null:
			counts[stroke.rune] += 1
	return counts


## True if a spell of `strokes` is sent at the foe.
static func is_sent(strokes: Array) -> bool:
	return count(strokes)[Rune.Type.FLOW] > 0


## How much more the whole of a spell of `strokes` does for its σ.
func focus(strokes: Array) -> float:
	return 1.0 + focus_per_variability * mini(count(strokes)[Rune.Type.VARIABILITY], variability_at_most)


## What a spell of `strokes` does, at full potency.
func effects_of(strokes: Array) -> Array[SpellEffect]:
	var does: Array[SpellEffect] = []
	var n := count(strokes)
	var flow := n[Rune.Type.FLOW]
	var build := n[Rune.Type.DEVELOPMENT]
	var decay := n[Rune.Type.DECAY]
	var turn := n[Rune.Type.REFRACTION]
	var last := n[Rune.Type.PERSISTENCE]
	var same := n[Rune.Type.EQUIVELANCE]
	var sharper := focus(strokes)

	if flow > 0:
		if same > 0 and turn > 0:
			# What the foe cast is turned about and is the caster's.
			var share := echo_share + echo_per_equivalence * same
			does.append(SpellEffect.make(SpellEffect.Kind.ECHO, minf(share * sharper, 1.0)))
			turn = 0
		elif same > 0 and last > 0:
			# What lasts round the one lasts round the other.
			var share := exchange_share + exchange_per_equivalence * same
			does.append(SpellEffect.make(SpellEffect.Kind.EXCHANGE, minf(share * sharper, 1.0)))
			last = 0
		if build + decay > 0:
			var blow := damage_per_flow * flow + damage_per_development * build + damage_per_decay * decay
			does.append(SpellEffect.make(SpellEffect.Kind.DAMAGE, _rounded(blow * sharper)))
		elif does.is_empty():
			does.append(SpellEffect.make(SpellEffect.Kind.BATTER, _rounded(batter_per_flow * flow * sharper)))
			does.append(SpellEffect.make(SpellEffect.Kind.DAMAGE, _rounded(bare_damage_per_flow * flow * sharper)))
		if turn > 0:
			does.append(SpellEffect.make(SpellEffect.Kind.INTERRUPT, 1.0))
		if decay > 0:
			does.append(SpellEffect.make(
				SpellEffect.Kind.CHILL,
				snappedf(minf(chill_per_decay * decay * sharper, chill_at_most), 0.01),
				chill_seconds + chill_seconds_per_persistence * last,
			))
		return does

	if same > 0:
		# A ward is made over into health.
		var made := transmute_per_equivalence * same + transmute_per_development * build
		does.append(SpellEffect.make(SpellEffect.Kind.TRANSMUTE, _rounded(made * sharper)))
		build = 0
	if last > 0:
		does.append(SpellEffect.make(
			SpellEffect.Kind.WARD,
			_rounded(ward_per_persistence * last * sharper),
			ward_seconds + ward_seconds_per_persistence * last,
		))
		if turn > 0:
			does.append(SpellEffect.make(SpellEffect.Kind.REFLECT, snappedf(minf(reflect_per_refraction * turn * sharper, reflect_at_most), 0.01)))
	if build > 0:
		does.append(SpellEffect.make(SpellEffect.Kind.HEAL, _rounded(heal_per_development * build * sharper)))
	return does


## The runes of `strokes` that do nothing where they are, with what each
## is wanting, as lines to be shown. A spell with some is a spell, and
## costs what it costs. It could be shorter.
func idle_runes(strokes: Array) -> PackedStringArray:
	var idle: PackedStringArray = []
	var n := count(strokes)
	var sent := n[Rune.Type.FLOW] > 0
	var same := n[Rune.Type.EQUIVELANCE] > 0
	if sent:
		if same and n[Rune.Type.REFRACTION] == 0 and n[Rune.Type.PERSISTENCE] == 0:
			idle.append("φ has nothing to work on. Sent at the foe it wants θ, to take their spell, or κ, to take their ward.")
		if n[Rune.Type.PERSISTENCE] > 0 and n[Rune.Type.DECAY] == 0 and not same:
			idle.append("κ has nothing to make last. Sent at the foe it makes a chill last, and there is no λ to chill.")
		if same and n[Rune.Type.REFRACTION] > 0 and n[Rune.Type.PERSISTENCE] > 0 and n[Rune.Type.DECAY] == 0:
			idle.append("κ has nothing to make last. φ has taken θ, and there is no λ to chill.")
	else:
		if n[Rune.Type.DECAY] > 0:
			idle.append("λ has nothing to break down. A spell that is kept is the caster's own.")
		if n[Rune.Type.REFRACTION] > 0 and n[Rune.Type.PERSISTENCE] == 0:
			idle.append("θ has nothing to turn blows back from. Kept, it wants κ, for a ward.")
		if n[Rune.Type.VARIABILITY] > 0 and effects_of(strokes).is_empty():
			idle.append("σ has nothing to centre.")
	if n[Rune.Type.VARIABILITY] > variability_at_most:
		idle.append("σ counts %d times, and there are %d." % [variability_at_most, n[Rune.Type.VARIABILITY]])
	return idle


## Everything that stops `strokes` being a spell. Empty when they are one.
func problems(strokes: Array) -> PackedStringArray:
	var found: PackedStringArray = []
	if strokes.size() < MIN_STROKES:
		found.append("A spell wants at least %d strokes. Any two fit a rhythm, so two cannot be off it." % [MIN_STROKES])
	if strokes.size() > MAX_STROKES:
		found.append("A spell has at most %d strokes." % [MAX_STROKES])
	for i in strokes.size():
		var stroke: RuneStroke = strokes[i]
		if stroke.position.length() > Spell.CIRCLE_RADIUS:
			found.append("Rune %d is outside the circle." % [i + 1])
		for j in i:
			if stroke.position.distance_to(strokes[j].position) < MIN_APART:
				found.append("Runes %d and %d are on top of each other." % [j + 1, i + 1])
		if i == 0:
			if stroke.tick != 0:
				found.append("The first stroke is on tick %d, and a spell starts on tick 0." % [stroke.tick])
			continue
		var gap: int = stroke.tick - strokes[i - 1].tick
		if gap < 1:
			found.append("Stroke %d is not after stroke %d." % [i + 1, i])
		elif gap > MAX_GAP:
			found.append("There are %d ticks before stroke %d, and %d is the longest silence." % [gap, i + 1, MAX_GAP])
	if not strokes.is_empty() and strokes[-1].tick - strokes[0].tick > MAX_SPAN:
		found.append("The spell is %d ticks long, and %d is the longest." % [strokes[-1].tick - strokes[0].tick, MAX_SPAN])
	if strokes.size() >= MIN_STROKES and effects_of(strokes).is_empty():
		found.append("These runes do nothing together.")
	return found


## How hard a spell of `strokes` is to cast, from 0 to 1. Half of it is
## the rhythm: how many different lengths there are between one stroke
## and the next. Half is the reach: how far it is from each rune to the
## next.
func difficulty_of(strokes: Array) -> float:
	if strokes.size() < 2:
		return 0.0
	var lengths := {}
	var reach := 0.0
	for i in range(1, strokes.size()):
		lengths[strokes[i].tick - strokes[i - 1].tick] = true
		reach += strokes[i].position.distance_to(strokes[i - 1].position)
	reach /= strokes.size() - 1
	var rhythm := clampf((lengths.size() - 1) / 2.0, 0.0, 1.0)
	var apart := clampf((reach - MIN_APART) / maxf(far_apart - MIN_APART, 1.0), 0.0, 1.0)
	return (rhythm + apart) / 2.0


## What a spell of `strokes` costs, in chi.
func cost_of(strokes: Array) -> float:
	var worth := 0.0
	for effect in effects_of(strokes):
		worth += worth_of(effect)
	worth *= 1.0 + surcharge
	worth *= maxf(1.0 - discount_per_stroke * maxi(strokes.size() - MIN_STROKES, 0), 0.5)
	worth *= 1.0 + swing_for_difficulty * (1.0 - 2.0 * difficulty_of(strokes))
	return maxf(roundf(worth), least_cost)


## What one thing a spell does is worth, in chi, before anything is
## added or taken off.
func worth_of(effect: SpellEffect) -> float:
	match effect.kind:
		SpellEffect.Kind.DAMAGE:
			return cost_of_damage * effect.amount
		SpellEffect.Kind.BATTER:
			return cost_of_batter * effect.amount
		SpellEffect.Kind.HEAL:
			return cost_of_heal * effect.amount
		SpellEffect.Kind.WARD:
			return cost_of_ward * effect.amount
		SpellEffect.Kind.TRANSMUTE:
			return cost_of_transmute * effect.amount
		SpellEffect.Kind.INTERRUPT:
			return cost_of_interrupt
		SpellEffect.Kind.CHILL:
			return cost_of_chill * effect.amount + cost_of_chill_second * effect.duration
		SpellEffect.Kind.REFLECT:
			return cost_of_reflect * effect.amount
		SpellEffect.Kind.ECHO:
			return cost_of_echo * effect.amount
		SpellEffect.Kind.EXCHANGE:
			return cost_of_exchange * effect.amount
	return 0.0


## The rank of a spell of `strokes`, which goes by how long it is.
static func rank_of(strokes: Array) -> Spell.Rank:
	match strokes.size():
		0, 1, 2, 3, 4:
			return Spell.Rank.NOVICE
		5:
			return Spell.Rank.APPRENTICE
		6, 7:
			return Spell.Rank.ADEPT
		8:
			return Spell.Rank.EXPERT
	return Spell.Rank.MASTER


## The school of a spell that does `does`, which goes by the first thing
## it does.
static func school_of(does: Array) -> Spell.School:
	if does.is_empty():
		return Spell.School.EVOCATION
	match (does[0] as SpellEffect).kind:
		SpellEffect.Kind.WARD, SpellEffect.Kind.REFLECT, SpellEffect.Kind.EXCHANGE:
			return Spell.School.ABJURATION
		SpellEffect.Kind.HEAL, SpellEffect.Kind.TRANSMUTE:
			return Spell.School.TRANSMUTATION
		SpellEffect.Kind.ECHO:
			return Spell.School.ILLUSION
		SpellEffect.Kind.INTERRUPT, SpellEffect.Kind.CHILL:
			return Spell.School.ENCHANTMENT
	return Spell.School.EVOCATION


## How hard a spell is, in a word.
static func difficulty_name(difficulty: float) -> String:
	if difficulty < 0.2:
		return "easy"
	if difficulty < 0.45:
		return "middling"
	if difficulty < 0.7:
		return "hard"
	return "very hard"


## What each rune is for in a spell, in a line, for whoever is making one.
static func what_it_is_for(type: Rune.Type) -> String:
	match type:
		Rune.Type.FLOW:
			return "Sends the spell at the foe."
		Rune.Type.DEVELOPMENT:
			return "Builds the blow, or mends you if the spell is kept."
		Rune.Type.DECAY:
			return "Harms what it is sent at, and chills."
		Rune.Type.REFRACTION:
			return "Breaks the foe's cast, or has your ward turn blows back."
		Rune.Type.PERSISTENCE:
			return "Wards you, or makes a chill last."
		Rune.Type.VARIABILITY:
			return "Has the whole spell do a little more."
		Rune.Type.EQUIVELANCE:
			return "With θ takes the foe's spell, with κ their ward. Kept, makes your ward health."
	return ""


static func _rounded(amount: float) -> float:
	return snappedf(amount, 0.5)
