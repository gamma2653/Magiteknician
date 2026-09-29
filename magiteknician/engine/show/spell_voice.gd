class_name SpellVoice
extends Node
## Sounds what SpellShow shows.
##
## It is told of each mark as the mark is born, and plays the sound that
## goes with it. So a sound is heard when the thing is seen, which for
## what happens where a spell lands is when the spell gets there.
##
## How much a spell did is how it sounds, as it is how it looks. A harder
## blow is louder, and lower.

## How many sounds can be heard at once. One more than that takes the
## place of whichever has been playing longest.
const VOICES := 6
## How much quieter than its loudest the least of a sound is, in decibels.
const QUIETEST_DB := -12.0
## What is turned back, and the second ring of a ward that turns blows
## back, are this much quieter than the thing itself.
const ECHO_DB := -7.0
## A blow is played this much faster at its least, and slower at its most.
const LIGHTEST_PITCH := 1.3
const HEAVIEST_PITCH := 0.85
## The ring of a ward that turns blows back is this much higher.
const ECHO_PITCH := 1.5

const SOUND_OF: Dictionary[SpellMark.Kind, StringName] = {
	SpellMark.Kind.BURST: SpellSounds.BLOW,
	SpellMark.Kind.FLARE: SpellSounds.WARD_BLOW,
	SpellMark.Kind.RAISE: SpellSounds.WARD_UP,
	SpellMark.Kind.SHATTER: SpellSounds.WARD_BREAK,
	SpellMark.Kind.MOTES: SpellSounds.MEND,
	SpellMark.Kind.FROST: SpellSounds.CHILL,
	SpellMark.Kind.CRACK: SpellSounds.BREAK,
	SpellMark.Kind.SPUTTER: SpellSounds.FIZZLE,
}

## False to say nothing.
var is_on: bool = true
## Everything that has been sounded, oldest first, as dictionaries with
## "sound", "volume_db" and "pitch". For whoever wants to know what was
## heard without being able to hear it.
var sounded: Array[Dictionary] = []

var _players: Array[AudioStreamPlayer] = []
var _next: int = 0


func _ready() -> void:
	SpellSounds.prepare()
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)


## Sounds `mark`, if it is of a kind that makes a sound.
func sound(mark: SpellMark) -> void:
	if not is_on or mark == null or not SOUND_OF.has(mark.kind):
		return
	var strength := clampf(mark.strength, 0.0, 1.0)
	var volume_db := lerpf(QUIETEST_DB, 0.0, strength)
	var pitch := 1.0
	if mark.kind == SpellMark.Kind.BURST:
		pitch = lerpf(LIGHTEST_PITCH, HEAVIEST_PITCH, strength)
	if mark.is_echo:
		volume_db += ECHO_DB
		if mark.kind == SpellMark.Kind.RAISE:
			pitch = ECHO_PITCH
	play(SOUND_OF[mark.kind], volume_db, pitch)


## Plays the sound called `sound_name`.
func play(sound_name: StringName, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var stream := SpellSounds.stream(sound_name)
	if stream == null:
		return
	sounded.append({"sound": sound_name, "volume_db": volume_db, "pitch": pitch})
	if _players.is_empty():
		return
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()
