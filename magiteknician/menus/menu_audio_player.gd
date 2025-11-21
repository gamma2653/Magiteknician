extends Node2D

@export var audio_stream: AudioStream # Default sound
@export var audio_streams: Dictionary = {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if audio_stream:
		# Set default
		$PrimaryPlayer.stream = audio_stream

func play_sound(sound_id: String):
	if sound_id in audio_streams:
		$PrimaryPlayer.stream = audio_streams[sound_id]
	else:
		print("Invalid sound_id supplied. Valid keys are: %s" % [audio_streams.keys()])
		if not $PrimaryPlayer.stream and audio_stream:
			print("Playing default sound.")
			$PrimaryPlayer.stream = audio_stream
	$PrimaryPlayer.play()
	
