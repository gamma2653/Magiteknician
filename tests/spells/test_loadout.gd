extends TestCase
## Loadout: which spells are brought to a duel, in the campaign and in
## versus, and the choosing of them.

const CAMPAIGN_MENU := preload("res://magiteknician/menus/campaign_menu.tscn")
const VERSUS_MENU := preload("res://magiteknician/menus/versus_menu.tscn")
const VERSUS_ARENA := preload("res://magiteknician/levels/versus_arena.tscn")
const ARENA := preload("res://magiteknician/levels/duel_arena.tscn")
const PRACTICE := preload("res://magiteknician/levels/practice_range.tscn")
const PATH := "user://test_loadout_save.json"

const ALL: Array[StringName] = [&"spark", &"fire_bolt", &"ward", &"mend", &"gust", &"frost_bolt", &"flinch", &"bulwark", &"lightning"]


func before_each() -> void:
	forget_progress()
	forget_settings()
	_forget_versus()


func after_each() -> void:
	forget_progress()
	forget_settings()
	_forget_versus()
	DirAccess.remove_absolute(PATH)


func _forget_versus() -> void:
	FakeLink.forget_hosts()
	Session.versus_name = ""
	Session.versus_foe_name = ""
	Session.versus_spells = []
	Session.versus_foe_spells = []
	Session.versus_is_host = true


# The rules

func test_six_spells_can_be_brought() -> void:
	assert_eq(Loadout.SIZE, 6)
	assert_lt(Loadout.SIZE, Spellbook.MAX_SLOTS + 1, "and each has a number key")


func test_a_loadout_is_made_fit_to_bring() -> void:
	assert_eq(Loadout.tidy([&"ward", &"spark"], ALL), [&"ward", &"spark"], "in the order it was chosen")
	assert_eq(Loadout.tidy([&"ward", &"fireball", &"spark"], ALL), [&"ward", &"spark"], "without what is not known")
	assert_eq(Loadout.tidy([&"ward", &"ward", &"spark"], ALL), [&"ward", &"spark"], "with nothing twice")
	assert_eq(Loadout.tidy(ALL, ALL), ALL.slice(0, 6), "and no more than can be brought")
	assert_eq(Loadout.tidy(["ward", "spark"], ["ward", "spark", "mend"]), [&"ward", &"spark"], "whether it was written as names or read from a file")


func test_a_loadout_of_nothing_is_the_first_few_spells_known() -> void:
	assert_eq(Loadout.tidy([], [&"spark", &"ward"]), [&"spark", &"ward"])
	assert_eq(Loadout.tidy([], ALL), ALL.slice(0, 6))
	assert_eq(Loadout.tidy([&"fireball"], [&"spark", &"ward"]), [&"spark", &"ward"])
	assert_eq(Loadout.tidy([], []), [])


func test_a_spell_is_put_in_and_taken_out() -> void:
	var chosen: Array[StringName] = [&"spark", &"ward"]
	assert_eq(Loadout.toggled(chosen, &"mend"), [&"spark", &"ward", &"mend"], "at the end")
	assert_eq(Loadout.toggled(chosen, &"spark"), [&"ward"])
	assert_eq(chosen, [&"spark", &"ward"], "what was handed in is left alone")


func test_there_is_no_putting_in_where_there_is_no_room() -> void:
	var full := ALL.slice(0, 6)
	assert_false(Loadout.has_room(full))
	assert_eq(Loadout.toggled(full, &"lightning"), full)
	assert_true(Loadout.has_room(ALL.slice(0, 5)))


func test_the_last_spell_cannot_be_taken_out() -> void:
	assert_eq(Loadout.toggled([&"spark"], &"spark"), [&"spark"])


func test_a_spell_that_is_learned_is_brought_if_there_is_room() -> void:
	assert_eq(Loadout.with_learned([&"spark"], &"mend"), [&"spark", &"mend"])
	assert_eq(Loadout.with_learned(ALL.slice(0, 6), &"lightning"), ALL.slice(0, 6))
	assert_eq(Loadout.with_learned([&"spark"], &"spark"), [&"spark"])


