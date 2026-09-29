extends TestCase
## Fighting a duel again, finding a host nearby, and choosing the port.

const MENU := preload("res://magiteknician/menus/versus_menu.tscn")
const ARENA := preload("res://magiteknician/levels/versus_arena.tscn")
const VersusMenu := preload("res://magiteknician/menus/versus_menu.gd")
const BEAT := 100_000
## A port for the tests to call out and listen on, which is not the game's.
const TEST_PORT := 24811

var host_link: FakeLink
var guest_link: FakeLink
var clock: int


func before_each() -> void:
	FakeLink.forget_hosts()
	forget_settings()
	forget_replays()
	_forget_versus()
	host_link = add_managed(FakeLink.new())
	guest_link = add_managed(FakeLink.new())
	clock = 1_000_000


func after_each() -> void:
	FakeLink.forget_hosts()
	forget_settings()
	forget_replays()
	_forget_versus()


func _forget_versus() -> void:
	Session.versus_name = ""
	Session.versus_foe_name = ""
	Session.versus_spells = []
	Session.versus_foe_spells = []
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


func _arena(link: FakeLink, mine: String, theirs: String, hosting: bool) -> Node:
	Session.versus_name = mine
	Session.versus_foe_name = theirs
	Session.versus_is_host = hosting
	var arena: Node = ARENA.instantiate()
	arena.link = link
	add_managed(arena)
	arena.set_process(false)
	return arena


## Two arenas joined to each other, with the duel over and Hana the winner.
func _fought() -> Array:
	host_link.host()
	guest_link.join("127.0.0.1")
	_settle()
	var hosting := _arena(host_link, "Hana", "Gil", true)
	var joining := _arena(guest_link, "Gil", "Hana", false)
	hosting._process(3.1)
	_settle()
	hosting.player_circle.accepts_input = false
	joining.player_circle.accepts_input = false
	hosting.foe.health = 1.0
	var spark := SpellLibrary.find(&"spark")
	hosting.hud.spell_bar.choose_spell(spark)
	for stroke in spark.strokes:
		hosting.player_circle.strike(stroke.rune, stroke.position, clock + stroke.tick * BEAT)
		_settle()
	return [hosting, joining]


# Fighting it again

func test_a_duel_that_is_over_can_be_fought_again() -> void:
	var arenas := _fought()
	for arena in arenas:
		assert_true(arena.is_over)
		assert_true(arena.hud.overlay.confirm.visible)
		assert_eq(arena.hud.overlay.confirm.text, "Rematch")
		assert_true(arena.hud.overlay.decline.visible, "and it can still be left")


func test_asking_is_not_enough() -> void:
	var arenas := _fought()
	arenas[0].hud.overlay.confirm.pressed.emit()
	_settle()
	assert_true(arenas[0].i_want_a_rematch)
	assert_true(arenas[1].they_want_a_rematch)
	assert_true("Waiting for Gil" in arenas[0].hud.overlay.body.text)
	assert_false(arenas[0].hud.overlay.confirm.visible, "there is nothing more to press")
	assert_true("Hana asks to fight again" in arenas[1].hud.overlay.body.text)
	assert_true(arenas[1].hud.overlay.confirm.visible)
	for arena in arenas:
		assert_eq(arena._destination, "", "nobody has gone anywhere")
		assert_true("The duel lasted" in arena.hud.overlay.body.text, "and how the duel went is still told")


func test_when_both_have_asked_both_go_back_to_the_beginning() -> void:
	var arenas := _fought()
	arenas[1].hud.overlay.confirm.pressed.emit()
	_settle()
	arenas[0].hud.overlay.confirm.pressed.emit()
	_settle()
	for arena in arenas:
		assert_eq(arena._destination, Session.VERSUS_ARENA_SCENE)
	assert_ne(host_link.role, NetLink.Role.NONE, "and the two are still joined")
	assert_eq(host_link.other, guest_link)
	assert_eq(Session.versus_foe_name, "Hana", "the last arena made here was the guest's, and it remembers who it fights")


func test_asking_twice_asks_once() -> void:
	var arenas := _fought()
	var before := host_link.sent.size()
	arenas[0].ask_for_a_rematch()
	arenas[0].ask_for_a_rematch()
	assert_eq(host_link.sent.size(), before + 1)
	assert_eq(host_link.sent[-1], DuelProtocol.rematch())


