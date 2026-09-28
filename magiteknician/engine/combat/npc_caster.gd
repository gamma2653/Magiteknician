class_name NpcCaster
extends Caster
## Casts spells for an NPC by making strokes on a spell circle.
##
## The NPC goes round a loop: think for a moment, choose a spell, draw up
## the cast, then make each stroke when its time comes. The strokes go
## through SpellCircle.strike() like anyone else's, so the circle shows the
## cast as it happens and judges it by the usual rules.

signal spell_chosen(spell: Spell)

enum State { IDLE, THINKING, CASTING }

## Where a stray stroke is aimed: well clear of any rune.
const STRAY_LOCATION := Vector2(0, Spell.CIRCLE_RADIUS * 3.0)

var profile: CasterProfile = CasterProfile.new()
var rng := RandomNumberGenerator.new()

var state: State = State.IDLE
var plan: CastPlan

# Microseconds this caster has been running. It keeps its own time, fed by
# advance(), so that a duel can be paused, stepped or replayed.
var _clock_usec: int = 0
var _think_until_usec: int = 0
var _cast_started_usec: int = 0
var _next_stroke: int = 0


## Starts the NPC casting. It thinks first, so it never acts on the very
## first frame of a duel.
func begin() -> void:
	_think()


## Stops the NPC where it stands, abandoning any cast in progress.
func halt() -> void:
	if state == State.CASTING and circle != null:
		circle.abandon()
	state = State.IDLE
	plan = null


## Breaks the cast in progress, if there is one, and sends the NPC back to
## thinking. Returns true if a cast was broken.
func interrupt() -> bool:
	if state != State.CASTING:
		return false
	circle.abandon()
	plan = null
	_think()
	return true


func _process(delta: float) -> void:
	advance(delta)


## Lets `seconds` pass for this caster.
func advance(seconds: float) -> void:
	if state == State.IDLE or seconds <= 0.0:
		return
	_clock_usec += roundi(seconds * 1_000_000.0)
	if state == State.THINKING and _clock_usec >= _think_until_usec:
		_start_cast()
	if state == State.CASTING:
		_make_due_strokes()


func _think() -> void:
	state = State.THINKING
	var pause := rng.randf_range(profile.think_seconds_min, maxf(profile.think_seconds_min, profile.think_seconds_max))
	_think_until_usec = _clock_usec + roundi(pause * 1_000_000.0)


func _start_cast() -> void:
	if me == null or foe == null or circle == null or me.is_defeated() or foe.is_defeated():
		state = State.IDLE
		return
	var spell := NpcBrain.choose(me, foe, foe_spell, profile, rng)
	if spell == null:
		# Nothing it can afford. Wait for chi and look again.
		_think()
		return
	plan = CastPlan.draw(spell, profile, rng)
	circle.prepare(spell)
	spell_chosen.emit(spell)
	state = State.CASTING
	# Strokes are timed from when the cast was due to start, not from the
	# frame that noticed, so a slow frame does not shift the rhythm.
	_cast_started_usec = _think_until_usec
	_next_stroke = 0


func _make_due_strokes() -> void:
	while state == State.CASTING and _next_stroke < plan.stroke_count():
		var due := _cast_started_usec + plan.offsets_usec[_next_stroke]
		if _clock_usec < due:
			return
		var stroke := plan.spell.strokes[_next_stroke]
		if plan.strays_before[_next_stroke]:
			circle.strike(stroke.rune, STRAY_LOCATION, due)
		var outcome := circle.strike(stroke.rune, stroke.position + plan.aim_offsets[_next_stroke], due)
		if outcome != SpellCircle.Outcome.HIT:
			# The circle would not take the stroke: the cast was refused or
			# broken from outside. Start over rather than press on.
			plan = null
			_think()
			return
		_next_stroke += 1
	if state == State.CASTING:
		plan = null
		_think()
