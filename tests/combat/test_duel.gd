extends TestCase
## Duel: two casters, real time, first to fall loses.

const BEAT := 250_000

var duel: Duel
var player: Duelist
var opponent: Duelist
var player_circle: SpellCircle
var opponent_circle: SpellCircle
var npc: NpcCaster
var log: Array
var clock: int


func before_each() -> void:
	player = Duelist.new("Player")
	player.spellbook = Spellbook.complete()
	opponent = Duelist.new("Opponent")
	opponent.spellbook = Spellbook.of([&"fire_bolt"])

	player_circle = add_managed(SpellCircle.new())
	opponent_circle = add_managed(SpellCircle.new())
	npc = add_managed(NpcCaster.new())
	npc.rng.seed = 5
	npc.profile = CasterProfile.make(300_000, 0.03, 0.2, 0.0)
	npc.profile.think_seconds_min = 1.0
	npc.profile.think_seconds_max = 1.0
	npc.profile.tempo_spread = 0.0

	duel = add_managed(Duel.new())
	# Time is fed by hand so the test does not depend on the frame rate.
	duel.set_process(false)
	duel.setup(player, opponent, player_circle, opponent_circle, npc)

	log = []
	clock = 1_000_000
	duel.spell_resolved.connect(func (outcome): log.append(outcome.describe()))
	duel.cast_refused.connect(func (caster, spell): log.append("%s cannot afford %s" % [caster.display_name, spell.display_name]))
	duel.finished.connect(func (winner, loser): log.append("%s beat %s" % [winner.display_name, loser.display_name]))


func _run(seconds: float) -> void:
	for i in roundi(seconds * 60.0):
		duel.advance(1.0 / 60.0)


## The player casts `id` flawlessly. No time passes in the duel.
func _player_casts(id: StringName) -> SpellCircle.Outcome:
	var spell := SpellLibrary.find(id)
	player_circle.prepare(spell)
	var last := SpellCircle.Outcome.IGNORED
	for stroke in spell.strokes:
		last = player_circle.strike(stroke.rune, stroke.position, clock + stroke.tick * BEAT)
		if last != SpellCircle.Outcome.HIT:
			return last
	clock += 10_000_000
	return last


func test_nothing_happens_before_the_duel_begins() -> void:
	assert_eq(duel.state, Duel.State.WAITING)
	assert_false(player_circle.accepts_input)
	_run(5.0)
	assert_eq(npc.state, NpcCaster.State.IDLE)
	assert_almost_eq(duel.elapsed_seconds, 0.0)


func test_beginning_the_duel_lets_both_sides_cast() -> void:
	var began := []
	duel.began.connect(func (): began.append(true))
	duel.begin()
	assert_eq(duel.state, Duel.State.RUNNING)
	assert_true(player_circle.accepts_input)
	assert_false(opponent_circle.accepts_input, "the opponent's circle never listens to the keyboard")
	assert_eq(npc.state, NpcCaster.State.THINKING)
	assert_eq(began.size(), 1)


func test_the_players_spell_strikes_the_opponent() -> void:
	duel.begin()
	_player_casts(&"fire_bolt")
	var blow := SpellLibrary.find(&"fire_bolt").effects[0].amount
	assert_almost_eq(opponent.health, 100.0 - blow)
	assert_almost_eq(player.health, 100.0)
	assert_eq(log, ["Player cast Fire Bolt (S): %d damage." % [blow]])
	assert_eq(duel.player_casts.size(), 1)
	assert_almost_eq(duel.player_mean_quality(), 1.0, 0.0001)


func test_the_opponents_spell_strikes_the_player() -> void:
	duel.begin()
	_run(1.0 + 6 * 0.3 + 0.3)
	assert_lt(player.health, 100.0)
	assert_almost_eq(opponent.health, 100.0)
	assert_eq(duel.outcomes.size(), 1)
	assert_eq(duel.outcomes[0].caster, opponent)
	assert_eq(duel.player_casts.size(), 0, "only the player's casts are kept for the summary")


