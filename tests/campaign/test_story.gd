extends TestCase
## What the opponents say, and what the campaign tells between its duels.

const ARENA := preload("res://magiteknician/levels/duel_arena.tscn")
const CAMPAIGN_MENU := preload("res://magiteknician/menus/campaign_menu.tscn")
const BEAT := 250_000
const START := 5_000_000

var campaign: Campaign


func before_each() -> void:
	forget_progress()
	forget_settings()
	forget_replays()
	campaign = Session.campaign


func after_each() -> void:
	forget_progress()
	forget_settings()
	forget_replays()


func _spell(id: StringName) -> Spell:
	return SpellLibrary.find(id)


## Every line anybody says, as [who, which line, the line].
func _every_line() -> Array:
	var lines := []
	for index in campaign.stage_count():
		var opponent := campaign.stage(index).opponent
		for which in ["greeting", "on_winning", "on_losing"]:
			if not str(opponent.get(which)).is_empty():
				lines.append([opponent.display_name, which, opponent.get(which)])
		for moment in opponent.remarks:
			lines.append([opponent.display_name, String(moment), opponent.remarks[moment]])
	return lines


## Everything that is told, as [which stage, which part, the telling].
func _everything_told() -> Array:
	var told := [["the campaign", "introduction", campaign.introduction], ["the campaign", "epilogue", campaign.epilogue]]
	for index in campaign.stage_count():
		var stage := campaign.stage(index)
		var label := "stage %d" % [index + 1]
		told.append([label, "prologue", stage.prologue])
		told.append([label, "victory", stage.victory_text])
		told.append([label, "defeat", stage.defeat_text])
		told.append([label, "introduction", stage.opponent.introduction])
	return told


## An opponent who says `line` of every moment there is.
func _talker(line: String = "Well.") -> Opponent:
	var talker: Opponent = load("res://magiteknician/opponents/training_sphere.tres").duplicate(true)
	talker.display_name = "Talker"
	talker.max_health = 100.0
	var remarks: Dictionary[StringName, String] = {}
	for moment in DuelBanter.MOMENTS:
		remarks[moment] = "%s (%s)" % [line, moment]
	talker.remarks = remarks
	talker.greeting = "Begin."
	talker.on_winning = "I have won."
	talker.on_losing = "I have lost."
	return talker


func _arena(opponent: Opponent) -> Node:
	Session.opponent = opponent
	var arena: Node = add_managed(ARENA.instantiate())
	arena.duel.set_process(false)
	return arena


func _cast(arena: Node, id: StringName, first_usec: int) -> void:
	var spell := _spell(id)
	arena.duel.player.chi = 100.0
	arena.player_circle.prepare(spell)
	for stroke in spell.strokes:
		arena.player_circle.strike(stroke.rune, stroke.position, first_usec + stroke.tick * BEAT)


# What is written

func test_everybody_who_can_speak_has_something_to_say() -> void:
	for index in campaign.stage_count():
		var opponent := campaign.stage(index).opponent
		if opponent.id == &"training_sphere":
			continue
		assert_false(opponent.greeting.is_empty(), "%s greets" % [opponent.display_name])
		assert_false(opponent.on_winning.is_empty(), "%s has a word on winning" % [opponent.display_name])
		assert_false(opponent.on_losing.is_empty(), "%s has a word on losing" % [opponent.display_name])
		assert_gt(opponent.remarks.size(), 1, "%s remarks on the duel" % [opponent.display_name])
		assert_eq(opponent.problems(), PackedStringArray(), opponent.display_name)


func test_the_sphere_says_nothing() -> void:
	var sphere := campaign.stage(0).opponent
	assert_eq(sphere.id, &"training_sphere")
	assert_true(sphere.greeting.is_empty())
	assert_eq(sphere.remarks.size(), 0)
	assert_eq(sphere.quoted(sphere.on_losing), "")


func test_every_remark_is_on_a_moment_there_is() -> void:
	for index in campaign.stage_count():
		var opponent := campaign.stage(index).opponent
		for moment in opponent.remarks:
			assert_true(moment in DuelBanter.MOMENTS, "%s: %s" % [opponent.display_name, moment])
	for moment in DuelBanter.MOMENTS:
		assert_true(DuelBanter.MOMENT_MEANS.has(moment))
	var nonsense := _talker()
	nonsense.remarks[&"at_teatime"] = "Milk?"
	assert_gt(nonsense.problems().size(), 0)


func test_nobody_says_the_same_thing_as_anybody_else() -> void:
	var seen := {}
	for line in _every_line():
		assert_false(seen.has(line[2]), "%s and %s both say “%s”" % [line[0], seen.get(line[2], ""), line[2]])
		seen[line[2]] = line[0]
	assert_gt(seen.size(), 40)


