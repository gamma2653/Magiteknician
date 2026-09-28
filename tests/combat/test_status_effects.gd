extends TestCase
## Battering, interrupting, chilling and reflecting.

const BEAT := 250_000

var caster: Duelist
var target: Duelist


func before_each() -> void:
	caster = Duelist.new("Caster")
	target = Duelist.new("Target")


func _flawless(spell: Spell) -> CastResult:
	var ticks := spell.ticks()
	return CastScorer.score(ticks, ticks.map(func (tick): return tick * BEAT))


func _cast(id: StringName, by: Duelist = caster, at: Duelist = target) -> SpellOutcome:
	var spell := SpellLibrary.find(id)
	return SpellResolver.resolve(spell, _flawless(spell), by, at)


func _effect(id: StringName, kind: SpellEffect.Kind) -> SpellEffect:
	for effect in SpellLibrary.find(id).effects:
		if effect.kind == kind:
			return effect
	return null


# Battering

func test_battering_wears_a_ward_down_and_spares_the_duelist() -> void:
	target.raise_ward(30.0, 10.0)
	assert_almost_eq(target.batter(12.0), 12.0)
	assert_almost_eq(target.ward, 18.0)
	assert_almost_eq(target.health, 100.0)


func test_battering_takes_no_more_than_the_ward_has() -> void:
	var endings := []
	target.ward_ended.connect(func (broken): endings.append(broken))
	target.raise_ward(10.0, 10.0)
	assert_almost_eq(target.batter(50.0), 10.0)
	assert_false(target.is_warded())
	assert_eq(endings, [true], "the ward was broken, not left to lapse")
	assert_almost_eq(target.health, 100.0)


func test_there_is_nothing_to_batter_without_a_ward() -> void:
	assert_almost_eq(target.batter(20.0), 0.0)


func test_gust_strips_a_ward() -> void:
	_cast(&"ward", target, caster)
	var held := target.ward
	var outcome := _cast(&"gust")
	var batter := _effect(&"gust", SpellEffect.Kind.BATTER).amount
	assert_gt(batter, held, "the test wants a gust that takes the whole ward")
	assert_false(target.is_warded())
	assert_almost_eq(outcome.total(SpellEffect.Kind.BATTER), held)
	assert_true("off the ward" in outcome.describe())


func test_gust_does_little_to_an_unwarded_foe() -> void:
	var outcome := _cast(&"gust")
	assert_almost_eq(outcome.total(SpellEffect.Kind.BATTER), 0.0)
	assert_almost_eq(outcome.damage_dealt(), _effect(&"gust", SpellEffect.Kind.DAMAGE).amount)
	assert_false("off the ward" in outcome.describe())


func test_gust_is_a_better_answer_to_a_ward_than_a_bolt_is() -> void:
	_cast(&"bulwark", target, caster)
	var held := target.ward
	_cast(&"gust")
	var after_gust := held - target.ward
	var gust_cost := SpellLibrary.find(&"gust").chi_cost

	target.raise_ward(held, 10.0)
	_cast(&"fire_bolt")
	var after_bolt := held - target.ward
	var bolt_cost := SpellLibrary.find(&"fire_bolt").chi_cost
	assert_gt(after_gust / gust_cost, after_bolt / bolt_cost)


# Interrupting

func test_an_interruption_breaks_the_cast_in_progress() -> void:
	var broken := []
	target.interrupted.connect(func (spell): broken.append(spell.id))
	target.casting = SpellLibrary.find(&"lightning")
	var outcome := _cast(&"flinch")
	assert_eq(broken, [&"lightning"])
	assert_null(target.casting)
	assert_eq(outcome.spell_broken(), SpellLibrary.find(&"lightning"))
	assert_eq(outcome.describe(), "Caster cast Flinch (S): broke Lightning.")


func test_there_is_nothing_to_interrupt_in_a_foe_who_is_not_casting() -> void:
	var outcome := _cast(&"flinch")
	assert_null(outcome.spell_broken())
	assert_eq(outcome.describe(), "Caster cast Flinch (S) to no effect.")


