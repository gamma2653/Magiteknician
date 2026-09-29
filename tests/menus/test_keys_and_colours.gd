extends TestCase
## Choosing the keys, and choosing the colours of the runes.

const OPTIONS := preload("res://magiteknician/menus/options.tscn")
const PRACTICE := preload("res://magiteknician/levels/practice_range.tscn")
const FIRE_BOLT := preload("res://magiteknician/spells/fire_bolt.tres")
const FLOW := &"Rune-Flow"
const DECAY := &"Rune-Decay"
const LISTEN := &"Cast-Listen"
const ABANDON := &"Cast-Abandon"


func before_each() -> void:
	forget_progress()
	forget_settings()
	GameCursor.point()


func after_each() -> void:
	forget_progress()
	forget_settings()
	GameCursor.point()


func _open() -> Node:
	return add_managed(OPTIONS.instantiate())


func _press(keycode: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = keycode as Key
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await get_tree().process_frame
	var release := InputEventKey.new()
	release.physical_keycode = keycode as Key
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	await get_tree().process_frame


func _on_disk() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(Settings.path))


# The keys the game comes with

func test_the_game_comes_with_its_keys() -> void:
	var came := KeyBindings.came_with()
	assert_eq(came.size(), KeyBindings.REBINDABLE.size())
	assert_eq(came[FLOW], KEY_W)
	assert_eq(came[DECAY], KEY_Q)
	assert_eq(came[&"Rune-Dev"], KEY_A)
	assert_eq(came[&"Rune-Refrac"], KEY_S)
	assert_eq(came[&"Rune-Persist"], KEY_D)
	assert_eq(came[&"Rune-Equiv"], KEY_E)
	assert_eq(came[&"Rune-Var"], KEY_X)
	assert_eq(came[LISTEN], KEY_SPACE)
	assert_eq(came[ABANDON], KEY_ESCAPE)
	assert_eq(Settings.keys, came)
	for action in KeyBindings.REBINDABLE:
		assert_eq(KeyBindings.key_of(action), came[action], String(action))


func test_every_rune_has_a_key_that_can_be_chosen() -> void:
	for type in Rune.Type.values():
		assert_true(Rune.RuneToActionID[type] in KeyBindings.REBINDABLE, Rune.RuneToName[type])
	assert_eq(KeyBindings.label_of(FLOW), "ρ  Flow")
	assert_eq(KeyBindings.label_of(LISTEN), "Hear the spell")
	assert_eq(KeyBindings.label_of(ABANDON), "Give up a cast")


func test_a_key_has_a_name() -> void:
	assert_eq(KeyBindings.name_of(KEY_W), "W")
	assert_eq(KeyBindings.name_of(KEY_SPACE), "Space")
	assert_eq(KeyBindings.name_of(0), "none")


# Choosing a key

func test_a_key_can_be_chosen() -> void:
	Settings.choose_key(FLOW, KEY_F)
	assert_eq(Settings.keys[FLOW], KEY_F)
	assert_eq(KeyBindings.key_of(FLOW), KEY_F, "and it is the key that does it")
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F
	event.pressed = true
	assert_true(event.is_action(FLOW))
	event.physical_keycode = KEY_W
	assert_false(event.is_action(FLOW), "and the key it had no longer does")


func test_a_key_that_is_in_use_changes_places() -> void:
	Settings.choose_key(FLOW, KEY_Q)
	assert_eq(Settings.keys[FLOW], KEY_Q)
	assert_eq(Settings.keys[DECAY], KEY_W, "Decay had Q, and has the W that Flow had")
	assert_eq(KeyBindings.key_of(DECAY), KEY_W)
	var used := {}
	for action in Settings.keys:
		assert_false(used.has(Settings.keys[action]), "no key does two things")
		used[Settings.keys[action]] = true


func test_a_key_that_chooses_a_spell_cannot_be_chosen() -> void:
	assert_false(KeyBindings.can_be_chosen(KEY_1))
	assert_false(KeyBindings.can_be_chosen(KEY_6))
	Settings.choose_key(FLOW, KEY_1)
	assert_eq(Settings.keys[FLOW], KEY_W)
	assert_false(FileAccess.file_exists(Settings.path), "nothing was chosen, and nothing is written")


