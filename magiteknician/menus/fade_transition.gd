extends ColorRect
signal timeout


## A fade transition that can be used to transition between scenes.
func start_transition():
	$FadeTimer.start()
	$AnimationPlayer.play("fade_in")
	show()


## Ends the transition by fading back in.
func end_transition():
	$FadeTimer.start()
	$AnimationPlayer.play("fade_out")
	show()


func _on_fade_timer_timeout() -> void:
	hide()
	timeout.emit()
