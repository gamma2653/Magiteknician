class_name SpellSounds
extends RefCounted
## The sounds a spell makes as it lands.
##
## They are worked out by the game and not recorded, as the cursor is
## drawn and not painted. Each is a few notes of the kind the runes chime
## with, a note and a little of its third harmonic, with some noise where
## something strikes or breaks. The notes are from the scale the runes are
## tuned to, so that a spell landing is in tune with the casting of it.
##
## A recording takes the place of any of them. Put a file called after
## the sound in RECORDINGS, "blow.ogg" for one, and it is played instead.

const RECORDINGS := "res://magiteknician/assets/audio/spells"
const RECORDING_TYPES: Array[String] = ["ogg", "wav", "mp3"]

## Samples in a second of sound. Half of what a recording has, which is
## enough for notes this low and takes half as long to work out.
const RATE := 22050
## The loudest a sound is at its loudest, where 1 is as loud as can be.
## It is what the runes' chimes are recorded at.
const PEAK := 0.2
## The ends of a sound are brought to nothing over this long, in seconds.
## A sound that starts or stops anywhere else is heard to click.
const EDGE_SECONDS := 0.006

## A blow that got through.
const BLOW := &"blow"
## A ward taking a blow.
const WARD_BLOW := &"ward_blow"
## A ward going up.
const WARD_UP := &"ward_up"
## A ward breaking.
const WARD_BREAK := &"ward_break"
const MEND := &"mend"
const CHILL := &"chill"
## A cast being broken.
const BREAK := &"break"
const FIZZLE := &"fizzle"

const NAMES: Array[StringName] = [BLOW, WARD_BLOW, WARD_UP, WARD_BREAK, MEND, CHILL, BREAK, FIZZLE]

# Notes of the scale the runes chime in, in hertz.
const C3 := 130.81
const G3 := 196.0
const C4 := 261.63
const F4 := 349.23
const B4 := 493.88
const C5 := 523.25
const E5 := 659.26
const G5 := 783.99
const A5 := 880.0
const B5 := 987.77
const C6 := 1046.5
const E6 := 1318.51
const G6 := 1567.98

## A note and a little of its third harmonic, as the runes' chimes are.
const CHIME := [[1.0, 1.0], [3.0, 0.25]]
## A note with more of an edge to it.
const HARSH := [[1.0, 1.0], [3.0, 0.45], [5.0, 0.25]]
const PURE := [[1.0, 1.0]]

static var _streams: Dictionary[StringName, AudioStream] = {}


## The sound called `sound`: a recording if there is one, and otherwise
## worked out. Null if there is no sound of that name.
static func stream(sound: StringName) -> AudioStream:
	if not _streams.has(sound):
		var found := recording(sound)
		if found == null and sound in NAMES:
			found = as_stream(samples(sound))
		_streams[sound] = found
	return _streams[sound]


## The recording that takes the place of `sound`, or null.
static func recording(sound: StringName) -> AudioStream:
	for type in RECORDING_TYPES:
		var path := "%s/%s.%s" % [RECORDINGS, sound, type]
		if ResourceLoader.exists(path):
			return load(path) as AudioStream
	return null


## Works every sound out, so that none is worked out in the middle of a duel.
static func prepare() -> void:
	for sound in NAMES:
		stream(sound)


## Forgets the sounds, to have them looked for again.
static func forget() -> void:
	_streams.clear()


## The sound called `sound`, worked out, as samples from -1 to 1.
static func samples(sound: StringName) -> PackedFloat32Array:
	var made := PackedFloat32Array()
	match sound:
		BLOW:
			made = _silence(0.55)
			# Something heavy, falling in pitch as it lands, with the
			# crack of its landing over it and a note ringing after. It
			# is no lower than a small speaker can be heard to go.
			_add(made, _sweep(G3, C3, 0.09, 0.5, 0.14), 0.0, 1.0)
			_add(made, _noise(0.12, 0.025, 1800.0, 11), 0.0, 0.5)
			_add(made, _note(C4, 0.5, 0.16, CHIME), 0.0, 0.3)
		WARD_BLOW:
			made = _silence(0.45)
			# Glass, struck.
			_add(made, _note(C6, 0.45, 0.11, CHIME), 0.0, 0.8)
			_add(made, _note(E6 * 1.004, 0.45, 0.09, PURE), 0.0, 0.5)
			_add(made, _note(C3, 0.2, 0.04, PURE), 0.0, 0.6)
		WARD_UP:
			made = _silence(0.8)
			# Three notes, going up, each ringing on under the next.
			_add(made, _note(E5, 0.7, 0.22, CHIME, 0.012), 0.0, 0.7)
			_add(made, _note(G5, 0.65, 0.22, CHIME, 0.012), 0.06, 0.7)
			_add(made, _note(C6, 0.6, 0.26, CHIME, 0.012), 0.12, 0.8)
		WARD_BREAK:
			made = _silence(0.65)
			# Glass, broken: the crack, and the pieces falling.
			_add(made, _noise(0.25, 0.06, 3500.0, 23, 1200.0), 0.0, 0.6)
			_add(made, _note(G6, 0.3, 0.07, CHIME), 0.0, 0.6)
			_add(made, _note(E6, 0.3, 0.08, CHIME), 0.04, 0.55)
			_add(made, _note(C6, 0.3, 0.09, CHIME), 0.09, 0.5)
			_add(made, _note(A5, 0.35, 0.1, CHIME), 0.15, 0.45)
		MEND:
			made = _silence(0.95)
			# A chord, a note at a time, and softly.
			_add(made, _note(C5, 0.8, 0.28, CHIME, 0.02), 0.0, 0.6)
			_add(made, _note(E5, 0.75, 0.28, CHIME, 0.02), 0.08, 0.6)
			_add(made, _note(G5, 0.7, 0.28, CHIME, 0.02), 0.16, 0.6)
			_add(made, _note(C6, 0.65, 0.32, CHIME, 0.02), 0.24, 0.7)
		CHILL:
			made = _silence(0.85)
			# High and thin, and shivering.
			var ice := _silence(0.85)
			_add(ice, _note(B5, 0.85, 0.3, PURE, 0.04), 0.0, 0.8)
			_add(ice, _note(E6, 0.85, 0.3, PURE, 0.04), 0.0, 0.6)
			_shiver(ice, 13.0, 0.45)
			_add(made, ice, 0.0, 1.0)
			_add(made, _noise(0.5, 0.18, 5000.0, 37, 2500.0), 0.0, 0.2)
		BREAK:
			made = _silence(0.4)
			# Two notes that do not go together, cut short.
			_add(made, _noise(0.05, 0.008, 5000.0, 41), 0.0, 0.8)
			_add(made, _note(F4, 0.35, 0.08, HARSH), 0.0, 0.8)
			_add(made, _note(B4, 0.35, 0.08, HARSH), 0.0, 0.8)
		FIZZLE:
			made = _silence(0.5)
			# Air going out of it.
			_add(made, _noise(0.5, 0.13, 900.0, 53), 0.0, 1.0)
			_add(made, _sweep(300.0, 90.0, 0.3, 0.4, 0.12), 0.0, 0.35)
		_:
			return made
	_level(made)
	_soften_edges(made)
	return made


