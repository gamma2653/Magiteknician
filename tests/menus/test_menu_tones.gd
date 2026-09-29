extends TestCase
## The tones of the main menu: one to a button, going down the menu.
##
## The tones are measured, not taken on trust. Each sound is decoded and
## its pitch found, so a recording that is swapped for another, or a
## button given the tone of its neighbour, is heard by the tests.

const MAIN_MENU := preload("res://magiteknician/menus/main_menu.tscn")
const Player := preload("res://magiteknician/menus/menu_audio_player.gd")
## How much of a sound to listen to. A tenth of a second, past its start.
const LISTEN_FRAMES := 4096
const SKIP_FRAMES := 2048
## The tones are between these, in hertz, with room to spare either side.
const LOWEST_HZ := 150.0
const HIGHEST_HZ := 600.0
const BUTTONS := ["NewGame", "Continue", "Practice", "Versus", "Options", "Quit"]

var _pitches: Dictionary = {}


func before_each() -> void:
	forget_progress()


func after_each() -> void:
	forget_progress()


func _menu() -> Node:
	return add_managed(MAIN_MENU.instantiate())


## The items of the menu in the order of their buttons, from the top down.
func _items_from_the_top(menu: Node) -> Array:
	var items := [
		menu.MenuItem.NEW_GAME, menu.MenuItem.CONTINUE, menu.MenuItem.PRACTICE,
		menu.MenuItem.VERSUS, menu.MenuItem.OPTIONS, menu.MenuItem.QUIT,
	]
	return items


## The pitch of the recording called `sound_id`, in hertz.
func _recorded_hz(sound_id: String) -> float:
	if not _pitches.has(sound_id):
		var stream: AudioStream = Loader.RESOURCES["sound"]["common_menu_map"][sound_id]
		_pitches[sound_id] = _pitch_of(stream)
	return _pitches[sound_id]


## The pitch a sound is heard at, which is that of the recording times how
## fast it is played.
func _heard_hz(tone: int, entering: bool) -> float:
	return _recorded_hz(Player.sound_of(tone, entering)) * Player.pitch_of(tone)


## Finds the pitch of `stream` by the lag at which it best matches itself.
func _pitch_of(stream: AudioStream) -> float:
	var playback := stream.instantiate_playback()
	playback.start(0.0)
	var frames: PackedVector2Array = playback.mix_audio(1.0, SKIP_FRAMES + LISTEN_FRAMES)
	playback.stop()
	if frames.size() < SKIP_FRAMES + LISTEN_FRAMES:
		return 0.0
	var samples := PackedFloat32Array()
	samples.resize(LISTEN_FRAMES)
	var mean := 0.0
	for i in LISTEN_FRAMES:
		samples[i] = (frames[SKIP_FRAMES + i].x + frames[SKIP_FRAMES + i].y) / 2.0
		mean += samples[i]
	mean /= LISTEN_FRAMES
	for i in LISTEN_FRAMES:
		samples[i] -= mean

	var rate := AudioServer.get_mix_rate()
	var shortest := int(rate / HIGHEST_HZ)
	var longest := int(rate / LOWEST_HZ)
	var span := LISTEN_FRAMES - longest - 1
	var matches := PackedFloat32Array()
	matches.resize(longest + 2)
	for lag in range(shortest - 1, longest + 2):
		var sum := 0.0
		for i in span:
			sum += samples[i] * samples[i + lag]
		matches[lag] = sum
	var best := shortest
	for lag in range(shortest, longest + 1):
		if matches[lag] > matches[best]:
			best = lag
	# The true lag is between samples. Fit a curve through the best and
	# its neighbours, and take the top of the curve.
	var before := matches[best - 1]
	var after := matches[best + 1]
	var bend := before - 2.0 * matches[best] + after
	var exact := float(best)
	if not is_zero_approx(bend):
		exact += 0.5 * (before - after) / bend
	return rate / exact


func _semitones_between(higher_hz: float, lower_hz: float) -> float:
	return 12.0 * log(higher_hz / lower_hz) / log(2.0)


# The recordings

func test_the_recordings_go_down_a_semitone_at_a_time() -> void:
	var recorded := Player.RECORDED_TONES
	assert_eq(recorded.size(), 4)
	for i in range(1, recorded.size()):
		var step := _semitones_between(_recorded_hz(recorded[i - 1]), _recorded_hz(recorded[i]))
		assert_almost_eq(step, 1.0, 0.15, "%s is a semitone below %s" % [recorded[i], recorded[i - 1]])


func test_the_highest_recording_is_the_f_above_middle_c() -> void:
	assert_almost_eq(_recorded_hz("opt1"), 349.2, 4.0)


func test_the_sound_of_coming_to_a_button_is_the_same_tone_as_pushing_it() -> void:
	for recorded in Player.RECORDED_TONES:
		var apart := _semitones_between(_recorded_hz(recorded), _recorded_hz(recorded + Player.ENTER_SUFFIX))
		assert_almost_eq(apart, 0.0, 0.1, recorded)


# The tones

func test_a_recorded_tone_is_played_as_it_was_recorded() -> void:
	for tone in Player.RECORDED_TONES.size():
		assert_eq(Player.sound_of(tone), Player.RECORDED_TONES[tone])
		assert_eq(Player.sound_of(tone, true), Player.RECORDED_TONES[tone] + "_sel")
		assert_almost_eq(Player.pitch_of(tone), 1.0)


func test_a_tone_below_the_recordings_is_the_lowest_of_them_played_slower() -> void:
	assert_eq(Player.sound_of(4), "opt4")
	assert_eq(Player.sound_of(6, true), "opt4_sel")
	assert_almost_eq(Player.pitch_of(4), 1.0 / Player.SEMITONE)
	assert_almost_eq(Player.pitch_of(5), 1.0 / pow(Player.SEMITONE, 2.0))
	assert_almost_eq(Player.pitch_of(6), 1.0 / pow(Player.SEMITONE, 3.0))
	assert_almost_eq(pow(Player.SEMITONE, 12.0), 2.0, 1e-6, "twelve semitones are an octave")


