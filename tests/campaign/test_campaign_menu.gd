extends TestCase
## The campaign menu, the main menu's way into it, and the arena's way back.

const MENU := preload("res://magiteknician/menus/campaign_menu.tscn")
const MAIN_MENU := preload("res://magiteknician/menus/main_menu.tscn")
const ARENA := preload("res://magiteknician/levels/duel_arena.tscn")
const BEAT := 250_000

var campaign: Campaign


func before_each() -> void:
	forget_progress()
	campaign = Session.campaign


func after_each() -> void:
	forget_progress()


func _open_menu() -> Node:
	return add_managed(MENU.instantiate())


func _stage_button(menu: Node, index: int) -> Button:
	return menu.stage_list.get_child(index) as Button


## Opens the arena on the stage at `index` and wins it.
func _win_stage(index: int) -> Node:
	Session.enter_stage(index)
	var arena: Node = add_managed(ARENA.instantiate())
	arena.duel.set_process(false)
	arena.overlay.confirm.pressed.emit()
	arena.npc.halt()
	var spark := SpellLibrary.find(&"spark")
	arena.duel.opponent.health = 1.0
	arena.player_circle.prepare(spark)
	for stroke in spark.strokes:
		arena.player_circle.strike(stroke.rune, stroke.position, 1_000_000 + stroke.tick * BEAT)
	return arena


func test_the_menu_lists_every_stage() -> void:
	Session.new_game()
	var menu := _open_menu()
	assert_eq(menu.heading.text, campaign.title)
	assert_eq(menu.introduction.text, campaign.introduction)
	assert_eq(menu.stage_list.get_child_count(), campaign.stage_count())
	for i in campaign.stage_count():
		assert_true(campaign.stage(i).opponent.display_name in _stage_button(menu, i).text)


func test_only_the_next_stage_can_be_chosen_in_a_new_game() -> void:
	Session.new_game()
	var menu := _open_menu()
	assert_false(_stage_button(menu, 0).disabled)
	assert_true("next" in _stage_button(menu, 0).text)
	for i in range(1, campaign.stage_count()):
		assert_true(_stage_button(menu, i).disabled, "stage %d" % [i + 1])
		assert_true("locked" in _stage_button(menu, i).text)


func test_the_menu_opens_on_the_next_duel() -> void:
	Session.new_game()
	Session.save.stages_cleared = 2
	var menu := _open_menu()
	assert_eq(menu.selected, 2)
	var opponent := campaign.stage(2).opponent
	assert_eq(menu.opponent_name.text, opponent.display_name)
	assert_eq(menu.opponent_title.text, opponent.title)
	assert_eq(menu.opponent_introduction.text, opponent.introduction)
	assert_eq(menu.duel_button.text, "Duel")
	assert_false(menu.duel_button.disabled)


func test_the_panel_says_what_an_opponent_knows_and_teaches() -> void:
	Session.new_game()
	var menu := _open_menu()
	for id in campaign.stage(0).opponent.spell_ids:
		assert_true(SpellLibrary.find(id).display_name in menu.knows.text)
	assert_true(SpellLibrary.find(campaign.stage(0).reward_spell_ids[0]).display_name in menu.teaches.text)
	assert_eq(menu.best.text, "", "nothing to boast of yet")


func test_a_won_stage_shows_the_best_win() -> void:
	Session.new_game()
	Session.save.stages_cleared = 1
	Session.save.record_win(campaign.stage(0).opponent.id, 0.9, 41.6)
	var menu := _open_menu()
	assert_true("✓" in _stage_button(menu, 0).text)
	assert_true("A in 42 s" in _stage_button(menu, 0).text)
	menu.select(0)
	assert_eq(menu.best.text, "Your best: A in 42 s")
	assert_eq(menu.duel_button.text, "Duel again")


func test_duel_sends_the_player_to_the_arena() -> void:
	Session.new_game()
	var menu := _open_menu()
	menu._on_duel_pressed()
	assert_eq(menu._destination, Session.ARENA_SCENE)
	assert_eq(Session.opponent, campaign.stage(0).opponent)
	assert_eq(Session.stage_index, 0)


