class_name CastTuning
extends Resource
## The numbers that decide how strictly a cast is judged.
##
## They live in a Resource, rather than as constants in the scorer, so that
## a difficulty setting or a practice mode can swap the whole set.

@export_group("Rhythm")
## How far off the beat, in ticks, a stroke can land before its score has
## fallen to about 60%. This is the σ of the gaussian a stroke is scored on:
## full marks on the beat, falling away smoothly either side.
@export_range(0.01, 1.0, 0.005) var rhythm_tolerance: float = 0.1
## Largest deviation, in ticks, that still earns each judgement. Anything
## beyond the last window is a miss. Must be in increasing order.
@export var perfect_window: float = 0.04
@export var great_window: float = 0.08
@export var good_window: float = 0.15
@export var poor_window: float = 0.25

@export_group("Aim")
## How much of a cast's quality sloppy aim can take away. At 0.25, a cast
## whose every stroke scored nothing for aim keeps 75% of what its rhythm
## earned.
@export_range(0.0, 1.0, 0.01) var aim_weight: float = 0.25
## Score for a stroke that only just catches the edge of its rune. A stroke
## dead centre scores 1.
@export_range(0.0, 1.0, 0.01) var aim_edge_score: float = 0.5

@export_group("Penalties")
## Quality lost for each stroke that landed on nothing, or on the wrong
## rune. Without this, mashing every rune key would cast any spell.
@export_range(0.0, 1.0, 0.01) var stray_penalty: float = 0.06

@export_group("Outcome")
## A cast whose quality is below this fizzles and has no effect.
@export_range(0.0, 1.0, 0.01) var fizzle_below: float = 0.3
## Potency of a cast that only just avoids fizzling.
@export_range(0.0, 2.0, 0.01) var potency_at_worst: float = 0.35
## Potency of a flawless cast.
@export_range(0.0, 2.0, 0.01) var potency_at_best: float = 1.0
## Lowest quality that earns each grade. Must be in decreasing order.
@export var grade_s: float = 0.95
@export var grade_a: float = 0.85
@export var grade_b: float = 0.7
@export var grade_c: float = 0.5


## A copy of this tuning that asks for `precision` times the accuracy in
## timing: at 0.7, every tolerance and window is 70% of what it was.
## Aim, penalties and grades are left alone.
func stricter(precision: float) -> CastTuning:
	var copy: CastTuning = duplicate()
	copy.rhythm_tolerance = rhythm_tolerance * precision
	copy.perfect_window = perfect_window * precision
	copy.great_window = great_window * precision
	copy.good_window = good_window * precision
	copy.poor_window = poor_window * precision
	return copy


## Score between 0 and 1 for a stroke `deviation` ticks off the beat.
func rhythm_score(deviation: float) -> float:
	var scaled := deviation / rhythm_tolerance
	return exp(-0.5 * scaled * scaled)


## Score between 0 and 1 for a stroke that landed `aim_error` of the way
## from the rune's centre (0) to its edge (1).
func aim_score(aim_error: float) -> float:
	var clamped := clampf(aim_error, 0.0, 1.0)
	return lerpf(1.0, aim_edge_score, clamped * clamped)


func judge(deviation: float) -> CastResult.Judgement:
	var distance := absf(deviation)
	if distance <= perfect_window:
		return CastResult.Judgement.PERFECT
	if distance <= great_window:
		return CastResult.Judgement.GREAT
	if distance <= good_window:
		return CastResult.Judgement.GOOD
	if distance <= poor_window:
		return CastResult.Judgement.POOR
	return CastResult.Judgement.MISS


func grade(quality: float) -> CastResult.Grade:
	if quality < fizzle_below:
		return CastResult.Grade.FIZZLE
	if quality >= grade_s:
		return CastResult.Grade.S
	if quality >= grade_a:
		return CastResult.Grade.A
	if quality >= grade_b:
		return CastResult.Grade.B
	if quality >= grade_c:
		return CastResult.Grade.C
	return CastResult.Grade.D


## How strongly a cast of this quality takes effect. Zero when it fizzles.
func potency(quality: float) -> float:
	if quality < fizzle_below:
		return 0.0
	var span := 1.0 - fizzle_below
	var progress := 1.0 if span <= 0.0 else (quality - fizzle_below) / span
	return lerpf(potency_at_worst, potency_at_best, clampf(progress, 0.0, 1.0))