func test_a_ward_keeps_an_interruption_out() -> void:
	target.raise_ward(5.0, 10.0)
	target.casting = SpellLibrary.find(&"lightning")
	var outcome := _cast(&"flinch")
	assert_null(outcome.spell_broken())
	assert_eq(target.casting, SpellLibrary.find(&"lightning"))
	assert_almost_eq(target.ward, 5.0, 0.0001, "and is none the worse for it")


# Chilling

func test_a_chill_makes_timing_stricter_for_a_while() -> void:
	var changes := []
	target.precision_changed.connect(func (precision): changes.append(precision))
	assert_almost_eq(target.precision(), 1.0)
	target.apply_chill(0.35, 6.0)
	assert_true(target.is_chilled())
	assert_almost_eq(target.precision(), 0.65)
	target.advance(5.9)
	assert_true(target.is_chilled())
	target.advance(0.2)
	assert_false(target.is_chilled())
	assert_almost_eq(target.precision(), 1.0)
	assert_eq(changes, [0.65, 1.0])


func test_a_harder_chill_replaces_a_milder_one() -> void:
	target.apply_chill(0.2, 6.0)
	target.advance(4.0)
	target.apply_chill(0.5, 3.0)
	assert_almost_eq(target.chill, 0.5)
	assert_almost_eq(target.chill_seconds_left, 3.0)
	target.apply_chill(0.1, 10.0)
	assert_almost_eq(target.chill, 0.5, 0.0001, "a milder chill does not thaw a harder one")
	assert_almost_eq(target.chill_seconds_left, 10.0, 0.0001, "but it does keep it going")


func test_no_chill_takes_all_of_a_duelists_tolerance() -> void:
	target.apply_chill(1.0, 5.0)
	assert_almost_eq(target.precision(), Duelist.MIN_PRECISION)


func test_frost_bolt_harms_and_chills() -> void:
	var outcome := _cast(&"frost_bolt")
	assert_almost_eq(outcome.damage_dealt(), _effect(&"frost_bolt", SpellEffect.Kind.DAMAGE).amount)
	assert_true(target.is_chilled())
	assert_almost_eq(target.chill, _effect(&"frost_bolt", SpellEffect.Kind.CHILL).amount)
	assert_false(caster.is_chilled())
	assert_true("chilled" in outcome.describe())


func test_a_stricter_tuning_scores_the_same_cast_lower() -> void:
	var tuning := CastTuning.new()
	var strict := tuning.stricter(0.65)
	assert_almost_eq(strict.rhythm_tolerance, tuning.rhythm_tolerance * 0.65)
	assert_almost_eq(strict.good_window, tuning.good_window * 0.65)
	assert_almost_eq(strict.aim_weight, tuning.aim_weight, 0.0001, "aim is left alone")
	assert_almost_eq(tuning.rhythm_tolerance, CastTuning.new().rhythm_tolerance, 0.0001, "and so is the original")

	var ticks := [0, 1, 2, 3, 4]
	var times := [0, 270_000, 480_000, 770_000, 1_000_000]
	var usual := CastScorer.score(ticks, times, [], 0, tuning)
	var chilled := CastScorer.score(ticks, times, [], 0, strict)
	assert_lt(chilled.quality, usual.quality)


# Reflecting

func test_a_reflecting_ward_turns_part_of_a_blow_back() -> void:
	target.raise_ward(26.0, 10.0)
	target.make_ward_reflect(0.3)
	var outcome := _cast(&"fire_bolt")
	var blow := _effect(&"fire_bolt", SpellEffect.Kind.DAMAGE).amount
	assert_almost_eq(outcome.damage_absorbed(), blow)
	assert_almost_eq(outcome.damage_reflected(), blow * 0.3)
	assert_almost_eq(caster.health, 100.0 - blow * 0.3)
	assert_almost_eq(target.health, 100.0)
	assert_true("turned back" in outcome.describe())


