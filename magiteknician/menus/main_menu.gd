extends Node2D

enum MenuItems {
	NEW_GAME,
	CONTINUE,
	OPTIONS,
	QUIT
}

var btn_pressed: MenuItems = MenuItems.NEW_GAME

func _ready():
	$FadeTransition.end_transition()

## Transition to new game
func _on_new_game_pressed() -> void:
	btn_pressed = MenuItems.NEW_GAME
	$MenuAudioPlayer.play_sound("new_game")
	$FadeTransition.start_transition()
	print("New game pressed.")


## Transition to continue last save
func _on_continue_pressed() -> void:
	btn_pressed = MenuItems.CONTINUE
	$MenuAudioPlayer.play_sound("continue")
	$FadeTransition.start_transition()
	print("Continue pressed.")


## Transition to options menu
func _on_options_pressed() -> void:
	btn_pressed = MenuItems.OPTIONS
	$MenuAudioPlayer.play_sound("options")
	$FadeTransition.start_transition()
	print("Options pressed.")


## Quit the game
func _on_quit_pressed() -> void:
	btn_pressed = MenuItems.QUIT
	$MenuAudioPlayer.play_sound("quit")
	$FadeTransition.start_transition()


func _on_fade_transition_timeout() -> void:
	match btn_pressed:
		MenuItems.NEW_GAME:
			print("New game...")
		MenuItems.CONTINUE:
			print("Continuing...")
		MenuItems.OPTIONS:
			get_tree().change_scene_to_packed(Level.LEVELS["menu"]["options"])
		MenuItems.QUIT:
			get_tree().quit()