func test_a_duel_that_is_not_over_cannot_be_fought_again() -> void:
	host_link.host()
	guest_link.join("127.0.0.1")
	_settle()
	var hosting := _arena(host_link, "Hana", "Gil", true)
	var joining := _arena(guest_link, "Gil", "Hana", false)
	hosting._process(3.1)
	_settle()
	var before := host_link.sent.size()
	hosting.ask_for_a_rematch()
	assert_eq(host_link.sent.size(), before)
	guest_link.send(DuelProtocol.rematch())
	_settle()
	assert_false(hosting.they_want_a_rematch)
	assert_false(hosting.is_over)
	assert_not_null(joining)


func test_if_they_leave_there_is_nobody_to_fight_again() -> void:
	var arenas := _fought()
	arenas[0].hud.overlay.confirm.pressed.emit()
	_settle()
	arenas[1].leave()
	_settle()
	assert_true("Gil has left" in arenas[0].hud.overlay.body.text)
	assert_false(arenas[0].hud.overlay.confirm.visible)
	assert_false(arenas[0].i_want_a_rematch)
	assert_eq(arenas[0]._destination, "")
	arenas[0].ask_for_a_rematch()
	assert_true(arenas[0].i_want_a_rematch, "asking is allowed, and goes unanswered")


func test_a_rematch_is_a_message_like_any_other() -> void:
	var message: Dictionary = DuelProtocol.through_json(DuelProtocol.rematch())
	assert_eq(DuelProtocol.problems(message), PackedStringArray())
	assert_eq(DuelProtocol.VERSION, 1, "a player who cannot answer it is one who is not asked")


func test_each_duel_of_a_rematch_is_recorded() -> void:
	_fought()
	assert_eq(DuelRecording.all_in(Session.replay_dir).size(), 1, "the host has the duel, and records it")


# The port

func test_the_game_comes_with_its_own_port() -> void:
	assert_eq(Settings.versus_port, NetLink.DEFAULT_PORT)
	var menu := _menu(host_link, "Hana")
	assert_eq(int(menu.port_box.value), NetLink.DEFAULT_PORT)
	assert_eq(menu.port(), NetLink.DEFAULT_PORT)


func test_the_port_can_be_chosen_and_is_kept() -> void:
	var menu := _menu(host_link, "Hana")
	menu.port_box.value = 24700
	assert_eq(Settings.versus_port, 24700)
	Settings.reset()
	assert_eq(Settings.versus_port, NetLink.DEFAULT_PORT)
	Settings.read()
	assert_eq(Settings.versus_port, 24700)


func test_a_port_there_is_none_of_is_the_nearest_there_is() -> void:
	assert_eq(Settings.tidy_port(80), 1024)
	assert_eq(Settings.tidy_port(70_000), 65535)
	assert_eq(Settings.tidy_port(24700), 24700)
	var file := FileAccess.open(Settings.path, FileAccess.WRITE)
	file.store_string('{"version": 1, "versus_port": "the usual"}')
	file.close()
	Settings.read()
	assert_eq(Settings.versus_port, NetLink.DEFAULT_PORT)


func test_a_duel_is_hosted_on_the_port_that_was_chosen() -> void:
	var menu := _menu(host_link, "Hana")
	menu.port_box.value = 24700
	menu._on_host_pressed()
	assert_true("24700" in menu.status.text)
	assert_true(FakeLink.hosts.has("127.0.0.1:24700"))
	assert_false(menu.port_box.editable, "and cannot be changed while it is")


func test_a_host_on_another_port_can_be_joined() -> void:
	var hosting := _menu(host_link, "Hana")
	hosting.port_box.value = 24700
	hosting._on_host_pressed()
	var joining := _menu(guest_link, "Gil")
	joining.address.text = "127.0.0.1:24700"
	joining._on_join_pressed()
	_settle()
	assert_eq(guest_link.other, host_link)
	assert_true("Hana" in joining.status.text)


