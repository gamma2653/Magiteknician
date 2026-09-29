extends TestCase
## The versus menu and the versus arena, with two players in one process.

const MENU := preload("res://magiteknician/menus/versus_menu.tscn")
const ARENA := preload("res://magiteknician/levels/versus_arena.tscn")
const MAIN_MENU := preload("res://magiteknician/menus/main_menu.tscn")
# Casts here are made in no time at all, and the host will not believe a
# cast that claims to have taken longer than it has been since it began,
# give or take DuelProtocol.ARRIVAL_SLACK_USEC. A beat this short keeps the
# longest spell inside that allowance.
const BEAT := 100_000

var host_link: FakeLink
var guest_link: FakeLink
var clock: int


func before_each() -> void:
	FakeLink.forget_hosts()
	Session.versus_name = ""
	Session.versus_foe_name = ""
	Session.versus_is_host = true
	host_link = add_managed(FakeLink.new())
	guest_link = add_managed(FakeLink.new())
	clock = 1_000_000


func after_each() -> void:
	FakeLink.forget_hosts()
	Session.versus_name = ""
	Session.versus_foe_name = ""
	Session.versus_is_host = true


func _settle() -> void:
	for i in 3:
		guest_link.settle()
		host_link.settle()


func _menu(link: FakeLink, player_name: String) -> Node:
	var menu: Node = MENU.instantiate()
	menu.link = link
	add_managed(menu)
	menu.player_name.text = player_name
	return menu


## Two menus, one hosting and one joined to it, with greetings exchanged.
func _met() -> Array:
	var hosting := _menu(host_link, "Hana")
	var joining := _menu(guest_link, "Gil")
	hosting._on_host_pressed()
	joining._on_join_pressed()
	_settle()
	return [hosting, joining]


func _arena(link: FakeLink, mine: String, theirs: String, hosting: bool) -> Node:
	Session.versus_name = mine
	Session.versus_foe_name = theirs
	Session.versus_is_host = hosting
	var arena: Node = ARENA.instantiate()
	arena.link = link
	add_managed(arena)
	# Time is fed by hand so the test does not depend on the frame rate.
	arena.set_process(false)
	return arena


## Two arenas joined to each other, with the countdown over.
func _duelling() -> Array:
	host_link.host()
	guest_link.join("127.0.0.1")
	_settle()
	var hosting := _arena(host_link, "Hana", "Gil", true)
	var joining := _arena(guest_link, "Gil", "Hana", false)
	hosting._process(VersusArenaTimes.COUNTDOWN + 0.1)
	_settle()
	hosting.player_circle.accepts_input = false
	joining.player_circle.accepts_input = false
	return [hosting, joining]


func _cast(arena: Node, id: StringName) -> void:
	var spell := SpellLibrary.find(id)
	arena.hud.spell_bar.choose_spell(spell)
	for stroke in spell.strokes:
		arena.player_circle.strike(stroke.rune, stroke.position, clock + stroke.tick * BEAT)
		_settle()
	clock += 10_000_000


func _run(arenas: Array, seconds: float) -> void:
	for i in roundi(seconds * 30.0):
		for arena in arenas:
			arena._process(1.0 / 30.0)
		_settle()


class VersusArenaTimes:
	const COUNTDOWN := 3.0


# The menu

func test_the_menu_waits_to_be_told_what_to_do() -> void:
	var menu := _menu(host_link, "")
	assert_true(menu.begin_button.disabled)
	assert_false(menu.host_button.disabled)
	assert_eq(menu.address.text, "127.0.0.1")


func test_hosting_waits_for_a_challenger() -> void:
	var menu := _menu(host_link, "Hana")
	menu._on_host_pressed()
	assert_eq(host_link.role, NetLink.Role.HOST)
	assert_true("Waiting for a challenger" in menu.status.text)
	assert_true(menu.host_button.disabled, "there is no hosting twice")
	assert_true(menu.begin_button.disabled, "and nobody to begin with yet")


func test_the_two_are_introduced_when_the_guest_joins() -> void:
	var menus := _met()
	assert_eq(menus[0].status.text, "Gil has joined. Begin when you are ready.")
	assert_eq(menus[1].status.text, "Joined Hana. Waiting for them to begin.")
	assert_false(menus[0].begin_button.disabled)
	assert_true(menus[1].begin_button.disabled, "only the host begins")
	assert_eq(host_link.sent_types(), ["hello"])
	assert_eq(guest_link.sent_types(), ["hello"])


