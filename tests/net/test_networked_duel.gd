extends TestCase
## A duel between two machines, joined by a link that lives in memory.
##
## Everything either side sends is passed through JSON on the way, so
## nothing crosses that a real transport could not carry. And nothing
## arrives while its sender is still in the middle of sending: messages
## wait in a queue until the call that produced them has returned, as they
## would on a network.

const BEAT := 250_000

var host: DuelHost
var guest: DuelGuest
## The host's own view: its player and the guest, as the duel has them.
var hana: Duelist
var gil: Duelist
## The guest's view of the same two.
var gil_there: Duelist
var hana_there: Duelist
var host_circle: SpellCircle
var guest_circle_on_host: SpellCircle
var guest_circle: SpellCircle
var host_circle_on_guest: SpellCircle
var guest_log: Array
var clock: int
var to_guest: int
var to_host: int
## Messages on their way, as [receiver, contents, arrival time].
var in_flight: Array


func before_each() -> void:
	clock = 1_000_000
	to_guest = 0
	to_host = 0
	in_flight = []
	guest_log = []

	hana = Duelist.new("Hana")
	hana.spellbook = Spellbook.complete()
	gil = Duelist.new("Gil")
	gil.spellbook = Spellbook.complete()
	host_circle = add_managed(SpellCircle.new())
	guest_circle_on_host = add_managed(SpellCircle.new())
	host = add_managed(DuelHost.new())
	host.set_process(false)
	host.setup(hana, gil, host_circle, guest_circle_on_host)

	gil_there = Duelist.new("Gil")
	gil_there.spellbook = Spellbook.complete()
	hana_there = Duelist.new("Hana")
	guest_circle = add_managed(SpellCircle.new())
	host_circle_on_guest = add_managed(SpellCircle.new())
	guest = add_managed(DuelGuest.new())
	guest.setup(gil_there, hana_there, guest_circle, host_circle_on_guest)

	host.outgoing.connect(func (contents):
		to_guest += 1
		in_flight.append([guest, DuelProtocol.through_json(contents), clock])
	)
	guest.outgoing.connect(func (contents):
		to_host += 1
		in_flight.append([host, DuelProtocol.through_json(contents), clock + int(contents.get("t", 0))])
	)
	guest.mirror.resolved.connect(func (line, _by_me): guest_log.append(line))

	# Input is not what is under test; strokes are made by calling strike().
	host.begin()
	guest.begin()
	host_circle.accepts_input = false
	guest_circle.accepts_input = false
	_deliver()


## Hands over every message in flight, and any sent in answer to them.
func _deliver() -> void:
	while not in_flight.is_empty():
		var next: Array = in_flight.pop_front()
		next[0].receive(next[1], next[2])


func _strike(circle: SpellCircle, stroke: RuneStroke, time: int) -> void:
	circle.strike(stroke.rune, stroke.position, time)
	_deliver()


func _cast(circle: SpellCircle, id: StringName) -> CastResult:
	var spell := SpellLibrary.find(id)
	circle.prepare(spell)
	_deliver()
	var before := circle.last_result
	for stroke in spell.strokes:
		_strike(circle, stroke, clock + stroke.tick * BEAT)
	clock += 10_000_000
	# The verdict on this cast, or null if it never got as far as one.
	return circle.last_result if circle.last_result != before else null


func _run(seconds: float) -> void:
	for i in roundi(seconds * 60.0):
		host.advance(1.0 / 60.0)
		_deliver()


func test_the_guest_is_told_how_things_stand_at_the_start() -> void:
	assert_gt(to_guest, 0)
	assert_almost_eq(hana_there.health, 100.0)
	assert_almost_eq(gil_there.chi, 100.0)


func test_the_guests_spell_strikes_the_host() -> void:
	_cast(guest_circle, &"fire_bolt")
	var blow := SpellLibrary.find(&"fire_bolt").effects[0].amount
	assert_almost_eq(hana.health, 100.0 - blow, 0.0001, "on the host, where the duel is")
	assert_almost_eq(hana_there.health, 100.0 - blow, 0.0001, "and on the guest, once told")
	assert_almost_eq(gil.health, 100.0)


func test_the_hosts_spell_strikes_the_guest() -> void:
	_cast(host_circle, &"fire_bolt")
	var blow := SpellLibrary.find(&"fire_bolt").effects[0].amount
	assert_almost_eq(gil.health, 100.0 - blow)
	assert_almost_eq(gil_there.health, 100.0 - blow)


func test_each_side_watches_the_others_cast_take_shape() -> void:
	var lightning := SpellLibrary.find(&"lightning")
	guest_circle.prepare(lightning)
	for i in 4:
		_strike(guest_circle, lightning.strokes[i], clock + lightning.strokes[i].tick * BEAT)
	assert_eq(guest_circle_on_host.spell, lightning)
	assert_eq(guest_circle_on_host.expected.current_index, 4)

	var spark := SpellLibrary.find(&"spark")
	host_circle.prepare(spark)
	_strike(host_circle, spark.strokes[0], clock)
	assert_eq(host_circle_on_guest.spell, spark)
	assert_eq(host_circle_on_guest.expected.current_index, 1)


func test_the_guest_pays_for_its_casts_on_both_machines() -> void:
	_cast(guest_circle, &"fire_bolt")
	var cost := SpellLibrary.find(&"fire_bolt").chi_cost
	assert_almost_eq(gil.chi, 100.0 - cost)
	assert_almost_eq(gil_there.chi, 100.0 - cost)