func test_a_key_that_does_nothing_by_itself_cannot_be_chosen() -> void:
	for keycode in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META, KEY_CAPSLOCK, 0, -4]:
		assert_false(KeyBindings.can_be_chosen(keycode), str(keycode))
	assert_true(KeyBindings.can_be_chosen(KEY_F))
	assert_true(KeyBindings.can_be_chosen(KEY_W), "a key that is in use can be: the two change places")


func test_the_mouse_still_gives_up_a_cast() -> void:
	Settings.choose_key(ABANDON, KEY_BACKSPACE)
	var mouse := 0
	var keys := 0
	for event in InputMap.action_get_events(ABANDON):
		if event is InputEventMouseButton:
			mouse += 1
		if event is InputEventKey:
			keys += 1
	assert_eq(mouse, 1)
	assert_eq(keys, 1)
	assert_eq(KeyBindings.key_of(ABANDON), KEY_BACKSPACE)


func test_the_keys_are_kept() -> void:
	Settings.choose_key(FLOW, KEY_F)
	assert_eq(int(_on_disk()["keys"]["Rune-Flow"]), KEY_F)
	Settings.reset()
	assert_eq(KeyBindings.key_of(FLOW), KEY_W, "the keys the game comes with")
	Settings.read()
	assert_eq(Settings.keys[FLOW], KEY_F)
	assert_eq(KeyBindings.key_of(FLOW), KEY_F, "and the keys that were chosen are the keys again")


func test_the_keys_can_be_put_back() -> void:
	Settings.choose_key(FLOW, KEY_Q)
	Settings.choose_key(LISTEN, KEY_TAB)
	assert_false(KeyBindings.are_as_they_came(Settings.keys))
	Settings.reset_keys()
	assert_true(KeyBindings.are_as_they_came(Settings.keys))
	assert_eq(KeyBindings.key_of(FLOW), KEY_W)
	assert_eq(KeyBindings.key_of(DECAY), KEY_Q)
	assert_eq(KeyBindings.key_of(LISTEN), KEY_SPACE)
	assert_true(KeyBindings.are_as_they_came(_on_disk()["keys"]), "and that is kept")


func test_keys_that_make_no_sense_are_made_fit() -> void:
	var fit := KeyBindings.tidy({"Rune-Flow": KEY_F, "Rune-Decay": "the usual", "Rune-Dev": KEY_1, "Rune-Teatime": KEY_T})
	assert_eq(fit[FLOW], KEY_F)
	assert_eq(fit[DECAY], KEY_Q)
	assert_eq(fit[&"Rune-Dev"], KEY_A, "a key that cannot be chosen is not")
	assert_false(fit.has(&"Rune-Teatime"))
	assert_eq(fit.size(), KeyBindings.REBINDABLE.size())
	# Two actions given the one key: one of them has it, and the other
	# has a key of its own.
	var both := KeyBindings.tidy({"Rune-Flow": KEY_F, "Rune-Decay": KEY_F})
	assert_true((both[DECAY] == KEY_F) != (both[FLOW] == KEY_F))
	var seen := {}
	for action in both:
		assert_false(seen.has(both[action]))
		seen[both[action]] = true


func test_a_file_from_before_the_keys_could_be_chosen_has_the_keys_the_game_comes_with() -> void:
	var file := FileAccess.open(Settings.path, FileAccess.WRITE)
	file.store_string('{"version": 1, "cursor": "brush"}')
	file.close()
	Settings.read()
	assert_true(KeyBindings.are_as_they_came(Settings.keys))
	assert_eq(Settings.palette, RunePalette.Choice.PAINTED)