func test_an_address_can_have_its_port_written_after_it() -> void:
	assert_eq(VersusMenu.where_to_join("192.168.1.20", 24653), {"address": "192.168.1.20", "port": 24653})
	assert_eq(VersusMenu.where_to_join(" 192.168.1.20:24700 ", 24653), {"address": "192.168.1.20", "port": 24700})
	assert_eq(VersusMenu.where_to_join("hanas-machine.local:24700", 24653), {"address": "hanas-machine.local", "port": 24700})
	assert_eq(VersusMenu.where_to_join("hanas-machine", 24700), {"address": "hanas-machine", "port": 24700})
	assert_eq(VersusMenu.where_to_join("fe80::1", 24653), {"address": "fe80::1", "port": 24653}, "an address of the long kind has colons of its own")
	assert_eq(VersusMenu.where_to_join("192.168.1.20:80", 24653)["port"], 1024)
	assert_eq(VersusMenu.where_to_join("192.168.1.20:", 24653), {"address": "192.168.1.20:", "port": 24653})
	assert_eq(VersusMenu.where_to_join("   ", 24653), {})


# Calling out, and hearing

func test_a_host_says_who_and_where() -> void:
	var said := HostBeacon.announcement("  Hana  ", 24700)
	assert_eq(said["name"], "Hana")
	assert_eq(said["port"], 24700)
	assert_eq(said["game"], HostBeacon.GAME)
	assert_eq(said["version"], DuelProtocol.VERSION)
	assert_eq(HostBeacon.read(JSON.stringify(said)), {"name": "Hana", "port": 24700})
	said["id"] = "1234abcd"
	assert_eq(HostBeacon.read(JSON.stringify(said)), {"name": "Hana", "port": 24700, "id": "1234abcd"})


func test_what_is_not_a_call_from_this_game_is_not_heard() -> void:
	var good := HostBeacon.announcement("Hana", 24700)
	assert_false(HostBeacon.read(JSON.stringify(good)).is_empty())
	for spoiled in [
		"", "nonsense", "[1, 2]", "{}",
		JSON.stringify({"game": "chess", "version": 1, "name": "Hana", "port": 24700}),
		JSON.stringify({"game": HostBeacon.GAME, "version": DuelProtocol.VERSION + 1, "name": "Hana", "port": 24700}),
		JSON.stringify({"game": HostBeacon.GAME, "version": 1, "name": 7, "port": 24700}),
		JSON.stringify({"game": HostBeacon.GAME, "version": 1, "name": "Hana", "port": 0}),
		JSON.stringify({"game": HostBeacon.GAME, "version": 1, "name": "Hana", "port": 99_999}),
		JSON.stringify({"game": HostBeacon.GAME, "version": 1, "name": "Hana", "port": "24700"}),
		JSON.stringify({"game": HostBeacon.GAME, "version": 1, "name": "x".repeat(600), "port": 24700}),
	]:
		assert_true(HostBeacon.read(spoiled).is_empty(), spoiled.left(60))


func test_a_name_that_is_called_out_is_made_fit_to_show() -> void:
	var said := HostBeacon.read(JSON.stringify({"game": HostBeacon.GAME, "version": 1, "name": "A very long name indeed\nand more", "port": 24700}))
	assert_lt(said["name"].length(), DuelProtocol.MAX_NAME_LENGTH + 1)
	assert_false("\n" in said["name"])


func _finder() -> HostFinder:
	var finder: HostFinder = add_managed(HostFinder.new())
	finder.set_process(false)
	return finder


func test_a_host_that_is_heard_is_listed() -> void:
	var finder := _finder()
	var changes := [0]
	finder.changed.connect(func (): changes[0] += 1)
	finder.hear(JSON.stringify(HostBeacon.announcement("Hana", 24653)), "192.168.1.20")
	assert_eq(finder.hosts.size(), 1)
	assert_eq(finder.hosts[0]["name"], "Hana")
	assert_eq(finder.hosts[0]["address"], "192.168.1.20")
	assert_eq(finder.hosts[0]["port"], 24653)
	assert_eq(changes[0], 1)
	assert_eq(HostFinder.label_of(finder.hosts[0]), "Hana, at 192.168.1.20")


