class_name CastRaster
extends Control
## A raster of one cast: the expected train above, the actual train below.
##
## The actual train is drawn after rescaling time to the caster's own
## tempo, which is how it was judged. A stroke directly under its expected
## tick was on the beat; one to the right of it was late.

const EXPECTED_COLOR := Color(0.75, 0.9, 1.0, 0.9)
const AXIS_COLOR := Color(1, 1, 1, 0.15)
const LINK_COLOR := Color(1, 1, 1, 0.25)
const LABEL_COLOR := Color(1, 1, 1, 0.45)
const SPIKE_WIDTH := 3.0
const PADDING := 14.0
const LABEL_SIZE := 12
const EXPECTED_LABEL := "spell"
const ACTUAL_LABEL := "cast"

var _ticks: Array[int] = []
var _result: CastResult


func show_cast(spell: Spell, result: CastResult) -> void:
	_ticks = spell.ticks() if spell != null else ([] as Array[int])
	_result = result
	queue_redraw()


func clear() -> void:
	_ticks = []
	_result = null
	queue_redraw()


## Where `tick` falls across the width of the raster.
func x_of(tick: float) -> float:
	if _ticks.is_empty():
		return PADDING
	# Leave a tick of room either side for strokes that came early or late.
	var first := float(_ticks[0]) - 1.0
	var last := float(_ticks[-1]) + 1.0
	return lerpf(PADDING, size.x - PADDING, (tick - first) / (last - first))


func _draw() -> void:
	var upper := size.y * 0.27
	var lower := size.y * 0.73
	var spike := size.y * 0.18
	draw_line(Vector2(PADDING, upper), Vector2(size.x - PADDING, upper), AXIS_COLOR, 1.0)
	draw_line(Vector2(PADDING, lower), Vector2(size.x - PADDING, lower), AXIS_COLOR, 1.0)
	var font := get_theme_default_font()
	draw_string(font, Vector2(0, upper - spike), EXPECTED_LABEL, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, LABEL_COLOR)
	draw_string(font, Vector2(0, lower + spike + LABEL_SIZE), ACTUAL_LABEL, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, LABEL_COLOR)
	for tick in _ticks:
		var x := x_of(tick)
		draw_line(Vector2(x, upper - spike), Vector2(x, upper + spike), EXPECTED_COLOR, SPIKE_WIDTH)
	if _result == null:
		return
	for i in mini(_ticks.size(), _result.stroke_count):
		var expected_x := x_of(_ticks[i])
		var actual_x := x_of(_ticks[i] + _result.deviations[i])
		var color: Color = Rune.JUDGEMENT_COLORS[_result.judgements[i]]
		draw_line(Vector2(expected_x, upper + spike), Vector2(actual_x, lower - spike), LINK_COLOR, 1.0, true)
		draw_line(Vector2(actual_x, lower - spike), Vector2(actual_x, lower + spike), color, SPIKE_WIDTH)