func test_beginning_sends_both_to_the_arena() -> void:
	var menus := _met()
	menus[0]._on_begin_pressed()
	assert_eq(menus[0]._destination, Session.VERSUS_ARENA_SCENE)
	assert_eq(Session.versus_name, "Hana")
	assert_eq(Session.versus_foe_name, "Gil")
	assert_true(Session.versus_is_host)
	_settle()
	assert_eq(menus[1]._destination, Session.VERSUS_ARENA_SCENE)
	assert_eq(Session.versus_name, "Gil")
	assert_eq(Session.versus_foe_name, "Hana")
	assert_false(Session.versus_is_host)


func test_a_guest_cannot_begin() -> void:
	var menus := _met()
	menus[1]._on_begin_pressed()
	_settle()
	assert_eq(menus[0]._destination, "")
	assert_eq(menus[1]._destination, "")


func test_players_with_the_same_name_are_told_apart() -> void:
	var hosting := _menu(host_link, "Sam")
	var joining := _menu(guest_link, "Sam")
	hosting._on_host_pressed()
	joining._on_join_pressed()
	_settle()
	hosting._on_begin_pressed()
	assert_eq(Session.versus_name, "Sam")
	assert_eq(Session.versus_foe_name, "Sam II")


func test_a_player_with_no_name_is_given_one() -> void:
	var hosting := _menu(host_link, "   ")
	var joining := _menu(guest_link, "")
	hosting._on_host_pressed()
	joining._on_join_pressed()
	_settle()
	assert_true("Guest has joined" in hosting.status.text)
	assert_true("Joined Host" in joining.status.text)


func test_names_are_kept_short() -> void:
	assert_eq(DuelProtocol.tidy_name("  Rizzle Dram of Gratiswiesel  "), "Rizzle Dram of G")
	assert_eq(DuelProtocol.tidy_name("two\nlines"), "two lines")
	assert_eq(DuelProtocol.tidy_name("", "Guest"), "Guest")
	assert_eq(DuelProtocol.names_for_duel("Ann", "Ann"), ["Ann", "Ann II"] as Array[String])
	assert_eq(DuelProtocol.names_for_duel("Ann", "Bo"), ["Ann", "Bo"] as Array[String])


func test_joining_where_nobody_is_hosting_fails() -> void:
	var menu := _menu(guest_link, "Gil")
	menu._on_join_pressed()
	_settle()
	assert_true("Nobody answered" in menu.status.text)
	assert_false(menu.join_button.disabled, "so the player may try again")


func test_joining_needs_an_address() -> void:
	var menu := _menu(guest_link, "Gil")
	menu.address.text = "  "
	menu._on_join_pressed()
	assert_eq(guest_link.role, NetLink.Role.NONE)
	assert_true("where the host is" in menu.status.text)


func test_hosting_can_fail() -> void:
	host_link.answer = ERR_CANT_CREATE
	var menu := _menu(host_link, "Hana")
	menu._on_host_pressed()
	assert_true("Could not host" in menu.status.text)
	assert_false(menu.host_button.disabled)


func test_the_host_is_told_when_the_guest_leaves() -> void:
	var menus := _met()
	guest_link.close()
	assert_true("They have left" in menus[0].status.text)
	assert_true(menus[0].begin_button.disabled)


func test_the_guest_is_told_when_the_host_leaves() -> void:
	var menus := _met()
	host_link.close()
	assert_eq(menus[1].status.text, "The host has gone.")
	assert_false(menus[1].join_button.disabled)


func test_a_different_version_cannot_duel() -> void:
	var menu := _menu(host_link, "Hana")
	menu._on_host_pressed()
	guest_link.join("127.0.0.1")
	_settle()
	var greeting := DuelProtocol.hello("Gil")
	greeting["version"] = DuelProtocol.VERSION + 1
	guest_link.send(greeting)
	_settle()
	assert_true("different version" in menu.status.text)
	assert_true(menu.begin_button.disabled)
	assert_eq(host_link.role, NetLink.Role.NONE)


func test_back_lets_go_of_the_other_player() -> void:
	var menus := _met()
	menus[0]._on_back_pressed()
	assert_eq(menus[0]._destination, Session.MAIN_MENU_SCENE)
	assert_false(guest_link.is_joined())
	assert_eq(Session.versus_name, "Hana", "the name is kept for next time")


func test_the_main_menu_leads_to_versus() -> void:
	var menu: Node = add_managed(MAIN_MENU.instantiate())
	assert_not_null(menu.get_node_or_null("ButtonManager/Versus"))
	menu._on_versus_pressed()
	assert_eq(menu.btn_pressed, menu.MenuItem.VERSUS)


# The arena