func test_what_is_said_in_a_duel_is_short_enough_to_be_read_in_one() -> void:
	for index in campaign.stage_count():
		var opponent := campaign.stage(index).opponent
		for moment in opponent.remarks:
			assert_lt(opponent.remarks[moment].length(), 72, "%s on %s" % [opponent.display_name, moment])
		for line in [opponent.greeting, opponent.on_winning, opponent.on_losing]:
			assert_lt(line.length(), 110, opponent.display_name)


func test_the_lucky_8_are_spoken_of_by_their_number_names() -> void:
	# In what is said, a number is a name and is written out. Five is
	# Five, and never 5.
	for line in _every_line():
		for digit in "0123456789":
			assert_false(digit in line[2], "%s, %s: “%s”" % [line[0], line[1], line[2]])
	var last := campaign.stage(campaign.stage_count() - 1)
	assert_eq(last.opponent.id, &"femble_downey")
	assert_true("Five is the first to applaud" in last.victory_text)
	assert_true("Five of the Lucky 8" in last.opponent.introduction, "the council keeps its figure")
	assert_true("Five" in campaign.stage(campaign.stage_count() - 2).opponent.on_losing)


func test_nothing_that_is_told_is_at_odds_with_the_notes() -> void:
	for told in _everything_told():
		var text: String = told[2]
		assert_false("spice-root" in text.to_lower(), "%s, %s: it is root-sap" % [told[0], told[1]])
		assert_false("Femble says" in text or "says Femble" in text, "%s, %s: she is Five to whoever speaks of her" % [told[0], told[1]])
	# Rizzle Dram is a woman, and Morellis Kingston is Mint's husband.
	var rizzle: Opponent = load("res://magiteknician/opponents/rizzle_dram.tres")
	var stage_of_rizzle: CampaignStage
	for index in campaign.stage_count():
		if campaign.stage(index).opponent == rizzle:
			stage_of_rizzle = campaign.stage(index)
	for text in [rizzle.introduction, stage_of_rizzle.prologue, stage_of_rizzle.victory_text, stage_of_rizzle.defeat_text]:
		for word in [" he ", " his ", " him ", "He ", "His "]:
			assert_false(word in text, "“%s”" % [text])
	assert_true("her strokes" in stage_of_rizzle.prologue)


func test_every_stage_has_a_before_and_two_afters() -> void:
	for index in campaign.stage_count():
		var stage := campaign.stage(index)
		assert_false(stage.prologue.is_empty(), "stage %d has a prologue" % [index + 1])
		assert_false(stage.victory_text.is_empty(), "stage %d, won" % [index + 1])
		assert_false(stage.defeat_text.is_empty(), "stage %d, lost" % [index + 1])
		assert_ne(stage.victory_text, stage.defeat_text)
	assert_false(campaign.epilogue.is_empty())


func test_a_line_is_quoted_with_the_name_of_whoever_said_it() -> void:
	var derek: Opponent = load("res://magiteknician/opponents/derek_hiddleston.tres")
	assert_eq(derek.quoted("Well."), "“Well.”\n— Derek Hiddleston")
	assert_eq(derek.quoted(""), "")
	assert_eq(derek.quoted("   "), "")
	assert_eq(derek.remark_on(&"at_teatime"), "")
	assert_false(derek.remark_on(DuelBanter.HURT).is_empty())


# In the campaign menu

func test_the_campaign_menu_tells_what_happens_before_a_duel() -> void:
	Session.new_game()
	var menu: Node = add_managed(CAMPAIGN_MENU.instantiate())
	var stage := campaign.stage(0)
	assert_true(stage.prologue in menu.opponent_introduction.text)
	assert_true(stage.opponent.introduction in menu.opponent_introduction.text)
	assert_lt(menu.opponent_introduction.text.find(stage.prologue), menu.opponent_introduction.text.find(stage.opponent.introduction), "in that order")


func test_the_campaign_menu_has_the_epilogue_once_the_campaign_is_won() -> void:
	Session.new_game()
	var before: Node = add_managed(CAMPAIGN_MENU.instantiate())
	assert_eq(before.introduction.text, campaign.introduction)
	Session.save.stages_cleared = campaign.stage_count()
	var after: Node = add_managed(CAMPAIGN_MENU.instantiate())
	assert_eq(after.introduction.text, campaign.epilogue)
	assert_true("Any duel can be fought again" in campaign.epilogue, "it says what there is left to do")


# In the arena

