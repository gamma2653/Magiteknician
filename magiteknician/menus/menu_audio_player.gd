extends Node2D
## Plays the sounds of a menu.
##
## A menu's buttons each have a tone, and the tones go down the menu as
## the buttons do: the button at the top has the highest, and each button
## under it is a semitone lower. No two buttons share one.
##
## Four tones were recorded: F, E, D sharp and D. The tones below those
## are the lowest of them played slower, which lowers it. A semitone or
## three is too little for the ear to tell it from a recording.

## How much faster a tone is than the tone a semitone below it.
const SEMITONE := pow(2.0, 1.0 / 12.0)
## The tones that were recorded, from the highest down.
const RECORDED_TONES: Array[String] = ["opt1", "opt2", "opt3", "opt4"]
## How many tones there are, which is how many buttons a menu can have
## before two of them must share.
const TONE_COUNT := 7
## What is added to the name of a tone for the sound of the cursor coming
## to a button. It is the same tone, and brighter.
const ENTER_SUFFIX := "_sel"

@export var audio_stream: AudioStream # Default sound
@export var audio_streams: Dictionary = {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if audio_stream:
		# Set default
		$PrimaryPlayer.stream = audio_stream

func play_sound(sound_id: String, pitch: float = 1.0):
	if sound_id in audio_streams:
		$PrimaryPlayer.stream = audio_streams[sound_id]
	else:
		print("Invalid sound_id supplied. Valid keys are: %s" % [audio_streams.keys()])
		if not $PrimaryPlayer.stream and audio_stream:
			print("Playing default sound.")
			$PrimaryPlayer.stream = audio_stream
	$PrimaryPlayer.pitch_scale = pitch
	$PrimaryPlayer.play()


## Plays the tone that is `tone` semitones below the highest: as a button
## is pushed, or as the cursor comes to it if `entering`.
func play_tone(tone: int, entering: bool = false):
	play_sound(sound_of(tone, entering), pitch_of(tone))


## The recording that the tone is played from.
static func sound_of(tone: int, entering: bool = false) -> String:
	var recorded := RECORDED_TONES[clampi(tone, 0, RECORDED_TONES.size() - 1)]
	return recorded + ENTER_SUFFIX if entering else recorded


## How fast the recording is played to make the tone. A tone that was
## recorded is played as it is.
static func pitch_of(tone: int) -> float:
	var below := clampi(tone, 0, TONE_COUNT - 1) - (RECORDED_TONES.size() - 1)
	return pow(SEMITONE, -maxi(below, 0))
