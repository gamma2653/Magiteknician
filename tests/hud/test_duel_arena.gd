extends TestCase
## The duel arena and the HUD pieces it is made of.

const ARENA := preload("res://magiteknician/levels/duel_arena.tscn")
const PANEL := preload("res://magiteknician/hud/DuelistPanel.tscn")
const BEAT := 250_000

var arena: Node
var clock: int


func before_each() -> void:
	Session.clear()
	clock = 1_000_000
	arena = ARENA.instantiate()
	arena.opponent_seed = 9
	add_managed(arena)
	# Time is fed by hand so the test does not depend on the frame rate.
	arena.duel.set_process(false)


func after_each() -> void:
	Session.clear()


func _cast(id: StringName) -> void:
	var spell := SpellLibrary.find(id)
	arena.spell_bar.choose_spell(spell)
	for stroke in spell.strokes:
		arena.player_circle.strike(stroke.rune, stroke.position, clock + stroke.tick * BEAT)
	clock += 10_000_000


## Casts Fire Bolt until the opponent falls, waiting for chi in between.
## Returns how many casts it took.
func _defeat_the_opponent() -> int:
	var casts := 0
	arena.npc.halt()
	while not arena.duel.is_over() and casts < 50:
		arena.duel.player.chi = arena.duel.player.max_chi
		_cast(&"fire_bolt")
		casts += 1
	return casts


func _run(seconds: float) -> void:
	for i in roundi(seconds * 60.0):
		arena.duel.advance(1.0 / 60.0)


func test_the_arena_opens_on_an_introduction() -> void:
	assert_true(arena.overlay.visible)
	assert_eq(arena.overlay.heading.text, "Training Sphere")
	assert_eq(arena.overlay.body.text, arena.opponent.introduction)
	assert_eq(arena.overlay.confirm.text, "Begin")
	assert_eq(arena.duel.state, Duel.State.WAITING)
	assert_false(arena.player_circle.accepts_input)


func test_both_duelists_are_shown() -> void:
	assert_eq(arena.player_panel.title.text, "You")
	assert_eq(arena.opponent_panel.title.text, "Training Sphere")
	assert_eq(arena.opponent_panel.subtitle.text, "Gratiswiesel Academy")
	assert_almost_eq(arena.opponent_panel.health_bar.max_value, arena.opponent.max_health)
	assert_eq(arena.opponent_panel.health_text.text, "70 / 70")


func test_the_player_brings_the_novice_spells_by_default() -> void:
	var book: Spellbook = arena.duel.player.spellbook
	assert_gt(book.spells.size(), 0)
	for spell in book.spells:
		assert_eq(spell.rank, Spell.Rank.NOVICE, String(spell.id))
	assert_eq(arena.spell_bar.slot_count(), book.spells.size())
	assert_eq(arena.player_circle.spell, book.spells[0], "the first is laid out ready")


func test_the_session_decides_who_is_fought_and_with_what() -> void:
	var rival := Opponent.new()
	rival.id = &"rival"
	rival.display_name = "Rival"
	rival.spell_ids = [&"spark"]
	rival.profile = CasterProfile.new()
	Session.opponent = rival
	Session.spell_ids = [&"ward", &"lightning"]
	var other: Node = add_managed(ARENA.instantiate())
	assert_eq(other.opponent, rival)
	assert_eq(other.opponent_panel.title.text, "Rival")
	assert_eq(other.duel.player.spellbook.ids(), [&"ward", &"lightning"])


func test_begin_starts_the_duel() -> void:
	arena.overlay.confirm.pressed.emit()
	assert_false(arena.overlay.visible)
	assert_eq(arena.duel.state, Duel.State.RUNNING)
	assert_true(arena.player_circle.accepts_input)


func test_slots_show_what_a_spell_costs() -> void:
	var first := arena.spell_bar.get_child(0) as Button
	var spell: Spell = arena.duel.player.spellbook.spells[0]
	assert_true(SpellInfo.cost_text(spell) in first.text)
	assert_true(spell.describe_effects() in first.tooltip_text)


func test_the_chosen_spell_says_what_it_does() -> void:
	arena.spell_bar.choose_spell(SpellLibrary.find(&"fire_bolt"))
	assert_true("Fire Bolt" in arena.chosen_spell.text)
	assert_true(SpellLibrary.find(&"fire_bolt").describe_effects() in arena.chosen_spell.text)


func test_every_slot_fits_on_the_screen() -> void:
	Session.spell_ids = Session.campaign.spell_ids_after(Session.campaign.stage_count())
	var full: Node = add_managed(ARENA.instantiate())
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(full.spell_bar.slot_count(), Spellbook.MAX_SLOTS)
	for slot in full.spell_bar.get_children():
		var rect: Rect2 = (slot as Control).get_global_rect()
		assert_true(rect.position.x >= 0.0, "%s starts on the screen" % [slot.text.get_slice("\n", 0)])
		assert_true(rect.end.x <= 1152.0, "%s ends on the screen" % [slot.text.get_slice("\n", 0)])


