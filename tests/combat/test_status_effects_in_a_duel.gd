extends TestCase
## Status effects as they play out in a duel, and as an NPC weighs them.

const BEAT := 250_000

var duel: Duel
var player: Duelist
var opponent: Duelist
var player_circle: SpellCircle
var opponent_circle: SpellCircle
var npc: NpcCaster
var clock: int


func before_each() -> void:
	player = Duelist.new(Duelist.SECOND_PERSON)
	player.spellbook = Spellbook.complete()
	opponent = Duelist.new("Opponent")
	opponent.spellbook = Spellbook.of([&"lightning"])
	player_circle = add_managed(SpellCircle.new())
	opponent_circle = add_managed(SpellCircle.new())
	npc = add_managed(NpcCaster.new())
	npc.rng.seed = 5
	npc.profile = CasterProfile.make(300_000, 0.0, 0.0, 0.0)
	npc.profile.think_seconds_min = 1.0
	npc.profile.think_seconds_max = 1.0
	npc.profile.tempo_spread = 0.0
	duel = add_managed(Duel.new())
	duel.set_process(false)
	duel.setup(player, opponent, player_circle, opponent_circle, npc)
	duel.begin()
	clock = 1_000_000


func _run(seconds: float) -> void:
	for i in roundi(seconds * 60.0):
		duel.advance(1.0 / 60.0)


## The player casts `id`, every stroke `wobble` ticks off the beat in turn.
func _player_casts(id: StringName, wobble: float = 0.0) -> CastResult:
	var spell := SpellLibrary.find(id)
	player_circle.prepare(spell)
	for i in spell.strokes.size():
		var stroke := spell.strokes[i]
		var nudge := 0.0 if i == 0 else (wobble if i % 2 == 1 else -wobble)
		player_circle.strike(stroke.rune, stroke.position, clock + int((stroke.tick + nudge) * BEAT))
	clock += 10_000_000
	return player_circle.last_result


func test_the_duel_knows_what_each_side_is_casting() -> void:
	assert_null(player.casting)
	var fire_bolt := SpellLibrary.find(&"fire_bolt")
	player_circle.prepare(fire_bolt)
	player_circle.strike(fire_bolt.strokes[0].rune, fire_bolt.strokes[0].position, clock)
	assert_eq(player.casting, fire_bolt)
	player_circle.abandon()
	assert_null(player.casting)

	# It thinks for a second, casts for 2.1, then thinks for another.
	_run(1.2)
	assert_eq(opponent.casting, SpellLibrary.find(&"lightning"))
	_run(2.3)
	assert_null(opponent.casting, "the cast has landed")


func test_flinch_breaks_the_opponents_cast() -> void:
	_run(1.5)
	assert_eq(npc.state, NpcCaster.State.CASTING)
	var chi_before := opponent.chi
	_player_casts(&"flinch")
	assert_eq(duel.outcomes[-1].spell_broken(), SpellLibrary.find(&"lightning"))
	assert_eq(npc.state, NpcCaster.State.THINKING)
	assert_eq(opponent_circle.actual.runes.size(), 0)
	assert_almost_eq(opponent.chi, chi_before, 0.0001, "the chi it spent is not given back")
	_run(0.5)
	assert_almost_eq(player.health, 100.0, 0.0001, "the lightning never arrived")


func test_the_opponents_flinch_breaks_the_players_cast() -> void:
	opponent.spellbook = Spellbook.of([&"flinch"])
	var broken := []
	player.interrupted.connect(func (spell): broken.append(spell.id))
	_run(0.5)
	var lightning := SpellLibrary.find(&"lightning")
	player_circle.prepare(lightning)
	for i in 3:
		player_circle.strike(lightning.strokes[i].rune, lightning.strokes[i].position, clock + lightning.strokes[i].tick * BEAT)
	assert_eq(player_circle.state, SpellCircle.State.CASTING)
	_run(2.0)
	assert_eq(broken, [&"lightning"])
	assert_eq(player_circle.state, SpellCircle.State.READY)
	assert_eq(player_circle.expected.current_index, 0, "the spell is laid out to be started over")
	assert_null(npc.foe_spell)


func test_a_ward_lets_the_player_cast_through_a_flinch() -> void:
	opponent.spellbook = Spellbook.new()
	_player_casts(&"ward")
	var lightning := SpellLibrary.find(&"lightning")
	player_circle.prepare(lightning)
	player_circle.strike(lightning.strokes[0].rune, lightning.strokes[0].position, clock)
	# An NPC knows better than to try this, so it is done on its behalf.
	var flinch := SpellLibrary.find(&"flinch")
	var flawless := CastScorer.score(flinch.ticks(), flinch.ticks().map(func (tick): return tick * BEAT))
	var outcome := SpellResolver.resolve(flinch, flawless, opponent, player)
	assert_null(outcome.spell_broken())
	assert_eq(player_circle.state, SpellCircle.State.CASTING)
	assert_eq(player.casting, lightning)


