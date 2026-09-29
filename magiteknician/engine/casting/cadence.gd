class_name Cadence
extends RefCounted
## The beat a caster keeps from one cast to the next.
##
## A cast is judged on its own: the tempo is fitted to its strokes and
## nothing before the first of them counts. Cadence is what joins one cast
## to the next. A cast that goes on in the beat of the one before it, at
## the same tempo and beginning on a beat, follows it, and casts that
## follow one another are stronger for it.
##
## In spike-train terms the casts are bursts, and this asks whether the
## bursts are locked to one oscillation or each to its own.
##
## The beat is kept by whoever is casting and not by the game. After a
## cast the game knows the tempo and where the beats fell, and carries
## them forward to see whether the next cast lands on them.

enum Verdict {
	## There was no beat to follow: this is the first cast, or the one
	## before it fizzled or was given up.
	FIRST,
	## The cast went on in the beat of the one before it.
	FOLLOWED,
	## It began off the beat.
	OFF_THE_BEAT,
	## It was cast faster or slower than the one before it.
	CHANGED_TEMPO,
	## Too many beats went by before it began.
	RESTED_TOO_LONG,
	## The cast itself came to nothing.
	FIZZLED,
}

## Length of one tick of the beat that is being kept, in microseconds.
## Zero when there is none.
var usec_per_tick: float = 0.0
## When some one beat of it fell, in microseconds.
var origin_usec: float = 0.0
## When the last stroke of the last cast fell, by the beat and not by the
## hand, in microseconds.
var last_beat_usec: float = 0.0
## How many casts in a row have followed the one before them.
var links: int = 0

## What became of the last cast that was taken.
var verdict: Verdict = Verdict.FIRST
## How far off the beat it began, in ticks of the beat it was to follow.
## Positive is late.
var entry: float = 0.0
## Its tempo as a share of the tempo it was to follow: above 1 is slower.
var tempo_ratio: float = 1.0
## How many beats went by between the last stroke of the cast before and
## the first of this one.
var rest: int = 0


## True while there is a beat to follow.
func is_alive() -> bool:
	return usec_per_tick > 0.0


## True once so long has gone by since the last cast that the next cannot
## follow it, as of `now_usec`.
func has_lapsed(now_usec: float, tuning: CastTuning) -> bool:
	if not is_alive():
		return true
	return now_usec > last_beat_usec + (tuning.cadence_max_rest + tuning.cadence_entry_window) * usec_per_tick


## How many ticks it is until the next beat, as of `now_usec`: from 1, just
## after a beat, down to 0 as the next falls. NAN when there is no beat.
func ticks_until_beat(now_usec: float) -> float:
	if not is_alive():
		return NAN
	var beats := (now_usec - origin_usec) / usec_per_tick
	return ceilf(beats) - beats


## When the first beat falls that a cast begun after `after_usec` could
## begin on, in microseconds.
func next_beat_after(after_usec: float) -> float:
	if not is_alive():
		return after_usec
	var earliest := maxf(after_usec, last_beat_usec + 0.5 * usec_per_tick)
	return origin_usec + ceilf((earliest - origin_usec) / usec_per_tick) * usec_per_tick


## Takes a cast that has just been judged: decides whether it followed the
## one before, and carries its beat forward for the next. `result` is told
## what was decided, and its potency is raised by what it has earned.
func take(result: CastResult, ticks: Array, tuning: CastTuning) -> Verdict:
	if result == null or result.fizzled or not result.rhythm_was_measured or ticks.is_empty():
		drop()
		verdict = Verdict.FIZZLED
		_tell(result, tuning)
		return verdict

	var first_beat := result.origin_usec + result.usec_per_tick * float(ticks[0])
	verdict = _judge(first_beat, result.usec_per_tick, tuning)
	links = links + 1 if verdict == Verdict.FOLLOWED else 0

	usec_per_tick = result.usec_per_tick
	origin_usec = result.origin_usec
	last_beat_usec = result.origin_usec + result.usec_per_tick * float(ticks[-1])
	_tell(result, tuning)
	return verdict


## Ends the cadence. The next cast has nothing to follow.
func drop() -> void:
	usec_per_tick = 0.0
	origin_usec = 0.0
	last_beat_usec = 0.0
	links = 0
	entry = 0.0
	tempo_ratio = 1.0
	rest = 0


## How much stronger a cast is for being the last of `links_` that
## followed one another, as a share: 0.1 is a tenth stronger.
static func bonus_for(links_: int, tuning: CastTuning) -> float:
	return clampi(links_, 0, tuning.cadence_max_links) * tuning.cadence_bonus_per_link


## What became of the last cast, in a few words, or "" if there is
## nothing to say.
func describe(tuning: CastTuning) -> String:
	match verdict:
		Verdict.FOLLOWED:
			return "In cadence, %d in a row: %d%% stronger." % [links + 1, roundi(bonus_for(links, tuning) * 100.0)]
		Verdict.OFF_THE_BEAT:
			return "Out of cadence: it began %.2f of a tick %s." % [absf(entry), "late" if entry > 0.0 else "early"]
		Verdict.CHANGED_TEMPO:
			return "Out of cadence: it was cast %d%% %s than the last." % [
				roundi(absf(tempo_ratio - 1.0) * 100.0), "slower" if tempo_ratio > 1.0 else "faster",
			]
		Verdict.RESTED_TOO_LONG:
			return "Out of cadence: %d beats went by, and %d is the most." % [rest, tuning.cadence_max_rest]
	return ""


func _judge(first_beat_usec: float, new_usec_per_tick: float, tuning: CastTuning) -> Verdict:
	entry = 0.0
	tempo_ratio = 1.0
	rest = 0
	if not is_alive():
		return Verdict.FIRST
	tempo_ratio = new_usec_per_tick / usec_per_tick
	var beats := (first_beat_usec - last_beat_usec) / usec_per_tick
	rest = maxi(roundi(beats), 1)
	entry = beats - rest
	if rest > tuning.cadence_max_rest:
		return Verdict.RESTED_TOO_LONG
	if absf(tempo_ratio - 1.0) > tuning.cadence_tempo_window:
		return Verdict.CHANGED_TEMPO
	if absf(entry) > tuning.cadence_entry_window:
		return Verdict.OFF_THE_BEAT
	return Verdict.FOLLOWED


func _tell(result: CastResult, tuning: CastTuning) -> void:
	if result == null:
		return
	result.cadence_links = links
	result.cadence_bonus = bonus_for(links, tuning)
	result.potency *= 1.0 + result.cadence_bonus