func test_chi_is_paid_when_the_cast_begins() -> void:
	duel.begin()
	var fire_bolt := SpellLibrary.find(&"fire_bolt")
	player_circle.prepare(fire_bolt)
	assert_almost_eq(player.chi, 100.0, 0.0001, "laying a spell out is free")
	var first := fire_bolt.strokes[0]
	player_circle.strike(first.rune, first.position, clock)
	assert_almost_eq(player.chi, 100.0 - fire_bolt.chi_cost)


func test_chi_is_not_returned_for_an_abandoned_cast() -> void:
	duel.begin()
	var fire_bolt := SpellLibrary.find(&"fire_bolt")
	player_circle.prepare(fire_bolt)
	player_circle.strike(fire_bolt.strokes[0].rune, fire_bolt.strokes[0].position, clock)
	player_circle.abandon()
	assert_almost_eq(player.chi, 100.0 - fire_bolt.chi_cost)


func test_a_cast_that_cannot_be_afforded_does_not_begin() -> void:
	duel.begin()
	player.chi = 10.0
	assert_eq(_player_casts(&"fire_bolt"), SpellCircle.Outcome.REFUSED)
	assert_eq(player_circle.state, SpellCircle.State.READY)
	assert_almost_eq(player.chi, 10.0)
	assert_almost_eq(opponent.health, 100.0)
	assert_eq(log, ["Player cannot afford Fire Bolt"])


func test_chi_comes_back_as_the_duel_goes_on() -> void:
	duel.begin()
	player.chi = 10.0
	opponent.spellbook = Spellbook.new()
	_run(2.0)
	assert_almost_eq(player.chi, 10.0 + 2.0 * player.chi_per_second, 0.01)
	assert_eq(_player_casts(&"fire_bolt"), SpellCircle.Outcome.HIT)


func test_a_ward_raised_in_time_takes_the_blow() -> void:
	duel.begin()
	_player_casts(&"bulwark")
	var held := SpellLibrary.find(&"bulwark").effects[0].amount
	assert_almost_eq(player.ward, held)
	_run(1.0 + 6 * 0.3 + 0.3)
	assert_almost_eq(player.health, 100.0)
	assert_lt(player.ward, held)
	assert_true("warded" in log[-1])


func test_wards_lapse_as_the_duel_goes_on() -> void:
	duel.begin()
	opponent.spellbook = Spellbook.new()
	_player_casts(&"ward")
	_run(8.2)
	assert_false(player.is_warded())


func test_the_npc_sees_what_the_player_is_casting() -> void:
	duel.begin()
	var lightning := SpellLibrary.find(&"lightning")
	player_circle.prepare(lightning)
	assert_null(npc.foe_spell, "nothing to see until the cast begins")
	player_circle.strike(lightning.strokes[0].rune, lightning.strokes[0].position, clock)
	assert_eq(npc.foe_spell, lightning)
	player_circle.abandon()
	assert_null(npc.foe_spell)


func test_the_npc_stops_watching_once_the_spell_has_landed() -> void:
	duel.begin()
	_player_casts(&"spark")
	assert_null(npc.foe_spell)


func test_the_duel_ends_when_the_opponent_falls() -> void:
	duel.begin()
	opponent.health = 10.0
	_player_casts(&"fire_bolt")
	assert_true(duel.is_over())
	assert_true(duel.player_won())
	assert_eq(duel.winner, player)
	assert_eq(log[-1], "Player beat Opponent")
	assert_eq(npc.state, NpcCaster.State.IDLE)
	assert_false(player_circle.accepts_input)


func test_the_duel_ends_when_the_player_falls() -> void:
	duel.begin()
	player.health = 5.0
	_run(1.0 + 6 * 0.3 + 0.3)
	assert_true(duel.is_over())
	assert_false(duel.player_won())
	assert_eq(duel.winner, opponent)
	assert_eq(log[-1], "Opponent beat Player")


func test_nothing_more_happens_once_the_duel_is_over() -> void:
	duel.begin()
	opponent.health = 10.0
	_player_casts(&"fire_bolt")
	var resolved := duel.outcomes.size()
	var elapsed := duel.elapsed_seconds
	_player_casts(&"fire_bolt")
	_run(5.0)
	assert_eq(duel.outcomes.size(), resolved)
	assert_almost_eq(duel.elapsed_seconds, elapsed)
	assert_almost_eq(player.health, 100.0)