func test_a_loadout_knows_whether_it_does_harm() -> void:
	assert_true(Loadout.does_harm([&"ward", &"spark"]))
	assert_false(Loadout.does_harm([&"ward", &"mend", &"bulwark", &"flinch"]))
	assert_false(Loadout.does_harm([]))


func test_what_is_brought_to_versus_by_one_who_has_not_chosen() -> void:
	assert_eq(Loadout.STANDARD.size(), Loadout.SIZE)
	assert_eq(Loadout.tidy(Loadout.STANDARD, Loadout.every_spell()), Loadout.STANDARD, "every one of them is a spell there is")
	assert_true(Loadout.does_harm(Loadout.STANDARD))
	assert_eq(Loadout.every_spell().size(), SpellLibrary.all().size())


# In the save

func test_a_new_game_brings_the_spells_it_begins_with() -> void:
	Session.new_game()
	assert_eq(Session.save.loadout, Session.campaign.starting_spell_ids)
	assert_eq(Session.save.bring(), Session.campaign.starting_spell_ids)


func test_the_loadout_is_kept_with_the_progress() -> void:
	var save := SaveGame.new()
	save.spell_ids = ALL.duplicate()
	save.loadout = [&"lightning", &"ward", &"mend"]
	assert_eq(save.to_dict()["loadout"], ["lightning", "ward", "mend"])
	assert_eq(save.write(PATH), OK)
	var read := SaveGame.read(PATH)
	assert_eq(read.loadout, [&"lightning", &"ward", &"mend"])
	assert_eq(read.bring(), [&"lightning", &"ward", &"mend"])


func test_a_save_from_before_there_were_loadouts_brings_the_first_spells_learned() -> void:
	var old := SaveGame.from_dict({"campaign_id": "a_campaign", "stages_cleared": 8, "spell_ids": ALL.map(func (id): return String(id))})
	assert_eq(old.spell_ids.size(), 9)
	assert_eq(old.bring(), ALL.slice(0, 6))


func test_a_loadout_in_a_save_that_makes_no_sense_is_made_fit() -> void:
	var mended := SaveGame.from_dict({"spell_ids": ["spark", "ward"], "loadout": ["lightning", "ward", 7, "ward"]})
	assert_eq(mended.bring(), [&"ward"])
	var nonsense := SaveGame.from_dict({"spell_ids": ["spark", "ward"], "loadout": "everything"})
	assert_eq(nonsense.bring(), [&"spark", &"ward"])


func test_a_spell_won_is_brought_while_there_is_room() -> void:
	var save := SaveGame.new()
	save.spell_ids = [&"spark", &"fire_bolt", &"ward"]
	assert_true(save.learn(&"mend"))
	assert_eq(save.bring(), [&"spark", &"fire_bolt", &"ward", &"mend"])
	assert_false(save.learn(&"mend"), "it is known already")
	save.learn(&"gust")
	save.learn(&"frost_bolt")
	assert_eq(save.bring().size(), 6)
	save.learn(&"flinch")
	assert_eq(save.spell_ids.size(), 7)
	assert_eq(save.bring().size(), 6, "the seventh is known and is left behind")
	assert_false(save.bring().has(&"flinch"))


func test_a_spell_won_does_not_disturb_what_was_chosen() -> void:
	var save := SaveGame.new()
	save.spell_ids = [&"spark", &"fire_bolt", &"ward", &"mend"]
	save.loadout = [&"ward", &"spark"]
	save.learn(&"gust")
	assert_eq(save.bring(), [&"ward", &"spark", &"gust"])


