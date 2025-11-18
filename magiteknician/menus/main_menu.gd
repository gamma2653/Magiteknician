extends Node2D

enum MenuItems {
	NEW_GAME,
	CONTINUE,
	OPTIONS,
	#QUIT
}

var btn_pressed: MenuItems = MenuItems.NEW_GAME

func _on_new_game_pressed() -> void:
	btn_pressed = MenuItems.NEW_GAME
	print("New game pressed.")


func _on_continue_pressed() -> void:
	btn_pressed = MenuItems.CONTINUE
	$FadeTransition.start_transition()
	print("Continue pressed.")


func _on_options_pressed() -> void:
	btn_pressed = MenuItems.OPTIONS
	$FadeTransition.start_transition()
	print("Options pressed.")


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_fade_transition_timeout() -> void:
	match btn_pressed:
		MenuItems.NEW_GAME:
			print("New game...")
		MenuItems.CONTINUE:
			print("Continuing...")
		MenuItems.OPTIONS:
			get_tree().change_scene_to_packed(Level.ALL_LEVELS["menu"]["options"])