func test_the_opponent_greets_the_player_before_the_duel() -> void:
	Session.new_game()
	Session.save.stages_cleared = 3
	Session.enter_stage(3)
	var arena: Node = add_managed(ARENA.instantiate())
	arena.duel.set_process(false)
	var stage := campaign.stage(3)
	var body: String = arena.overlay.body.text
	assert_true(stage.prologue in body)
	assert_true(stage.opponent.introduction in body)
	assert_true("“%s”" % [stage.opponent.greeting] in body)
	assert_true(body.ends_with("— %s" % [stage.opponent.display_name]))


func test_an_opponent_with_nothing_to_say_is_introduced_as_before() -> void:
	var sphere: Opponent = load("res://magiteknician/opponents/training_sphere.tres")
	var arena := _arena(sphere)
	assert_eq(arena.overlay.body.text, sphere.introduction, "outside the campaign there is no prologue either")


func test_the_opponent_remarks_on_the_duel_beginning() -> void:
	var arena := _arena(_talker())
	assert_false(arena.hud.speech.visible)
	arena.overlay.confirm.pressed.emit()
	assert_true(arena.hud.speech.visible)
	assert_eq(arena.hud.speech.text, "“Well. (began)”\n— Talker")
	assert_eq(arena.banter.spoken, [DuelBanter.BEGAN])


func test_an_opponent_draws_breath_between_remarks() -> void:
	var arena := _arena(_talker())
	arena.overlay.confirm.pressed.emit()
	arena.npc.halt()
	arena.duel.opponent.max_health = 1000.0
	arena.duel.opponent.health = 1000.0
	arena.duel.advance(1.0)
	_cast(arena, &"lightning", START)
	assert_eq(arena.banter.spoken, [DuelBanter.BEGAN], "a second after the last, they say nothing")
	arena.duel.advance(DuelBanter.BREATH_SECONDS)
	_cast(arena, &"lightning", START + 40 * BEAT)
	assert_eq(arena.banter.spoken, [DuelBanter.BEGAN, DuelBanter.STRUCK_HARD])
	assert_eq(arena.hud.speech.text, "“Well. (struck_hard)”\n— Talker")


func test_each_thing_is_said_once() -> void:
	var arena := _arena(_talker())
	arena.overlay.confirm.pressed.emit()
	arena.npc.halt()
	arena.duel.opponent.max_health = 1000.0
	arena.duel.opponent.health = 1000.0
	for cast in 4:
		arena.duel.advance(DuelBanter.BREATH_SECONDS + 1.0)
		_cast(arena, &"lightning", START + cast * 100 * BEAT)
	assert_eq(arena.banter.spoken.count(DuelBanter.STRUCK_HARD), 1)
	assert_true(DuelBanter.FLAWLESS in arena.banter.spoken, "and having said it, they find something else to say")


func test_an_opponent_remarks_on_what_happens_to_them() -> void:
	var arena := _arena(_talker())
	arena.overlay.confirm.pressed.emit()
	arena.npc.halt()
	var foe: Duelist = arena.duel.opponent

	arena.duel.advance(10.0)
	foe.raise_ward(5.0, 20.0)
	foe.take_damage(6.0)
	assert_eq(arena.banter.spoken[-1], DuelBanter.WARD_BROKEN)

	arena.duel.advance(10.0)
	foe.casting = _spell(&"lightning")
	foe.interrupt()
	assert_eq(arena.banter.spoken[-1], DuelBanter.CAST_BROKEN)

	arena.duel.advance(10.0)
	foe.health = foe.max_health * 0.4
	assert_eq(arena.banter.spoken[-1], DuelBanter.HURT)

	arena.duel.advance(10.0)
	arena.duel.player.health = 30.0
	assert_eq(arena.banter.spoken[-1], DuelBanter.WINNING)

	arena.duel.advance(60.0)
	assert_eq(arena.banter.spoken[-1], DuelBanter.ESCALATED)


func test_a_ward_that_lapses_is_not_remarked_on() -> void:
	var arena := _arena(_talker())
	arena.overlay.confirm.pressed.emit()
	arena.npc.halt()
	arena.duel.advance(10.0)
	arena.duel.opponent.raise_ward(5.0, 2.0)
	arena.duel.advance(10.0)
	assert_false(arena.duel.opponent.is_warded())
	assert_false(DuelBanter.WARD_BROKEN in arena.banter.spoken)


