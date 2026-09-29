extends TestCase
## The spells of the higher ranks, whose rhythms are not even, and what
## is asked of every spell there is.

const PRACTICE := preload("res://magiteknician/levels/practice_range.tscn")
const HARDER: Array[StringName] = [&"sunder", &"rime_lance", &"stillness", &"restoration", &"aegis", &"cataclysm"]
const BEAT := 200_000
const START := 5_000_000


func before_each() -> void:
	forget_progress()
	forget_settings()


func after_each() -> void:
	forget_progress()
	forget_settings()


func _spell(id: StringName) -> Spell:
	return SpellLibrary.find(id)


func _on_the_beat(spell: Spell, beat: int = BEAT) -> Array[int]:
	var times: Array[int] = []
	for stroke in spell.strokes:
		times.append(START + stroke.tick * beat)
	return times


# What is asked of every spell

func test_every_spell_can_be_cast() -> void:
	assert_eq(SpellLibrary.all().size(), 18)
	for spell in SpellLibrary.all():
		assert_eq(spell.problems(), PackedStringArray(), spell.display_name)
		assert_gt(spell.strokes.size(), 2, "%s has a rhythm to be judged on" % [spell.display_name])
		assert_false(spell.effects.is_empty(), "%s does something" % [spell.display_name])
		assert_false(spell.description.is_empty())
		assert_true(CastScorer.score(spell.ticks(), _on_the_beat(spell)).grade == CastResult.Grade.S, spell.display_name)


func test_no_two_spells_have_the_same_rhythm() -> void:
	var seen := {}
	for spell in SpellLibrary.all():
		var rhythm := spell.rhythm_text()
		assert_false(seen.has(rhythm), "%s has the rhythm of %s" % [spell.display_name, seen.get(rhythm, "")])
		seen[rhythm] = spell.display_name


func test_no_two_runes_of_a_spell_are_laid_on_top_of_each_other() -> void:
	for spell in SpellLibrary.all():
		for i in spell.strokes.size():
			for j in i:
				var apart := spell.strokes[i].position.distance_to(spell.strokes[j].position)
				assert_gt(apart, Rune.RADIUS * 2.0 + 4.0, "%s: runes %d and %d" % [spell.display_name, j + 1, i + 1])


func test_no_spell_takes_longer_than_a_duel_can_bear() -> void:
	for spell in SpellLibrary.all():
		assert_lt(spell.span_ticks(), 17, spell.display_name)
		assert_lt(spell.gaps().max(), 6, "%s: no silence so long that the beat is lost" % [spell.display_name])


func test_a_spell_costs_more_the_higher_its_rank() -> void:
	var dearest := {}
	var cheapest := {}
	for spell in SpellLibrary.all():
		dearest[spell.rank] = maxf(dearest.get(spell.rank, 0.0), spell.chi_cost)
		cheapest[spell.rank] = minf(cheapest.get(spell.rank, INF), spell.chi_cost)
	assert_gt(dearest[Spell.Rank.MASTER], dearest[Spell.Rank.EXPERT])
	assert_gt(dearest[Spell.Rank.EXPERT], dearest[Spell.Rank.ADEPT])
	assert_lt(dearest[Spell.Rank.MASTER], 100.0, "and none more than a caster has")


# The rhythm, written down

func test_a_rhythm_is_the_ticks_from_each_stroke_to_the_next() -> void:
	assert_eq(_spell(&"spark").gaps(), [1, 1])
	assert_eq(_spell(&"spark").rhythm_text(), "1 1")
	assert_eq(_spell(&"rime_lance").gaps(), [3, 3, 2, 3])
	assert_eq(_spell(&"rime_lance").rhythm_text(), "3 3 2 3")
	assert_eq(Spell.new().gaps(), [])
	assert_eq(Spell.new().rhythm_text(), "")


func test_the_rhythm_adds_up_to_the_length_of_the_spell() -> void:
	for spell in SpellLibrary.all():
		var total := 0
		for gap in spell.gaps():
			assert_gt(gap, 0)
			total += gap
		assert_eq(total, spell.span_ticks(), spell.display_name)
		assert_eq(spell.gaps().size(), spell.strokes.size() - 1)


func test_a_spell_knows_whether_it_is_even() -> void:
	assert_true(_spell(&"spark").is_even())
	assert_false(_spell(&"fire_bolt").is_even())
	assert_true(Spell.new().is_even())
	for id in HARDER:
		assert_false(_spell(id).is_even(), String(id))


func test_the_practice_range_says_how_a_spell_goes() -> void:
	var practice: Node = add_managed(PRACTICE.instantiate())
	practice.spell_bar.choose_spell(_spell(&"cataclysm"))
	assert_eq(practice.spell_info.formula.text, SpellInfo.formula_text(_spell(&"cataclysm")))
	assert_true(practice.spell_info.formula.text.ends_with("9 strokes over 16 ticks, as 2 3 2 3 2 1 1 2"))
	assert_true(_spell(&"cataclysm").formula() in practice.spell_info.formula.text)


# The harder spells