func test_a_rune_is_struck_with_the_key_that_was_chosen() -> void:
	Settings.choose_key(&"Rune-Dev", KEY_F)
	var circle: SpellCircle = add_managed(SpellCircle.new())
	circle.prepare(FIRE_BOLT)
	var first := FIRE_BOLT.strokes[0]
	assert_eq(first.rune, Rune.Type.DEVELOPMENT)
	# The cursor is over the rune.
	var motion := InputEventMouseMotion.new()
	motion.position = circle.position + first.position
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	await get_tree().process_frame
	await _press(KEY_A)
	assert_eq(circle.state, SpellCircle.State.READY, "the key it had does nothing")
	await _press(KEY_F)
	assert_eq(circle.state, SpellCircle.State.CASTING)


# In the options

func test_the_options_list_the_keys() -> void:
	var options := _open()
	assert_eq(options.keys.get_child_count(), KeyBindings.REBINDABLE.size() * 2, "a name and a button for each")
	assert_eq(options.key_button_of(FLOW).text, "W")
	assert_eq(options.key_button_of(LISTEN).text, "Space")
	assert_eq(options.key_button_of(ABANDON).text, "Escape")
	assert_true(options.reset_keys.disabled, "there is nothing to put back")


func test_pressing_a_keys_button_waits_for_a_key() -> void:
	var options := _open()
	options.key_button_of(FLOW).pressed.emit()
	assert_eq(options.choosing_for, FLOW)
	assert_eq(options.key_button_of(FLOW).text, "Press a key")
	await _press(KEY_F)
	assert_eq(options.choosing_for, &"")
	assert_eq(options.key_button_of(FLOW).text, "F")
	assert_eq(Settings.keys[FLOW], KEY_F)
	assert_false(options.reset_keys.disabled)


func test_a_key_that_is_in_use_changes_places_in_the_list() -> void:
	var options := _open()
	options.key_button_of(FLOW).pressed.emit()
	await _press(KEY_Q)
	assert_eq(options.key_button_of(FLOW).text, "Q")
	assert_eq(options.key_button_of(DECAY).text, "W")


func test_escape_leaves_a_key_as_it_was() -> void:
	var options := _open()
	options.key_button_of(FLOW).pressed.emit()
	await _press(KEY_ESCAPE)
	assert_eq(options.choosing_for, &"")
	assert_eq(options.key_button_of(FLOW).text, "W")
	assert_true(KeyBindings.are_as_they_came(Settings.keys))


func test_a_key_that_cannot_be_used_is_refused_and_said_to_be() -> void:
	var options := _open()
	options.key_button_of(FLOW).pressed.emit()
	await _press(KEY_3)
	assert_eq(options.key_button_of(FLOW).text, "W")
	assert_true(options.keys_note.text.begins_with("3 cannot be used"))


func test_a_key_pressed_while_none_is_waited_for_chooses_nothing() -> void:
	var options := _open()
	await _press(KEY_F)
	assert_true(KeyBindings.are_as_they_came(Settings.keys))
	options.take_key(KEY_F)
	assert_true(KeyBindings.are_as_they_came(Settings.keys))


func test_the_keys_can_be_put_back_from_the_options() -> void:
	Settings.choose_key(FLOW, KEY_F)
	var options := _open()
	assert_eq(options.key_button_of(FLOW).text, "F")
	options.reset_keys.pressed.emit()
	assert_eq(options.key_button_of(FLOW).text, "W")
	assert_true(options.reset_keys.disabled)


func test_the_legend_shows_the_keys_that_were_chosen() -> void:
	Settings.choose_key(FLOW, KEY_F)
	var practice: Node = add_managed(PRACTICE.instantiate())
	var legend: Label = practice.get_node("HUD/InputLegend")
	assert_true("ρ: F" in legend.text, legend.text)
	assert_false("ρ: W" in legend.text)


# The colours

func test_the_runes_come_as_they_were_painted() -> void:
	assert_eq(Settings.palette, RunePalette.Choice.PAINTED)
	for type in Rune.Type.values():
		assert_eq(RunePalette.texture_of(type, RunePalette.Choice.PAINTED), RunePalette.painted(type))
		assert_eq(GameCursor.ink_of(type), RunePalette.colour_of(type, RunePalette.Choice.PAINTED))


