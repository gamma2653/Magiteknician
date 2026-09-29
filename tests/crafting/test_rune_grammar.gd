extends TestCase
## RuneGrammar: what a spell does, worked out from its runes.

const D := Rune.Type.DEVELOPMENT
const F := Rune.Type.EQUIVELANCE
const K := Rune.Type.PERSISTENCE
const L := Rune.Type.DECAY
const R := Rune.Type.FLOW
const S := Rune.Type.VARIABILITY
const T := Rune.Type.REFRACTION

var grammar: RuneGrammar


func before_each() -> void:
	grammar = RuneGrammar.new()


## Strokes of `runes`, a tick apart, round a ring.
func _strokes(runes: Array, gaps: Array = []) -> Array[RuneStroke]:
	var strokes: Array[RuneStroke] = []
	var tick := 0
	for i in runes.size():
		if i > 0:
			tick += gaps[i - 1] if i - 1 < gaps.size() else 1
		strokes.append(RuneStroke.make(runes[i], tick, (Vector2.from_angle(TAU * i / runes.size()) * 150.0).round()))
	return strokes


func _kinds(runes: Array) -> Array:
	return grammar.effects_of(_strokes(runes)).map(func (effect): return effect.kind)


func _amount(runes: Array, kind: SpellEffect.Kind) -> float:
	for effect in grammar.effects_of(_strokes(runes)):
		if effect.kind == kind:
			return effect.amount
	return 0.0


func _effect(runes: Array, kind: SpellEffect.Kind) -> SpellEffect:
	for effect in grammar.effects_of(_strokes(runes)):
		if effect.kind == kind:
			return effect
	return null


# Sent, and kept

func test_a_spell_with_flow_in_it_is_sent() -> void:
	assert_true(RuneGrammar.is_sent(_strokes([R, D, D])))
	assert_false(RuneGrammar.is_sent(_strokes([K, K, S])))
	assert_false(RuneGrammar.is_sent([]))


func test_the_runes_are_counted() -> void:
	var counts := RuneGrammar.count(_strokes([R, R, D, S, R]))
	assert_eq(counts[R], 3)
	assert_eq(counts[D], 1)
	assert_eq(counts[S], 1)
	assert_eq(counts[K], 0)
	assert_eq(counts.size(), Rune.Type.size())


# What each rune does

func test_flow_with_something_to_carry_is_a_blow() -> void:
	assert_eq(_kinds([R, D, D]), [SpellEffect.Kind.DAMAGE])
	assert_almost_eq(_amount([R, D, D], SpellEffect.Kind.DAMAGE), 3.0 + 4.5 * 2.0)
	assert_gt(_amount([R, R, D, D], SpellEffect.Kind.DAMAGE), _amount([R, D, D], SpellEffect.Kind.DAMAGE), "more flow, more force")
	assert_gt(_amount([R, D, D, D], SpellEffect.Kind.DAMAGE), _amount([R, R, D, D], SpellEffect.Kind.DAMAGE), "and development builds more than flow throws")


func test_flow_with_nothing_to_carry_is_momentum_alone() -> void:
	assert_eq(_kinds([R, R, R]), [SpellEffect.Kind.BATTER, SpellEffect.Kind.DAMAGE])
	assert_almost_eq(_amount([R, R, R], SpellEffect.Kind.BATTER), 21.0)
	assert_lt(_amount([R, R, R], SpellEffect.Kind.DAMAGE), 5.0, "it wears a ward down, and does little harm")


func test_decay_harms_and_chills() -> void:
	assert_eq(_kinds([R, L, L]), [SpellEffect.Kind.DAMAGE, SpellEffect.Kind.CHILL])
	var chill := _effect([R, L, L], SpellEffect.Kind.CHILL)
	assert_almost_eq(chill.amount, 0.24)
	assert_almost_eq(chill.duration, 4.0)
	assert_lt(_amount([R, L, L], SpellEffect.Kind.DAMAGE), _amount([R, D, D], SpellEffect.Kind.DAMAGE), "it harms less than development builds")


