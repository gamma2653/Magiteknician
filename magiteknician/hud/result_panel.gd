class_name ResultPanel
extends PanelContainer
## Shows the verdict on the most recent cast.

const GRADE_COLORS: Dictionary[CastResult.Grade, Color] = {
	CastResult.Grade.S: Color(1.0, 0.87, 0.35),
	CastResult.Grade.A: Color(0.5, 1.0, 0.55),
	CastResult.Grade.B: Color(0.5, 0.8, 1.0),
	CastResult.Grade.C: Color(0.85, 0.85, 0.85),
	CastResult.Grade.D: Color(1.0, 0.62, 0.3),
	CastResult.Grade.FIZZLE: Color(1.0, 0.35, 0.35),
}
const NOTHING_YET := "Strike the first rune to begin.\nGo as fast or as slowly as you like; keep the rhythm."

@onready var grade: Label = %Grade
@onready var summary: Label = %Summary
@onready var tempo: Label = %Tempo
@onready var judgements: Label = %Judgements
@onready var raster: CastRaster = %Raster


func _ready() -> void:
	clear()


func clear() -> void:
	grade.text = "–"
	grade.modulate = Color.WHITE
	summary.text = NOTHING_YET
	tempo.text = ""
	judgements.text = ""
	raster.clear()


func show_result(spell: Spell, result: CastResult) -> void:
	grade.text = result.grade_name
	grade.modulate = GRADE_COLORS[result.grade]
	summary.text = summary_text(result)
	tempo.text = tempo_text(result)
	judgements.text = judgements_text(result)
	raster.show_cast(spell, result)


static func summary_text(result: CastResult) -> String:
	if result.fizzled:
		return "Quality %d%%. The spell fizzled." % [roundi(result.quality * 100.0)]
	return "Quality %d%%, cast at %d%% potency." % [
		roundi(result.quality * 100.0),
		roundi(result.potency * 100.0),
	]


static func tempo_text(result: CastResult) -> String:
	if result.usec_per_tick <= 0.0:
		return ""
	return "%d ticks a minute, %.2f s from first stroke to last." % [
		roundi(result.ticks_per_minute()),
		result.duration_usec / 1_000_000.0,
	]


static func judgements_text(result: CastResult) -> String:
	var parts: PackedStringArray = []
	if not result.rhythm_was_measured:
		parts.append("Too few strokes to judge the rhythm")
	else:
		for judgement in CastResult.Judgement.values():
			var count := result.count_of(judgement)
			if count > 0:
				parts.append("%s %d" % [CastResult.JUDGEMENT_NAMES[judgement], count])
	if result.strays > 0:
		parts.append("Stray %d" % [result.strays])
	return " · ".join(parts)
