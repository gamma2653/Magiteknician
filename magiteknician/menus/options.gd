extends Node2D

var going_back = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$FadeTransition.end_transition()


func _on_fade_transition_timeout() -> void:
	if going_back:
		going_back = false
		get_tree().change_scene_to_packed(Loader.LEVELS["menu"]["main_menu"])


func _on_back_pressed() -> void:
	$FadeTransition.start_transition()
	going_back = true