func test_persistence_makes_a_chill_last() -> void:
	var chill := _effect([R, L, K, K], SpellEffect.Kind.CHILL)
	assert_almost_eq(chill.duration, 8.0)
	assert_almost_eq(chill.amount, 0.12, 1e-6, "and no harder")


func test_there_is_a_hardest_chill() -> void:
	assert_almost_eq(_amount([R, L, L, L, L, L, L, L, L], SpellEffect.Kind.CHILL), grammar.chill_at_most)


func test_refraction_breaks_a_cast() -> void:
	assert_true(SpellEffect.Kind.INTERRUPT in _kinds([R, T, S]))
	assert_true(SpellEffect.Kind.INTERRUPT in _kinds([R, D, T]), "with a blow, if there is one")
	assert_true(SpellEffect.Kind.DAMAGE in _kinds([R, D, T]))


func test_development_kept_mends() -> void:
	assert_eq(_kinds([D, D, S]), [SpellEffect.Kind.HEAL])
	assert_almost_eq(_amount([D, D, D], SpellEffect.Kind.HEAL), 16.5)


func test_persistence_kept_wards() -> void:
	assert_eq(_kinds([K, K, S]), [SpellEffect.Kind.WARD])
	var ward := _effect([K, K, K], SpellEffect.Kind.WARD)
	assert_almost_eq(ward.amount, 19.5)
	assert_almost_eq(ward.duration, 9.5, 1e-6, "and the more of it, the longer")


func test_refraction_kept_has_a_ward_turn_blows_back() -> void:
	assert_eq(_kinds([K, K, T]), [SpellEffect.Kind.WARD, SpellEffect.Kind.REFLECT])
	assert_almost_eq(_amount([K, K, T], SpellEffect.Kind.REFLECT), 0.15)
	assert_almost_eq(_amount([K, T, T, T, T, T], SpellEffect.Kind.REFLECT), grammar.reflect_at_most)
	assert_eq(_kinds([D, D, T]), [SpellEffect.Kind.HEAL], "with no ward there is nothing to turn them back from")


func test_a_spell_can_ward_and_mend() -> void:
	assert_eq(_kinds([K, K, D, D]), [SpellEffect.Kind.WARD, SpellEffect.Kind.HEAL])


func test_variability_has_the_whole_spell_do_a_little_more() -> void:
	var plain := _amount([R, D, D], SpellEffect.Kind.DAMAGE)
	var focused := _amount([R, D, D, S], SpellEffect.Kind.DAMAGE)
	assert_almost_eq(focused, snappedf(plain * 1.08, 0.5))
	assert_almost_eq(grammar.focus(_strokes([S, S, K])), 1.16)
	assert_almost_eq(grammar.focus(_strokes([S, S, S, S, S, S, K])), 1.32, 1e-6, "four of them count")
	assert_gt(_amount([K, K, S, S], SpellEffect.Kind.WARD), _amount([K, K], SpellEffect.Kind.WARD))
	assert_gt(_effect([R, L, S, S], SpellEffect.Kind.CHILL).amount, _effect([R, L], SpellEffect.Kind.CHILL).amount)


# Equivalence

func test_equivalence_kept_makes_a_ward_health() -> void:
	assert_eq(_kinds([F, F, S]), [SpellEffect.Kind.TRANSMUTE])
	assert_almost_eq(_amount([F, F, D], SpellEffect.Kind.TRANSMUTE), 15.0, 1e-6, "and development is put to it")
	assert_false(SpellEffect.Kind.HEAL in _kinds([F, F, D]))
	assert_eq(_kinds([F, K, K]), [SpellEffect.Kind.TRANSMUTE, SpellEffect.Kind.WARD], "a ward to make it of can be raised in the same spell")


func test_equivalence_sent_with_refraction_takes_the_foes_spell() -> void:
	assert_eq(_kinds([R, F, T]), [SpellEffect.Kind.ECHO])
	assert_almost_eq(_amount([R, F, T], SpellEffect.Kind.ECHO), 0.6)
	assert_almost_eq(_amount([R, F, F, F, F, T], SpellEffect.Kind.ECHO), 1.0, 1e-6, "and no more than the whole of it")
	assert_false(SpellEffect.Kind.INTERRUPT in _kinds([R, F, T]), "the refraction is taken up by it")