## `made` as a sound that can be played.
static func as_stream(made: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(made.size() * 2)
	for i in made.size():
		bytes.encode_s16(i * 2, roundi(clampf(made[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	return wav


# The parts a sound is made of

static func _silence(seconds: float) -> PackedFloat32Array:
	var made := PackedFloat32Array()
	made.resize(int(seconds * RATE))
	return made


## A note at `hertz` that dies away, falling to a third of its loudness
## every `fade` seconds. `partials` are its harmonics, as [which, how loud].
static func _note(hertz: float, seconds: float, fade: float, partials: Array, attack: float = 0.003) -> PackedFloat32Array:
	var made := _silence(seconds)
	for i in made.size():
		var time := float(i) / RATE
		var loudness := exp(-time / fade) * minf(time / attack, 1.0)
		var value := 0.0
		for partial: Array in partials:
			value += sin(TAU * hertz * partial[0] * time) * partial[1]
		made[i] = value * loudness
	return made


## A note that slides from `from_hertz` to `to_hertz` in `slide` seconds
## and stays there, dying away as a note does.
static func _sweep(from_hertz: float, to_hertz: float, slide: float, seconds: float, fade: float) -> PackedFloat32Array:
	var made := _silence(seconds)
	var turned := 0.0
	for i in made.size():
		var time := float(i) / RATE
		var along := clampf(time / slide, 0.0, 1.0)
		# Fast at first, as a thing that is dropped.
		var hertz := lerpf(from_hertz, to_hertz, 1.0 - (1.0 - along) * (1.0 - along))
		turned += TAU * hertz / RATE
		made[i] = sin(turned) * exp(-time / fade) * minf(time / 0.003, 1.0)
	return made


## Noise that dies away. What is above `ceiling` hertz is taken out of
## it, and what is below `floor_`, if there is one. `scatter` settles
## which noise it is, so that it is the same every time.
static func _noise(seconds: float, fade: float, ceiling: float, scatter: int, floor_: float = 0.0) -> PackedFloat32Array:
	var made := _silence(seconds)
	var rng := RandomNumberGenerator.new()
	rng.seed = scatter
	var smooth := 1.0 - exp(-TAU * ceiling / RATE)
	var slow := 1.0 - exp(-TAU * floor_ / RATE)
	var once := 0.0
	var low := 0.0
	var lower := 0.0
	for i in made.size():
		var time := float(i) / RATE
		# Smoothed twice over. Once leaves a hiss.
		once += (rng.randf_range(-1.0, 1.0) - once) * smooth
		low += (once - low) * smooth
		lower += (low - lower) * slow
		var value := low - lower if floor_ > 0.0 else low
		made[i] = value * exp(-time / fade) * minf(time / 0.002, 1.0)
	return made


## Makes `made` louder and softer `hertz` times a second, by `depth`.
static func _shiver(made: PackedFloat32Array, hertz: float, depth: float) -> void:
	for i in made.size():
		made[i] *= 1.0 - depth * (0.5 + 0.5 * sin(TAU * hertz * i / RATE))


## Adds `part` into `made`, `at` seconds in and `gain` times as loud.
static func _add(made: PackedFloat32Array, part: PackedFloat32Array, at: float, gain: float) -> void:
	var offset := int(at * RATE)
	var count := mini(part.size(), made.size() - offset)
	for i in count:
		made[offset + i] += part[i] * gain


## Makes the loudest of `made` as loud as PEAK.
static func _level(made: PackedFloat32Array) -> void:
	var loudest := 0.0
	for value in made:
		loudest = maxf(loudest, absf(value))
	if loudest <= 0.0:
		return
	var gain := PEAK / loudest
	for i in made.size():
		made[i] *= gain


static func _soften_edges(made: PackedFloat32Array) -> void:
	var edge := mini(int(EDGE_SECONDS * RATE), made.size() / 2)
	for i in edge:
		var share := float(i) / edge
		made[i] *= share
		made[made.size() - 1 - i] *= share