func test_a_host_that_is_heard_again_is_listed_once() -> void:
	var finder := _finder()
	var changes := [0]
	finder.changed.connect(func (): changes[0] += 1)
	for i in 5:
		finder.hear(JSON.stringify(HostBeacon.announcement("Hana", 24653)), "192.168.1.20")
	assert_eq(finder.hosts.size(), 1)
	assert_eq(changes[0], 1, "and the list has changed once")


func test_two_hosts_are_two_hosts() -> void:
	var finder := _finder()
	finder.hear(JSON.stringify(HostBeacon.announcement("Hana", 24653)), "192.168.1.20")
	finder.hear(JSON.stringify(HostBeacon.announcement("Ilse", 24653)), "192.168.1.31")
	finder.hear(JSON.stringify(HostBeacon.announcement("Hana", 24700)), "192.168.1.20")
	assert_eq(finder.hosts.size(), 3, "two machines, and two duels on the one")
	assert_eq(HostFinder.label_of(finder.hosts[2]), "Hana, at 192.168.1.20, port 24700")


func test_a_host_on_two_networks_is_one_host() -> void:
	var finder := _finder()
	var said := HostBeacon.announcement("Hana", 24653)
	said["id"] = "1234abcd"
	finder.hear(JSON.stringify(said), "192.168.56.1")
	finder.hear(JSON.stringify(said), "192.168.1.20")
	assert_eq(finder.hosts.size(), 1)
	assert_eq(finder.hosts[0]["address"], "192.168.56.1", "at the address it was first heard from")
	var other := HostBeacon.announcement("Hana", 24653)
	other["id"] = "99990000"
	finder.hear(JSON.stringify(other), "192.168.1.31")
	assert_eq(finder.hosts.size(), 2, "and another of the same name is another")
	finder.age(HostFinder.FORGET_SECONDS - 0.5)
	finder.hear(JSON.stringify(said), "192.168.1.20")
	finder.age(1.0)
	assert_eq(finder.hosts.size(), 1, "heard from on either network, it has been heard from")


func test_a_call_goes_out_on_every_network_the_machine_is_on() -> void:
	var networks := HostBeacon.networks()
	assert_eq(networks[0], "", "the one the machine would choose")
	for network in networks.slice(1):
		assert_true(network.is_valid_ip_address(), network)
		assert_false(network.begins_with("127."), "and not to itself")
		assert_false(":" in network)
	var beacon: HostBeacon = add_managed(HostBeacon.new())
	beacon.set_process(false)
	assert_eq(beacon.call_out("Hana", 24653), OK)
	assert_true(beacon.is_calling)
	beacon.stop()


func test_a_host_that_goes_quiet_is_forgotten() -> void:
	var finder := _finder()
	finder.hear(JSON.stringify(HostBeacon.announcement("Hana", 24653)), "192.168.1.20")
	finder.age(HostFinder.FORGET_SECONDS - 0.5)
	assert_eq(finder.hosts.size(), 1)
	finder.hear(JSON.stringify(HostBeacon.announcement("Hana", 24653)), "192.168.1.20")
	finder.age(HostFinder.FORGET_SECONDS - 0.5)
	assert_eq(finder.hosts.size(), 1, "it was heard from in between")
	finder.age(1.0)
	assert_eq(finder.hosts.size(), 0)
	assert_gt(HostFinder.FORGET_SECONDS, HostBeacon.EVERY_SECONDS * 3.0, "a call or two can be lost on the way")


func test_a_host_that_changes_its_name_is_the_same_host() -> void:
	var finder := _finder()
	finder.hear(JSON.stringify(HostBeacon.announcement("Hana", 24653)), "192.168.1.20")
	finder.hear(JSON.stringify(HostBeacon.announcement("Hanako", 24653)), "192.168.1.20")
	assert_eq(finder.hosts.size(), 1)
	assert_eq(finder.hosts[0]["name"], "Hanako")


func test_the_list_is_not_let_grow_without_end() -> void:
	var finder := _finder()
	for i in HostFinder.MOST + 5:
		finder.hear(JSON.stringify(HostBeacon.announcement("Host %d" % [i], 24653)), "192.168.1.%d" % [i + 1])
	assert_eq(finder.hosts.size(), HostFinder.MOST)


