extends Node2D

enum MenuItem {
	NEW_GAME,
	CONTINUE,
	OPTIONS,
	QUIT,
	NONE
}

var MenuItemsToID: Dictionary[MenuItem, String] = {
	MenuItem.NEW_GAME: "new_game",
	MenuItem.CONTINUE: "continue",
	MenuItem.OPTIONS: "options",
	MenuItem.QUIT: "quit"
}

# Reasonable default in case the timer gets unexpectedly started.
var btn_pressed: MenuItem = MenuItem.NONE

func _ready():
	$FadeTransition.end_transition()

func transition(state: MenuItem):
	btn_pressed = state
	$MenuAudioPlayer.play_sound(MenuItemsToID[state])
	$FadeTransition.start_transition()
	print("Transitioning to: %s" % [MenuItemsToID[state]])

## Transition to new game
func _on_new_game_pressed() -> void:
	transition(MenuItem.NEW_GAME)


## Transition to continue last save
func _on_continue_pressed() -> void:
	transition(MenuItem.CONTINUE)


## Transition to options menu
func _on_options_pressed() -> void:
	transition(MenuItem.OPTIONS)


## Quit the game
func _on_quit_pressed() -> void:
	transition(MenuItem.QUIT)


func _on_fade_transition_timeout() -> void:
	match btn_pressed:
		MenuItem.NEW_GAME:
			print("New game...")
		MenuItem.CONTINUE:
			print("Continuing...")
		MenuItem.OPTIONS:
			get_tree().change_scene_to_packed(Level.LEVELS["menu"]["options"])
		MenuItem.QUIT:
			get_tree().quit()
		MenuItem.NONE:
			pass