func test_winning_a_duel_brings_the_spell_it_teaches() -> void:
	Session.new_game()
	Session.enter_stage(0)
	var arena: Node = add_managed(ARENA.instantiate())
	arena.duel.set_process(false)
	arena.overlay.confirm.pressed.emit()
	arena.npc.halt()
	arena.duel.opponent.health = 1.0
	var spark := SpellLibrary.find(&"spark")
	arena.spell_bar.choose_spell(spark)
	for stroke in spark.strokes:
		arena.player_circle.strike(stroke.rune, stroke.position, 1_000_000 + stroke.tick * 250_000)
	assert_true(arena.duel.player_won())
	var reward: StringName = Session.campaign.stage(0).reward_spell_ids[0]
	assert_true(Session.save.bring().has(reward))
	assert_true(SaveGame.read(Session.save_path).loadout.has(reward), "and the save on disk says so")


# In the campaign

func test_the_player_brings_what_they_chose() -> void:
	Session.new_game()
	Session.save.stages_cleared = 8
	Session.save.spell_ids = ALL.duplicate()
	assert_eq(Session.choose_loadout([&"lightning", &"ward"]), [&"lightning", &"ward"])
	assert_true(Session.enter_stage(8))
	assert_eq(Session.spell_ids, [&"lightning", &"ward"])
	var arena: Node = add_managed(ARENA.instantiate())
	assert_eq(arena.duel.player.spellbook.ids(), [&"lightning", &"ward"])
	assert_eq(arena.spell_bar.slot_count(), 2)
	assert_eq(SaveGame.read(Session.save_path).loadout, [&"lightning", &"ward"], "and the choice is kept")


func test_the_player_never_brings_more_than_can_be_brought() -> void:
	Session.new_game()
	Session.save.stages_cleared = 8
	Session.save.spell_ids = ALL.duplicate()
	assert_eq(Session.choose_loadout(ALL).size(), Loadout.SIZE)
	Session.enter_stage(8)
	assert_eq(Session.spell_ids.size(), Loadout.SIZE)


func test_the_campaign_menu_says_how_many_spells_are_brought() -> void:
	Session.new_game()
	var menu: Node = add_managed(CAMPAIGN_MENU.instantiate())
	assert_eq(menu.spells_button.text, "Spells: 3 of 6")
	assert_false(menu.loadout.visible)


func test_the_campaign_menu_opens_the_spells_that_are_known() -> void:
	Session.new_game()
	Session.save.spell_ids = ALL.duplicate()
	var menu: Node = add_managed(CAMPAIGN_MENU.instantiate())
	menu._on_spells_pressed()
	assert_true(menu.loadout.visible)
	var picker: LoadoutPicker = menu.loadout.picker
	for id in ALL:
		assert_not_null(picker.button_of(id), String(id))
	assert_eq(picker.chosen, Session.campaign.starting_spell_ids)
	menu.loadout.done.pressed.emit()
	assert_false(menu.loadout.visible)


func test_choosing_in_the_campaign_menu_is_kept() -> void:
	Session.new_game()
	Session.save.spell_ids = ALL.duplicate()
	var menu: Node = add_managed(CAMPAIGN_MENU.instantiate())
	menu._on_spells_pressed()
	menu.loadout.picker.button_of(&"lightning").pressed.emit()
	assert_eq(menu.spells_button.text, "Spells: 4 of 6")
	assert_true(Session.save.bring().has(&"lightning"))
	assert_true(SaveGame.read(Session.save_path).loadout.has(&"lightning"))


# The picker

func _picker(known: Array[StringName], chosen: Array[StringName]) -> LoadoutPicker:
	var picker := LoadoutPicker.new()
	add_managed(picker)
	picker.offer(Spellbook.of(known).spells, chosen)
	return picker


func test_a_spell_that_is_brought_says_which_key_it_is_under() -> void:
	var picker := _picker(ALL, [&"ward", &"spark"])
	assert_true(picker.button_of(&"ward").text.begins_with("1  Ward"))
	assert_true(picker.button_of(&"spark").text.begins_with("2  Spark"))
	assert_true(picker.button_of(&"mend").text.begins_with("–  Mend"))
	assert_true(picker.button_of(&"ward").button_pressed)
	assert_false(picker.button_of(&"mend").button_pressed)
	assert_true(SpellLibrary.find(&"ward").formula() in picker.button_of(&"ward").text)
	assert_true("14 chi" in picker.button_of(&"ward").text)