func test_nonsense_is_not_listed() -> void:
	var finder := _finder()
	finder.hear("nonsense", "192.168.1.20")
	finder.hear(JSON.stringify(HostBeacon.announcement("Hana", 24653)), "")
	assert_eq(finder.hosts.size(), 0)


func test_a_call_is_heard_across_a_real_socket() -> void:
	var finder: HostFinder = add_managed(HostFinder.new())
	var beacon: HostBeacon = add_managed(HostBeacon.new())
	assert_eq(finder.listen(TEST_PORT, "127.0.0.1"), OK)
	beacon.address = "127.0.0.1"
	beacon.port = TEST_PORT
	assert_eq(beacon.call_out("Hana", 24700), OK)
	assert_true(beacon.is_calling)
	var patience := Time.get_ticks_msec() + 3000
	while finder.hosts.is_empty() and Time.get_ticks_msec() < patience:
		await get_tree().process_frame
	assert_eq(finder.hosts.size(), 1)
	if not finder.hosts.is_empty():
		assert_eq(finder.hosts[0]["name"], "Hana")
		assert_eq(finder.hosts[0]["address"], "127.0.0.1")
		assert_eq(finder.hosts[0]["port"], 24700)
	beacon.stop()
	finder.stop()
	assert_false(beacon.is_calling)
	assert_false(finder.is_listening)
	assert_eq(finder.hosts.size(), 0, "one that has stopped listening has heard nobody")


func test_a_port_can_be_listened_on_again_once_it_is_let_go() -> void:
	var first: HostFinder = add_managed(HostFinder.new())
	assert_eq(first.listen(TEST_PORT, "127.0.0.1"), OK)
	first.stop()
	var second: HostFinder = add_managed(HostFinder.new())
	assert_eq(second.listen(TEST_PORT, "127.0.0.1"), OK)
	second.stop()


# In the menu

func test_the_menu_lists_the_hosts_that_are_heard() -> void:
	var menu := _menu(guest_link, "Gil")
	assert_true(menu.nobody_nearby.visible)
	assert_eq(menu.nearby.get_child_count(), 0)
	menu.finder.hear(JSON.stringify(HostBeacon.announcement("Hana", 24653)), "127.0.0.1")
	assert_false(menu.nobody_nearby.visible)
	assert_eq(menu.nearby.get_child_count(), 1)
	assert_eq((menu.nearby.get_child(0) as Button).text, "Hana, at 127.0.0.1")
	menu.finder.age(HostFinder.FORGET_SECONDS + 1.0)
	await get_tree().process_frame
	assert_eq(menu.nearby.get_child_count(), 0)
	assert_true(menu.nobody_nearby.visible)


func test_pressing_a_host_joins_it() -> void:
	var hosting := _menu(host_link, "Hana")
	hosting.port_box.value = 24700
	hosting._on_host_pressed()
	var joining := _menu(guest_link, "Gil")
	joining.finder.hear(JSON.stringify(HostBeacon.announcement("Hana", 24700)), "127.0.0.1")
	(joining.nearby.get_child(0) as Button).pressed.emit()
	_settle()
	assert_eq(guest_link.other, host_link)
	assert_eq(joining.address.text, "127.0.0.1")
	assert_true("Joined Hana" in joining.status.text)
	assert_true((joining.nearby.get_child(0) as Button).disabled, "one host at a time")


func test_a_host_calls_out_and_stops_when_somebody_has_come() -> void:
	var hosting := _menu(host_link, "Hana")
	assert_false(hosting.beacon.is_calling)
	hosting._on_host_pressed()
	assert_true(hosting.beacon.is_calling)
	assert_false(hosting.finder.is_listening, "a host has nobody to listen for")
	var joining := _menu(guest_link, "Gil")
	joining._on_join_pressed()
	_settle()
	assert_false(hosting.beacon.is_calling, "there is room for one, and they have come")
	guest_link.close()
	_settle()
	assert_true(hosting.beacon.is_calling, "and calls out again when they have gone")


func test_leaving_the_menu_stops_the_calling_and_the_listening() -> void:
	var hosting := _menu(host_link, "Hana")
	hosting._on_host_pressed()
	hosting._on_back_pressed()
	assert_false(hosting.beacon.is_calling)
	assert_false(hosting.finder.is_listening)