func test_equivalence_sent_with_persistence_takes_the_foes_ward() -> void:
	assert_eq(_kinds([R, F, K]), [SpellEffect.Kind.EXCHANGE])
	assert_almost_eq(_amount([R, F, K], SpellEffect.Kind.EXCHANGE), 0.6)
	assert_almost_eq(_amount([R, F, F, F, K], SpellEffect.Kind.EXCHANGE), 1.0)


func test_an_echo_can_carry_a_blow_of_its_own() -> void:
	assert_eq(_kinds([R, F, T, D]), [SpellEffect.Kind.ECHO, SpellEffect.Kind.DAMAGE])


# Runes that do nothing where they are

func test_a_rune_with_nothing_to_work_on_is_said_to_be_idle() -> void:
	assert_eq(grammar.idle_runes(_strokes([R, D, D])).size(), 0)
	assert_true(grammar.idle_runes(_strokes([R, F, D]))[0].begins_with("φ has nothing to work on"))
	assert_true(grammar.idle_runes(_strokes([R, D, K]))[0].begins_with("κ has nothing to make last"))
	assert_true(grammar.idle_runes(_strokes([D, D, L]))[0].begins_with("λ has nothing to break down"))
	assert_true(grammar.idle_runes(_strokes([D, D, T]))[0].begins_with("θ has nothing to turn blows back from"))
	assert_true(grammar.idle_runes(_strokes([R, D, S, S, S, S, S]))[0].begins_with("σ counts 4 times"))
	assert_eq(grammar.idle_runes(_strokes([R, L, K])).size(), 0, "it has a chill to make last")
	assert_eq(grammar.idle_runes(_strokes([R, F, K])).size(), 0)


func test_a_spell_with_an_idle_rune_is_still_a_spell() -> void:
	var strokes := _strokes([R, D, K])
	assert_eq(grammar.problems(strokes), PackedStringArray())
	assert_eq(grammar.effects_of(strokes).size(), 1)


# What stops a spell being one

func test_a_spell_wants_three_strokes_and_has_at_most_nine() -> void:
	assert_gt(grammar.problems(_strokes([R, D])).size(), 0)
	assert_eq(grammar.problems(_strokes([R, D, D])), PackedStringArray())
	assert_eq(grammar.problems(_strokes([R, D, D, D, D, D, D, D, D])), PackedStringArray())
	assert_gt(grammar.problems(_strokes([R, D, D, D, D, D, D, D, D, D])).size(), 0)
	assert_gt(grammar.problems([]).size(), 0)


func test_runes_that_do_nothing_together_are_not_a_spell() -> void:
	assert_true("These runes do nothing together." in grammar.problems(_strokes([S, S, S])))
	assert_true("These runes do nothing together." in grammar.problems(_strokes([L, T, S])))


func test_the_runes_have_to_be_on_the_circle_and_apart() -> void:
	var outside := _strokes([R, D, D])
	outside[1].position = Vector2(Spell.CIRCLE_RADIUS + 5.0, 0.0)
	assert_true("Rune 2 is outside the circle." in grammar.problems(outside))
	var piled := _strokes([R, D, D])
	piled[2].position = piled[0].position + Vector2(20, 0)
	assert_true("Runes 1 and 3 are on top of each other." in grammar.problems(piled))
	assert_gt(RuneGrammar.MIN_APART, Rune.RADIUS * 2.0)


func test_the_rhythm_has_to_be_one_that_can_be_kept() -> void:
	assert_eq(grammar.problems(_strokes([R, D, D], [1, 5])), PackedStringArray())
	assert_gt(grammar.problems(_strokes([R, D, D], [1, 6])).size(), 0, "too long a silence")
	assert_gt(grammar.problems(_strokes([R, D, D, D, D, D], [4, 4, 4, 4, 4])).size(), 0, "too long a spell")
	var backwards := _strokes([R, D, D])
	backwards[2].tick = 0
	assert_gt(grammar.problems(backwards).size(), 0)
	var late := _strokes([R, D, D])
	for stroke in late:
		stroke.tick += 2
	assert_gt(grammar.problems(late).size(), 0, "a spell starts on tick 0")