func test_pressing_a_spell_puts_it_in_and_says_so() -> void:
	var picker := _picker(ALL, [&"ward", &"spark"])
	var heard: Array = []
	picker.changed.connect(func (chosen): heard.append(chosen))
	picker.button_of(&"mend").pressed.emit()
	assert_eq(picker.chosen, [&"ward", &"spark", &"mend"])
	assert_eq(heard, [[&"ward", &"spark", &"mend"]])
	assert_true(picker.button_of(&"mend").text.begins_with("3  Mend"))
	assert_eq(picker.count_text(), "Bring up to 6 spells. 3 chosen.")


func test_taking_a_spell_out_moves_the_rest_up() -> void:
	var picker := _picker(ALL, [&"ward", &"spark", &"mend"])
	picker.button_of(&"ward").pressed.emit()
	assert_eq(picker.chosen, [&"spark", &"mend"])
	assert_true(picker.button_of(&"spark").text.begins_with("1  Spark"))
	assert_true(picker.button_of(&"mend").text.begins_with("2  Mend"))


func test_when_there_is_no_room_the_rest_cannot_be_pressed() -> void:
	var picker := _picker(ALL, ALL.slice(0, 6))
	assert_true(picker.button_of(&"lightning").disabled)
	assert_false(picker.button_of(&"spark").disabled)
	assert_eq(picker.count_text(), "Bring up to 6 spells. 6 chosen. Take one out to put another in.")
	picker.button_of(&"spark").pressed.emit()
	assert_false(picker.button_of(&"lightning").disabled)


func test_the_last_spell_cannot_be_pressed_out() -> void:
	var picker := _picker(ALL, [&"spark"])
	assert_true(picker.button_of(&"spark").disabled)
	picker.toggle(&"spark")
	assert_eq(picker.chosen, [&"spark"])


func test_the_picker_warns_of_a_loadout_that_does_no_harm() -> void:
	var picker := _picker(ALL, [&"ward", &"spark"])
	var warning := picker.get_child(picker.get_child_count() - 1) as Label
	assert_false(warning.visible)
	picker.button_of(&"spark").pressed.emit()
	assert_true(warning.visible)
	assert_eq(warning.text, LoadoutPicker.HARMLESS_WARNING)


# In versus

func test_the_versus_loadout_is_kept_with_the_options() -> void:
	assert_eq(Settings.versus_spells, Loadout.STANDARD)
	Settings.choose_versus_spells([&"lightning", &"bulwark"])
	assert_eq(Settings.versus_spells, [&"lightning", &"bulwark"])
	Settings.reset()
	assert_eq(Settings.versus_spells, Loadout.STANDARD)
	Settings.read()
	assert_eq(Settings.versus_spells, [&"lightning", &"bulwark"])


func test_a_versus_loadout_that_makes_no_sense_is_made_fit() -> void:
	var file := FileAccess.open(Settings.path, FileAccess.WRITE)
	file.store_string('{"version": 1, "versus_spells": ["lightning", "fireball", 3]}')
	file.close()
	Settings.read()
	assert_eq(Settings.versus_spells, [&"lightning"])
	file = FileAccess.open(Settings.path, FileAccess.WRITE)
	file.store_string('{"version": 1, "versus_spells": "all of them"}')
	file.close()
	Settings.read()
	assert_eq(Settings.versus_spells, Loadout.STANDARD)


func test_the_greeting_says_what_is_brought() -> void:
	var greeting: Dictionary = DuelProtocol.through_json(DuelProtocol.hello("Gil", [&"lightning", &"ward"]))
	assert_eq(DuelProtocol.problems(greeting), PackedStringArray())
	assert_eq(DuelProtocol.spells_in(greeting), [&"lightning", &"ward"])
	var start: Dictionary = DuelProtocol.through_json(DuelProtocol.start("Hana", "Gil", [&"spark"], [&"lightning", &"ward"]))
	assert_eq(DuelProtocol.problems(start), PackedStringArray())
	assert_eq(DuelProtocol.spells_in(start, "host_spells"), [&"spark"])
	assert_eq(DuelProtocol.spells_in(start, "guest_spells"), [&"lightning", &"ward"])