func test_a_fizzled_cast_is_resolved_as_a_fizzle() -> void:
	duel.begin()
	var fire_bolt := SpellLibrary.find(&"fire_bolt")
	player_circle.prepare(fire_bolt)
	for i in fire_bolt.strokes.size():
		var stroke := fire_bolt.strokes[i]
		if i == 1:
			for stray in 20:
				player_circle.strike(Rune.Type.PERSISTENCE, Vector2(900, 900), clock)
		player_circle.strike(stroke.rune, stroke.position, clock + stroke.tick * BEAT)
	assert_almost_eq(opponent.health, 100.0)
	assert_eq(log, ["Player's Fire Bolt fizzled."])
	assert_eq(player.possessive, "Player's")
	assert_almost_eq(player.chi, 100.0 - fire_bolt.chi_cost, 0.0001, "and the chi is spent all the same")


func test_a_duel_escalates_after_its_first_minute() -> void:
	var escalations := []
	duel.escalated.connect(func (): escalations.append(duel.elapsed_seconds))
	opponent.spellbook = Spellbook.new()
	duel.begin()
	assert_almost_eq(duel.damage_scale(), 1.0)
	_run(Duel.ESCALATION_STARTS - 1.0)
	assert_almost_eq(duel.damage_scale(), 1.0)
	assert_false(duel.has_escalated())
	assert_eq(escalations.size(), 0)
	_run(31.0)
	assert_true(duel.has_escalated())
	assert_eq(escalations.size(), 1, "and says so once")
	assert_almost_eq(duel.damage_scale(), 1.5, 0.01)
	_run(30.0)
	assert_almost_eq(duel.damage_scale(), 2.0, 0.01)


func test_blows_land_harder_once_the_duel_has_escalated() -> void:
	opponent.spellbook = Spellbook.new()
	opponent.max_health = 500.0
	opponent.health = 500.0
	duel.begin()
	_player_casts(&"fire_bolt")
	var early := duel.outcomes[-1].damage_dealt()
	_run(Duel.ESCALATION_STARTS + 60.0)
	_player_casts(&"fire_bolt")
	var late := duel.outcomes[-1].damage_dealt()
	assert_almost_eq(late, early * duel.damage_scale(), 0.01)
	assert_almost_eq(late, early * 2.0, 0.1)


func test_a_stand_in_can_cast_for_the_player() -> void:
	var other := Duel.new()
	add_managed(other)
	other.set_process(false)
	var circles: Array[SpellCircle] = [add_managed(SpellCircle.new()), add_managed(SpellCircle.new())]
	var stand_in: NpcCaster = add_managed(NpcCaster.new())
	var foe: NpcCaster = add_managed(NpcCaster.new())
	stand_in.rng.seed = 1
	foe.rng.seed = 2
	stand_in.profile = CasterProfile.make(300_000, 0.03)
	foe.profile = CasterProfile.make(500_000, 0.15)
	var challenger := Duelist.new("Stand-in")
	challenger.spellbook = Spellbook.of([&"fire_bolt", &"ward"])
	var sphere := Duelist.new("Sphere", 60.0)
	sphere.spellbook = Spellbook.of([&"spark"])
	other.setup(challenger, sphere, circles[0], circles[1], foe, stand_in)
	other.begin()
	assert_false(circles[0].accepts_input, "nobody is at the keyboard")
	for i in 60 * 60:
		if other.is_over():
			break
		other.advance(1.0 / 60.0)
	assert_true(other.is_over())
	assert_true(other.player_won())
	assert_gt(other.player_casts.size(), 2)
	assert_eq(stand_in.state, NpcCaster.State.IDLE)


func test_a_whole_duel_plays_out() -> void:
	# The player answers with a Fire Bolt every three seconds until someone
	# falls. A sturdier opponent would win; this one does not.
	opponent.max_health = 60.0
	opponent.health = 60.0
	duel.begin()
	for round_ in 40:
		if duel.is_over():
			break
		_player_casts(&"fire_bolt")
		_run(3.0)
	assert_true(duel.is_over())
	assert_true(duel.player_won())
	assert_gt(duel.elapsed_seconds, 3.0)
	assert_lt(player.health, 100.0, "the opponent got some blows in")
