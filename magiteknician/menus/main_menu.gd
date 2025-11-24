extends Transitionable

enum MenuItem {
	NEW_GAME,
	CONTINUE,
	OPTIONS,
	QUIT,
	NONE
}

const MenuItemsToID: Dictionary[String, Dictionary] = {
	"push": {
		MenuItem.NEW_GAME: "opt1",
		MenuItem.CONTINUE: "opt2",
		MenuItem.OPTIONS: "opt3",
		MenuItem.QUIT: "opt4"
	},
	"enter": {
		MenuItem.NEW_GAME: "opt1_sel",
		MenuItem.CONTINUE: "opt2_sel",
		MenuItem.OPTIONS: "opt3_sel",
		MenuItem.QUIT: "opt4_sel",
	}
}

# Reasonable default in case the timer gets unexpectedly started.
var btn_pressed: MenuItem = MenuItem.NONE

func _ready():
	$MenuAudioPlayer.audio_streams = Loader.RESOURCES["sound"]["common_menu_map"]
	$FadeTransition.end_transition()

func transition(state: MenuItem):
	btn_pressed = state
	$MenuAudioPlayer.play_sound(MenuItemsToID["push"][state])
	$FadeTransition.start_transition()

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
			get_tree().change_scene_to_packed(Loader.LEVELS["section1"]["level1"])
		MenuItem.CONTINUE:
			print("Continuing...")
		MenuItem.OPTIONS:
			get_tree().change_scene_to_packed(Loader.LEVELS["menu"]["options"])
		MenuItem.QUIT:
			get_tree().quit()
		MenuItem.NONE:
			pass

#Attach additional sound handlers

func _on_new_game_mouse_entered() -> void:
	$MenuAudioPlayer.play_sound(MenuItemsToID["enter"][MenuItem.NEW_GAME])


func _on_continue_mouse_entered() -> void:
	$MenuAudioPlayer.play_sound(MenuItemsToID["enter"][MenuItem.CONTINUE])


func _on_options_mouse_entered() -> void:
	$MenuAudioPlayer.play_sound(MenuItemsToID["enter"][MenuItem.OPTIONS])


func _on_quit_mouse_entered() -> void:
	$MenuAudioPlayer.play_sound(MenuItemsToID["enter"][MenuItem.QUIT])