func test_each_arena_shows_its_own_player_on_the_left() -> void:
	var arenas := _duelling()
	assert_eq(arenas[0].hud.player_panel.title.text, "Hana")
	assert_eq(arenas[0].hud.opponent_panel.title.text, "Gil")
	assert_eq(arenas[1].hud.player_panel.title.text, "Gil")
	assert_eq(arenas[1].hud.opponent_panel.title.text, "Hana")
	assert_not_null(arenas[0].host)
	assert_null(arenas[0].guest)
	assert_not_null(arenas[1].guest)
	assert_null(arenas[1].host)


func test_both_players_bring_every_spell() -> void:
	var arenas := _duelling()
	for arena in arenas:
		assert_eq(arena.hud.spell_bar.slot_count(), Spellbook.MAX_SLOTS)


func test_nothing_happens_during_the_countdown() -> void:
	host_link.host()
	guest_link.join("127.0.0.1")
	_settle()
	var hosting := _arena(host_link, "Hana", "Gil", true)
	var joining := _arena(guest_link, "Gil", "Hana", false)
	assert_true(hosting.hud.overlay.visible)
	assert_true("begins in 3" in hosting.hud.overlay.body.text)
	assert_true("Waiting for the host" in joining.hud.overlay.body.text)
	assert_false(hosting.hud.overlay.confirm.visible, "there is nothing to press")
	hosting._process(1.2)
	assert_true("begins in 2" in hosting.hud.overlay.body.text)
	assert_false(hosting.player_circle.accepts_input)
	assert_false(joining.player_circle.accepts_input)
	assert_eq(host_link.sent_types(), [], "and nothing to say")


func test_the_duel_begins_on_both_machines_when_the_countdown_ends() -> void:
	host_link.host()
	guest_link.join("127.0.0.1")
	_settle()
	var hosting := _arena(host_link, "Hana", "Gil", true)
	var joining := _arena(guest_link, "Gil", "Hana", false)
	hosting._process(3.1)
	assert_true(hosting.player_circle.accepts_input)
	assert_false(hosting.hud.overlay.visible)
	assert_false(joining.player_circle.accepts_input, "the guest has not heard yet")
	_settle()
	assert_true(joining.player_circle.accepts_input)
	assert_false(joining.hud.overlay.visible)
	assert_eq(host_link.sent_types().slice(0, 2), ["go", "snapshot"])


func test_a_blow_lands_on_both_screens() -> void:
	var arenas := _duelling()
	_cast(arenas[1], &"fire_bolt")
	var blow := SpellLibrary.find(&"fire_bolt").effects[0].amount
	assert_almost_eq(arenas[0].hud.player_panel.health_bar.value, 100.0 - blow)
	assert_almost_eq(arenas[1].hud.opponent_panel.health_bar.value, 100.0 - blow)
	assert_eq(arenas[0].hud.combat_log.lines[-1], "Gil cast Fire Bolt (S): 16 damage.")
	assert_eq(arenas[1].hud.combat_log.lines[-1], "You cast Fire Bolt (S): 16 damage.")

	_cast(arenas[0], &"spark")
	assert_eq(arenas[0].hud.combat_log.lines[-1], "You cast Spark (S): 5 damage.")
	assert_eq(arenas[1].hud.combat_log.lines[-1], "Hana cast Spark (S): 5 damage.")
	assert_almost_eq(arenas[1].hud.player_panel.health_bar.value, 95.0)


func test_a_spell_is_shown_landing_on_both_screens() -> void:
	var arenas := _duelling()
	_cast(arenas[1], &"fire_bolt")
	for arena in arenas:
		var shown: SpellShow = arena.spell_show
		assert_eq(shown.count_of(SpellMark.Kind.STREAK), 1)
		assert_eq(shown.count_of(SpellMark.Kind.BURST), 1)
		assert_eq(shown.marks_of(SpellMark.Kind.GRADE)[0].text, "S")
		assert_eq(shown.marks_of(SpellMark.Kind.NUMBER)[0].text, "16")
	# Each sees it from their own side: the guest cast it, so it leaves
	# the guest's left and arrives on the host's left.
	var there: SpellMark = arenas[1].spell_show.marks_of(SpellMark.Kind.STREAK)[0]
	var here: SpellMark = arenas[0].spell_show.marks_of(SpellMark.Kind.STREAK)[0]
	assert_eq(there.at, arenas[1].opponent_circle.global_position)
	assert_eq(here.at, arenas[0].player_circle.global_position)
	assert_almost_eq(there.size, here.size * arenas[1].spell_show.stand_of(arenas[1].foe).drawn_scale(), 0.001, "and it is the same spell, drawn to the size of the circle it lands on")