func test_the_panels_follow_the_duel() -> void:
	arena.overlay.confirm.pressed.emit()
	_cast(&"fire_bolt")
	var fire_bolt := SpellLibrary.find(&"fire_bolt")
	var blow := fire_bolt.effects[0].amount
	assert_almost_eq(arena.opponent_panel.health_bar.value, 70.0 - blow)
	assert_eq(arena.opponent_panel.health_text.text, "%d / 70" % [70.0 - blow])
	assert_almost_eq(arena.player_panel.chi_bar.value, 100.0 - fire_bolt.chi_cost)
	assert_eq(arena.combat_log.lines[-1], "You cast Fire Bolt (S): %d damage." % [blow])


func test_a_ward_shows_on_the_panel() -> void:
	arena.overlay.confirm.pressed.emit()
	assert_almost_eq(arena.player_panel.ward_bar.modulate.a, 0.0, 0.001, "no ward, no bar")
	_cast(&"ward")
	var held := SpellLibrary.find(&"ward").effects[0].amount
	assert_almost_eq(arena.player_panel.ward_bar.modulate.a, 1.0)
	assert_almost_eq(arena.player_panel.ward_bar.value, held)
	arena.duel.player.take_damage(held - 5.0)
	assert_almost_eq(arena.player_panel.ward_bar.value, 5.0)
	assert_almost_eq(arena.player_panel.ward_bar.max_value, held, 0.001, "the bar stays as long as the ward was")
	arena.duel.player.take_damage(15.0)
	assert_almost_eq(arena.player_panel.ward_bar.modulate.a, 0.0)


func test_spells_that_cannot_be_afforded_are_dimmed() -> void:
	arena.overlay.confirm.pressed.emit()
	arena.duel.player.chi = 9.0
	var book: Spellbook = arena.duel.player.spellbook
	for i in book.spells.size():
		assert_eq(arena.spell_bar.is_shown_affordable(i), book.spells[i].chi_cost <= 9.0, String(book.spells[i].id))
	arena.duel.player.chi = 100.0
	for i in book.spells.size():
		assert_true(arena.spell_bar.is_shown_affordable(i))


func test_a_refused_cast_is_explained() -> void:
	arena.overlay.confirm.pressed.emit()
	arena.duel.player.chi = 3.0
	_cast(&"fire_bolt")
	assert_eq(arena.combat_log.lines[-1], "Not enough chi for Fire Bolt.")
	assert_almost_eq(arena.duel.opponent.health, arena.opponent.max_health)


func test_the_opponents_spell_is_named_while_it_is_cast() -> void:
	arena.overlay.confirm.pressed.emit()
	assert_eq(arena.opponent_spell.text, "")
	_run(3.0)
	assert_eq(arena.npc.state, NpcCaster.State.CASTING)
	assert_eq(arena.opponent_spell.text, arena.opponent_circle.spell.display_name)
	_run(6.0)
	assert_gt(arena.duel.outcomes.size(), 0)


func test_winning_shows_the_verdict() -> void:
	arena.overlay.confirm.pressed.emit()
	var casts := _defeat_the_opponent()
	assert_true(arena.duel.player_won())
	assert_true(arena.overlay.visible)
	assert_eq(arena.overlay.heading.text, "Victory")
	assert_eq(arena.overlay.confirm.text, "Duel again")
	assert_true("%d casts" % [casts] in arena.overlay.body.text)
	assert_true("100%" in arena.overlay.body.text)


func test_losing_shows_the_verdict() -> void:
	arena.overlay.confirm.pressed.emit()
	arena.duel.player.health = 1.0
	_run(12.0)
	assert_true(arena.duel.is_over())
	assert_eq(arena.overlay.heading.text, "Defeat")
	assert_true("did not finish a single cast" in arena.overlay.body.text)


func test_leaving_goes_back_where_the_player_came_from() -> void:
	Session.return_scene = "res://magiteknician/levels/practice_range.tscn"
	arena.overlay.decline.pressed.emit()
	assert_eq(arena._destination, "res://magiteknician/levels/practice_range.tscn")
	assert_false(arena.player_circle.accepts_input)


func test_duelling_again_reloads_the_arena() -> void:
	arena.overlay.confirm.pressed.emit()
	_defeat_the_opponent()
	arena.overlay.confirm.pressed.emit()
	assert_eq(arena._destination, "res://magiteknician/levels/duel_arena.tscn")


func test_a_panel_can_be_handed_another_duelist() -> void:
	var panel: DuelistPanel = add_managed(PANEL.instantiate())
	var first := Duelist.new("First")
	var second := Duelist.new("Second", 50.0)
	panel.bind(first)
	panel.bind(second)
	first.take_damage(30.0)
	assert_eq(panel.title.text, "Second")
	assert_almost_eq(panel.health_bar.value, 50.0, 0.001, "the first duelist is no longer listened to")


func test_the_log_keeps_only_the_latest_lines() -> void:
	var combat_log := CombatLog.new()
	combat_log.capacity = 3
	add_managed(combat_log)
	for i in 5:
		combat_log.add("line %d" % [i])
	assert_eq(combat_log.lines, PackedStringArray(["line 2", "line 3", "line 4"]))
	assert_eq(combat_log.text, "line 2\nline 3\nline 4")
	combat_log.clear()
	assert_eq(combat_log.text, "")
