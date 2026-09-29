class_name CastScorer
extends RefCounted
## Turns the raw record of a cast into a CastResult.
##
## Read as a spike-train comparison, this is an edit distance in the manner
## of Victor and Purpura, taken after rescaling time to the caster's own
## tempo: moving a stroke costs more the further it moved, an extra stroke
## (a stray) has a fixed cost, and a missing stroke costs the whole cast.
##
## Everything here is a pure function of its arguments. The player, an NPC
## and (later) a remote opponent are all scored by handing their strokes to
## the same code, so nobody is judged by different rules.

static var _default_tuning: CastTuning


## The tuning used when a caller doesn't supply one.
static func default_tuning() -> CastTuning:
	if _default_tuning == null:
		_default_tuning = CastTuning.new()
	return _default_tuning


## Scores a completed cast.
##
## `ticks` is the spell's rhythm, `times_usec` when each of its strokes
## landed, `aim_errors` how far from its rune's centre each landed (0 centre
## to 1 edge) and `strays` how many strokes missed altogether.
static func score(
	ticks: Array,
	times_usec: Array,
	aim_errors: Array = [],
	strays: int = 0,
	tuning: CastTuning = null
) -> CastResult:
	if tuning == null:
		tuning = default_tuning()
	var result := CastResult.new()
	var count: int = mini(ticks.size(), times_usec.size())
	if count == 0 or count < ticks.size():
		# Nothing was struck, or the cast stopped short of the last rune.
		result.strays = strays
		return result

	var fit := RhythmFit.fit(ticks, times_usec)
	result.usec_per_tick = fit.usec_per_tick
	result.origin_usec = fit.origin_usec
	result.rhythm_was_measured = fit.is_measurable
	result.duration_usec = int(times_usec[count - 1]) - int(times_usec[0])
	result.strays = strays
	result.deviations = fit.deviations

	var rhythm_total := 0.0
	var aim_total := 0.0
	for i in count:
		result.judgements.append(tuning.judge(fit.deviations[i]))
		rhythm_total += tuning.rhythm_score(fit.deviations[i])
		var aim_error := float(aim_errors[i]) if i < aim_errors.size() else 0.0
		result.aim_errors.append(aim_error)
		aim_total += tuning.aim_score(aim_error)
	result.rhythm_score = rhythm_total / count
	result.aim_score = aim_total / count

	# Rhythm is the cast; aim can only take away from it. Blending the two
	# as equals would let tidy aim rescue a spell with no rhythm at all.
	var aim_factor := lerpf(1.0, result.aim_score, tuning.aim_weight)
	var quality := result.rhythm_score * aim_factor - tuning.stray_penalty * strays
	result.quality = clampf(quality, 0.0, 1.0)
	result.grade = tuning.grade(result.quality)
	result.potency = tuning.potency(result.quality)
	return result