func test_a_ward_is_kept_up_on_both_screens() -> void:
	var arenas := _duelling()
	_cast(arenas[0], &"ward")
	_run(arenas, 0.5)
	for arena in arenas:
		arena.spell_show.observe()
	assert_true(arenas[0].me.is_warded())
	assert_true(arenas[1].foe.is_warded())
	assert_gt(arenas[0].spell_show.ward_left(arenas[0].me), 0.8)
	assert_gt(arenas[1].spell_show.ward_left(arenas[1].foe), 0.8)
	assert_eq(arenas[0].spell_show.count_of(SpellMark.Kind.RAISE), 1)
	assert_eq(arenas[1].spell_show.count_of(SpellMark.Kind.RAISE), 1)


func test_each_player_sees_the_others_spell_named() -> void:
	var arenas := _duelling()
	var lightning := SpellLibrary.find(&"lightning")
	arenas[1].hud.spell_bar.choose_spell(lightning)
	arenas[1].player_circle.strike(lightning.strokes[0].rune, lightning.strokes[0].position, clock)
	_settle()
	assert_eq(arenas[0].hud.opponent_spell.text, "Lightning")
	assert_eq(arenas[0].opponent_circle.expected.current_index, 1)
	arenas[1].player_circle.abandon()
	_settle()
	assert_eq(arenas[0].hud.opponent_spell.text, "")


func test_time_passes_on_both_machines() -> void:
	var arenas := _duelling()
	arenas[0].me.chi = 10.0
	_run(arenas, 2.0)
	assert_almost_eq(arenas[0].elapsed_seconds(), 2.0, 0.1)
	assert_almost_eq(arenas[1].elapsed_seconds(), 2.0, 0.4)
	assert_gt(arenas[1].hud.opponent_panel.chi_bar.value, 20.0, "the guest sees the host's chi come back")


func test_both_are_told_when_the_duel_escalates() -> void:
	var arenas := _duelling()
	_run(arenas, Duel.ESCALATION_STARTS + 1.0)
	assert_eq(arenas[0].hud.combat_log.lines[-1], DuelHud.ESCALATION_LINE)
	assert_eq(arenas[1].hud.combat_log.lines[-1], DuelHud.ESCALATION_LINE)
	_run(arenas, 2.0)
	assert_eq(arenas[0].hud.combat_log.lines.count(DuelHud.ESCALATION_LINE), 1, "and only once")


func test_the_verdict_is_shown_on_both_machines() -> void:
	var arenas := _duelling()
	arenas[0].me.health = 4.0
	_cast(arenas[1], &"spark")
	assert_true(arenas[0].is_over)
	assert_true(arenas[1].is_over)
	assert_eq(arenas[0].hud.overlay.heading.text, "Defeat")
	assert_eq(arenas[1].hud.overlay.heading.text, "Victory")
	assert_eq(arenas[0].hud.overlay.subheading.text, "against Gil")
	assert_eq(arenas[1].hud.overlay.subheading.text, "against Hana")
	assert_false(arenas[1].hud.overlay.confirm.visible)
	assert_true(arenas[1].hud.overlay.decline.visible)
	assert_false(arenas[1].player_circle.accepts_input)


func test_a_player_who_leaves_ends_the_duel() -> void:
	var arenas := _duelling()
	guest_link.close()
	assert_true(arenas[0].is_over)
	assert_eq(arenas[0].hud.overlay.subheading.text, "has left the duel")
	assert_true(arenas[0].hud.overlay.decline.visible)
	assert_false(arenas[0].player_circle.accepts_input)


func test_leaving_goes_back_to_the_versus_menu() -> void:
	var arenas := _duelling()
	arenas[1].hud.overlay.decline.pressed.emit()
	assert_eq(arenas[1]._destination, Session.VERSUS_MENU_SCENE)
	assert_false(host_link.is_joined())
	assert_true(arenas[0].is_over, "and the other player is told")


func test_a_whole_duel_is_fought_between_two_arenas() -> void:
	var arenas := _duelling()
	for round_ in 30:
		if arenas[0].is_over:
			break
		_cast(arenas[0], &"fire_bolt")
		_run(arenas, 1.5)
		if arenas[0].is_over:
			break
		_cast(arenas[1], &"spark")
		_run(arenas, 1.5)
	assert_true(arenas[0].is_over)
	assert_true(arenas[1].is_over)
	assert_eq(arenas[0].hud.overlay.heading.text, "Victory")
	assert_eq(arenas[1].hud.overlay.heading.text, "Defeat")
	assert_almost_eq(arenas[1].me.health, 0.0)
	assert_almost_eq(arenas[0].me.health, arenas[1].foe.health, 0.0001)
	assert_eq(arenas[0].host.remote.rejections, 0)