func test_as_painted_some_runes_are_much_alike() -> void:
	var flow := RunePalette.colour_of(Rune.Type.FLOW, RunePalette.Choice.PAINTED)
	var decay := RunePalette.colour_of(Rune.Type.DECAY, RunePalette.Choice.PAINTED)
	assert_gt(flow.g, flow.r, "Flow is green")
	assert_gt(decay.g, decay.r, "and so is Decay")
	assert_gt(decay.g, decay.b)


func test_how_far_apart_two_colours_are_is_measured() -> void:
	assert_almost_eq(RunePalette.apart(Color.WHITE, Color.BLACK), 100.0, 0.1, "black from white")
	assert_almost_eq(RunePalette.apart(Color.RED, Color.RED), 0.0, 0.001)
	assert_almost_eq(RunePalette.as_seen(Color.WHITE).x, 100.0, 0.1, "white is as light as there is")
	assert_almost_eq(RunePalette.as_seen(Color.WHITE).y, 0.0, 0.1, "and is no colour")
	assert_almost_eq(RunePalette.as_seen(Color(0.5, 0.5, 0.5)).x, 53.4, 0.3, "a grey half way up is a little over half as light")
	assert_gt(RunePalette.apart(Color.RED, Color.GREEN), 80.0)
	# To an eye that does not see red, or green, the two are much alike.
	assert_lt(RunePalette.apart(Color.RED, Color.GREEN, RunePalette.Eye.NO_GREEN), RunePalette.apart(Color.RED, Color.GREEN) * 0.5)
	assert_lt(RunePalette.apart(Color.RED, Color.GREEN, RunePalette.Eye.NO_RED), RunePalette.apart(Color.RED, Color.GREEN) * 0.5)
	# And to any eye a grey is the grey it was.
	for eye in RunePalette.Eye.values():
		assert_almost_eq(RunePalette.apart(Color(0.5, 0.5, 0.5), Color(0.5, 0.5, 0.5), eye), 0.0, 0.001)
		assert_lt(RunePalette.as_seen(Color(0.5, 0.5, 0.5), eye).distance_to(RunePalette.as_seen(Color(0.5, 0.5, 0.5))), 1.5)


func test_as_painted_two_runes_are_all_but_one_to_an_eye_that_does_not_see_red() -> void:
	var alike := RunePalette.most_alike(RunePalette.Choice.PAINTED, RunePalette.Eye.NO_RED)
	assert_lt(alike[2], 8.0)
	assert_eq([alike[0], alike[1]], [Rune.Type.FLOW, Rune.Type.VARIABILITY], "the green of Flow and the yellow of Variability")
	assert_gt(RunePalette.most_alike(RunePalette.Choice.PAINTED, RunePalette.Eye.ALL)[2], 30.0, "which are far apart to an eye that sees red")


func test_the_other_colours_can_be_told_apart_by_any_eye() -> void:
	assert_eq(RunePalette.DISTINCT.size(), Rune.Type.size())
	for eye in RunePalette.Eye.values():
		var alike := RunePalette.most_alike(RunePalette.Choice.DISTINCT, eye)
		var said := "%s and %s, to the eye %s" % [Rune.RuneToName[alike[0]], Rune.RuneToName[alike[1]], RunePalette.Eye.find_key(eye)]
		assert_gt(alike[2], 15.0, said)
		if eye != RunePalette.Eye.ALL:
			assert_gt(alike[2], RunePalette.most_alike(RunePalette.Choice.PAINTED, eye)[2], "%s: further apart than the two most alike as painted" % [said])


func test_the_other_colours_are_near_the_colours_that_were_painted_where_they_can_be() -> void:
	for type in [Rune.Type.FLOW, Rune.Type.DEVELOPMENT, Rune.Type.REFRACTION, Rune.Type.VARIABILITY, Rune.Type.EQUIVELANCE]:
		var was := RunePalette.colour_of(type, RunePalette.Choice.PAINTED)
		var now := RunePalette.colour_of(type, RunePalette.Choice.DISTINCT)
		assert_lt(absf(was.h - now.h), 0.2, "%s is the hue it was, or near it" % [Rune.RuneToName[type]])


