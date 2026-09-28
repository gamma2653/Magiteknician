extends TestCase
## StrokeSender and RemoteCaster: a cast on one circle, shown on another.

const BEAT := 300_000
const START := 5_000_000

## The circle the strokes are made on, and the one they are sent to.
var here: SpellCircle
var there: SpellCircle
var sender: StrokeSender
var remote: RemoteCaster
var sent: Array
var results: Array
var rejections: Array
var lost: Array


func before_each() -> void:
	here = add_managed(SpellCircle.new())
	here.accepts_input = false
	there = add_managed(SpellCircle.new())
	there.accepts_input = false
	there.rearm_after_cast = false
	sender = add_managed(StrokeSender.new())
	sender.circle = here
	remote = add_managed(RemoteCaster.new())
	remote.circle = there
	remote.begin()

	sent = []
	results = []
	rejections = []
	lost = []
	# Through JSON, as over a network, and arriving a moment late.
	sender.message.connect(func (contents):
		sent.append(contents)
		remote.receive(DuelProtocol.through_json(contents), START + 80_000 + int(contents.get("t", 0)))
	)
	there.cast_finished.connect(func (_spell, result): results.append(result))
	remote.rejected.connect(func (_contents, reasons): rejections.append(reasons))
	remote.cast_lost.connect(func (spell, refused): lost.append([spell.id, refused]))


func _cast_here(id: StringName, nudges_in_ticks: Array = [], offset: Vector2 = Vector2.ZERO) -> CastResult:
	var spell := SpellLibrary.find(id)
	here.prepare(spell)
	for i in spell.strokes.size():
		var stroke := spell.strokes[i]
		var nudge: float = nudges_in_ticks[i] if i < nudges_in_ticks.size() else 0.0
		here.strike(stroke.rune, stroke.position + offset, START + int((stroke.tick + nudge) * BEAT))
	return here.last_result


func test_a_cast_is_sent_as_a_beginning_and_its_strokes() -> void:
	_cast_here(&"spark")
	var types := sent.map(func (contents): return contents[DuelProtocol.TYPE])
	assert_eq(types, ["begin", "stroke", "stroke", "stroke"])
	assert_eq(sent[0]["spell"], "spark")
	assert_eq(sent[1]["t"], 0, "strokes are timed from the first")
	assert_eq(sent[2]["t"], BEAT)
	assert_eq(sent[3]["t"], 2 * BEAT)


func test_the_cast_takes_shape_on_the_other_circle() -> void:
	var fire_bolt := SpellLibrary.find(&"fire_bolt")
	here.prepare(fire_bolt)
	for i in 3:
		here.strike(fire_bolt.strokes[i].rune, fire_bolt.strokes[i].position, START + fire_bolt.strokes[i].tick * BEAT)
	assert_eq(there.spell, fire_bolt)
	assert_eq(there.state, SpellCircle.State.CASTING)
	assert_eq(there.expected.current_index, 3)
	assert_eq(there.actual.runes.size(), 3)
	assert_eq(remote.spell, fire_bolt)


func test_the_other_side_reaches_the_same_verdict() -> void:
	var mine := _cast_here(&"fire_bolt", [0.0, 0.08, -0.05, 0.12, 0.0], Vector2(9, -6))
	assert_eq(results.size(), 1)
	var theirs: CastResult = results[0]
	assert_almost_eq(theirs.quality, mine.quality, 0.0001)
	assert_almost_eq(theirs.rhythm_score, mine.rhythm_score, 0.0001)
	assert_almost_eq(theirs.aim_score, mine.aim_score, 0.0001)
	assert_eq(theirs.grade, mine.grade)
	assert_eq(theirs.judgements, mine.judgements)
	assert_null(remote.spell, "the cast is over")


func test_delay_on_the_way_does_not_change_the_verdict() -> void:
	# Every message arrives late, and by a different amount. The strokes
	# are judged on when they were made, which the messages carry.
	sender.message.disconnect(sender.message.get_connections()[0]["callable"])
	var delays := [40_000, 900_000, 5_000, 400_000, 120_000, 700_000]
	var arrival := START
	sender.message.connect(func (contents):
		arrival += delays[sent.size() % delays.size()]
		sent.append(contents)
		remote.receive(DuelProtocol.through_json(contents), arrival + int(contents.get("t", 0)))
	)
	var mine := _cast_here(&"fire_bolt", [0.0, 0.08, -0.05, 0.12, 0.0])
	assert_eq(results.size(), 1)
	assert_almost_eq(results[0].quality, mine.quality, 0.0001)
	assert_almost_eq(results[0].usec_per_tick, mine.usec_per_tick, 0.01)
	assert_eq(rejections, [])


func test_strays_are_sent_and_counted() -> void:
	var spark := SpellLibrary.find(&"spark")
	here.prepare(spark)
	here.strike(spark.strokes[0].rune, spark.strokes[0].position, START)
	here.strike(Rune.Type.PERSISTENCE, Vector2(150, 150), START + 100_000)
	here.strike(spark.strokes[1].rune, spark.strokes[1].position, START + BEAT)
	here.strike(spark.strokes[2].rune, spark.strokes[2].position, START + 2 * BEAT)
	assert_eq(here.last_result.strays, 1)
	assert_eq(results[0].strays, 1)
	assert_almost_eq(results[0].quality, here.last_result.quality, 0.0001)