func test_there_are_seven_tones_and_each_is_a_semitone_below_the_last() -> void:
	assert_eq(Player.TONE_COUNT, 7)
	for entering in [false, true]:
		for tone in range(1, Player.TONE_COUNT):
			var step := _semitones_between(_heard_hz(tone - 1, entering), _heard_hz(tone, entering))
			assert_almost_eq(step, 1.0, 0.15, "tone %d is a semitone below tone %d" % [tone, tone - 1])


func test_a_tone_there_is_none_of_is_the_nearest_there_is() -> void:
	assert_eq(Player.sound_of(-1), "opt1")
	assert_almost_eq(Player.pitch_of(-1), 1.0)
	assert_eq(Player.sound_of(40), "opt4")
	assert_almost_eq(Player.pitch_of(40), Player.pitch_of(Player.TONE_COUNT - 1))


# The menu

func test_every_button_has_a_tone_of_its_own() -> void:
	var menu := _menu()
	var seen := {}
	for item in _items_from_the_top(menu):
		assert_true(menu.MenuItemsToTone.has(item))
		var tone: int = menu.MenuItemsToTone[item]
		assert_false(seen.has(tone), "tone %d is used once" % [tone])
		assert_between(tone, 0, Player.TONE_COUNT - 1)
		seen[tone] = true
	assert_eq(seen.size(), BUTTONS.size())
	assert_eq(menu.MenuItemsToTone.size(), BUTTONS.size(), "and there is no button left over")


func test_the_buttons_are_in_the_order_the_tests_take_them_to_be() -> void:
	var menu := _menu()
	var last := -INF
	for button_name in BUTTONS:
		var button: Button = menu.get_node("ButtonManager/" + button_name)
		assert_gt(button.position.y, last, "%s is below the button before it" % [button_name])
		last = button.position.y
	assert_eq(menu.get_node("ButtonManager").get_child_count(), BUTTONS.size())


func test_the_tones_go_down_the_menu() -> void:
	var menu := _menu()
	var items := _items_from_the_top(menu)
	for entering in [false, true]:
		for i in range(1, items.size()):
			var above := _heard_hz(menu.MenuItemsToTone[items[i - 1]], entering)
			var here := _heard_hz(menu.MenuItemsToTone[items[i]], entering)
			assert_lt(here, above, "%s is lower than %s" % [BUTTONS[i], BUTTONS[i - 1]])
			assert_almost_eq(_semitones_between(above, here), 1.0, 0.15, "by a semitone")


func test_pushing_a_button_plays_its_tone() -> void:
	var menu := _menu()
	var player: AudioStreamPlayer2D = menu.get_node("MenuAudioPlayer/PrimaryPlayer")
	var sounds: Dictionary = Loader.RESOURCES["sound"]["common_menu_map"]

	menu._on_practice_pressed()
	assert_eq(player.stream, sounds["opt3"])
	assert_almost_eq(player.pitch_scale, 1.0)

	menu._on_options_pressed()
	assert_eq(player.stream, sounds["opt4"])
	assert_almost_eq(player.pitch_scale, 1.0 / Player.SEMITONE)

	menu._on_quit_pressed()
	assert_eq(player.stream, sounds["opt4"])
	assert_almost_eq(player.pitch_scale, 1.0 / pow(Player.SEMITONE, 2.0))
	# Quit leaves the game when the fade is over. Stop it there.
	menu.btn_pressed = menu.MenuItem.NONE


func test_coming_to_a_button_plays_its_tone_and_brighter() -> void:
	var menu := _menu()
	var player: AudioStreamPlayer2D = menu.get_node("MenuAudioPlayer/PrimaryPlayer")
	var sounds: Dictionary = Loader.RESOURCES["sound"]["common_menu_map"]

	menu._on_new_game_mouse_entered()
	assert_eq(player.stream, sounds["opt1_sel"])
	assert_almost_eq(player.pitch_scale, 1.0)

	menu._on_versus_mouse_entered()
	assert_eq(player.stream, sounds["opt4_sel"])
	assert_almost_eq(player.pitch_scale, 1.0)

	menu._on_quit_mouse_entered()
	assert_eq(player.stream, sounds["opt4_sel"])
	assert_almost_eq(player.pitch_scale, 1.0 / pow(Player.SEMITONE, 2.0))


func test_a_tone_played_slower_does_not_slow_the_one_after_it() -> void:
	var menu := _menu()
	var player: AudioStreamPlayer2D = menu.get_node("MenuAudioPlayer/PrimaryPlayer")
	menu._on_quit_mouse_entered()
	assert_lt(player.pitch_scale, 1.0)
	menu._on_new_game_mouse_entered()
	assert_almost_eq(player.pitch_scale, 1.0)
	menu.get_node("MenuAudioPlayer").play_sound("opt2")
	assert_almost_eq(player.pitch_scale, 1.0, 1e-6, "a sound played by name is played as it was recorded")


func test_a_button_that_cannot_be_pushed_is_silent() -> void:
	var menu := _menu()
	var player: AudioStreamPlayer2D = menu.get_node("MenuAudioPlayer/PrimaryPlayer")
	assert_true(menu.get_node("ButtonManager/Continue").disabled, "there is no save to continue from")
	menu._on_new_game_mouse_entered()
	menu._on_continue_mouse_entered()
	assert_eq(player.stream, Loader.RESOURCES["sound"]["common_menu_map"]["opt1_sel"], "the last sound is still New Game's")
