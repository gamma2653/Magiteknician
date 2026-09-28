class_name RhythmFit
extends RefCounted
## The tempo that best explains a cast, and how far each stroke strayed
## from it.
##
## A spell's rhythm is written in unscaled ticks: "strike at 0, 1 and 3"
## says the third gap is twice as long as the first, and nothing about how
## long either is. The caster picks the tempo. To judge them we therefore
## can't compare their timestamps with a clock; we find the tempo they were
## evidently casting at and measure how well they kept to it.
##
## That tempo is the least-squares line through (tick, time): the slope is
## the length of one tick, the intercept is when tick 0 "should" have
## happened. What is left over, divided by the tick length, is each stroke's
## deviation in ticks. Being a ratio, it reads the same at any speed.

## Fewer strokes than this always fit a line exactly, so they carry no
## rhythm information.
const MIN_MEASURABLE_STROKES := 3

## Length of one tick at the caster's tempo, in microseconds.
var usec_per_tick: float = 0.0
## When tick 0 falls on the fitted line, in microseconds.
var origin_usec: float = 0.0
## Signed distance of each stroke from the fitted line, in ticks.
## Positive is late, negative is early.
var deviations: Array[float] = []
## False when there were too few strokes for the rhythm to be judged.
var is_measurable: bool = false
## Number of strokes the fit was made from.
var stroke_count: int = 0


## Fits a tempo to `times_usec`, the moments the strokes at `ticks` landed.
## Ticks must be strictly increasing. If the arrays differ in length the
## extra entries of the longer one are ignored, which is what a fit over a
## cast still in progress wants.
static func fit(ticks: Array, times_usec: Array) -> RhythmFit:
	var result := RhythmFit.new()
	var count: int = mini(ticks.size(), times_usec.size())
	result.stroke_count = count
	if count == 0:
		return result

	# Work relative to the first stroke; raw timestamps are large enough to
	# cost precision once they are squared.
	var first_usec: float = float(times_usec[0])
	var mean_tick := 0.0
	var mean_time := 0.0
	for i in count:
		mean_tick += float(ticks[i])
		mean_time += float(times_usec[i]) - first_usec
	mean_tick /= count
	mean_time /= count

	var covariance := 0.0
	var tick_spread := 0.0
	for i in count:
		var tick_offset := float(ticks[i]) - mean_tick
		covariance += tick_offset * (float(times_usec[i]) - first_usec - mean_time)
		tick_spread += tick_offset * tick_offset

	result.deviations.resize(count)
	result.deviations.fill(0.0)
	if count < 2 or tick_spread <= 0.0 or covariance <= 0.0:
		# A single stroke, or strokes that don't advance in time or ticks:
		# there is no tempo to speak of.
		result.origin_usec = first_usec
		return result

	result.usec_per_tick = covariance / tick_spread
	result.origin_usec = first_usec + mean_time - result.usec_per_tick * mean_tick
	result.is_measurable = count >= MIN_MEASURABLE_STROKES
	for i in count:
		var expected_usec := result.predict_usec(ticks[i])
		result.deviations[i] = (float(times_usec[i]) - expected_usec) / result.usec_per_tick
	return result


## When the stroke at `tick` would land if the caster held this tempo.
func predict_usec(tick: float) -> float:
	return origin_usec + usec_per_tick * tick


## The tempo in ticks per minute, or 0 when there is no tempo yet.
func ticks_per_minute() -> float:
	if usec_per_tick <= 0.0:
		return 0.0
	return 60_000_000.0 / usec_per_tick
