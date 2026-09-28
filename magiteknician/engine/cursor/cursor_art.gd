class_name CursorArt
extends RefCounted
## Draws the game's cursors, pixel by pixel.
##
## There are no image files behind them. Each cursor is a shape described
## by how far a point is from its edge, and a pixel is filled by how much
## of it falls inside. That gives smooth edges at any size, and a cursor
## that can be any colour.

## The colour of root-sap, which is what runes are drawn with.
const SAP := Color(0.96, 0.84, 0.58)
## What goes round every shape, so that it shows against anything.
const OUTLINE := Color(0.05, 0.05, 0.08, 0.9)
const OUTLINE_WIDTH := 1.6

## The reticle is this many pixels square, and aims with its centre.
const RETICLE_SIZE := 48
## Wide enough to go round the letter on a rune and not across it, and
## narrow enough to sit well inside the rune's edge.
const RETICLE_RADIUS := 17.0
const RETICLE_THICKNESS := 2.4
## Pressed, the ring draws in and thickens, as a brush does on the page.
const RETICLE_PRESSED_RADIUS := 12.0
const RETICLE_PRESSED_THICKNESS := 3.4
const RETICLE_DOT_RADIUS := 2.2

## The pointer is this many pixels square, and points with its tip.
const POINTER_SIZE := 40
const POINTER_TIP := Vector2(3.5, 3.5)
const POINTER_LENGTH := 20.0
const POINTER_RADIUS := 8.5


## A ring with a dot at its centre, for aiming at runes.
static func reticle(ink: Color = SAP, pressed: bool = false) -> Image:
	var radius := RETICLE_PRESSED_RADIUS if pressed else RETICLE_RADIUS
	var half_thickness := (RETICLE_PRESSED_THICKNESS if pressed else RETICLE_THICKNESS) / 2.0
	var centre := reticle_hotspot()
	return _draw(RETICLE_SIZE, ink, func (point: Vector2) -> float:
		var from_centre := point.distance_to(centre)
		var ring := absf(from_centre - radius) - half_thickness
		var dot := from_centre - RETICLE_DOT_RADIUS
		return minf(ring, dot)
	)


## A drop of sap that comes to a point, for choosing things in menus.
static func pointer(ink: Color = SAP) -> Image:
	# It lies along the diagonal, like the arrow everyone is used to.
	var body := POINTER_TIP + Vector2.ONE.normalized() * POINTER_LENGTH
	return _draw(POINTER_SIZE, ink, func (point: Vector2) -> float:
		return _drop(point, POINTER_TIP, body, POINTER_RADIUS)
	)


## Where the reticle aims: its centre.
static func reticle_hotspot() -> Vector2:
	return Vector2(RETICLE_SIZE, RETICLE_SIZE) / 2.0


## Where the pointer points: its tip.
static func pointer_hotspot() -> Vector2:
	return POINTER_TIP


# Fills a square image from `distance`, which says how far a point is from
# the edge of the shape: negative inside, positive outside.
static func _draw(size: int, ink: Color, distance: Callable) -> Image:
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			# Pixels are measured from their middles.
			var from_edge: float = distance.call(Vector2(x + 0.5, y + 0.5))
			var filled := _coverage(from_edge)
			var outlined := _coverage(from_edge - OUTLINE_WIDTH)
			if outlined <= 0.0:
				continue
			# The ink, over the outline, over nothing.
			var under := OUTLINE.a * outlined
			var alpha := filled + under * (1.0 - filled)
			var colour := (ink * filled + OUTLINE * under * (1.0 - filled)) / alpha
			colour.a = alpha
			image.set_pixel(x, y, colour)
	return image


# How much of a pixel is inside the shape, given how far its middle is
# from the edge. It goes from all to none across the width of one pixel.
static func _coverage(from_edge: float) -> float:
	return clampf(0.5 - from_edge, 0.0, 1.0)


# The distance from `point` to a drop: the shape swept by a circle that
# grows from nothing at `tip` to `radius` at `body`.
static func _drop(point: Vector2, tip: Vector2, body: Vector2, radius: float) -> float:
	var length := tip.distance_to(body)
	var along := (body - tip) / length
	var across := Vector2(-along.y, along.x)
	var local := Vector2(absf((point - tip).dot(across)), (point - tip).dot(along))
	# The slope of the drop's side, which leans out from the tip.
	var sine := radius / length
	var cosine := sqrt(1.0 - sine * sine)
	var side := local.dot(Vector2(sine, cosine))
	if side < 0.0:
		# Behind the tip.
		return local.length()
	if side > cosine * length:
		# Round the far end.
		return local.distance_to(Vector2(0.0, length)) - radius
	return local.dot(Vector2(cosine, -sine))