func test_no_colour_is_so_dark_that_the_letter_on_it_cannot_be_read() -> void:
	var darkest_painted := INF
	for type in Rune.Type.values():
		var lightness := RunePalette.as_seen(RunePalette.colour_of(type, RunePalette.Choice.DISTINCT)).x
		assert_gt(lightness, 45.0, Rune.RuneToName[type])
		darkest_painted = minf(darkest_painted, RunePalette.as_seen(RunePalette.colour_of(type, RunePalette.Choice.PAINTED)).x)
	assert_lt(darkest_painted, 25.0, "as painted, Refraction is a black letter on a blue nearly as dark")


func test_a_rune_is_repainted_where_its_colour_was() -> void:
	var image := Image.create_empty(4, 1, false, Image.FORMAT_RGBA8)
	var green := Color(0.2, 0.8, 0.2)
	image.set_pixel(0, 0, green)
	image.set_pixel(1, 0, Color.BLACK)
	image.set_pixel(2, 0, Color(0.1, 0.4, 0.1))
	image.set_pixel(3, 0, Color(0.2, 0.8, 0.2, 0.0))
	var orange := Color(0.9, 0.6, 0.0)
	var made := RunePalette.repainted(image, green, orange)
	assert_almost_eq(made.get_pixel(0, 0).r, 0.9, 0.01)
	assert_almost_eq(made.get_pixel(0, 0).g, 0.6, 0.01)
	assert_almost_eq(made.get_pixel(1, 0).r, 0.0, 0.01, "what was black is black")
	assert_almost_eq(made.get_pixel(2, 0).r, 0.45, 0.01, "what was half the colour is half the new one")
	assert_almost_eq(made.get_pixel(2, 0).g, 0.3, 0.01)
	assert_almost_eq(made.get_pixel(3, 0).a, 0.0, 0.01, "and what could be seen through still can")
	assert_almost_eq(image.get_pixel(0, 0).g, 0.8, 0.01, "the picture that was handed in is left alone")


func test_a_rune_repainted_is_the_same_rune_in_another_colour() -> void:
	for type in Rune.Type.values():
		var was := RunePalette.painted(type).get_image()
		if was.is_compressed():
			was = was.duplicate()
			was.decompress()
		var now := RunePalette.texture_of(type, RunePalette.Choice.DISTINCT).get_image()
		assert_eq(now.get_size(), was.get_size())
		var middle := was.get_size() / 2
		var edge := Vector2i(middle.x, 1)
		assert_almost_eq(now.get_pixelv(Vector2i.ZERO).a, was.get_pixelv(Vector2i.ZERO).a, 0.01, "the corner")
		assert_almost_eq(now.get_pixelv(edge).a, was.get_pixelv(edge).a, 0.01)
		var disc := RunePalette.commonest_colour(now)
		var wanted := RunePalette.colour_of(type, RunePalette.Choice.DISTINCT)
		assert_lt(RunePalette.apart(disc, wanted), 6.0, "%s is the colour it is meant to be" % [Rune.RuneToName[type]])
		# The letter is still there: there is as much black as there was.
		var black_was := 0
		var black_now := 0
		for y in was.get_height():
			for x in was.get_width():
				var old := was.get_pixel(x, y)
				var new := now.get_pixel(x, y)
				if old.a > 0.9 and maxf(old.r, maxf(old.g, old.b)) < 0.2:
					black_was += 1
				if new.a > 0.9 and maxf(new.r, maxf(new.g, new.b)) < 0.2:
					black_now += 1
		assert_gt(black_was, 50, Rune.RuneToName[type])
		assert_between(float(black_now) / black_was, 0.85, 1.2, "%s has its letter" % [Rune.RuneToName[type]])


func test_a_picture_is_repainted_once() -> void:
	var first := RunePalette.texture_of(Rune.Type.FLOW, RunePalette.Choice.DISTINCT)
	assert_eq(RunePalette.texture_of(Rune.Type.FLOW, RunePalette.Choice.DISTINCT), first)


