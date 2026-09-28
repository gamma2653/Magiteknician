extends TestCase
## CastPlan: the strokes an NPC draws up before it casts.

const DRAWS := 600

var rng: RandomNumberGenerator
var fire_bolt: Spell


func before_each() -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = 2653
	fire_bolt = SpellLibrary.find(&"fire_bolt")


func _mean_quality(profile: CasterProfile, spell: Spell) -> float:
	var total := 0.0
	for i in DRAWS:
		total += CastPlan.draw(spell, profile, rng).foreseen_result().quality
	return total / DRAWS


func test_a_plan_has_a_stroke_for_every_rune() -> void:
	var plan := CastPlan.draw(fire_bolt, CasterProfile.new(), rng)
	assert_eq(plan.stroke_count(), fire_bolt.strokes.size())
	assert_eq(plan.aim_offsets.size(), fire_bolt.strokes.size())
	assert_eq(plan.strays_before.size(), fire_bolt.strokes.size())
	assert_eq(plan.offsets_usec[0], 0, "the first stroke starts the clock")
	assert_false(plan.strays_before[0], "and nothing can stray before it")


func test_strokes_are_always_in_order() -> void:
	# Jitter this wild would swap neighbouring strokes if nothing stopped it.
	var shaky := CasterProfile.make(200_000, 0.5)
	for i in 200:
		var plan := CastPlan.draw(fire_bolt, shaky, rng)
		for stroke in range(1, plan.stroke_count()):
			assert_true(
				plan.offsets_usec[stroke] - plan.offsets_usec[stroke - 1] >= CastPlan.MIN_GAP_USEC,
				"draw %d stroke %d" % [i, stroke]
			)


func test_every_meant_stroke_lands_on_its_rune() -> void:
	var wild := CasterProfile.make(400_000, 0.1, 1.0)
	for i in 200:
		for offset in CastPlan.draw(fire_bolt, wild, rng).aim_offsets:
			assert_true(offset.length() <= Rune.RADIUS * CastPlan.MAX_AIM + 0.001)


func test_steady_hands_cast_a_flawless_spell() -> void:
	var perfect := CasterProfile.make(400_000, 0.0, 0.0, 0.0)
	perfect.tempo_spread = 0.0
	var plan := CastPlan.draw(fire_bolt, perfect, rng)
	assert_eq(plan.offsets_usec, [0, 400_000, 1_200_000, 1_600_000, 2_400_000])
	assert_almost_eq(plan.duration_seconds(), 2.4)
	var result := plan.foreseen_result()
	assert_eq(result.grade, CastResult.Grade.S)
	assert_almost_eq(result.quality, 1.0, 0.0001)


func test_the_same_seed_gives_the_same_cast() -> void:
	var first := CastPlan.draw(fire_bolt, CasterProfile.new(), rng)
	rng.seed = 2653
	var second := CastPlan.draw(fire_bolt, CasterProfile.new(), rng)
	assert_eq(first.offsets_usec, second.offsets_usec)
	assert_eq(first.aim_offsets, second.aim_offsets)
	assert_eq(first.strays_before, second.strays_before)


func test_shakier_hands_cast_worse() -> void:
	var previous := 1.01
	for timing_error in [0.02, 0.06, 0.1, 0.16]:
		var quality := _mean_quality(CasterProfile.make(400_000, timing_error), fire_bolt)
		assert_lt(quality, previous, "timing error %s" % [timing_error])
		previous = quality


func test_longer_spells_are_harder_to_cast_well() -> void:
	var profile := CasterProfile.make(400_000, 0.1)
	var short := _mean_quality(profile, SpellLibrary.find(&"spark"))
	var long := _mean_quality(profile, SpellLibrary.find(&"lightning"))
	assert_gt(short, long)


func test_how_fast_an_npc_casts_does_not_change_how_well() -> void:
	var slow := CasterProfile.make(900_000, 0.08)
	var fast := CasterProfile.make(180_000, 0.08)
	var slow_quality := _mean_quality(slow, fire_bolt)
	var fast_quality := _mean_quality(fast, fire_bolt)
	assert_almost_eq(slow_quality, fast_quality, 0.03)


func test_a_faster_caster_finishes_sooner() -> void:
	var slow := CastPlan.draw(fire_bolt, CasterProfile.make(600_000, 0.05), rng)
	var fast := CastPlan.draw(fire_bolt, CasterProfile.make(250_000, 0.05), rng)
	assert_gt(slow.duration_seconds(), fast.duration_seconds())


func test_the_tempo_varies_from_cast_to_cast() -> void:
	var profile := CasterProfile.make(400_000, 0.05)
	profile.tempo_spread = 0.1
	var tempos := {}
	for i in 20:
		tempos[roundi(CastPlan.draw(fire_bolt, profile, rng).usec_per_tick)] = true
	assert_gt(tempos.size(), 10)


func test_strays_happen_as_often_as_the_profile_says() -> void:
	var clumsy := CasterProfile.make(400_000, 0.05, 0.3, 0.25)
	var strays := 0
	var chances := 0
	for i in DRAWS:
		var plan := CastPlan.draw(fire_bolt, clumsy, rng)
		strays += plan.strays_before.count(true)
		chances += plan.stroke_count() - 1
	assert_between(float(strays) / chances, 0.2, 0.3)