func test_only_what_the_ward_soaks_up_is_turned_back() -> void:
	target.raise_ward(10.0, 10.0)
	target.make_ward_reflect(0.5)
	var outcome := _cast(&"lightning")
	assert_almost_eq(outcome.damage_absorbed(), 10.0)
	assert_almost_eq(outcome.damage_reflected(), 5.0)
	assert_false(target.is_warded())
	assert_almost_eq(target.ward_reflect, 0.0, 0.0001, "the reflection goes with the ward")


func test_a_plain_ward_turns_nothing_back() -> void:
	_cast(&"ward", target, caster)
	var outcome := _cast(&"fire_bolt")
	assert_almost_eq(outcome.damage_reflected(), 0.0)
	assert_almost_eq(caster.health, 100.0)


func test_what_is_turned_back_is_not_turned_back_again() -> void:
	caster.raise_ward(50.0, 10.0)
	caster.make_ward_reflect(1.0)
	target.raise_ward(50.0, 10.0)
	target.make_ward_reflect(1.0)
	var outcome := _cast(&"fire_bolt")
	var blow := _effect(&"fire_bolt", SpellEffect.Kind.DAMAGE).amount
	assert_almost_eq(outcome.damage_reflected(), blow)
	assert_almost_eq(caster.ward, 50.0 - blow, 0.0001, "the caster's ward took it")
	assert_almost_eq(target.ward, 50.0 - blow, 0.0001, "and sent nothing back a second time")
	assert_almost_eq(caster.ward_reflect, 1.0, 0.0001, "and still reflects afterwards")


func test_a_new_ward_does_not_inherit_the_reflection_of_the_old() -> void:
	target.raise_ward(10.0, 10.0)
	target.make_ward_reflect(0.3)
	target.raise_ward(20.0, 10.0)
	assert_almost_eq(target.ward_reflect, 0.0)


func test_nothing_reflects_without_a_ward() -> void:
	assert_false(target.make_ward_reflect(0.3))
	assert_almost_eq(target.ward_reflect, 0.0)


func test_bulwark_is_a_ward_that_reflects() -> void:
	var outcome := _cast(&"bulwark")
	assert_almost_eq(caster.ward, _effect(&"bulwark", SpellEffect.Kind.WARD).amount)
	assert_almost_eq(caster.ward_reflect, _effect(&"bulwark", SpellEffect.Kind.REFLECT).amount)
	assert_true("turning back 30%" in outcome.describe())


func test_a_weakly_cast_bulwark_reflects_less() -> void:
	var bulwark := SpellLibrary.find(&"bulwark")
	var ticks := bulwark.ticks()
	var times := []
	for i in ticks.size():
		times.append(int((ticks[i] + (0.12 if i % 2 == 1 else -0.12 if i > 0 else 0.0)) * BEAT))
	var sloppy := CastScorer.score(ticks, times)
	assert_false(sloppy.fizzled)
	SpellResolver.resolve(bulwark, sloppy, caster, target)
	assert_almost_eq(caster.ward_reflect, _effect(&"bulwark", SpellEffect.Kind.REFLECT).amount * sloppy.potency, 0.0001)


# Status

func test_a_duelist_can_say_what_state_they_are_in() -> void:
	assert_eq(target.status_text(), "")
	target.raise_ward(26.0, 9.5)
	assert_eq(target.status_text(), "Warded 10s")
	target.make_ward_reflect(0.3)
	target.apply_chill(0.35, 5.2)
	assert_eq(target.status_text(), "Warded 10s, turning back 30% · Chilled 6s")


func test_effects_describe_themselves() -> void:
	assert_eq(SpellEffect.make(SpellEffect.Kind.BATTER, 16.0).describe(), "batters a ward for 16")
	assert_eq(SpellEffect.make(SpellEffect.Kind.INTERRUPT, 1.0).describe(), "breaks a cast")
	assert_eq(SpellEffect.make(SpellEffect.Kind.CHILL, 0.35, 6.0).describe(), "chills for 6s")
	assert_eq(SpellEffect.make(SpellEffect.Kind.REFLECT, 0.3).describe(), "turns back 30%")
	assert_eq(SpellEffect.make(SpellEffect.Kind.REFLECT, 0.3).describe(0.5), "turns back 15%")