func test_a_cadence_is_remarked_on_when_it_has_gone_on_a_while() -> void:
	var arena := _arena(_talker())
	arena.overlay.confirm.pressed.emit()
	arena.npc.halt()
	arena.duel.opponent.max_health = 1000.0
	arena.duel.opponent.health = 1000.0
	var first := START
	for cast in 3:
		arena.duel.advance(DuelBanter.BREATH_SECONDS + 1.0)
		_cast(arena, &"spark", first)
		first += (_spell(&"spark").strokes[-1].tick + 2) * BEAT
	assert_true(DuelBanter.IN_CADENCE in arena.banter.spoken)


func test_an_opponent_with_nothing_to_say_of_a_moment_says_nothing() -> void:
	var quiet := _talker()
	quiet.remarks = {}
	var arena := _arena(quiet)
	var heard := [0]
	arena.banter.said.connect(func (_who, _line): heard[0] += 1)
	arena.overlay.confirm.pressed.emit()
	arena.duel.advance(70.0)
	assert_eq(heard[0], 0)
	assert_false(arena.hud.speech.visible)


func test_the_opponent_has_the_last_word() -> void:
	var arena := _arena(_talker())
	arena.overlay.confirm.pressed.emit()
	arena.npc.halt()
	arena.duel.opponent.health = 1.0
	_cast(arena, &"spark", START)
	assert_true(arena.duel.player_won())
	assert_true(arena.overlay.body.text.begins_with("“I have lost.”\n— Talker"))
	assert_false(arena.hud.speech.visible, "what they were saying is taken down")


func test_the_opponent_has_the_last_word_when_they_win() -> void:
	var arena := _arena(_talker())
	arena.overlay.confirm.pressed.emit()
	arena.duel.player.health = 1.0
	var spark := _spell(&"spark")
	arena.opponent_circle.prepare(spark)
	for stroke in spark.strokes:
		arena.opponent_circle.strike(stroke.rune, stroke.position, START + stroke.tick * BEAT)
	assert_true(arena.duel.is_over())
	assert_false(arena.duel.player_won())
	assert_true(arena.overlay.body.text.begins_with("“I have won.”\n— Talker"))


func test_a_campaign_duel_tells_what_happened_after() -> void:
	Session.new_game()
	Session.save.stages_cleared = 3
	Session.enter_stage(3)
	var arena: Node = add_managed(ARENA.instantiate())
	arena.duel.set_process(false)
	arena.overlay.confirm.pressed.emit()
	arena.npc.halt()
	arena.duel.opponent.health = 1.0
	_cast(arena, &"spark", START)
	var stage := campaign.stage(3)
	var body: String = arena.overlay.body.text
	assert_true(body.begins_with(stage.opponent.quoted(stage.opponent.on_losing)))
	assert_true(stage.victory_text in body)
	assert_lt(body.find(stage.opponent.on_losing), body.find(stage.victory_text), "what was said, and then what happened")


func test_a_campaign_duel_that_is_lost_tells_that_too() -> void:
	Session.new_game()
	Session.enter_stage(0)
	var arena: Node = add_managed(ARENA.instantiate())
	arena.duel.set_process(false)
	arena.overlay.confirm.pressed.emit()
	arena.duel.player.health = 1.0
	var spark := _spell(&"spark")
	arena.opponent_circle.prepare(spark)
	for stroke in spark.strokes:
		arena.opponent_circle.strike(stroke.rune, stroke.position, START + stroke.tick * BEAT)
	assert_true(campaign.stage(0).defeat_text in arena.overlay.body.text)
	assert_eq(arena.overlay.confirm.text, "Duel again")
	assert_eq(Session.save.stages_cleared, 0)


func test_what_is_said_goes_away() -> void:
	var arena := _arena(_talker())
	arena.hud.say("Talker", "Briefly.")
	assert_true(arena.hud.speech.visible)
	assert_almost_eq(arena.hud.speech.modulate.a, 1.0)
	arena.hud.hush()
	assert_false(arena.hud.speech.visible)
	assert_gt(DuelHud.SPEECH_SECONDS, 3.0, "there is time to read it")
	assert_lt(DuelHud.SPEECH_SECONDS, DuelBanter.BREATH_SECONDS, "and it is gone before the next")


func test_banter_changes_nothing() -> void:
	# The same casts, at an opponent who talks and at one who does not.
	var ends := []
	for talks in [true, false]:
		var opponent := _talker()
		if not talks:
			opponent.remarks = {}
		var arena := _arena(opponent)
		arena.overlay.confirm.pressed.emit()
		arena.npc.halt()
		for cast in 3:
			arena.duel.advance(7.0)
			_cast(arena, &"fire_bolt", START + cast * 50 * BEAT)
		ends.append([arena.duel.opponent.health, arena.duel.player.chi, arena.duel.outcomes.size()])
		remove_child(arena)
		arena.free()
	assert_eq(ends[0], ends[1])
