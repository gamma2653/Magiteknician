extends TestCase
## CursorArt: the cursors, as pictures.

const CENTRE := 24


func _alpha(image: Image, x: int, y: int) -> float:
	return image.get_pixel(x, y).a


func _is_sap(colour: Color) -> bool:
	return colour.a > 0.9 \
		and absf(colour.r - CursorArt.SAP.r) < 0.05 \
		and absf(colour.g - CursorArt.SAP.g) < 0.05 \
		and absf(colour.b - CursorArt.SAP.b) < 0.05


# The reticle

func test_the_reticle_aims_with_its_centre() -> void:
	var image := CursorArt.reticle()
	assert_eq(image.get_width(), CursorArt.RETICLE_SIZE)
	assert_eq(image.get_height(), CursorArt.RETICLE_SIZE)
	assert_eq(CursorArt.reticle_hotspot(), Vector2(CENTRE, CENTRE))
	assert_true(_is_sap(image.get_pixel(CENTRE, CENTRE)), "there is a dot at the centre")


func test_the_reticle_is_a_ring_round_a_dot() -> void:
	var image := CursorArt.reticle()
	var ring := int(CursorArt.RETICLE_RADIUS)
	assert_true(_is_sap(image.get_pixel(CENTRE + ring, CENTRE)), "the ring")
	assert_true(_is_sap(image.get_pixel(CENTRE, CENTRE - ring - 1)), "the ring, above")
	assert_almost_eq(_alpha(image, CENTRE + 9, CENTRE), 0.0, 0.001, "nothing between the dot and the ring")
	assert_almost_eq(_alpha(image, 0, 0), 0.0, 0.001, "nothing in the corner")
	assert_almost_eq(_alpha(image, CENTRE + 23, CENTRE), 0.0, 0.001, "nothing beyond the ring")


func test_the_reticle_is_the_same_whichever_way_up() -> void:
	var image := CursorArt.reticle()
	var last := CursorArt.RETICLE_SIZE - 1
	for y in CursorArt.RETICLE_SIZE:
		for x in CursorArt.RETICLE_SIZE:
			var here := image.get_pixel(x, y)
			if not here.is_equal_approx(image.get_pixel(last - x, y)) \
					or not here.is_equal_approx(image.get_pixel(x, last - y)) \
					or not here.is_equal_approx(image.get_pixel(y, x)):
				fail("the pixel at (%d, %d) has no twin" % [x, y])
				return
	assert_true(true)


func test_the_reticle_has_a_dark_edge_to_show_against_anything() -> void:
	var image := CursorArt.reticle()
	# Just outside the ring: past the ink, within the outline.
	var outside := int(CursorArt.RETICLE_RADIUS + CursorArt.RETICLE_THICKNESS / 2.0 + 1.0)
	var edge := image.get_pixel(CENTRE + outside, CENTRE)
	assert_gt(edge.a, 0.5)
	assert_lt(edge.get_luminance(), 0.3, "and it is dark")


func test_pressed_the_ring_draws_in() -> void:
	var up := CursorArt.reticle(CursorArt.SAP, false)
	var down := CursorArt.reticle(CursorArt.SAP, true)
	var wide := int(CursorArt.RETICLE_RADIUS)
	var narrow := int(CursorArt.RETICLE_PRESSED_RADIUS)
	assert_true(_is_sap(up.get_pixel(CENTRE + wide, CENTRE)))
	assert_almost_eq(_alpha(down, CENTRE + wide, CENTRE), 0.0, 0.001, "the ring has left where it was")
	assert_true(_is_sap(down.get_pixel(CENTRE + narrow, CENTRE)), "and is further in")
	assert_true(_is_sap(down.get_pixel(CENTRE, CENTRE)), "the dot has not moved")
	assert_lt(CursorArt.RETICLE_PRESSED_RADIUS, CursorArt.RETICLE_RADIUS)


func test_the_reticle_goes_round_a_runes_letter_and_inside_its_edge() -> void:
	var outer := CursorArt.RETICLE_RADIUS + CursorArt.RETICLE_THICKNESS / 2.0 + CursorArt.OUTLINE_WIDTH
	assert_lt(outer, Rune.RADIUS, "inside the rune")
	assert_gt(CursorArt.RETICLE_RADIUS, Rune.RADIUS / 2.0, "and more than half way out")
	assert_lt(outer, CursorArt.RETICLE_SIZE / 2.0, "and all of it is in the picture")


func test_a_cursor_can_be_drawn_in_any_colour() -> void:
	var red := CursorArt.reticle(Color.RED)
	var pixel := red.get_pixel(CENTRE, CENTRE)
	assert_almost_eq(pixel.r, 1.0, 0.02)
	assert_almost_eq(pixel.g, 0.0, 0.02)


# The pointer

func test_the_pointer_points_with_its_tip() -> void:
	var image := CursorArt.pointer()
	assert_eq(image.get_width(), CursorArt.POINTER_SIZE)
	var tip := CursorArt.pointer_hotspot()
	assert_lt(tip.x, 6.0, "the tip is in the top left, where an arrow's is")
	assert_lt(tip.y, 6.0)
	assert_gt(_alpha(image, int(tip.x), int(tip.y)), 0.0, "and there is something there")


func test_the_pointer_is_a_drop() -> void:
	var image := CursorArt.pointer()
	var body := CursorArt.POINTER_TIP + Vector2.ONE.normalized() * CursorArt.POINTER_LENGTH
	assert_true(_is_sap(image.get_pixel(int(body.x), int(body.y))), "the body of the drop")
	assert_true(_is_sap(image.get_pixel(9, 9)), "the neck of it")
	var last := CursorArt.POINTER_SIZE - 1
	assert_almost_eq(_alpha(image, last, 0), 0.0, 0.001)
	assert_almost_eq(_alpha(image, 0, last), 0.0, 0.001)
	assert_almost_eq(_alpha(image, last, last), 0.0, 0.001)


func test_the_pointer_is_narrow_at_the_tip_and_wide_at_the_end() -> void:
	var image := CursorArt.pointer()
	# Count what is filled along lines that cross the drop: near the tip,
	# half way along, and where it is widest.
	var widest := int((CursorArt.POINTER_TIP + Vector2.ONE.normalized() * CursorArt.POINTER_LENGTH).x)
	var widths := []
	for along in [7, 11, widest]:
		var filled := 0
		for step in range(-along, along + 1):
			var x: int = along + step
			var y: int = along - step
			if x >= 0 and y >= 0 and x < CursorArt.POINTER_SIZE and y < CursorArt.POINTER_SIZE:
				if _is_sap(image.get_pixel(x, y)):
					filled += 1
		widths.append(filled)
	assert_gt(widths[0], 0)
	assert_gt(widths[1], widths[0])
	assert_gt(widths[2], widths[1])


func test_the_pointer_is_the_same_either_side_of_its_length() -> void:
	var image := CursorArt.pointer()
	for y in CursorArt.POINTER_SIZE:
		for x in CursorArt.POINTER_SIZE:
			if not image.get_pixel(x, y).is_equal_approx(image.get_pixel(y, x)):
				fail("the pixel at (%d, %d) has no twin" % [x, y])
				return
	assert_true(true)


func test_the_pointer_fits_in_its_picture() -> void:
	var image := CursorArt.pointer()
	var last := CursorArt.POINTER_SIZE - 1
	for i in CursorArt.POINTER_SIZE:
		assert_almost_eq(_alpha(image, i, last), 0.0, 0.001, "bottom edge at %d" % [i])
		assert_almost_eq(_alpha(image, last, i), 0.0, 0.001, "right edge at %d" % [i])
