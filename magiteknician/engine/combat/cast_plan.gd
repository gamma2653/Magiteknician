class_name CastPlan
extends RefCounted
## The strokes an NPC is about to make: when, and how far off-centre.
##
## The plan is drawn up in full when the cast begins. That keeps the random
## numbers in one place, so a seeded generator gives the same cast every
## time, and it lets the duel show what is coming.

## Strokes are never planned closer together than this, however the
## jitter falls, in microseconds.
const MIN_GAP_USEC := 40_000
## The furthest from a rune's centre an NPC will land a stroke it means to
## land, as a share of the radius.
const MAX_AIM := 0.95

var spell: Spell
## Length of one tick at the tempo chosen for this cast, in microseconds.
var usec_per_tick: float = 0.0
## When each stroke lands, in microseconds from the start of the cast.
var offsets_usec: Array[int] = []
## Where each stroke lands, relative to the centre of its rune.
var aim_offsets: Array[Vector2] = []
## Whether each stroke is preceded by a stray.
var strays_before: Array[bool] = []


## Draws up a cast of `spell` by a caster with `profile`.
static func draw(spell_: Spell, profile: CasterProfile, rng: RandomNumberGenerator) -> CastPlan:
	var plan := CastPlan.new()
	plan.spell = spell_
	var tempo_factor := maxf(0.4, 1.0 + rng.randfn(0.0, profile.tempo_spread))
	plan.usec_per_tick = profile.usec_per_tick * tempo_factor

	var first_tick := 0
	if not spell_.strokes.is_empty():
		first_tick = spell_.strokes[0].tick
	var previous := -MIN_GAP_USEC
	for i in spell_.strokes.size():
		var stroke := spell_.strokes[i]
		# The first stroke starts the clock, so it cannot be early or late.
		var jitter := 0.0 if i == 0 else rng.randfn(0.0, profile.timing_error)
		var offset := roundi((stroke.tick - first_tick + jitter) * plan.usec_per_tick)
		offset = maxi(offset, previous + MIN_GAP_USEC)
		plan.offsets_usec.append(offset)
		previous = offset

		var distance := minf(absf(rng.randfn(0.0, profile.aim_error)), MAX_AIM) * Rune.RADIUS
		plan.aim_offsets.append(Vector2.from_angle(rng.randf() * TAU) * distance)
		plan.strays_before.append(i > 0 and rng.randf() < profile.stray_chance)
	return plan


func stroke_count() -> int:
	return offsets_usec.size()


## How long the cast takes from its first stroke to its last, in seconds.
func duration_seconds() -> float:
	if offsets_usec.is_empty():
		return 0.0
	return (offsets_usec[-1] - offsets_usec[0]) / 1_000_000.0


## The verdict this plan would earn if it were carried out undisturbed.
func foreseen_result(tuning: CastTuning = null) -> CastResult:
	var aim_errors: Array[float] = []
	for offset in aim_offsets:
		aim_errors.append(offset.length() / Rune.RADIUS)
	return CastScorer.score(spell.ticks(), offsets_usec, aim_errors, strays_before.count(true), tuning)
