extends TestCase
## NpcCaster: an NPC casting on a spell circle over time.

var npc: NpcCaster
var circle: SpellCircle
var results: Array
var chosen: Array


func before_each() -> void:
	circle = SpellCircle.new()
	circle.accepts_input = false
	circle.rearm_after_cast = false
	add_managed(circle)

	npc = NpcCaster.new()
	add_managed(npc)
	# Time is fed by hand so the test does not depend on the frame rate.
	npc.set_process(false)
	npc.circle = circle
	npc.me = Duelist.new("Npc")
	npc.foe = Duelist.new("Player")
	npc.me.spellbook = Spellbook.of([&"fire_bolt"])
	npc.rng.seed = 11
	npc.profile = CasterProfile.make(300_000, 0.05, 0.3, 0.0)
	npc.profile.tempo_spread = 0.0
	npc.profile.think_seconds_min = 1.0
	npc.profile.think_seconds_max = 1.0

	results = []
	chosen = []
	circle.cast_finished.connect(func (_spell, result): results.append(result))
	npc.spell_chosen.connect(func (spell): chosen.append(spell.id))


## Lets `seconds` pass in steps of a sixtieth of a second.
func _run(seconds: float) -> void:
	for i in roundi(seconds * 60.0):
		npc.advance(1.0 / 60.0)


func test_it_does_nothing_until_it_is_told_to_begin() -> void:
	_run(5.0)
	assert_eq(npc.state, NpcCaster.State.IDLE)
	assert_eq(chosen, [])


func test_it_thinks_before_it_casts() -> void:
	npc.begin()
	_run(0.9)
	assert_eq(npc.state, NpcCaster.State.THINKING)
	assert_eq(chosen, [])
	_run(0.2)
	assert_eq(npc.state, NpcCaster.State.CASTING)
	assert_eq(chosen, [&"fire_bolt"])
	assert_eq(circle.spell.id, &"fire_bolt")


func test_its_strokes_arrive_one_at_a_time() -> void:
	npc.begin()
	_run(1.05)
	assert_eq(circle.actual.runes.size(), 1, "the first stroke lands as the cast begins")
	# Fire Bolt's strokes are on ticks 0 1 3 4 6, at 0.3 s a tick.
	_run(0.3)
	assert_eq(circle.actual.runes.size(), 2)
	_run(0.3)
	assert_eq(circle.actual.runes.size(), 2, "a tick of rest")
	_run(0.3)
	assert_eq(circle.actual.runes.size(), 3)
	assert_eq(results.size(), 0)


func test_it_finishes_the_cast_and_is_judged() -> void:
	npc.begin()
	_run(1.0 + 6 * 0.3 + 0.2)
	assert_eq(results.size(), 1)
	var result: CastResult = results[0]
	assert_eq(result.stroke_count, 5)
	assert_false(result.fizzled)
	assert_almost_eq(result.usec_per_tick, 300_000.0, 20_000.0)


func test_the_verdict_is_the_one_its_plan_foresaw() -> void:
	npc.begin()
	_run(1.05)
	var foreseen := npc.plan.foreseen_result()
	_run(6 * 0.3 + 0.2)
	assert_almost_eq(results[0].quality, foreseen.quality, 0.0001)
	assert_eq(results[0].grade, foreseen.grade)


func test_frame_rate_does_not_change_the_verdict() -> void:
	npc.begin()
	_run(3.2)
	var smooth: CastResult = results[0]

	# The same seed again, in lurching steps a fifth of a second long.
	before_each()
	npc.begin()
	for i in 16:
		npc.advance(0.2)
	assert_eq(results.size(), 1)
	assert_almost_eq(results[0].quality, smooth.quality, 0.0001)


func test_it_keeps_casting() -> void:
	npc.begin()
	_run(10.0)
	assert_gt(results.size(), 2)
	assert_eq(chosen.size(), results.size() + (1 if npc.state == NpcCaster.State.CASTING else 0))


func test_strays_are_made_and_counted() -> void:
	npc.profile.stray_chance = 1.0
	npc.begin()
	_run(3.2)
	assert_eq(results[0].strays, 4, "one before every stroke but the first")


func test_with_no_chi_it_waits() -> void:
	npc.me.chi = 0.0
	npc.me.chi_per_second = 0.0
	npc.begin()
	_run(5.0)
	assert_eq(chosen, [])
	assert_eq(npc.state, NpcCaster.State.THINKING)
	npc.me.chi = 100.0
	_run(1.1)
	assert_eq(chosen, [&"fire_bolt"])


func test_an_interrupted_cast_is_lost() -> void:
	npc.begin()
	_run(1.5)
	assert_eq(npc.state, NpcCaster.State.CASTING)
	assert_true(npc.interrupt())
	assert_eq(npc.state, NpcCaster.State.THINKING)
	assert_eq(circle.actual.runes.size(), 0)
	_run(0.9)
	assert_eq(results.size(), 0, "it has to think again before starting over")
	_run(3.5)
	assert_eq(results.size(), 1)


func test_there_is_nothing_to_interrupt_while_it_thinks() -> void:
	npc.begin()
	_run(0.5)
	assert_false(npc.interrupt())


func test_halting_stops_it_for_good() -> void:
	npc.begin()
	_run(1.5)
	npc.halt()
	_run(10.0)
	assert_eq(npc.state, NpcCaster.State.IDLE)
	assert_eq(results.size(), 0)
	assert_eq(circle.state, SpellCircle.State.READY)


func test_it_stops_when_the_duel_is_decided() -> void:
	npc.foe.take_damage(1000.0)
	npc.begin()
	_run(3.0)
	assert_eq(npc.state, NpcCaster.State.IDLE)
	assert_eq(chosen, [])


func test_it_answers_what_it_sees() -> void:
	npc.me.spellbook = Spellbook.of([&"spark", &"ward"])
	npc.profile.caution = 1.0
	npc.foe_spell = SpellLibrary.find(&"lightning")
	var wards := 0
	for i in 30:
		npc.state = NpcCaster.State.IDLE
		npc.begin()
		_run(1.05)
		if chosen[-1] == &"ward":
			wards += 1
		npc.halt()
	assert_gt(wards, 20)