func test_the_guest_reads_the_combat_log_in_the_second_person() -> void:
	_cast(guest_circle, &"spark")
	_cast(host_circle, &"spark")
	assert_eq(guest_log, ["You cast Spark (S): 5 damage.", "Hana cast Spark (S): 5 damage."])


func test_snapshots_keep_the_guest_in_step() -> void:
	gil.chi = 20.0
	var sent_before := to_guest
	_run(2.0)
	assert_gt(to_guest, sent_before + 5, "several snapshots in two seconds")
	# The guest is never further behind than one snapshot's worth.
	assert_almost_eq(gil_there.chi, gil.chi, gil.chi_per_second * DuelHost.SNAPSHOT_SECONDS + 0.01)
	assert_gt(gil_there.chi, 30.0, "chi came back on the host and the guest heard of it")
	assert_almost_eq(guest.mirror.elapsed_seconds, host.duel.elapsed_seconds, 0.3)


func test_a_ward_on_the_host_holds_off_the_guest() -> void:
	_cast(host_circle, &"bulwark")
	assert_true(hana_there.is_warded(), "the guest can see the ward")
	_cast(guest_circle, &"fire_bolt")
	assert_almost_eq(hana.health, 100.0)
	assert_lt(gil.health, 100.0, "and part of the blow came back")
	assert_almost_eq(gil_there.health, gil.health)


func test_the_hosts_flinch_breaks_the_guests_cast() -> void:
	var lightning := SpellLibrary.find(&"lightning")
	guest_circle.prepare(lightning)
	for i in 3:
		_strike(guest_circle, lightning.strokes[i], clock + lightning.strokes[i].tick * BEAT)
	assert_eq(gil.casting, lightning)
	_cast(host_circle, &"flinch")
	assert_null(gil.casting)
	assert_eq(guest_circle_on_host.state, SpellCircle.State.READY, "broken on the host")
	assert_eq(guest_circle.state, SpellCircle.State.READY, "and on the guest, once told")
	assert_eq(guest_circle.expected.current_index, 0)
	assert_almost_eq(hana.health, 100.0)


func test_the_guests_flinch_breaks_the_hosts_cast() -> void:
	var lightning := SpellLibrary.find(&"lightning")
	host_circle.prepare(lightning)
	for i in 3:
		_strike(host_circle, lightning.strokes[i], clock + lightning.strokes[i].tick * BEAT)
	_cast(guest_circle, &"flinch")
	assert_eq(host_circle.state, SpellCircle.State.READY)
	assert_eq(host_circle_on_guest.actual.runes.size(), 0, "the guest sees the cast go")


func test_a_chill_reaches_the_guests_own_circle() -> void:
	_cast(host_circle, &"frost_bolt")
	assert_true(gil_there.is_chilled())
	assert_lt(guest_circle.tuning.rhythm_tolerance, guest.tuning.rhythm_tolerance)
	_run(7.0)
	assert_false(gil_there.is_chilled())
	assert_almost_eq(guest_circle.tuning.rhythm_tolerance, guest.tuning.rhythm_tolerance)


func test_the_guest_cannot_begin_what_it_cannot_afford() -> void:
	gil.chi = 4.0
	host.send_snapshot()
	_deliver()
	var sent_before := to_host
	assert_null(_cast(guest_circle, &"fire_bolt"))
	assert_eq(guest_circle.state, SpellCircle.State.READY)
	assert_eq(to_host, sent_before, "nothing was sent")


func test_the_host_refuses_a_cast_the_guest_should_not_have_begun() -> void:
	# The guest believes it has the chi. The host knows better.
	gil.chi = 4.0
	_cast(guest_circle, &"fire_bolt")
	assert_almost_eq(hana.health, 100.0)
	assert_eq(guest_circle.state, SpellCircle.State.READY)
	assert_almost_eq(gil.chi, 4.0)


func test_the_duel_ends_on_both_machines() -> void:
	var endings := []
	guest.mirror.finished.connect(func (i_won): endings.append(i_won))
	hana.health = 3.0
	_cast(guest_circle, &"spark")
	assert_true(host.duel.is_over())
	assert_false(host.duel.player_won())
	assert_eq(endings, [true])
	assert_true(guest.mirror.is_over)
	assert_true(guest.mirror.i_won)
	assert_true(hana_there.is_defeated())
	assert_false(guest_circle.accepts_input)


func test_the_guest_can_lose() -> void:
	gil.health = 3.0
	_cast(host_circle, &"spark")
	assert_true(host.duel.player_won())
	assert_true(guest.mirror.is_over)
	assert_false(guest.mirror.i_won)


func test_nothing_more_happens_after_the_end() -> void:
	hana.health = 3.0
	_cast(guest_circle, &"spark")
	var sent_before := to_guest
	_cast(guest_circle, &"fire_bolt")
	_run(3.0)
	assert_eq(to_guest, sent_before)
	assert_almost_eq(gil.health, 100.0)


func test_a_whole_duel_is_fought_across_the_link() -> void:
	# Turn and turn about, with time passing between, until one falls.
	for round_ in 30:
		if host.duel.is_over():
			break
		_cast(guest_circle, &"fire_bolt")
		_run(1.5)
		if host.duel.is_over():
			break
		_cast(host_circle, &"spark")
		_run(1.5)
	assert_true(host.duel.is_over())
	assert_true(guest.mirror.is_over)
	assert_eq(guest.mirror.i_won, not host.duel.player_won())
	assert_true(guest.mirror.i_won, "fire bolts against sparks")
	assert_almost_eq(gil_there.health, gil.health, 0.0001)
	assert_almost_eq(hana_there.health, 0.0)
	assert_eq(host.remote.rejections, 0)