func test_the_colours_are_kept() -> void:
	Settings.choose_palette(RunePalette.Choice.DISTINCT)
	assert_eq(_on_disk()["palette"], "distinct")
	Settings.reset()
	assert_eq(Settings.palette, RunePalette.Choice.PAINTED)
	Settings.read()
	assert_eq(Settings.palette, RunePalette.Choice.DISTINCT)


func test_a_palette_the_game_does_not_know_is_ignored() -> void:
	var file := FileAccess.open(Settings.path, FileAccess.WRITE)
	file.store_string('{"version": 1, "palette": "sepia"}')
	file.close()
	Settings.read()
	assert_eq(Settings.palette, RunePalette.Choice.PAINTED)


func test_the_runes_on_a_circle_are_the_colours_that_were_chosen() -> void:
	Settings.choose_palette(RunePalette.Choice.DISTINCT)
	var circle: SpellCircle = add_managed(SpellCircle.new())
	circle.accepts_input = false
	circle.prepare(FIRE_BOLT)
	for ghost in circle.expected.bound_runes:
		assert_eq(ghost.primary_texture.texture, RunePalette.texture_of(ghost.rune_type, RunePalette.Choice.DISTINCT))
	var first := FIRE_BOLT.strokes[0]
	circle.strike(first.rune, first.position, 1_000_000)
	assert_eq(circle.actual.runes[0].primary_texture.texture, RunePalette.texture_of(first.rune, RunePalette.Choice.DISTINCT), "and so is the mark of a stroke")


func test_the_ink_and_the_streak_are_the_colours_that_were_chosen() -> void:
	Settings.choose_palette(RunePalette.Choice.DISTINCT)
	assert_eq(GameCursor.ink_of(Rune.Type.FLOW), RunePalette.DISTINCT[Rune.Type.FLOW])
	var bands := SpellShow.bands_of(FIRE_BOLT)
	assert_eq(bands[0], RunePalette.DISTINCT[FIRE_BOLT.strokes[-1].rune])
	var circle: SpellCircle = add_managed(SpellCircle.new())
	circle.prepare(FIRE_BOLT)
	assert_eq(circle.trail.ink, RunePalette.DISTINCT[FIRE_BOLT.strokes[0].rune])


func test_the_options_offer_both_sets_of_colours() -> void:
	var options := _open()
	assert_true(options.painted.button_pressed)
	assert_false(options.distinct.button_pressed)
	assert_eq(options.palette_note.text, options.PAINTED_NOTE)
	assert_not_null(options.painted.icon, "with a strip of each")
	assert_eq(options.painted.icon.get_size(), options.distinct.icon.get_size())
	options.distinct.pressed.emit()
	assert_eq(Settings.palette, RunePalette.Choice.DISTINCT)
	assert_true(options.distinct.button_pressed)
	assert_eq(options.palette_note.text, options.DISTINCT_NOTE)
	options.painted.pressed.emit()
	assert_eq(Settings.palette, RunePalette.Choice.PAINTED)


func test_a_strip_shows_the_seven_colours() -> void:
	var strip := RunePalette.swatches(RunePalette.Choice.DISTINCT, Vector2i(10, 10)).get_image()
	assert_eq(strip.get_size(), Vector2i(70, 10))
	var types := Rune.Type.values()
	for i in types.size():
		assert_eq(strip.get_pixel(i * 10 + 5, 5), RunePalette.DISTINCT[types[i]])


func test_everything_in_the_options_is_on_the_screen() -> void:
	var options := _open()
	await get_tree().process_frame
	await get_tree().process_frame
	for card_name in ["Card", "KeyCard"]:
		var card: Control = options.get_node(card_name)
		var rect := card.get_global_rect()
		assert_gt(rect.position.x, 0.0, card_name)
		assert_lt(rect.end.x, 1152.0, card_name)
		assert_lt(rect.end.y, 584.0, "%s is clear of the button under it" % [card_name])
	assert_lt(options.get_node("Card").get_global_rect().end.x, options.get_node("KeyCard").get_global_rect().position.x, "and the two are clear of each other")