func test_a_greeting_from_before_there_were_loadouts_is_still_a_greeting() -> void:
	assert_eq(DuelProtocol.VERSION, 1)
	var old := {"type": "hello", "version": 1, "name": "Gil"}
	assert_eq(DuelProtocol.problems(old), PackedStringArray())
	assert_eq(DuelProtocol.spells_in(old), [])
	assert_false(DuelProtocol.hello("Gil").has("spells"))


func test_a_greeting_cannot_bring_what_cannot_be_brought() -> void:
	var too_many := DuelProtocol.hello("Gil", ALL)
	assert_gt(DuelProtocol.problems(too_many).size(), 0)
	var unknown := DuelProtocol.hello("Gil", [&"fireball"])
	assert_gt(DuelProtocol.problems(unknown).size(), 0)
	var wordy := DuelProtocol.hello("Gil")
	wordy["spells"] = "everything"
	assert_gt(DuelProtocol.problems(wordy).size(), 0)


func _versus_menu(link: FakeLink, player_name: String) -> Node:
	var menu: Node = VERSUS_MENU.instantiate()
	menu.link = link
	add_managed(menu)
	menu.player_name.text = player_name
	return menu


func test_the_versus_menu_chooses_what_is_brought() -> void:
	var link: FakeLink = add_managed(FakeLink.new())
	var menu := _versus_menu(link, "Hana")
	assert_eq(menu.spells_button.text, "Spells: 6 of 6")
	menu._on_spells_pressed()
	assert_true(menu.loadout.visible)
	assert_not_null(menu.loadout.picker.button_of(&"lightning"), "every spell there is can be brought")
	menu.loadout.picker.button_of(&"flinch").pressed.emit()
	assert_eq(menu.spells_button.text, "Spells: 5 of 6")
	assert_false(Settings.versus_spells.has(&"flinch"))


func test_each_player_is_told_what_the_other_brings() -> void:
	var host_link: FakeLink = add_managed(FakeLink.new())
	var guest_link: FakeLink = add_managed(FakeLink.new())
	Settings.choose_versus_spells([&"lightning", &"ward"])
	var hosting := _versus_menu(host_link, "Hana")
	var joining := _versus_menu(guest_link, "Gil")
	hosting._on_host_pressed()
	joining._on_join_pressed()
	for i in 3:
		guest_link.settle()
		host_link.settle()
	assert_true(hosting.spells_button.disabled, "what is brought has been said")
	hosting._on_begin_pressed()
	assert_eq(Session.versus_spells, [&"lightning", &"ward"])
	assert_eq(Session.versus_foe_spells, [&"lightning", &"ward"], "in one process the two have the same options")


func _versus_arena(link: FakeLink, hosting: bool) -> Node:
	Session.versus_is_host = hosting
	var arena: Node = VERSUS_ARENA.instantiate()
	arena.link = link
	add_managed(arena)
	arena.set_process(false)
	return arena


func test_the_versus_arena_has_what_each_brought() -> void:
	var link: FakeLink = add_managed(FakeLink.new())
	Session.versus_spells = [&"lightning", &"ward"]
	Session.versus_foe_spells = [&"spark", &"flinch", &"mend"]
	var arena := _versus_arena(link, true)
	assert_eq(arena.me.spellbook.ids(), [&"lightning", &"ward"])
	assert_eq(arena.foe.spellbook.ids(), [&"spark", &"flinch", &"mend"])
	assert_eq(arena.hud.spell_bar.slot_count(), 2)
	assert_true("They bring Spark, Flinch, Mend." in arena.hud.overlay.body.text)


func test_a_player_who_does_not_say_brings_every_spell() -> void:
	var link: FakeLink = add_managed(FakeLink.new())
	var arena := _versus_arena(link, true)
	assert_eq(arena.me.spellbook.ids(), Loadout.STANDARD, "what I chose in the menu")
	assert_eq(arena.foe.spellbook.spells.size(), SpellLibrary.all().size())
	assert_true("They bring every spell." in arena.hud.overlay.body.text)


