class_name CastResult
extends RefCounted
## How well one cast went. Produced by CastScorer.
##
## This is plain data on purpose: it has to be shown on screen, stored in a
## save file and, later, sent to the other side of a multiplayer duel.

enum Judgement { PERFECT, GREAT, GOOD, POOR, MISS }
enum Grade { S, A, B, C, D, FIZZLE }

const JUDGEMENT_NAMES: Dictionary[Judgement, String] = {
	Judgement.PERFECT: "Perfect",
	Judgement.GREAT: "Great",
	Judgement.GOOD: "Good",
	Judgement.POOR: "Poor",
	Judgement.MISS: "Miss",
}
const GRADE_NAMES: Dictionary[Grade, String] = {
	Grade.S: "S",
	Grade.A: "A",
	Grade.B: "B",
	Grade.C: "C",
	Grade.D: "D",
	Grade.FIZZLE: "Fizzle",
}

## Signed distance of each stroke from the beat, in ticks. Positive is late.
var deviations: Array[float] = []
## What each stroke's timing earned.
var judgements: Array[Judgement] = []
## How far from its rune's centre each stroke landed: 0 centre, 1 edge.
var aim_errors: Array[float] = []
## Strokes that landed on nothing, or on the wrong rune.
var strays: int = 0
## Length of one tick at the tempo the caster chose, in microseconds.
var usec_per_tick: float = 0.0
## When tick 0 fell at that tempo, in microseconds: by the beat, and not
## by the hand.
var origin_usec: float = 0.0
## Time from the first stroke to the last, in microseconds.
var duration_usec: int = 0
## False when the spell had too few strokes for rhythm to be judged.
var rhythm_was_measured: bool = false

## Mean timing score of the strokes, 0 to 1.
var rhythm_score: float = 0.0
## Mean placement score of the strokes, 0 to 1.
var aim_score: float = 0.0
## Overall quality of the cast, 0 to 1, after penalties.
var quality: float = 0.0
var grade: Grade = Grade.FIZZLE
## Multiplier applied to the spell's effects. Zero when the cast fizzled.
## What the cast earned by its cadence is in it.
var potency: float = 0.0
## How many casts in a row, ending with this one, followed the cast
## before them. See Cadence.
var cadence_links: int = 0
## How much stronger the cast is for that, as a share.
var cadence_bonus: float = 0.0

var fizzled: bool:
	get:
		return grade == Grade.FIZZLE

var stroke_count: int:
	get:
		return deviations.size()

var grade_name: String:
	get:
		return GRADE_NAMES[grade]


## The tempo in ticks per minute, or 0 when the cast had no tempo.
func ticks_per_minute() -> float:
	if usec_per_tick <= 0.0:
		return 0.0
	return 60_000_000.0 / usec_per_tick


## How many strokes earned `judgement`.
func count_of(judgement: Judgement) -> int:
	return judgements.count(judgement)


## A cast that was abandoned, or otherwise came to nothing.
static func fizzle() -> CastResult:
	return CastResult.new()


func to_dict() -> Dictionary:
	return {
		"deviations": deviations.duplicate(),
		"judgements": judgements.duplicate(),
		"aim_errors": aim_errors.duplicate(),
		"strays": strays,
		"usec_per_tick": usec_per_tick,
		"origin_usec": origin_usec,
		"duration_usec": duration_usec,
		"rhythm_was_measured": rhythm_was_measured,
		"rhythm_score": rhythm_score,
		"aim_score": aim_score,
		"quality": quality,
		"grade": grade,
		"potency": potency,
		"cadence_links": cadence_links,
		"cadence_bonus": cadence_bonus,
	}


static func from_dict(data: Dictionary) -> CastResult:
	var result := CastResult.new()
	result.deviations.assign(data.get("deviations", []))
	result.judgements.assign(data.get("judgements", []))
	result.aim_errors.assign(data.get("aim_errors", []))
	result.strays = int(data.get("strays", 0))
	result.usec_per_tick = float(data.get("usec_per_tick", 0.0))
	result.origin_usec = float(data.get("origin_usec", 0.0))
	result.duration_usec = int(data.get("duration_usec", 0))
	result.rhythm_was_measured = bool(data.get("rhythm_was_measured", false))
	result.rhythm_score = float(data.get("rhythm_score", 0.0))
	result.aim_score = float(data.get("aim_score", 0.0))
	result.quality = float(data.get("quality", 0.0))
	result.grade = int(data.get("grade", Grade.FIZZLE)) as Grade
	result.potency = float(data.get("potency", 0.0))
	result.cadence_links = int(data.get("cadence_links", 0))
	result.cadence_bonus = float(data.get("cadence_bonus", 0.0))
	return result


func _to_string() -> String:
	var tempo := "no tempo"
	if usec_per_tick > 0.0:
		tempo = "%d ticks/min" % [roundi(ticks_per_minute())]
	return "[Cast %s: quality %d%%, potency %d%%, rhythm %d%%, aim %d%%, %d stray, %s]" % [
		grade_name,
		roundi(quality * 100.0),
		roundi(potency * 100.0),
		roundi(rhythm_score * 100.0),
		roundi(aim_score * 100.0),
		strays,
		tempo,
	]
