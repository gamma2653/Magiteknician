class_name InkTrail
extends Node2D
## The ink the cursor leaves behind it: a line that fades where it has
## been, and a ring that opens where a stroke lands.
##
## This is drawn by the game, so it is a frame behind the cursor, which
## the operating system draws. That does not matter here. Nobody aims
## with the trail.

## How long a point of the trail lasts, in seconds.
const TRAIL_SECONDS := 0.22
const TRAIL_WIDTH := 5.0
const TRAIL_ALPHA := 0.55
## The cursor has to move this far before the trail gains a point.
const TRAIL_STEP := 3.0
## Points further apart than this are not joined. The cursor left the
## window and came back somewhere else.
const TRAIL_BREAK := 220.0

const SPLASH_SECONDS := 0.32
const SPLASH_FROM := 10.0
const SPLASH_TO := 46.0
const SPLASH_WIDTH := 3.0

var ink: Color = CursorArt.SAP

# The trail, oldest first, as [where, when in microseconds].
var _points: Array = []
# Rings that are opening, as [where, when in microseconds, colour].
var _splashes: Array = []


## The cursor is at `where`, in this node's own coordinates.
func follow(where: Vector2, now_usec: int = Time.get_ticks_usec()) -> void:
	if not _points.is_empty() and _points[-1][0].distance_to(where) < TRAIL_STEP:
		return
	_points.append([where, now_usec])
	queue_redraw()


## A stroke landed at `where`.
func splash(where: Vector2, colour: Color = ink, now_usec: int = Time.get_ticks_usec()) -> void:
	_splashes.append([where, now_usec, colour])
	queue_redraw()


func clear() -> void:
	_points = []
	_splashes = []
	queue_redraw()


func point_count() -> int:
	return _points.size()


func splash_count() -> int:
	return _splashes.size()


## Forgets whatever has faded away by `now_usec`.
func age(now_usec: int = Time.get_ticks_usec()) -> void:
	var trail_usec := int(TRAIL_SECONDS * 1_000_000)
	var splash_usec := int(SPLASH_SECONDS * 1_000_000)
	_points = _points.filter(func (point): return now_usec - point[1] < trail_usec)
	_splashes = _splashes.filter(func (ring): return now_usec - ring[1] < splash_usec)


func _process(_delta: float) -> void:
	if _points.is_empty() and _splashes.is_empty():
		return
	age()
	queue_redraw()


func _draw() -> void:
	var now := Time.get_ticks_usec()
	for i in range(1, _points.size()):
		var from: Vector2 = _points[i - 1][0]
		var to: Vector2 = _points[i][0]
		if from.distance_to(to) > TRAIL_BREAK:
			continue
		# Newest is boldest.
		var freshness := 1.0 - clampf((now - _points[i][1]) / (TRAIL_SECONDS * 1_000_000), 0.0, 1.0)
		var colour := ink
		colour.a = TRAIL_ALPHA * freshness
		draw_line(from, to, colour, maxf(TRAIL_WIDTH * freshness, 1.0), true)
	for ring in _splashes:
		var progress := clampf((now - ring[1]) / (SPLASH_SECONDS * 1_000_000), 0.0, 1.0)
		# Quick at first, then slowing, as a drop spreads.
		var eased := 1.0 - (1.0 - progress) * (1.0 - progress)
		var colour: Color = ring[2]
		colour.a = 0.8 * (1.0 - progress)
		draw_arc(ring[0], lerpf(SPLASH_FROM, SPLASH_TO, eased), 0.0, TAU, 48, colour, SPLASH_WIDTH, true)
