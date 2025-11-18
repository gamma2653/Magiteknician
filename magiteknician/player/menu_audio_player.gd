extends Node2D

@export var audio_stream: AudioStream # Default sound
@export var audio_streams: Dictionary[String, AudioStream]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if audio_stream:
		# Set default
		$PrimaryPlayer.stream = audio_stream

func play_sound(sound_id: String):
	$PrimaryPlayer.stream = audio_streams[sound_id]
	$PrimaryPlayer.play()
	