func test_an_npc_does_not_waste_a_flinch_on_a_warded_foe() -> void:
	opponent.spellbook = Spellbook.of([&"flinch"])
	_player_casts(&"ward")
	var lightning := SpellLibrary.find(&"lightning")
	player_circle.prepare(lightning)
	player_circle.strike(lightning.strokes[0].rune, lightning.strokes[0].position, clock)
	var outcomes := duel.outcomes.size()
	_run(3.0)
	assert_eq(duel.outcomes.size(), outcomes, "it cast nothing")
	assert_eq(npc.state, NpcCaster.State.THINKING)


func test_a_chilled_player_is_judged_more_strictly() -> void:
	opponent.spellbook = Spellbook.new()
	opponent.max_health = 500.0
	opponent.health = 500.0
	var usual := _player_casts(&"fire_bolt", 0.06)
	player.apply_chill(0.35, 6.0)
	var chilled := _player_casts(&"fire_bolt", 0.06)
	assert_lt(chilled.quality, usual.quality)
	assert_lt(chilled.rhythm_score, usual.rhythm_score)
	_run(6.5)
	var thawed := _player_casts(&"fire_bolt", 0.06)
	assert_almost_eq(thawed.quality, usual.quality, 0.0001)


func test_a_chill_does_not_trouble_a_flawless_cast() -> void:
	opponent.spellbook = Spellbook.new()
	player.apply_chill(0.35, 6.0)
	assert_almost_eq(_player_casts(&"fire_bolt").quality, 1.0, 0.0001)


func test_the_opponent_is_chilled_by_the_same_rule() -> void:
	npc.profile.timing_error = 0.08
	_player_casts(&"frost_bolt")
	assert_true(opponent.is_chilled())
	assert_almost_eq(opponent_circle.tuning.rhythm_tolerance, duel.tuning.rhythm_tolerance * opponent.precision())
	assert_almost_eq(player_circle.tuning.rhythm_tolerance, duel.tuning.rhythm_tolerance, 0.0001, "the player is not")
	_run(6.5)
	assert_almost_eq(opponent_circle.tuning.rhythm_tolerance, duel.tuning.rhythm_tolerance)


func test_bulwark_turns_the_opponents_blow_back() -> void:
	_player_casts(&"bulwark")
	_run(1.0 + 7 * 0.3 + 0.3)
	var outcome := duel.outcomes[-1]
	assert_eq(outcome.caster, opponent)
	assert_gt(outcome.damage_reflected(), 0.0)
	assert_almost_eq(opponent.health, 100.0 - outcome.damage_reflected())


func test_a_duelist_can_fall_to_their_own_blow_turned_back() -> void:
	_player_casts(&"bulwark")
	player.make_ward_reflect(1.0)
	opponent.health = 5.0
	_run(1.0 + 7 * 0.3 + 0.3)
	assert_true(duel.is_over())
	assert_true(duel.player_won())


# What an NPC makes of them

func test_an_npc_batters_a_ward_and_not_thin_air() -> void:
	var profile := CasterProfile.new()
	var gust := SpellLibrary.find(&"gust")
	var unwarded := NpcBrain.weigh(gust, opponent, player, null, profile)
	player.raise_ward(26.0, 10.0)
	var warded := NpcBrain.weigh(gust, opponent, player, null, profile)
	assert_gt(warded, unwarded + 2.0)


func test_an_npc_interrupts_only_when_there_is_a_cast_to_break() -> void:
	var profile := CasterProfile.new()
	var flinch := SpellLibrary.find(&"flinch")
	assert_almost_eq(NpcBrain.weigh(flinch, opponent, player, null, profile), 0.0)
	assert_gt(NpcBrain.weigh(flinch, opponent, player, SpellLibrary.find(&"lightning"), profile), 2.0)
	player.raise_ward(5.0, 10.0)
	assert_almost_eq(
		NpcBrain.weigh(flinch, opponent, player, SpellLibrary.find(&"lightning"), profile), 0.0, 0.0001,
		"a ward would keep it out"
	)


func test_an_npc_would_sooner_break_a_heavy_spell_than_a_light_one() -> void:
	var profile := CasterProfile.new()
	var flinch := SpellLibrary.find(&"flinch")
	var light := NpcBrain.weigh(flinch, opponent, player, SpellLibrary.find(&"spark"), profile)
	var heavy := NpcBrain.weigh(flinch, opponent, player, SpellLibrary.find(&"lightning"), profile)
	assert_gt(heavy, light)


func test_an_npc_does_not_chill_the_chilled() -> void:
	var profile := CasterProfile.new()
	var frost_bolt := SpellLibrary.find(&"frost_bolt")
	var fresh := NpcBrain.weigh(frost_bolt, opponent, player, null, profile)
	player.apply_chill(0.35, 6.0)
	var chilled := NpcBrain.weigh(frost_bolt, opponent, player, null, profile)
	assert_almost_eq(fresh - chilled, NpcBrain.CHILL_WEIGHT)
