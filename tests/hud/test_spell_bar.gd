extends TestCase
## SpellBar: choosing a spell by slot.

var bar: SpellBar
var chosen: Array


func before_each() -> void:
	bar = SpellBar.new()
	add_managed(bar)
	chosen = []
	bar.spell_chosen.connect(func (spell): chosen.append(spell.id))
	bar.spellbook = Spellbook.of([&"spark", &"ward", &"fire_bolt"])


func _press(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await get_tree().process_frame
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	await get_tree().process_frame


func _pressed_slots() -> Array:
	var pressed := []
	for i in bar.get_child_count():
		if (bar.get_child(i) as Button).button_pressed:
			pressed.append(i)
	return pressed


func test_there_is_a_slot_for_each_spell() -> void:
	assert_eq(bar.slot_count(), 3)
	assert_null(bar.chosen, "nothing is chosen to begin with")
	var first := bar.get_child(0) as Button
	assert_true("Spark" in first.text)
	assert_true("1" in first.text, "the slot shows its number")
	assert_true(SpellLibrary.find(&"spark").formula() in first.text)
	assert_eq(first.focus_mode, Control.FOCUS_NONE)


func test_choosing_a_slot_announces_its_spell() -> void:
	assert_true(bar.choose(1))
	assert_eq(chosen, [&"ward"])
	assert_eq(bar.chosen, SpellLibrary.find(&"ward"))
	assert_eq(_pressed_slots(), [1])


func test_only_one_slot_is_chosen_at_a_time() -> void:
	bar.choose(0)
	bar.choose(2)
	assert_eq(chosen, [&"spark", &"fire_bolt"])
	assert_eq(_pressed_slots(), [2])


func test_a_slot_that_does_not_exist_cannot_be_chosen() -> void:
	assert_false(bar.choose(3))
	assert_false(bar.choose(-1))
	assert_eq(chosen, [])


func test_a_spell_can_be_chosen_by_name() -> void:
	assert_true(bar.choose_spell(SpellLibrary.find(&"fire_bolt")))
	assert_eq(_pressed_slots(), [2])
	assert_false(bar.choose_spell(SpellLibrary.find(&"lightning")), "not in the book")


func test_number_keys_choose_slots() -> void:
	await _press(&"Spell-2")
	assert_eq(chosen, [&"ward"])
	await _press(&"Spell-1")
	assert_eq(chosen, [&"ward", &"spark"])
	assert_eq(_pressed_slots(), [0])


func test_a_number_with_no_slot_does_nothing() -> void:
	await _press(&"Spell-7")
	assert_eq(chosen, [])


func test_clicking_a_slot_chooses_it() -> void:
	(bar.get_child(2) as Button).pressed.emit()
	assert_eq(chosen, [&"fire_bolt"])


func test_a_new_book_replaces_the_slots() -> void:
	bar.choose(0)
	bar.spellbook = Spellbook.of([&"mend"])
	assert_eq(bar.slot_count(), 1)
	assert_null(bar.chosen)


func test_there_is_a_key_for_every_slot() -> void:
	for i in Spellbook.MAX_SLOTS:
		assert_true(InputMap.has_action(SpellBar.SLOT_ACTION_PATTERN % [i + 1]))


func test_a_book_larger_than_the_bar_shows_what_fits() -> void:
	var book := Spellbook.new()
	for i in Spellbook.MAX_SLOTS + 3:
		var spell := Spell.new()
		spell.id = StringName("filler_%d" % [i])
		spell.display_name = "Filler %d" % [i]
		book.learn(spell)
	bar.spellbook = book
	assert_eq(bar.slot_count(), Spellbook.MAX_SLOTS)
