extends ColorRect

signal timeout

func start_transition():
	$FadeTimer.start()
	$AnimationPlayer.play("fade_in")
	show()

func end_transition():
	$FadeTimer.start()
	$AnimationPlayer.play("fade_out")
	show()


func _on_fade_timer_timeout() -> void:
	hide()
	timeout.emit()