func test_there_are_six_and_none_is_a_beginners() -> void:
	for id in HARDER:
		var spell := _spell(id)
		assert_not_null(spell, String(id))
		assert_gt(spell.rank, Spell.Rank.APPRENTICE, String(id))
	assert_eq(_spell(&"cataclysm").rank, Spell.Rank.MASTER)
	var ranks := {}
	for spell in SpellLibrary.all():
		ranks[spell.rank] = true
	assert_eq(ranks.size(), Spell.Rank.size(), "there is a spell of every rank")


func test_each_has_a_rhythm_that_has_a_name() -> void:
	assert_eq(_spell(&"sunder").rhythm_text(), "1 1 2 1 1 2", "a gallop")
	assert_eq(_spell(&"rime_lance").rhythm_text(), "3 3 2 3", "three, three, two")
	assert_eq(_spell(&"stillness").rhythm_text(), "1 2 1 2 1", "a limp")
	assert_eq(_spell(&"restoration").rhythm_text(), "1 1 5 1 1", "three, a silence, and three")
	assert_eq(_spell(&"aegis").rhythm_text(), "3 3 4 2 2 1 1", "the clave, and three to close")
	assert_eq(_spell(&"cataclysm").rhythm_text(), "2 3 2 3 2 1 1 2", "twos and threes, and a run")


func test_they_are_stronger_than_what_came_before() -> void:
	assert_gt(NpcBrain.damage_of(_spell(&"cataclysm")), NpcBrain.damage_of(_spell(&"lightning")))
	assert_gt(_spell(&"aegis").effects[0].amount, _spell(&"bulwark").effects[0].amount)
	assert_gt(_spell(&"restoration").effects[0].amount, _spell(&"mend").effects[0].amount)
	assert_gt(_spell(&"sunder").effects[0].amount, _spell(&"gust").effects[0].amount)


func test_a_harder_rhythm_is_judged_as_any_other() -> void:
	# On the beat at any tempo it is flawless, and off it, it is not.
	var aegis := _spell(&"aegis")
	for beat in [120_000, 300_000, 700_000]:
		assert_almost_eq(CastScorer.score(aegis.ticks(), _on_the_beat(aegis, beat)).quality, 1.0, 1e-6, "%d ms a tick" % [beat / 1000.0])
	# Played evenly, as if its strokes were as far apart as each other.
	var even: Array[int] = []
	for i in aegis.strokes.size():
		even.append(START + i * 2 * BEAT)
	var flattened := CastScorer.score(aegis.ticks(), even)
	assert_lt(flattened.quality, 0.5, "a rhythm that is not kept is not the spell")


func test_the_silence_in_a_spell_is_part_of_it() -> void:
	var restoration := _spell(&"restoration")
	var hurried := _on_the_beat(restoration)
	# The second three come in two beats early.
	for i in range(3, 6):
		hurried[i] -= 2 * BEAT
	var result := CastScorer.score(restoration.ticks(), hurried)
	assert_lt(result.quality, 0.7)
	assert_lt(result.grade, CastResult.Grade.FIZZLE + 1)
	assert_gt(result.grade, CastResult.Grade.A)


func test_they_can_be_cast_on_a_circle_and_kept_in_cadence() -> void:
	var circle: SpellCircle = add_managed(SpellCircle.new())
	circle.accepts_input = false
	var first := START
	for id in HARDER:
		var spell := _spell(id)
		circle.prepare(spell)
		for stroke in spell.strokes:
			circle.strike(stroke.rune, stroke.position, first + stroke.tick * BEAT)
		assert_eq(circle.last_result.grade, CastResult.Grade.S, String(id))
		first += (spell.strokes[-1].tick + 2) * BEAT
	assert_eq(circle.last_result.cadence_links, HARDER.size() - 1)


# In the campaign

func test_the_campaign_teaches_every_spell_there_is() -> void:
	var campaign := Session.campaign
	assert_eq(campaign.problems(), PackedStringArray())
	var taught := campaign.spell_ids_after(campaign.stage_count())
	assert_eq(taught.size(), SpellLibrary.all().size())
	for spell in SpellLibrary.all():
		assert_true(taught.has(spell.id), spell.display_name)


func test_the_harder_spells_are_taught_late() -> void:
	var campaign := Session.campaign
	var half := campaign.spell_ids_after(campaign.stage_count() / 2)
	for id in half:
		assert_lt(_spell(id).rank, Spell.Rank.ADEPT, "%s is taught in the first half" % [id])
	assert_true(campaign.stage(campaign.stage_count() - 1).reward_spell_ids.has(&"cataclysm"), "and the hardest of them last")


func test_an_opponent_casts_a_harder_spell_as_well_as_their_hands_allow() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var steady := CasterProfile.make(280_000, 0.02, 0.1, 0.0)
	var unsteady := CasterProfile.make(280_000, 0.14, 0.1, 0.0)
	var good := 0.0
	var poor := 0.0
	for cast in 40:
		good += CastPlan.draw(_spell(&"aegis"), steady, rng).foreseen_result().quality
		poor += CastPlan.draw(_spell(&"aegis"), unsteady, rng).foreseen_result().quality
	assert_gt(good / 40.0, 0.9)
	assert_lt(poor / 40.0, good / 40.0 - 0.15)


func test_the_opponents_who_know_them_can_still_duel() -> void:
	for index in Session.campaign.stage_count():
		var opponent := Session.campaign.stage(index).opponent
		assert_eq(opponent.problems(), PackedStringArray(), opponent.display_name)
