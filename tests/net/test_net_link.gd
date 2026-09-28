extends TestCase
## NetLink: two machines joined over ENet. Here both are in this one
## process, each under a branch of the tree with a multiplayer API of its
## own, talking through the loopback address.

const ADDRESS := "127.0.0.1"
const LINK_NAME := "Link"

## Each test takes the next port, so one that is slow to let go of its
## socket cannot trip up the test after it.
static var next_port: int = 24700

var port: int
var host_link: NetLink
var guest_link: NetLink
var host_got: Array
var guest_got: Array
var events: Array


func before_each() -> void:
	port = next_port
	next_port += 1
	host_got = []
	guest_got = []
	events = []
	host_link = _link("HostSide")
	guest_link = _link("GuestSide")
	guest_link.join_timeout_seconds = 1.0
	host_link.received.connect(func (contents): host_got.append(contents))
	guest_link.received.connect(func (contents): guest_got.append(contents))
	host_link.peer_joined.connect(func (): events.append("host: joined"))
	host_link.peer_left.connect(func (): events.append("host: left"))
	guest_link.joined.connect(func (): events.append("guest: joined"))
	guest_link.join_failed.connect(func (): events.append("guest: failed"))
	guest_link.peer_left.connect(func (): events.append("guest: left"))
	host_link.refused.connect(func (reason): events.append("host refused: %s" % [reason]))


func after_each() -> void:
	host_link.close()
	guest_link.close()


## A link under a branch of its own, with a multiplayer API of its own.
func _link(side_name: String) -> NetLink:
	var side := Node.new()
	side.name = side_name
	add_managed(side)
	get_tree().set_multiplayer(SceneMultiplayer.new(), side.get_path())
	var link := NetLink.new()
	link.name = LINK_NAME
	side.add_child(link)
	return link


