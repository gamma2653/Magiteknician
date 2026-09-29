extends Transitionable

enum MenuItem {
	NEW_GAME,
	CONTINUE,
	PRACTICE,
	VERSUS,
	OPTIONS,
	QUIT,
	NONE
}

## The tone of each button, in semitones below the highest. They go down
## the menu as the buttons do, and no two buttons share one.
const MenuItemsToTone: Dictionary[MenuItem, int] = {
	MenuItem.NEW_GAME: 0,
	MenuItem.CONTINUE: 1,
	MenuItem.PRACTICE: 2,
	MenuItem.VERSUS: 3,
	MenuItem.OPTIONS: 4,
	MenuItem.QUIT: 5,
}

# Reasonable default in case the timer gets unexpectedly started.
var btn_pressed: MenuItem = MenuItem.NONE

func _ready():
	$MenuAudioPlayer.audio_streams = Loader.RESOURCES["sound"]["common_menu_map"]
	$ButtonManager/Continue.disabled = not Session.has_save()
	$FadeTransition.end_transition()

func transition(state: MenuItem):
	btn_pressed = state
	$MenuAudioPlayer.play_tone(MenuItemsToTone[state])
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


## Transition to duels against other players
func _on_versus_pressed() -> void:
	transition(MenuItem.VERSUS)


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
		MenuItem.VERSUS:
			get_tree().change_scene_to_packed(Loader.LEVELS["menu"]["versus"].call())
		MenuItem.OPTIONS:
			get_tree().change_scene_to_packed(Loader.LEVELS["menu"]["options"].call())
		MenuItem.QUIT:
			get_tree().quit()
		MenuItem.NONE:
			pass

#Attach additional sound handlers

func _on_new_game_mouse_entered() -> void:
	$MenuAudioPlayer.play_tone(MenuItemsToTone[MenuItem.NEW_GAME], true)


func _on_continue_mouse_entered() -> void:
	if $ButtonManager/Continue.disabled:
		return
	$MenuAudioPlayer.play_tone(MenuItemsToTone[MenuItem.CONTINUE], true)


func _on_practice_mouse_entered() -> void:
	$MenuAudioPlayer.play_tone(MenuItemsToTone[MenuItem.PRACTICE], true)


func _on_versus_mouse_entered() -> void:
	$MenuAudioPlayer.play_tone(MenuItemsToTone[MenuItem.VERSUS], true)


func _on_options_mouse_entered() -> void:
	$MenuAudioPlayer.play_tone(MenuItemsToTone[MenuItem.OPTIONS], true)


func _on_quit_mouse_entered() -> void:
	$MenuAudioPlayer.play_tone(MenuItemsToTone[MenuItem.QUIT], true)