# How hard, and what it costs

func test_an_even_spell_over_runes_that_are_close_is_easy() -> void:
	var strokes: Array[RuneStroke] = []
	for i in 4:
		strokes.append(RuneStroke.make(R if i == 0 else D, i, Vector2(-110 + i * 70, 0)))
	assert_almost_eq(grammar.difficulty_of(strokes), 0.013, 0.02)
	assert_eq(RuneGrammar.difficulty_name(grammar.difficulty_of(strokes)), "easy")


func test_an_uneven_spell_over_runes_that_are_far_apart_is_hard() -> void:
	var strokes: Array[RuneStroke] = []
	var places := [Vector2(-180, 0), Vector2(180, 40), Vector2(-160, -80), Vector2(170, -90)]
	var ticks := [0, 3, 5, 6]
	for i in 4:
		strokes.append(RuneStroke.make(R if i == 0 else D, ticks[i], places[i]))
	assert_gt(grammar.difficulty_of(strokes), 0.9)
	assert_eq(RuneGrammar.difficulty_name(grammar.difficulty_of(strokes)), "very hard")


func test_the_rhythm_is_half_of_how_hard_and_the_reach_the_other_half() -> void:
	var close_and_even := _strokes([R, D, D, D])
	for i in 4:
		close_and_even[i].position = Vector2(-110 + i * 70, 0)
	var close_and_uneven := _strokes([R, D, D, D], [1, 2, 3])
	for i in 4:
		close_and_uneven[i].position = Vector2(-110 + i * 70, 0)
	assert_almost_eq(grammar.difficulty_of(close_and_uneven) - grammar.difficulty_of(close_and_even), 0.5, 0.001)
	assert_between(grammar.difficulty_of(_strokes([R, D, D, D, D, D, D, D, D])), 0.0, 1.0)
	assert_almost_eq(grammar.difficulty_of([]), 0.0)


func test_a_harder_spell_costs_less() -> void:
	var easy := _strokes([R, D, D, D])
	var hard := _strokes([R, D, D, D], [1, 2, 3])
	for i in 4:
		easy[i].position = Vector2(-110 + i * 70, 0)
		hard[i].position = [Vector2(-180, 0), Vector2(180, 40), Vector2(-160, -80), Vector2(170, -90)][i]
	assert_eq(grammar.effects_of(easy)[0].amount, grammar.effects_of(hard)[0].amount, "they do the same")
	assert_lt(grammar.cost_of(hard), grammar.cost_of(easy))
	assert_almost_eq(grammar.cost_of(easy) / grammar.cost_of(hard), 1.15 / 0.85, 0.1)


func test_a_spell_that_does_more_costs_more() -> void:
	assert_gt(grammar.cost_of(_strokes([R, D, D, D, D])), grammar.cost_of(_strokes([R, D, D])))
	assert_gt(grammar.cost_of(_strokes([K, K, K, K])), grammar.cost_of(_strokes([K, K, S])))


func test_a_spell_of_the_players_own_costs_more_than_its_like_from_the_book() -> void:
	# Fire Bolt is 16 damage for 16 chi. The same harm, made, is dearer.
	var strokes := _strokes([R, D, D, D])
	var harm: float = grammar.effects_of(strokes)[0].amount
	assert_almost_eq(harm, 16.5)
	assert_gt(grammar.cost_of(strokes), harm)
	assert_lt(grammar.cost_of(strokes), harm * 1.35)