func test_back_returns_to_the_main_menu() -> void:
	Session.new_game()
	var menu := _open_menu()
	menu._on_back_pressed()
	assert_eq(menu._destination, Session.MAIN_MENU_SCENE)


func test_opened_on_its_own_the_menu_starts_a_game() -> void:
	var menu := _open_menu()
	assert_not_null(Session.save)
	assert_eq(menu.stage_list.get_child_count(), campaign.stage_count())


func test_a_finished_campaign_says_so() -> void:
	Session.new_game()
	Session.save.stages_cleared = campaign.stage_count()
	var menu := _open_menu()
	assert_true("won" in menu.introduction.text)
	assert_eq(menu.selected, campaign.stage_count() - 1)
	for i in campaign.stage_count():
		assert_false(_stage_button(menu, i).disabled)


func test_winning_a_campaign_duel_moves_the_campaign_on() -> void:
	Session.new_game()
	var arena := _win_stage(0)
	assert_eq(Session.save.stages_cleared, 1)
	assert_eq(arena.overlay.heading.text, "Victory")
	assert_eq(arena.overlay.confirm.text, "Continue")
	assert_true(campaign.stage(0).victory_text in arena.overlay.body.text)
	var reward := SpellLibrary.find(campaign.stage(0).reward_spell_ids[0])
	assert_true("You have learned %s." % [reward.display_name] in arena.overlay.body.text)
	arena.overlay.confirm.pressed.emit()
	assert_eq(arena._destination, Session.CAMPAIGN_SCENE)


func test_losing_a_campaign_duel_offers_it_again() -> void:
	Session.new_game()
	Session.enter_stage(0)
	var arena: Node = add_managed(ARENA.instantiate())
	arena.duel.set_process(false)
	arena.overlay.confirm.pressed.emit()
	arena.duel.player.health = 1.0
	for i in 60 * 15:
		arena.duel.advance(1.0 / 60.0)
	assert_true(arena.duel.is_over())
	assert_eq(arena.overlay.heading.text, "Defeat")
	assert_eq(arena.overlay.confirm.text, "Duel again")
	assert_eq(Session.save.stages_cleared, 0)
	arena.overlay.confirm.pressed.emit()
	assert_eq(arena._destination, Session.ARENA_SCENE)
	assert_eq(Session.stage_index, 0, "the same stage is still set up")


func test_the_player_brings_what_they_have_learned() -> void:
	Session.new_game()
	Session.save.stages_cleared = 3
	Session.save.spell_ids = campaign.spell_ids_after(3)
	Session.enter_stage(3)
	var arena: Node = add_managed(ARENA.instantiate())
	assert_eq(arena.duel.player.spellbook.ids(), campaign.spell_ids_after(3))
	assert_eq(arena.opponent, campaign.stage(3).opponent)


func test_continue_is_offered_only_when_there_is_something_to_continue() -> void:
	var fresh: Node = add_managed(MAIN_MENU.instantiate())
	assert_true(fresh.get_node("ButtonManager/Continue").disabled)
	Session.new_game()
	var later: Node = add_managed(MAIN_MENU.instantiate())
	assert_false(later.get_node("ButtonManager/Continue").disabled)


func test_new_game_asks_before_throwing_progress_away() -> void:
	Session.new_game()
	Session.save.stages_cleared = 4
	Session.write_save()
	var menu: Node = add_managed(MAIN_MENU.instantiate())
	menu._on_new_game_pressed()
	assert_eq(menu.btn_pressed, menu.MenuItem.NONE, "nothing happens until the player confirms")
	assert_true(menu.get_node("StartOver").visible)
	menu.get_node("StartOver").hide()
	menu._on_start_over_confirmed()
	assert_eq(menu.btn_pressed, menu.MenuItem.NEW_GAME)


func test_new_game_does_not_ask_when_there_is_nothing_to_lose() -> void:
	var menu: Node = add_managed(MAIN_MENU.instantiate())
	menu._on_new_game_pressed()
	assert_eq(menu.btn_pressed, menu.MenuItem.NEW_GAME)
	assert_false(menu.get_node("StartOver").visible)
