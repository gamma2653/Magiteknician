extends TestCase
## Session: the player's progress through the campaign.

const BEAT := 250_000

var campaign: Campaign
var clock: int


func before_each() -> void:
	forget_progress()
	campaign = Session.campaign
	clock = 1_000_000


func after_each() -> void:
	forget_progress()


## A duel against the opponent the session has set up, which the player
## wins (or, with `win` false, loses) at once.
func _finished_duel(win: bool = true) -> Duel:
	var duel: Duel = add_managed(Duel.new())
	duel.set_process(false)
	var player := Duelist.new(Duelist.SECOND_PERSON)
	player.spellbook = Spellbook.of(Session.spell_ids)
	var circle: SpellCircle = add_managed(SpellCircle.new())
	duel.setup(player, Session.opponent.make_duelist(), circle, add_managed(SpellCircle.new()), add_managed(NpcCaster.new()))
	duel.begin()
	duel.advance(12.0)
	if win:
		duel.opponent.health = 1.0
		var spark := SpellLibrary.find(&"spark")
		circle.prepare(spark)
		for stroke in spark.strokes:
			circle.strike(stroke.rune, stroke.position, clock + stroke.tick * BEAT)
	else:
		duel.player.health = 1.0
		SpellResolver.resolve(SpellLibrary.find(&"spark"), CastScorer.score([0, 1, 2], [0, BEAT, 2 * BEAT]), duel.opponent, duel.player)
		duel._finish(duel.opponent, duel.player)
	return duel


func test_there_is_nothing_to_continue_at_first() -> void:
	assert_false(Session.has_save())
	assert_false(Session.continue_game())
	assert_null(Session.save)


func test_a_new_game_starts_at_the_beginning() -> void:
	Session.new_game()
	assert_eq(Session.save.stages_cleared, 0)
	assert_eq(Session.save.spell_ids, campaign.starting_spell_ids)
	assert_eq(Session.save.campaign_id, campaign.id)
	assert_true(Session.has_save(), "and is written down at once")


func test_only_the_next_stage_is_open() -> void:
	Session.new_game()
	assert_true(Session.is_unlocked(0))
	assert_false(Session.is_unlocked(1))
	assert_false(Session.is_cleared(0))
	assert_false(Session.is_unlocked(-1))
	assert_false(Session.is_unlocked(campaign.stage_count()))


func test_nothing_is_open_before_a_game_is_begun() -> void:
	assert_false(Session.is_unlocked(0))
	assert_false(Session.enter_stage(0))


func test_entering_a_stage_sets_the_duel_up() -> void:
	Session.new_game()
	assert_true(Session.enter_stage(0))
	assert_eq(Session.opponent, campaign.stage(0).opponent)
	assert_eq(Session.spell_ids, campaign.starting_spell_ids)
	assert_eq(Session.return_scene, Session.CAMPAIGN_SCENE)
	assert_eq(Session.stage_index, 0)


func test_a_locked_stage_cannot_be_entered() -> void:
	Session.new_game()
	assert_false(Session.enter_stage(3))
	assert_null(Session.opponent)
	assert_eq(Session.stage_index, -1)


func test_winning_opens_the_next_stage_and_teaches_a_spell() -> void:
	Session.new_game()
	Session.enter_stage(0)
	var learned := Session.report_duel(_finished_duel())
	assert_eq(learned, campaign.stage(0).rewards())
	assert_eq(Session.save.stages_cleared, 1)
	assert_true(Session.is_cleared(0))
	assert_true(Session.is_unlocked(1))
	for spell in learned:
		assert_true(Session.save.spell_ids.has(spell.id))
	var record := Session.save.best_against(campaign.stage(0).opponent.id)
	assert_almost_eq(record["seconds"], 12.0, 0.1)
	assert_gt(record["quality"], 0.9)


func test_losing_changes_nothing() -> void:
	Session.new_game()
	Session.enter_stage(0)
	var learned := Session.report_duel(_finished_duel(false))
	assert_eq(learned.size(), 0)
	assert_eq(Session.save.stages_cleared, 0)
	assert_true(Session.save.best.is_empty())


func test_progress_is_kept_between_sessions() -> void:
	Session.new_game()
	Session.enter_stage(0)
	Session.report_duel(_finished_duel())
	var spells := Session.save.spell_ids.duplicate()

	# As if the game had been closed and opened again.
	Session.clear()
	Session.save = null
	assert_true(Session.continue_game())
	assert_eq(Session.save.stages_cleared, 1)
	assert_eq(Session.save.spell_ids, spells)


func test_winning_a_stage_again_teaches_nothing_new() -> void:
	Session.new_game()
	Session.enter_stage(0)
	Session.report_duel(_finished_duel())
	Session.enter_stage(0)
	var learned := Session.report_duel(_finished_duel())
	assert_eq(learned.size(), 0)
	assert_eq(Session.save.stages_cleared, 1, "and does not open a second stage")


func test_the_spells_learned_are_brought_to_the_next_duel() -> void:
	Session.new_game()
	Session.enter_stage(0)
	Session.report_duel(_finished_duel())
	Session.enter_stage(1)
	assert_eq(Session.spell_ids, campaign.spell_ids_after(1))


func test_a_new_game_throws_the_old_one_away() -> void:
	Session.new_game()
	Session.enter_stage(0)
	Session.report_duel(_finished_duel())
	Session.new_game()
	assert_eq(Session.save.stages_cleared, 0)
	Session.save = null
	Session.continue_game()
	assert_eq(Session.save.stages_cleared, 0, "on disk as well")


func test_the_campaign_can_be_completed() -> void:
	Session.new_game()
	for i in campaign.stage_count():
		assert_false(Session.is_campaign_complete())
		assert_true(Session.enter_stage(i), "stage %d" % [i + 1])
		Session.report_duel(_finished_duel())
	assert_true(Session.is_campaign_complete())
	assert_eq(Session.save.spell_ids.size(), campaign.spell_ids_after(campaign.stage_count()).size())


func test_a_save_from_another_campaign_is_not_continued() -> void:
	var other := SaveGame.new()
	other.campaign_id = &"some_other_campaign"
	other.stages_cleared = 5
	other.write(Session.save_path)
	assert_false(Session.has_save())
	assert_false(Session.continue_game())


func test_a_save_made_before_a_reward_was_added_gains_it() -> void:
	var old := SaveGame.new()
	old.campaign_id = campaign.id
	old.stages_cleared = 2
	old.spell_ids = campaign.starting_spell_ids.duplicate()
	old.write(Session.save_path)
	assert_true(Session.continue_game())
	for id in campaign.spell_ids_after(2):
		assert_true(Session.save.spell_ids.has(id), String(id))


func test_a_duel_outside_the_campaign_is_not_progress() -> void:
	Session.new_game()
	Session.opponent = campaign.stage(0).opponent
	Session.spell_ids = [&"spark"]
	var learned := Session.report_duel(_finished_duel())
	assert_eq(learned.size(), 0)
	assert_eq(Session.save.stages_cleared, 0)