func test_no_spell_is_free_and_none_costs_more_than_a_caster_has() -> void:
	assert_gt(grammar.cost_of(_strokes([R, R, R])), grammar.least_cost - 0.001)
	var dearest := 0.0
	for runes in [[R, D, D, D, D, D, D, D, D], [K, K, K, K, K, T, T, T, T], [D, D, D, D, D, D, D, D, D], [R, F, F, F, F, T, D, D, D]]:
		dearest = maxf(dearest, grammar.cost_of(_strokes(runes)))
		assert_lt(grammar.cost_of(_strokes(runes)), 100.0, str(runes))
	assert_gt(dearest, 40.0, "the biggest spells are dear")


func test_what_each_thing_is_worth_is_near_what_the_book_asks_for_it() -> void:
	# What the book's spells would cost by these rules, before anything
	# is added for their being the player's own.
	var within := 0
	for spell in SpellLibrary.all():
		var worth := 0.0
		for effect in spell.effects:
			worth += grammar.worth_of(effect)
		if absf(worth - spell.chi_cost) <= spell.chi_cost * 0.35:
			within += 1
	assert_gt(within, SpellLibrary.all().size() * 0.7, "%d of %d are within a third" % [within, SpellLibrary.all().size()])


func test_every_kind_of_effect_is_worth_something() -> void:
	for kind in SpellEffect.Kind.values():
		assert_gt(grammar.worth_of(SpellEffect.make(kind, 1.0, 5.0)), 0.0, SpellEffect.KIND_NAMES[kind])


# Rank and school

func test_a_longer_spell_is_of_a_higher_rank() -> void:
	assert_eq(RuneGrammar.rank_of(_strokes([R, D, D])), Spell.Rank.NOVICE)
	assert_eq(RuneGrammar.rank_of(_strokes([R, D, D, D, D])), Spell.Rank.APPRENTICE)
	assert_eq(RuneGrammar.rank_of(_strokes([R, D, D, D, D, D, D])), Spell.Rank.ADEPT)
	assert_eq(RuneGrammar.rank_of(_strokes([R, D, D, D, D, D, D, D])), Spell.Rank.EXPERT)
	assert_eq(RuneGrammar.rank_of(_strokes([R, D, D, D, D, D, D, D, D])), Spell.Rank.MASTER)


func test_the_school_goes_by_what_the_spell_does_first() -> void:
	assert_eq(RuneGrammar.school_of(grammar.effects_of(_strokes([R, D, D]))), Spell.School.EVOCATION)
	assert_eq(RuneGrammar.school_of(grammar.effects_of(_strokes([K, K, S]))), Spell.School.ABJURATION)
	assert_eq(RuneGrammar.school_of(grammar.effects_of(_strokes([D, D, S]))), Spell.School.TRANSMUTATION)
	assert_eq(RuneGrammar.school_of(grammar.effects_of(_strokes([R, F, T]))), Spell.School.ILLUSION)
	assert_eq(RuneGrammar.school_of([]), Spell.School.EVOCATION)


func test_every_rune_is_said_to_be_for_something() -> void:
	var seen := {}
	for type in Rune.Type.values():
		var said := RuneGrammar.what_it_is_for(type)
		assert_false(said.is_empty(), Rune.RuneToName[type])
		assert_false(seen.has(said))
		seen[said] = true


func test_every_rune_does_something_in_some_spell() -> void:
	for type in Rune.Type.values():
		var found := false
		for companions in [[R, D], [K, K], [R, L], [R, T], [R, K], [D, D]]:
			var without := grammar.effects_of(_strokes(companions))
			var with := grammar.effects_of(_strokes(companions + [type]))
			if with.size() != without.size():
				found = true
			for i in mini(with.size(), without.size()):
				if with[i].kind != without[i].kind or not is_equal_approx(with[i].amount, without[i].amount) or not is_equal_approx(with[i].duration, without[i].duration):
					found = true
		assert_true(found, Rune.RuneToName[type])


func test_the_rules_are_numbers_that_can_be_changed() -> void:
	var gentler := RuneGrammar.new()
	gentler.damage_per_development = 2.0
	assert_lt(gentler.effects_of(_strokes([R, D, D]))[0].amount, grammar.effects_of(_strokes([R, D, D]))[0].amount)
	assert_eq(RuneGrammar.usual(), RuneGrammar.usual())
