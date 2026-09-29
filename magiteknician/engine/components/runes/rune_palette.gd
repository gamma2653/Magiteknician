class_name RunePalette
extends RefCounted
## The colours the runes are, and the choosing of them.
##
## A rune is known by its letter and by its colour. As they were painted,
## two of the runes are green and two are blue, and to an eye that does
## not see red the green of Flow and the yellow of Variability are all
## but the one colour. The other palette is seven colours chosen to be
## told apart by any eye: those of Okabe and Ito.
##
## How far apart two colours are is measured, and not supposed. The
## colours are put through what is known of the eyes that do not see
## red, green or blue, and the distance between them is taken in a space
## where equal distances look equally far. As painted, the two runes most
## alike to any eye are 6 apart. In the other palette they are 16.
##
## A rune is a disc of one colour with its letter and its edge in black.
## It is repainted by putting the new colour wherever the old one was,
## and as much of it as there was of the old. So an edge that was half
## colour and half black is half the new colour and half black.

enum Choice {
	## As the runes were painted.
	PAINTED,
	## Seven colours that can be told apart by any eye.
	DISTINCT,
}

const NAMES: Dictionary[Choice, String] = {
	Choice.PAINTED: "painted",
	Choice.DISTINCT: "distinct",
}
## Each rune has the colour of the seven that is nearest to what it was
## painted, as far as that goes. There is one green among them, and Flow
## has it, being the rune there is most of.
const DISTINCT: Dictionary[Rune.Type, Color] = {
	Rune.Type.FLOW: Color8(0, 158, 115),
	Rune.Type.DECAY: Color8(230, 159, 0),
	Rune.Type.DEVELOPMENT: Color8(86, 180, 233),
	Rune.Type.REFRACTION: Color8(0, 114, 178),
	Rune.Type.VARIABILITY: Color8(240, 228, 66),
	Rune.Type.PERSISTENCE: Color8(204, 121, 167),
	Rune.Type.EQUIVELANCE: Color8(213, 94, 0),
}

## An eye, by which colours it sees.
enum Eye {
	## Sees them all.
	ALL,
	## Does not see red.
	NO_RED,
	## Does not see green. The commonest of the three.
	NO_GREEN,
	## Does not see blue.
	NO_BLUE,
}

## What each eye makes of red, green and blue, as light and not as the
## numbers a screen is given. From Machado, Oliveira and Fernandes, "A
## physiologically-based model for simulation of color vision deficiency"
## (2009), at its full severity. Each is three rows of three.
const SEEN_BY: Dictionary[Eye, Array] = {
	Eye.ALL: [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0],
	Eye.NO_RED: [0.152286, 1.052583, -0.204868, 0.114503, 0.786281, 0.099216, -0.003882, -0.048116, 1.051998],
	Eye.NO_GREEN: [0.367322, 0.860646, -0.227968, 0.280085, 0.672501, 0.047413, -0.011820, 0.042940, 0.968881],
	Eye.NO_BLUE: [1.255528, -0.076749, -0.178779, -0.078411, 0.930809, 0.147602, 0.004733, 0.691367, 0.303900],
}

static var _colours: Dictionary = {}
static var _textures: Dictionary = {}


## The rune of `type` as it was painted.
static func painted(type: Rune.Type) -> Texture2D:
	return Loader.RESOURCES["img"]["runes"][Rune.RuneToID[type]]


## The colour of the rune of `type` in the palette `choice`.
static func colour_of(type: Rune.Type, choice: Choice) -> Color:
	if choice == Choice.DISTINCT:
		return DISTINCT[type]
	if not _colours.has(type):
		_colours[type] = commonest_colour(painted(type).get_image())
	return _colours[type]


## The picture of the rune of `type` in the palette `choice`.
static func texture_of(type: Rune.Type, choice: Choice) -> Texture2D:
	if choice == Choice.PAINTED:
		return painted(type)
	var key := "%d %d" % [type, choice]
	if not _textures.has(key):
		var image := painted(type).get_image()
		if image.is_compressed():
			image = image.duplicate()
			image.decompress()
		_textures[key] = ImageTexture.create_from_image(
			repainted(image, colour_of(type, Choice.PAINTED), colour_of(type, choice))
		)
	return _textures[key]


