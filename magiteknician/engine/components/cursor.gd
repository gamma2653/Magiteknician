extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

#var mouse_speed = 10000

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var mouse_pos = get_viewport().get_mouse_position()
	#position = position.move_toward(mouse_pos, mouse_speed*delta)
	# just update instantaenously
	position = mouse_pos