func test_the_host_will_not_let_a_spell_be_cast_that_was_not_brought() -> void:
	var link: FakeLink = add_managed(FakeLink.new())
	Session.versus_foe_spells = [&"spark"]
	var arena := _versus_arena(link, true)
	arena.begin()
	var rejected := [0]
	arena.host.remote.rejected.connect(func (_contents, _reasons): rejected[0] += 1)
	arena.host.receive(DuelProtocol.begin(SpellLibrary.find(&"lightning")))
	assert_eq(rejected[0], 1)
	arena.host.receive(DuelProtocol.begin(SpellLibrary.find(&"spark")))
	assert_eq(rejected[0], 1)
	assert_eq(arena.opponent_circle.spell, SpellLibrary.find(&"spark"))


# The spell bar, for a book of more spells than there are keys

func _book(count: int) -> Spellbook:
	var book := Spellbook.new()
	for i in count:
		var spell := Spell.new()
		spell.id = StringName("spell_%d" % [i])
		spell.display_name = "Spell %d" % [i]
		spell.strokes = SpellLibrary.find(&"spark").strokes
		spell.chi_cost = float(i)
		book.spells.append(spell)
	return book


func _bar(count: int) -> SpellBar:
	var bar := SpellBar.new()
	add_managed(bar)
	bar.spellbook = _book(count)
	return bar


func test_a_book_that_fits_the_keys_has_one_page() -> void:
	var bar := _bar(9)
	assert_eq(bar.page_count(), 1)
	assert_eq(bar.slot_count(), 9)
	assert_eq(bar.get_child_count(), 9, "and nothing to turn it with")
	assert_eq(bar.spell_count(), 9)


func test_a_book_that_does_not_is_shown_a_page_at_a_time() -> void:
	var bar := _bar(12)
	assert_eq(bar.page_count(), 2)
	assert_eq(bar.slot_count(), 8)
	assert_eq(bar.get_child_count(), 9, "eight spells, and the slot that turns the page")
	var turn := bar.get_child(8) as Button
	assert_true(turn.text.begins_with("9  More"))
	assert_true("1 of 2" in turn.text)
	bar.turn_page()
	assert_eq(bar.page, 1)
	assert_eq(bar.slot_count(), 4)
	assert_true((bar.get_child(0) as Button).text.begins_with("1  Spell 8"))
	bar.turn_page()
	assert_eq(bar.page, 0, "and round again")


func test_a_spell_on_another_page_can_be_chosen() -> void:
	var bar := _bar(12)
	var chosen: Array = []
	bar.spell_chosen.connect(func (spell): chosen.append(spell.id))
	assert_true(bar.choose(10))
	assert_eq(bar.page, 1)
	assert_eq(chosen, [&"spell_10"])
	assert_true((bar.get_child(2) as Button).button_pressed)
	assert_false(bar.choose(12))


func test_what_is_chosen_stays_chosen_when_the_page_is_turned() -> void:
	var bar := _bar(12)
	bar.choose(2)
	bar.turn_page()
	assert_eq(bar.chosen.id, &"spell_2")
	for i in bar.slot_count():
		assert_false((bar.get_child(i) as Button).button_pressed, "it is not on this page")
	bar.turn_page()
	assert_true((bar.get_child(2) as Button).button_pressed)


func test_what_can_be_afforded_is_shown_on_every_page() -> void:
	var bar := _bar(12)
	bar.show_affordable(9.5)
	assert_true(bar.is_shown_affordable(7))
	assert_false(bar.is_shown_affordable(9), "it is on the other page")
	bar.turn_page()
	assert_true(bar.is_shown_affordable(9))
	assert_false(bar.is_shown_affordable(10), "it costs more than there is")


func test_the_practice_range_offers_every_spell_there_is() -> void:
	var practice: Node = add_managed(PRACTICE.instantiate())
	assert_eq(practice.spell_bar.spell_count(), SpellLibrary.all().size())
