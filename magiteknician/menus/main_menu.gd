extends Transitionable

enum MenuItem {
	NEW_GAME,
	CONTINUE,
	PRACTICE,
	OPTIONS,
	QUIT,
	NONE
}

const MenuItemsToID: Dictionary[String, Dictionary] = {
	"push": {
		MenuItem.NEW_GAME: "opt1",
		MenuItem.CONTINUE: "opt2",
		MenuItem.PRACTICE: "opt2",
		MenuItem.OPTIONS: "opt3",
		MenuItem.QUIT: "opt4"
	},
	"enter": {
		MenuItem.NEW_GAME: "opt1_sel",
		MenuItem.CONTINUE: "opt2_sel",
		MenuItem.PRACTICE: "opt2_sel",
		MenuItem.OPTIONS: "opt3_sel",
		MenuItem.QUIT: "opt4_sel",
	}
}

# Reasonable default in case the timer gets unexpectedly started.
var btn_pressed: MenuItem = MenuItem.NONE

func _ready():
	$MenuAudioPlayer.audio_streams = Loader.RESOURCES["sound"]["common_menu_map"]
	$ButtonManager/Continue.disabled = not Session.has_save()
	$FadeTransition.end_transition()

func transition(state: MenuItem):
	btn_pressed = state
	$MenuAudioPlayer.play_sound(MenuItemsToID["push"][state])
	$FadeTransition.start_transition()

## Transition to new game
func _on_new_game_pressed() -> void:
	if Session.has_save():
		# Starting over throws progress away, so make sure it is meant.
		$StartOver.popup_centered()
		return
	transition(MenuItem.NEW_GAME)


func _on_start_over_confirmed() -> void:
	transition(MenuItem.NEW_GAME)


## Transition to continue last save
func _on_continue_pressed() -> void:
	transition(MenuItem.CONTINUE)


## Transition to the practice range
func _on_practice_pressed() -> void:
	transition(MenuItem.PRACTICE)


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
			Session.new_game()
			get_tree().change_scene_to_packed(Loader.LEVELS["menu"]["campaign"].call())
		MenuItem.CONTINUE:
			if Session.continue_game():
				get_tree().change_scene_to_packed(Loader.LEVELS["menu"]["campaign"].call())
		MenuItem.PRACTICE:
			get_tree().change_scene_to_packed(Loader.LEVELS["practice"]["range"].call())
		MenuItem.OPTIONS:
			get_tree().change_scene_to_packed(Loader.LEVELS["menu"]["options"].call())
		MenuItem.QUIT:
			get_tree().quit()
		MenuItem.NONE:
			pass

#Attach additional sound handlers

func _on_new_game_mouse_entered() -> void:
	$MenuAudioPlayer.play_sound(MenuItemsToID["enter"][MenuItem.NEW_GAME])


func _on_continue_mouse_entered() -> void:
	if $ButtonManager/Continue.disabled:
		return
	$MenuAudioPlayer.play_sound(MenuItemsToID["enter"][MenuItem.CONTINUE])


func _on_practice_mouse_entered() -> void:
	$MenuAudioPlayer.play_sound(MenuItemsToID["enter"][MenuItem.PRACTICE])


func _on_options_mouse_entered() -> void:
	$MenuAudioPlayer.play_sound(MenuItemsToID["enter"][MenuItem.OPTIONS])


func _on_quit_mouse_entered() -> void:
	$MenuAudioPlayer.play_sound(MenuItemsToID["enter"][MenuItem.QUIT])
