extends TestCase
## Campaign: the run of duels, and whether it is a fair climb.

const CAMPAIGN_DIR := "res://magiteknician/campaigns"

var campaign: Campaign


func before_each() -> void:
	campaign = Session.DEFAULT_CAMPAIGN


func _stand_in(usec_per_tick: int, timing_error: float, spell_ids: Array[StringName]) -> Opponent:
	var stand_in := Opponent.new()
	stand_in.id = &"stand_in"
	stand_in.display_name = "Stand-in"
	stand_in.spell_ids = spell_ids
	stand_in.profile = CasterProfile.make(usec_per_tick, timing_error, 0.3, 0.02)
	stand_in.profile.think_seconds_min = 1.0
	stand_in.profile.think_seconds_max = 1.6
	stand_in.profile.caution = 0.7
	return stand_in


func test_every_campaign_in_the_game_can_be_played_through() -> void:
	var checked := 0
	for file in ResourceLoader.list_directory(CAMPAIGN_DIR):
		if not file.ends_with(".tres"):
			continue
		var found := load(CAMPAIGN_DIR.path_join(file)) as Campaign
		assert_not_null(found, file)
		if found == null:
			continue
		checked += 1
		assert_eq(found.problems(), PackedStringArray(), file)
		assert_eq(String(found.id), file.get_basename(), "%s: id matches the file name" % [file])
		assert_false(found.title.is_empty())
	assert_gt(checked, 0, "found campaigns to check")


func test_stages_are_found_by_index_and_by_opponent() -> void:
	assert_gt(campaign.stage_count(), 3)
	assert_eq(campaign.stage(0).opponent.id, &"training_sphere")
	assert_null(campaign.stage(-1))
	assert_null(campaign.stage(campaign.stage_count()))
	assert_eq(campaign.index_of(&"training_sphere"), 0)
	assert_eq(campaign.index_of(&"nobody"), -1)


func test_the_player_learns_as_they_win() -> void:
	var known := campaign.spell_ids_after(0)
	assert_eq(known, campaign.starting_spell_ids)
	for i in campaign.stage_count():
		var after := campaign.spell_ids_after(i + 1)
		assert_true(after.size() >= known.size())
		for id in campaign.stage(i).reward_spell_ids:
			assert_true(after.has(id), "stage %d teaches %s" % [i + 1, id])
		known = after
	assert_eq(campaign.spell_ids_after(99), known, "there is no more to learn after the last stage")


func test_by_the_end_the_player_knows_every_spell() -> void:
	var known := campaign.spell_ids_after(campaign.stage_count())
	for spell in SpellLibrary.all():
		assert_true(known.has(spell.id), String(spell.id))


func test_a_stage_gives_its_rewards_as_spells() -> void:
	var rewards := campaign.stage(0).rewards()
	assert_eq(rewards.size(), campaign.stage(0).reward_spell_ids.size())
	assert_eq(rewards[0], SpellLibrary.find(campaign.stage(0).reward_spell_ids[0]))


func test_problems_are_reported() -> void:
	assert_gt(Campaign.new().problems().size(), 2)

	var harmless := Campaign.new()
	harmless.id = &"harmless"
	harmless.starting_spell_ids = [&"ward", &"mend"]
	harmless.stages = campaign.stages.slice(0, 1)
	assert_eq(harmless.problems().size(), 1, "the player could never win")

	var repeated := Campaign.new()
	repeated.id = &"repeated"
	repeated.starting_spell_ids = [&"spark"]
	repeated.stages = [campaign.stage(0), campaign.stage(0)]
	assert_eq(repeated.problems().size(), 1, "the same opponent twice")


func test_opponents_get_steadier_as_the_campaign_goes_on() -> void:
	# Not every stage is steadier than the one before; the first-year is
	# shakier than the sphere. But the last is far steadier than the first.
	var first := campaign.stage(0).opponent.profile
	var last := campaign.stage(campaign.stage_count() - 1).opponent.profile
	assert_lt(last.timing_error, first.timing_error * 0.5)
	assert_lt(last.usec_per_tick, first.usec_per_tick)


func test_a_practised_caster_beats_the_first_opponent() -> void:
	var simulation: DuelSimulation = add_managed(DuelSimulation.new())
	var challenger := _stand_in(340_000, 0.075, campaign.spell_ids_after(0))
	var tally: DuelSimulation.Tally = await simulation.play_many(challenger, campaign.stage(0).opponent, 6)
	assert_eq(tally.wins, 6, str(tally))


func test_a_beginner_does_not_beat_the_last_opponent() -> void:
	var simulation: DuelSimulation = add_managed(DuelSimulation.new())
	var last := campaign.stage_count() - 1
	var challenger := _stand_in(450_000, 0.13, campaign.spell_ids_after(last))
	var tally: DuelSimulation.Tally = await simulation.play_many(challenger, campaign.stage(last).opponent, 6)
	assert_eq(tally.losses, 6, str(tally))


func test_duels_end_well_before_the_time_limit() -> void:
	# Two careful casters who both ward and mend: the pairing most likely
	# to go round in circles.
	var simulation: DuelSimulation = add_managed(DuelSimulation.new())
	var careful := campaign.stage(campaign.index_of(&"mary_farwell")).opponent
	var tally: DuelSimulation.Tally = await simulation.play_many(careful, careful, 4)
	assert_eq(tally.draws, 0, str(tally))
	assert_lt(tally.mean_seconds(), DuelSimulation.TIME_LIMIT_SECONDS * 0.75)