## Waits until `done` says so, or until `seconds` have gone by.
func _wait_until(done: Callable, seconds: float = 3.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not done.call():
		if Time.get_ticks_msec() > deadline:
			return false
		await get_tree().process_frame
	return true


func _join() -> bool:
	if host_link.host(port) != OK or guest_link.join(ADDRESS, port) != OK:
		return false
	return await _wait_until(func (): return host_link.is_joined() and guest_link.is_joined())


func test_a_guest_joins_a_host() -> void:
	assert_eq(host_link.host(port), OK)
	assert_eq(host_link.role, NetLink.Role.HOST)
	assert_false(host_link.is_joined(), "nobody has come yet")
	assert_eq(guest_link.join(ADDRESS, port), OK)
	assert_eq(guest_link.role, NetLink.Role.GUEST)
	assert_true(await _wait_until(func (): return host_link.is_joined() and guest_link.is_joined()))
	assert_true("host: joined" in events)
	assert_true("guest: joined" in events)


func test_messages_cross_in_both_directions() -> void:
	assert_true(await _join())
	assert_true(guest_link.send(DuelProtocol.begin(SpellLibrary.find(&"spark"))))
	assert_true(host_link.send(DuelProtocol.finished(true)))
	assert_true(await _wait_until(func (): return host_got.size() == 1 and guest_got.size() == 1))
	assert_eq(host_got[0]["type"], "begin")
	assert_eq(host_got[0]["spell"], "spark")
	assert_eq(guest_got[0]["type"], "finished")
	assert_eq(guest_got[0]["host_won"], true)
	assert_eq(DuelProtocol.problems(host_got[0]), PackedStringArray())


func test_messages_arrive_in_the_order_they_were_sent() -> void:
	assert_true(await _join())
	for i in 40:
		guest_link.send(DuelProtocol.stroke(Rune.Type.FLOW, Vector2(i, -i), i * 1000))
	assert_true(await _wait_until(func (): return host_got.size() == 40))
	for i in 40:
		assert_eq(int(host_got[i]["t"]), i * 1000)


func test_a_whole_cast_crosses_the_link() -> void:
	assert_true(await _join())
	var here: SpellCircle = add_managed(SpellCircle.new())
	here.accepts_input = false
	var there: SpellCircle = add_managed(SpellCircle.new())
	there.accepts_input = false
	there.rearm_after_cast = false
	var sender: StrokeSender = add_managed(StrokeSender.new())
	sender.circle = here
	sender.message.connect(guest_link.send)
	var remote: RemoteCaster = add_managed(RemoteCaster.new())
	remote.circle = there
	remote.begin()
	host_link.received.connect(remote.receive)

	var fire_bolt := SpellLibrary.find(&"fire_bolt")
	here.prepare(fire_bolt)
	var start := Time.get_ticks_usec()
	var nudges := [0, 20_000, -15_000, 30_000, 0]
	for i in fire_bolt.strokes.size():
		var stroke := fire_bolt.strokes[i]
		here.strike(stroke.rune, stroke.position, start + stroke.tick * 60_000 + nudges[i])

	assert_true(await _wait_until(func (): return there.last_result != null))
	assert_almost_eq(there.last_result.quality, here.last_result.quality, 0.0001)
	assert_eq(there.last_result.judgements, here.last_result.judgements)
	assert_eq(remote.rejections, 0)


func test_there_is_nobody_to_send_to_before_anyone_joins() -> void:
	assert_false(host_link.send(DuelProtocol.abandon()), "not hosting")
	host_link.host(port)
	assert_false(host_link.send(DuelProtocol.abandon()), "hosting, but alone")


func test_a_guest_learns_that_nobody_is_there() -> void:
	# Nothing is listening on this port.
	assert_eq(guest_link.join(ADDRESS, port), OK)
	assert_true(await _wait_until(func (): return "guest: failed" in events))
	assert_eq(guest_link.role, NetLink.Role.NONE)
	assert_false(guest_link.is_joined())


func test_each_side_learns_when_the_other_leaves() -> void:
	assert_true(await _join())
	guest_link.close()
	assert_true(await _wait_until(func (): return "host: left" in events))
	assert_false(host_link.is_joined())

	# And the other way about, on a fresh pair.
	var first_port := port
	port = next_port
	next_port += 1
	host_link.close()
	events.clear()
	assert_ne(port, first_port)
	assert_true(await _join())
	host_link.close()
	assert_true(await _wait_until(func (): return "guest: left" in events))
	assert_false(guest_link.is_joined())


func test_a_host_takes_one_guest() -> void:
	assert_true(await _join())
	var third := _link("ThirdSide")
	third.join_timeout_seconds = 1.0
	var third_events := []
	third.joined.connect(func (): third_events.append("joined"))
	third.join_failed.connect(func (): third_events.append("failed"))
	third.join(ADDRESS, port)
	await _wait_until(func (): return not third_events.is_empty())
	assert_eq(third_events, ["failed"])
	assert_true(host_link.is_joined(), "the first guest is still there")
	third.close()


func test_what_is_not_a_message_is_thrown_away() -> void:
	host_link.accept("{ not json")
	host_link.accept("[1, 2, 3]")
	host_link.accept("\"begin\"")
	host_link.accept("{\"type\": \"%s\"}" % ["x".repeat(NetLink.MAX_MESSAGE_BYTES)])
	assert_eq(host_got, [])
	assert_eq(events, [
		"host refused: It was not JSON.",
		"host refused: It was not a message.",
		"host refused: It was not a message.",
		"host refused: It was too long.",
	])


func test_a_message_too_long_is_not_sent() -> void:
	allow_errors = true
	assert_true(await _join())
	assert_false(guest_link.send({"type": "begin", "spell": "x".repeat(NetLink.MAX_MESSAGE_BYTES)}))
	await get_tree().create_timer(0.2).timeout
	assert_eq(host_got, [])


func test_closing_a_link_that_was_never_opened_does_no_harm() -> void:
	host_link.close()
	host_link.close()
	assert_eq(host_link.role, NetLink.Role.NONE)