func test_giving_up_is_sent() -> void:
	var spark := SpellLibrary.find(&"spark")
	here.prepare(spark)
	here.strike(spark.strokes[0].rune, spark.strokes[0].position, START)
	here.abandon()
	assert_eq(sent[-1][DuelProtocol.TYPE], "abandon")
	assert_eq(there.state, SpellCircle.State.READY)
	assert_eq(there.actual.runes.size(), 0)
	assert_null(remote.spell)
	assert_eq(results.size(), 0)


func test_one_cast_follows_another() -> void:
	_cast_here(&"spark")
	_cast_here(&"fire_bolt")
	assert_eq(results.size(), 2)
	assert_eq(results[1].stroke_count, 5)


func test_nothing_is_acted_on_before_the_duel_begins() -> void:
	remote.halt()
	_cast_here(&"spark")
	assert_eq(results.size(), 0)
	assert_eq(there.state, SpellCircle.State.EMPTY)
	assert_gt(rejections.size(), 0)


func test_a_spell_the_caster_does_not_know_is_refused() -> void:
	remote.me = Duelist.new("Gil")
	remote.me.spellbook = Spellbook.of([&"spark"])
	_cast_here(&"lightning")
	assert_eq(results.size(), 0)
	assert_eq(there.state, SpellCircle.State.EMPTY)
	_cast_here(&"spark")
	assert_eq(results.size(), 1)


func test_a_stroke_with_no_cast_is_refused() -> void:
	remote.receive(DuelProtocol.stroke(Rune.Type.FLOW, Vector2.ZERO, 0), START)
	assert_eq(rejections.size(), 1)
	assert_eq(remote.rejections, 1)


func test_messages_meant_for_a_guest_are_refused() -> void:
	remote.receive(DuelProtocol.finished(true), START)
	remote.receive(DuelProtocol.snapshot(Duelist.new(), Duelist.new(), 0.0), START)
	assert_eq(rejections.size(), 2)


func test_strokes_cannot_go_back_in_time() -> void:
	var spark := SpellLibrary.find(&"spark")
	remote.receive(DuelProtocol.begin(spark), START)
	remote.receive(DuelProtocol.stroke(spark.strokes[0].rune, spark.strokes[0].position, 0), START)
	remote.receive(DuelProtocol.stroke(spark.strokes[1].rune, spark.strokes[1].position, 300_000), START + 300_000)
	remote.receive(DuelProtocol.stroke(spark.strokes[2].rune, spark.strokes[2].position, 200_000), START + 600_000)
	assert_eq(rejections.size(), 1)
	assert_eq(results.size(), 0)
	assert_eq(lost, [[&"spark", false]], "and the cast is lost, since it cannot be finished")


func test_a_cast_cannot_claim_to_have_taken_longer_than_it_did() -> void:
	# A slow, steady cast is easy to fake: claim ten seconds between
	# strokes and send them all at once.
	var spark := SpellLibrary.find(&"spark")
	remote.receive(DuelProtocol.begin(spark), START)
	remote.receive(DuelProtocol.stroke(spark.strokes[0].rune, spark.strokes[0].position, 0), START + 1_000)
	remote.receive(DuelProtocol.stroke(spark.strokes[1].rune, spark.strokes[1].position, 10_000_000), START + 2_000)
	assert_eq(rejections.size(), 1)
	assert_eq(lost, [[&"spark", false]])


func test_strokes_faster_than_a_hand_are_refused() -> void:
	var spark := SpellLibrary.find(&"spark")
	remote.receive(DuelProtocol.begin(spark), START)
	remote.receive(DuelProtocol.stroke(spark.strokes[0].rune, spark.strokes[0].position, 0), START)
	remote.receive(DuelProtocol.stroke(spark.strokes[1].rune, spark.strokes[1].position, 2_000), START + 2_000)
	assert_eq(rejections.size(), 1)
	assert_eq(results.size(), 0)


func test_a_stroke_that_claims_to_be_on_target_is_checked() -> void:
	# The sender says where the stroke landed; whether that is on the rune
	# is worked out here.
	var spark := SpellLibrary.find(&"spark")
	remote.receive(DuelProtocol.begin(spark), START)
	remote.receive(DuelProtocol.stroke(spark.strokes[0].rune, spark.strokes[0].position, 0), START)
	remote.receive(DuelProtocol.stroke(spark.strokes[1].rune, spark.strokes[1].position + Vector2(200, 0), BEAT), START + BEAT)
	assert_eq(there.strays, 1)
	assert_eq(there.expected.current_index, 1)


func test_a_cast_refused_for_want_of_chi_is_reported() -> void:
	var poor := Duelist.new("Gil")
	poor.chi = 2.0
	there.gate = poor.can_afford
	_cast_here(&"fire_bolt")
	assert_eq(lost, [[&"fire_bolt", true]])
	assert_eq(results.size(), 0)
	assert_null(remote.spell)


func test_an_interruption_is_reported() -> void:
	var fire_bolt := SpellLibrary.find(&"fire_bolt")
	here.prepare(fire_bolt)
	here.strike(fire_bolt.strokes[0].rune, fire_bolt.strokes[0].position, START)
	assert_true(remote.interrupt())
	assert_eq(lost, [[&"fire_bolt", false]])
	assert_eq(there.state, SpellCircle.State.READY)
	assert_false(remote.interrupt(), "there is nothing left to break")


func test_a_sender_can_be_moved_to_another_circle() -> void:
	var other: SpellCircle = add_managed(SpellCircle.new())
	other.accepts_input = false
	sender.circle = other
	_cast_here(&"spark")
	assert_eq(sent.size(), 0, "the first circle is no longer listened to")