## `image` with `new_colour` wherever `old_colour` was, and as much of it.
static func repainted(image: Image, old_colour: Color, new_colour: Color) -> Image:
	var made := Image.create_empty(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8)
	var old := Vector3(old_colour.r, old_colour.g, old_colour.b)
	var new := Vector3(new_colour.r, new_colour.g, new_colour.b)
	var old_squared := maxf(old.length_squared(), 0.0001)
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			var was := Vector3(pixel.r, pixel.g, pixel.b)
			# How much of the old colour is in the pixel. What is not the
			# colour is black, and stays black.
			var share := clampf(was.dot(old) / old_squared, 0.0, 1.0)
			# What is left over is neither the colour nor black: a light on
			# the disc, if one was painted. It is kept.
			var over := was - old * share
			var now := new * share + Vector3(maxf(over.x, 0.0), maxf(over.y, 0.0), maxf(over.z, 0.0))
			made.set_pixel(x, y, Color(minf(now.x, 1.0), minf(now.y, 1.0), minf(now.z, 1.0), pixel.a))
	return made


## The colour most of `image` is, leaving out what is see-through and what
## is nearly black. A rune is a disc of one colour with a black letter and
## a black edge, so this is the colour of the disc.
##
## "Nearly black" goes by the strongest of red, green and blue, and not by
## how bright the colour looks. A deep blue looks dark and is not black.
static func commonest_colour(image: Image) -> Color:
	if image == null or image.is_empty():
		return CursorArt.SAP
	if image.is_compressed():
		image = image.duplicate()
		image.decompress()
	var counts := {}
	var commonest := CursorArt.SAP
	var most := 0
	for y in image.get_height():
		for x in image.get_width():
			var colour := image.get_pixel(x, y)
			if colour.a < 0.9 or maxf(colour.r, maxf(colour.g, colour.b)) < 0.25:
				continue
			# Near enough is the same colour.
			var key := colour.to_rgba32() & 0xF0F0F000
			counts[key] = counts.get(key, 0) + 1
			if counts[key] > most:
				most = counts[key]
				commonest = Color(colour.r, colour.g, colour.b)
	return commonest


## A strip of the seven colours of `choice`, to show what it is.
static func swatches(choice: Choice, swatch: Vector2i = Vector2i(18, 18)) -> ImageTexture:
	var types := Rune.Type.values()
	var image := Image.create_empty(swatch.x * types.size(), swatch.y, false, Image.FORMAT_RGBA8)
	for i in types.size():
		image.fill_rect(Rect2i(Vector2i(i * swatch.x + 1, 1), swatch - Vector2i(2, 2)), colour_of(types[i], choice))
	return ImageTexture.create_from_image(image)


## How far apart two colours are to `eye`. It is the distance between
## them in CIELAB, in which 1 is about the least that can be told and 100
## is black from white.
static func apart(one: Color, other: Color, eye: Eye = Eye.ALL) -> float:
	return as_seen(one, eye).distance_to(as_seen(other, eye))


## `colour` as `eye` sees it, as a place in CIELAB: how light, how far
## from green to red, and how far from blue to yellow.
static func as_seen(colour: Color, eye: Eye = Eye.ALL) -> Vector3:
	var light := Vector3(_as_light(colour.r), _as_light(colour.g), _as_light(colour.b))
	var m: Array = SEEN_BY[eye]
	var seen := Vector3(
		clampf(m[0] * light.x + m[1] * light.y + m[2] * light.z, 0.0, 1.0),
		clampf(m[3] * light.x + m[4] * light.y + m[5] * light.z, 0.0, 1.0),
		clampf(m[6] * light.x + m[7] * light.y + m[8] * light.z, 0.0, 1.0),
	)
	# By way of CIE XYZ, against the white of a screen.
	var x := (0.4124564 * seen.x + 0.3575761 * seen.y + 0.1804375 * seen.z) / 0.95047
	var y := 0.2126729 * seen.x + 0.7151522 * seen.y + 0.0721750 * seen.z
	var z := (0.0193339 * seen.x + 0.1191920 * seen.y + 0.9503041 * seen.z) / 1.08883
	return Vector3(116.0 * _cube_root(y) - 16.0, 500.0 * (_cube_root(x) - _cube_root(y)), 200.0 * (_cube_root(y) - _cube_root(z)))


## The two runes that are most alike to `eye` in the palette `choice`,
## and how far apart they are, as [one, the other, how far].
static func most_alike(choice: Choice, eye: Eye) -> Array:
	var types := Rune.Type.values()
	var found := [types[0], types[1], INF]
	for i in types.size():
		for j in i:
			var distance := apart(colour_of(types[i], choice), colour_of(types[j], choice), eye)
			if distance < found[2]:
				found = [types[j], types[i], distance]
	return found


# The number a screen is given, as how much light it makes.
static func _as_light(given: float) -> float:
	if given <= 0.04045:
		return given / 12.92
	return pow((given + 0.055) / 1.055, 2.4)


static func _cube_root(ratio: float) -> float:
	if ratio > 0.008856:
		return pow(ratio, 1.0 / 3.0)
	return 7.787 * ratio + 16.0 / 116.0
