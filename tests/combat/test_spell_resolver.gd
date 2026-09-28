extends TestCase
## SpellResolver: what a cast does to the duelists.

const BEAT := 300_000

var caster: Duelist
var target: Duelist


func before_each() -> void:
	caster = Duelist.new("Caster")
	target = Duelist.new("Target")


## A verdict on `spell` cast with every stroke `wobble` ticks off the beat,
## alternately late and early.
func _cast(spell: Spell, wobble: float = 0.0) -> CastResult:
	var times := []
	var ticks := spell.ticks()
	for i in ticks.size():
		var nudge := wobble if i % 2 == 1 else -wobble
		if i == 0:
			nudge = 0.0
		times.append(int((ticks[i] + nudge) * BEAT))
	return CastScorer.score(ticks, times)


func test_a_flawless_cast_delivers_the_written_amount() -> void:
	var fire_bolt := SpellLibrary.find(&"fire_bolt")
	var outcome := SpellResolver.resolve(fire_bolt, _cast(fire_bolt), caster, target)
	assert_almost_eq(target.health, 100.0 - fire_bolt.effects[0].amount)
	assert_almost_eq(outcome.damage_dealt(), fire_bolt.effects[0].amount)
	assert_almost_eq(caster.health, 100.0, 0.0001, "the caster is unharmed")
	assert_false(outcome.fizzled)


func test_a_sloppy_cast_delivers_less() -> void:
	var fire_bolt := SpellLibrary.find(&"fire_bolt")
	var sloppy := _cast(fire_bolt, 0.12)
	assert_false(sloppy.fizzled)
	assert_lt(sloppy.potency, 1.0)
	var outcome := SpellResolver.resolve(fire_bolt, sloppy, caster, target)
	assert_almost_eq(outcome.damage_dealt(), fire_bolt.effects[0].amount * sloppy.potency, 0.0001)
	assert_gt(target.health, 100.0 - fire_bolt.effects[0].amount)


func test_a_fizzled_cast_does_nothing() -> void:
	var fire_bolt := SpellLibrary.find(&"fire_bolt")
	var outcome := SpellResolver.resolve(fire_bolt, CastResult.fizzle(), caster, target)
	assert_true(outcome.fizzled)
	assert_eq(outcome.entries.size(), 0)
	assert_almost_eq(target.health, 100.0)
	assert_eq(outcome.describe(), "Caster's Fire Bolt fizzled.")
	caster.display_name = Duelist.SECOND_PERSON
	assert_eq(outcome.describe(), "Your Fire Bolt fizzled.")


func test_a_ward_goes_on_the_caster() -> void:
	var ward := SpellLibrary.find(&"ward")
	var outcome := SpellResolver.resolve(ward, _cast(ward), caster, target)
	assert_almost_eq(caster.ward, ward.effects[0].amount)
	assert_almost_eq(caster.ward_seconds_left, ward.effects[0].duration)
	assert_false(target.is_warded())
	assert_eq(outcome.entries[0]["on"], caster)


func test_a_weak_cast_raises_a_weak_ward_that_lasts_as_long() -> void:
	var ward := SpellLibrary.find(&"ward")
	var sloppy := _cast(ward, 0.12)
	SpellResolver.resolve(ward, sloppy, caster, target)
	assert_almost_eq(caster.ward, ward.effects[0].amount * sloppy.potency, 0.0001)
	assert_almost_eq(caster.ward_seconds_left, ward.effects[0].duration)


func test_a_ward_answers_an_attack() -> void:
	var ward := SpellLibrary.find(&"ward")
	var fire_bolt := SpellLibrary.find(&"fire_bolt")
	SpellResolver.resolve(ward, _cast(ward), target, caster)
	var outcome := SpellResolver.resolve(fire_bolt, _cast(fire_bolt), caster, target)
	assert_almost_eq(outcome.damage_absorbed(), 20.0)
	assert_almost_eq(outcome.damage_dealt(), 2.0)
	assert_almost_eq(target.health, 98.0)
	assert_true("warded" in outcome.describe())


func test_mending_heals_the_caster() -> void:
	var mend := SpellLibrary.find(&"mend")
	caster.take_damage(50.0)
	var outcome := SpellResolver.resolve(mend, _cast(mend), caster, target)
	assert_almost_eq(caster.health, 50.0 + mend.effects[0].amount)
	assert_almost_eq(outcome.total(SpellEffect.Kind.HEAL), mend.effects[0].amount)


func test_healing_reports_what_was_restored_not_what_was_offered() -> void:
	var mend := SpellLibrary.find(&"mend")
	caster.take_damage(5.0)
	var outcome := SpellResolver.resolve(mend, _cast(mend), caster, target)
	assert_almost_eq(outcome.total(SpellEffect.Kind.HEAL), 5.0)


func test_a_spell_can_do_several_things() -> void:
	var spell := Spell.new()
	spell.id = &"drain"
	spell.display_name = "Drain"
	spell.strokes = SpellLibrary.find(&"spark").strokes
	spell.effects = [
		SpellEffect.make(SpellEffect.Kind.DAMAGE, 10.0),
		SpellEffect.make(SpellEffect.Kind.HEAL, 6.0),
	]
	caster.take_damage(20.0)
	var outcome := SpellResolver.resolve(spell, _cast(spell), caster, target)
	assert_eq(outcome.entries.size(), 2)
	assert_almost_eq(target.health, 90.0)
	assert_almost_eq(caster.health, 86.0)


func test_the_outcome_reads_as_a_line_of_a_combat_log() -> void:
	var fire_bolt := SpellLibrary.find(&"fire_bolt")
	var outcome := SpellResolver.resolve(fire_bolt, _cast(fire_bolt), caster, target)
	assert_eq(outcome.describe(), "Caster cast Fire Bolt (S): 22 damage.")


func test_every_spell_in_the_game_does_something_and_costs_something() -> void:
	for spell in SpellLibrary.all():
		assert_gt(spell.effects.size(), 0, "%s has an effect" % [spell.id])
		assert_gt(spell.chi_cost, 0.0, "%s costs chi" % [spell.id])
		assert_true(spell.chi_cost <= Duelist.new().max_chi, "%s can be afforded on a full pool" % [spell.id])
		assert_false(spell.describe_effects().is_empty(), "%s can describe itself" % [spell.id])


func test_effects_describe_themselves() -> void:
	assert_eq(SpellEffect.make(SpellEffect.Kind.DAMAGE, 22.0).describe(), "22 damage")
	assert_eq(SpellEffect.make(SpellEffect.Kind.DAMAGE, 22.0).describe(0.5), "11 damage")
	assert_eq(SpellEffect.make(SpellEffect.Kind.WARD, 20.0, 8.0).describe(), "ward of 20 for 8s")
	assert_eq(SpellEffect.make(SpellEffect.Kind.WARD, 20.0, 7.5).describe(), "ward of 20 for 7.5s")
	assert_eq(SpellEffect.make(SpellEffect.Kind.HEAL, 18.0).describe(), "heals 18")
