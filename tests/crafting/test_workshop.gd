extends TestCase
## Making a spell, keeping it, and what can be done with one that is kept.

const WORKSHOP := preload("res://magiteknician/levels/workshop.tscn")
const PRACTICE := preload("res://magiteknician/levels/practice_range.tscn")
const ARENA := preload("res://magiteknician/levels/duel_arena.tscn")
const CAMPAIGN_MENU := preload("res://magiteknician/menus/campaign_menu.tscn")
const REPLAY_ARENA := preload("res://magiteknician/levels/replay_arena.tscn")
const D := Rune.Type.DEVELOPMENT
const F := Rune.Type.EQUIVELANCE
const K := Rune.Type.PERSISTENCE
const L := Rune.Type.DECAY
const R := Rune.Type.FLOW
const S := Rune.Type.VARIABILITY
const T := Rune.Type.REFRACTION
const BEAT := 250_000
const START := 5_000_000
const PLACES: Array[Vector2] = [
	Vector2(-150, 0), Vector2(-50, -90), Vector2(60, 40), Vector2(150, -60), Vector2(0, 150),
	Vector2(-120, 120), Vector2(120, 130), Vector2(-20, -170), Vector2(180, 40),
]


func before_each() -> void:
	forget_progress()
	forget_settings()
	forget_replays()
	forget_made_spells()
	GameCursor.point()


func after_each() -> void:
	forget_progress()
	forget_settings()
	forget_replays()
	forget_made_spells()
	GameCursor.point()


func _strokes(runes: Array, gaps: Array = []) -> Array[RuneStroke]:
	var strokes: Array[RuneStroke] = []
	var tick := 0
	for i in runes.size():
		if i > 0:
			tick += gaps[i - 1] if i - 1 < gaps.size() else 1
		strokes.append(RuneStroke.make(runes[i], tick, PLACES[i]))
	return strokes


## A spell of `runes`, made and kept, as the library has it.
func _kept(spell_name: String, runes: Array, gaps: Array = []) -> Spell:
	var spell := SpellForge.make(spell_name, _strokes(runes, gaps))
	assert_eq(SpellForge.keep(spell, SpellLibrary.made_dir), OK)
	return SpellLibrary.find(spell.id)


func _open() -> Node:
	return add_managed(WORKSHOP.instantiate())


func _click(workshop: Node, where: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = button
		event.pressed = pressed
		event.position = workshop.circle.position + where
		event.global_position = event.position
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await get_tree().process_frame


func _cast(circle: SpellCircle, spell: Spell, first_usec: int = START) -> CastResult:
	for stroke in spell.strokes:
		circle.strike(stroke.rune, stroke.position, first_usec + stroke.tick * BEAT)
	return circle.last_result


# Making a spell

func test_a_spell_that_is_made_has_what_it_does_worked_out() -> void:
	var spell := SpellForge.make("  Hammer  ", _strokes([R, D, D, D]))
	assert_eq(spell.display_name, "Hammer")
	assert_eq(spell.strokes.size(), 4)
	assert_eq(spell.effects.size(), 1)
	assert_almost_eq(spell.effects[0].amount, 16.5)
	assert_almost_eq(spell.chi_cost, RuneGrammar.usual().cost_of(spell.strokes))
	assert_eq(spell.rank, Spell.Rank.NOVICE)
	assert_eq(spell.school, Spell.School.EVOCATION)
	assert_eq(spell.formula(), "ρ + δ ×3")
	assert_true(spell.id.is_empty(), "it has no id until it is kept")
	assert_eq(SpellForge.problems(spell), PackedStringArray())


func test_the_strokes_that_are_handed_in_are_left_alone() -> void:
	var strokes := _strokes([R, D, D])
	var spell := SpellForge.make("Hammer", strokes)
	spell.strokes[0].position = Vector2(7, 7)
	assert_eq(strokes[0].position, PLACES[0])


func test_a_spell_with_no_name_is_given_one() -> void:
	assert_eq(SpellForge.make("", _strokes([R, D, D])).display_name, SpellForge.UNNAMED)
	assert_eq(SpellForge.make("   ", _strokes([R, D, D])).display_name, SpellForge.UNNAMED)
	assert_eq(SpellForge.make("x".repeat(60), _strokes([R, D, D])).display_name.length(), SpellForge.MAX_NAME_LENGTH)


# Keeping it

func test_the_tests_keep_their_spells_apart_from_the_players() -> void:
	assert_ne(SpellLibrary.made_dir, SpellLibrary.DEFAULT_MADE_DIR)


func test_a_spell_that_is_kept_can_be_found() -> void:
	var spell := SpellForge.make("Hammer", _strokes([R, D, D, D], [1, 2, 1]))
	assert_eq(SpellForge.keep(spell, SpellLibrary.made_dir), OK)
	assert_eq(spell.id, &"made_1")
	assert_true(SpellForge.is_made(spell))
	var found := SpellLibrary.find(&"made_1")
	assert_not_null(found)
	assert_eq(found.display_name, "Hammer")
	assert_eq(found.ticks(), [0, 1, 3, 4])
	assert_eq(found.strokes[2].position, PLACES[2])
	assert_almost_eq(found.chi_cost, spell.chi_cost)
	assert_eq(SpellLibrary.made().size(), 1)
	assert_true(SpellLibrary.has_spell(&"made_1"))


func test_a_spell_that_was_made_is_not_one_of_the_books() -> void:
	_kept("Hammer", [R, D, D])
	assert_eq(SpellLibrary.all().size(), 18, "the book is as it was")
	assert_eq(SpellLibrary.everything().size(), 19)
	assert_eq(SpellLibrary.everything()[-1].display_name, "Hammer", "what was made comes after")
	for spell in SpellLibrary.all():
		assert_false(SpellForge.is_made(spell), spell.display_name)
	assert_false(SpellForge.is_made(null))
	assert_eq(Spellbook.complete().spells.size(), 18)
	assert_eq(Spellbook.with_what_was_made().spells.size(), 19)


func test_each_spell_that_is_kept_has_an_id_of_its_own() -> void:
	var first := _kept("One", [R, D, D])
	var second := _kept("Two", [K, K, S])
	assert_ne(first.id, second.id)
	SpellForge.discard(first.id, SpellLibrary.made_dir)
	var third := _kept("Three", [D, D, S])
	assert_eq(third.id, &"made_1", "an id that was let go is taken up again")
	assert_eq(SpellLibrary.made().size(), 2)


func test_keeping_a_spell_again_keeps_it_in_place() -> void:
	var spell := _kept("Hammer", [R, D, D])
	var changed := SpellForge.make("Sledge", _strokes([R, D, D, D, D]), spell.id)
	assert_eq(SpellForge.keep(changed, SpellLibrary.made_dir), OK)
	assert_eq(SpellLibrary.made().size(), 1)
	assert_eq(SpellLibrary.find(spell.id).display_name, "Sledge")
	assert_eq(SpellLibrary.find(spell.id).strokes.size(), 5)


func test_no_more_than_a_few_spells_are_kept() -> void:
	for i in SpellForge.MOST:
		_kept("Spell %d" % [i], [R, D, D])
	var one_more := SpellForge.make("One more", _strokes([R, D, D]))
	assert_eq(SpellForge.keep(one_more, SpellLibrary.made_dir), FAILED)
	assert_eq(SpellLibrary.made().size(), SpellForge.MOST)
	# One that is there already can still be kept again.
	var first := SpellForge.make("Changed", _strokes([K, K, S]), &"made_1")
	assert_eq(SpellForge.keep(first, SpellLibrary.made_dir), OK)


func test_what_is_not_a_spell_is_not_kept() -> void:
	assert_eq(SpellForge.keep(SpellForge.make("Two", _strokes([R, D])), SpellLibrary.made_dir), FAILED)
	assert_eq(SpellForge.keep(SpellForge.make("Nothing", _strokes([S, S, S])), SpellLibrary.made_dir), FAILED)
	assert_eq(SpellForge.keep(SpellForge.make("A book's", _strokes([R, D, D]), &"fire_bolt"), SpellLibrary.made_dir), FAILED, "nor under the id of a spell from the book")
	assert_eq(SpellLibrary.made().size(), 0)
	assert_eq(SpellLibrary.find(&"fire_bolt").display_name, "Fire Bolt")


func test_a_spell_that_is_thrown_away_is_gone() -> void:
	var spell := _kept("Hammer", [R, D, D])
	SpellForge.discard(spell.id, SpellLibrary.made_dir)
	assert_null(SpellLibrary.find(spell.id))
	assert_eq(SpellLibrary.made().size(), 0)
	SpellForge.discard(&"fire_bolt", SpellLibrary.made_dir)
	assert_not_null(SpellLibrary.find(&"fire_bolt"), "a spell from the book cannot be")


func test_what_a_spell_does_is_not_in_its_file() -> void:
	var spell := _kept("Hammer", [R, D, D, D])
	var path := SpellForge.path_of(spell.id, SpellLibrary.made_dir)
	var written: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_eq(written["name"], "Hammer")
	assert_eq(written["strokes"].size(), 4)
	assert_false(written.has("effects"))
	assert_false(written.has("chi_cost"))
	# So a file that is mended to say more does no more.
	written["effects"] = [{"kind": 0, "amount": 500.0}]
	written["chi_cost"] = 1.0
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(written))
	file.close()
	SpellLibrary.forget_made()
	var read := SpellLibrary.find(spell.id)
	assert_almost_eq(read.effects[0].amount, 16.5)
	assert_gt(read.chi_cost, 10.0)


func test_a_file_that_is_not_a_spell_is_passed_over() -> void:
	_kept("Hammer", [R, D, D])
	var good: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SpellForge.path_of(&"made_1", SpellLibrary.made_dir)))
	var spoiled := {
		"made_2": "nonsense",
		"made_3": JSON.stringify({"version": 9, "id": "made_3", "name": "From later", "strokes": good["strokes"]}),
		"made_4": JSON.stringify({"version": 1, "id": "made_4", "name": "Two", "strokes": good["strokes"].slice(0, 2)}),
		"made_5": JSON.stringify({"version": 1, "id": "made_5", "name": "No such rune", "strokes": [{"rune": 40, "tick": 0, "x": 0, "y": 0}]}),
		"made_6": JSON.stringify({"version": 1, "id": "made_9", "name": "Another's file", "strokes": good["strokes"]}),
		"made_7": JSON.stringify({"version": 1, "id": "fire_bolt", "name": "A book's", "strokes": good["strokes"]}),
	}
	for id in spoiled:
		var file := FileAccess.open(SpellLibrary.made_dir.path_join("%s.json" % [id]), FileAccess.WRITE)
		file.store_string(spoiled[id])
		file.close()
	SpellLibrary.forget_made()
	assert_eq(SpellLibrary.made().size(), 1)
	assert_eq(SpellLibrary.made()[0].display_name, "Hammer")
	assert_eq(SpellLibrary.find(&"fire_bolt").display_name, "Fire Bolt")


# What can be done with it

func test_a_spell_that_was_made_is_cast_as_any_other() -> void:
	var spell := _kept("Hammer", [R, D, D, D], [1, 2, 1])
	var caster := Duelist.new("You")
	var target := Duelist.new("Femble")
	var circle: SpellCircle = add_managed(SpellCircle.new())
	circle.accepts_input = false
	circle.prepare(spell)
	var result := _cast(circle, spell)
	assert_eq(result.grade, CastResult.Grade.S)
	var outcome := SpellResolver.resolve(spell, result, caster, target)
	assert_almost_eq(target.health, 100.0 - 16.5)
	assert_eq(outcome.describe(), "You cast Hammer (S): 17 damage.")


func test_the_practice_range_offers_what_was_made() -> void:
	_kept("Hammer", [R, D, D])
	var practice: Node = add_managed(PRACTICE.instantiate())
	assert_eq(practice.spell_bar.spell_count(), 19)
	assert_eq(practice.spellbook.spells[-1].display_name, "Hammer")
	assert_true(practice.spell_bar.choose_spell(SpellLibrary.find(&"made_1")))
	assert_eq(practice.circle.spell.display_name, "Hammer")
	assert_eq(practice.spell_info.title.text, "Hammer")


func test_the_practice_range_leads_to_the_workshop() -> void:
	var practice: Node = add_managed(PRACTICE.instantiate())
	assert_eq((practice.get_node("HUD/Workshop") as Button).text, "Make a spell")
	practice._on_workshop_pressed()
	assert_eq(practice._destination, Session.WORKSHOP_SCENE)
	assert_null(Session.spell_to_practise, "a spell from the book is not taken there to be changed")


func test_the_practice_range_takes_a_spell_that_was_made_to_the_workshop() -> void:
	var spell := _kept("Hammer", [R, D, D])
	var practice: Node = add_managed(PRACTICE.instantiate())
	practice.spell_bar.choose_spell(spell)
	practice._on_workshop_pressed()
	assert_eq(Session.spell_to_practise, spell)
	var workshop := _open()
	assert_eq(workshop.editing_id, spell.id)
	assert_eq(workshop.name_box.text, "Hammer")
	assert_null(Session.spell_to_practise)


func test_the_practice_range_opens_on_what_was_made_in_the_workshop() -> void:
	var spell := _kept("Hammer", [R, D, D])
	Session.spell_to_practise = spell
	var practice: Node = add_managed(PRACTICE.instantiate())
	assert_eq(practice.circle.spell.id, spell.id)
	assert_null(Session.spell_to_practise)


# In the campaign

func test_a_caster_makes_spells_of_what_they_have_learned() -> void:
	var known: Array[Spell] = [SpellLibrary.find(&"spark"), SpellLibrary.find(&"fire_bolt"), SpellLibrary.find(&"ward")]
	# Spark is ρ and σ, Fire Bolt δ, ρ and λ, and Ward κ, ρ and σ.
	assert_true(SpellForge.can_be_brought(SpellForge.make("Hammer", _strokes([R, D, D, D])), known))
	assert_true(SpellForge.can_be_brought(SpellForge.make("Shield", _strokes([K, K, S])), known))
	var turned := SpellForge.make("Mirror", _strokes([K, K, T]))
	assert_false(SpellForge.can_be_brought(turned, known))
	assert_eq(SpellForge.why_not_brought(turned, known), "You have not learned a spell with θ in it.")
	var long := SpellForge.make("Long", _strokes([R, D, D, D, D, D]))
	assert_eq(SpellForge.why_not_brought(long, known), "It has 6 strokes, and the longest spell you have learned has 5.")
	known.append(SpellLibrary.find(&"bulwark"))
	assert_true(SpellForge.can_be_brought(turned, known), "Bulwark has θ in it, and seven strokes")
	assert_true(SpellForge.can_be_brought(long, known))


func test_a_spell_that_was_made_teaches_nothing() -> void:
	# What a caster may make goes by the book's spells that they know.
	var known: Array[Spell] = [SpellLibrary.find(&"spark"), SpellForge.make("Mirror", _strokes([K, K, T, T, T, T]), &"made_1")]
	assert_false(SpellForge.can_be_brought(SpellForge.make("Another", _strokes([K, K, T])), known))


func test_the_player_can_bring_what_they_have_made() -> void:
	Session.new_game()
	var hammer := _kept("Hammer", [R, D, D, D])
	var mirror := _kept("Mirror", [K, K, T])
	var can := Session.ids_to_bring()
	assert_true(can.has(hammer.id))
	assert_false(can.has(mirror.id), "there is no θ in what they have learned")
	assert_eq(Session.choose_loadout([&"fire_bolt", hammer.id, mirror.id]), [&"fire_bolt", hammer.id])
	assert_true(Session.enter_stage(0))
	assert_eq(Session.spell_ids, [&"fire_bolt", hammer.id])
	var arena: Node = add_managed(ARENA.instantiate())
	arena.duel.set_process(false)
	assert_eq(arena.duel.player.spellbook.ids(), [&"fire_bolt", hammer.id])
	assert_true("Hammer" in (arena.spell_bar.get_child(1) as Button).text)


func test_what_was_chosen_is_kept_though_it_was_made() -> void:
	Session.new_game()
	var hammer := _kept("Hammer", [R, D, D, D])
	Session.choose_loadout([hammer.id, &"ward"])
	Session.save = null
	assert_true(Session.continue_game())
	assert_eq(Session.brought(), [hammer.id, &"ward"])


func test_a_spell_that_has_been_thrown_away_is_not_brought() -> void:
	Session.new_game()
	var hammer := _kept("Hammer", [R, D, D, D])
	Session.choose_loadout([hammer.id, &"ward"])
	SpellForge.discard(hammer.id, SpellLibrary.made_dir)
	assert_eq(Session.brought(), [&"ward"])
	Session.enter_stage(0)
	assert_eq(Session.spell_ids, [&"ward"])


func test_a_spell_that_has_been_changed_past_what_is_known_is_not_brought() -> void:
	Session.new_game()
	var hammer := _kept("Hammer", [R, D, D, D])
	Session.choose_loadout([hammer.id, &"ward"])
	SpellForge.keep(SpellForge.make("Hammer", _strokes([R, D, D, T]), hammer.id), SpellLibrary.made_dir)
	assert_eq(Session.brought(), [&"ward"])


func test_the_campaign_menu_offers_what_can_be_brought() -> void:
	Session.new_game()
	var hammer := _kept("Hammer", [R, D, D, D])
	var mirror := _kept("Mirror", [K, K, T])
	var menu: Node = add_managed(CAMPAIGN_MENU.instantiate())
	menu._on_spells_pressed()
	assert_not_null(menu.loadout.picker.button_of(hammer.id))
	assert_null(menu.loadout.picker.button_of(mirror.id))
	menu.loadout.picker.button_of(hammer.id).pressed.emit()
	assert_eq(menu.spells_button.text, "Spells: 4 of 6")
	assert_true(Session.brought().has(hammer.id))


# In a recording

func test_a_duel_with_a_spell_that_was_made_is_recorded_with_the_spell() -> void:
	Session.new_game()
	var hammer := _kept("Hammer", [R, D, D, D], [1, 2, 1])
	Session.choose_loadout([hammer.id, &"ward"])
	Session.enter_stage(0)
	var arena: Node = add_managed(ARENA.instantiate())
	arena.duel.set_process(false)
	arena.overlay.confirm.pressed.emit()
	arena.npc.halt()
	arena.duel.opponent.health = 10.0
	arena.spell_bar.choose_spell(hammer)
	_cast(arena.player_circle, hammer)
	assert_true(arena.duel.player_won())
	var recording := DuelRecording.all_in(Session.replay_dir)[0]
	assert_eq(recording.made.size(), 1)
	assert_eq(recording.made[0]["name"], "Hammer")
	assert_eq(recording.spell_names(DuelRecording.PLAYER), PackedStringArray(["Hammer", "Ward"]))
	assert_eq(recording.problems(), PackedStringArray())


func test_the_recording_plays_the_spell_as_it_was() -> void:
	Session.new_game()
	var hammer := _kept("Hammer", [R, D, D, D], [1, 2, 1])
	Session.choose_loadout([hammer.id, &"ward"])
	Session.enter_stage(0)
	var arena: Node = add_managed(ARENA.instantiate())
	arena.duel.set_process(false)
	arena.overlay.confirm.pressed.emit()
	arena.npc.halt()
	arena.duel.opponent.max_health = 300.0
	arena.duel.opponent.health = 300.0
	arena.spell_bar.choose_spell(hammer)
	_cast(arena.player_circle, hammer)
	var struck: float = arena.duel.outcomes[-1].damage_dealt()
	var recording: DuelRecording = arena.recorder.so_far()
	remove_child(arena)
	arena.free()

	# The spell is changed since, and then thrown away.
	SpellForge.keep(SpellForge.make("Tap", _strokes([R, L, L]), hammer.id), SpellLibrary.made_dir)
	var written := DuelRecording.from_dict(JSON.parse_string(JSON.stringify(recording.to_dict())))
	Session.replay = written
	var watching: Node = add_managed(REPLAY_ARENA.instantiate())
	watching.player.set_process(false)
	while not watching.player.is_over():
		watching.player.advance(1.0 / 30.0)
	assert_eq(watching.player.duel.outcomes.size(), 1)
	assert_eq(watching.player.duel.outcomes[0].spell.display_name, "Hammer")
	assert_almost_eq(watching.player.duel.outcomes[0].damage_dealt(), struck)
	assert_eq(SpellLibrary.find(hammer.id).display_name, "Hammer", "while the recording is played")
	remove_child(watching)
	watching.free()
	assert_eq(SpellLibrary.find(hammer.id).display_name, "Tap", "and what the player has now, after")

	SpellForge.discard(hammer.id, SpellLibrary.made_dir)
	assert_eq(written.problems(), PackedStringArray(), "and it can still be played when the spell is gone")


# The workshop

func test_the_workshop_opens_with_nothing_on_the_circle() -> void:
	var workshop := _open()
	assert_eq(workshop.strokes.size(), 0)
	assert_eq(workshop.circle.state, SpellCircle.State.EMPTY)
	assert_false(workshop.circle.accepts_input)
	assert_eq(workshop.formula.text, workshop.NOTHING_YET)
	assert_eq(workshop.notes.text, "")
	assert_true(workshop.keep_button.disabled)
	assert_true(workshop.try_button.disabled)
	assert_true(workshop.hear_button.disabled)
	assert_eq(workshop.rune_row.get_child_count(), Rune.Type.size())
	assert_eq(GameCursor.look, GameCursor.Look.POINTER, "there is nothing to strike")


func test_a_rune_is_put_down_where_it_is_wanted() -> void:
	var workshop := _open()
	assert_true(workshop.place(R, PLACES[0]))
	assert_true(workshop.place(D, PLACES[1]))
	assert_eq(workshop.strokes.size(), 2)
	assert_eq(workshop.strokes[0].rune, R)
	assert_eq(workshop.strokes[0].tick, 0)
	assert_eq(workshop.strokes[1].tick, 1, "a tick after the last")
	assert_eq(workshop.strokes[1].position, PLACES[1])
	assert_eq(workshop.chosen, 1, "and is the one that is chosen")
	assert_eq(workshop.circle.expected.bound_runes.size(), 2)


func test_a_rune_cannot_be_put_where_there_is_no_room() -> void:
	var workshop := _open()
	workshop.place(R, PLACES[0])
	assert_false(workshop.place(D, PLACES[0] + Vector2(30, 0)), "on top of another")
	assert_false(workshop.place(D, Vector2(Spell.CIRCLE_RADIUS + 10.0, 0)), "off the circle")
	assert_eq(workshop.strokes.size(), 1)
	for i in range(1, RuneGrammar.MAX_STROKES):
		assert_true(workshop.place(D, PLACES[i]))
	assert_false(workshop.place(D, Vector2(0, 0)), "nine is the most")


func test_clicking_on_the_circle_puts_down_the_rune_that_is_chosen() -> void:
	var workshop := _open()
	workshop.choose_rune(K)
	await _click(workshop, PLACES[0])
	assert_eq(workshop.strokes.size(), 1)
	assert_eq(workshop.strokes[0].rune, K)
	assert_eq(workshop.strokes[0].position, PLACES[0])
	assert_true((workshop.rune_row.get_child(Rune.Type.values().find(K)) as Button).button_pressed)


func test_clicking_on_a_rune_chooses_it() -> void:
	var workshop := _open()
	for i in 3:
		workshop.place(D, PLACES[i])
	await _click(workshop, PLACES[1] + Vector2(5, 5))
	assert_eq(workshop.chosen, 1)
	assert_eq(workshop.strokes.size(), 3, "and puts nothing down")
	assert_true(workshop.chosen_stroke.text.begins_with("2  δ"))


func test_clicking_a_rune_with_the_other_button_takes_it_out() -> void:
	var workshop := _open()
	for i in 3:
		workshop.place(D, PLACES[i])
	await _click(workshop, PLACES[0], MOUSE_BUTTON_RIGHT)
	assert_eq(workshop.strokes.size(), 2)
	assert_eq(workshop.strokes[0].position, PLACES[1])
	assert_eq(workshop.strokes[0].tick, 0, "what was second is first, and on tick 0")


func test_a_rune_can_be_moved() -> void:
	var workshop := _open()
	workshop.place(R, PLACES[0])
	workshop.place(D, PLACES[1])
	assert_true(workshop.move(0, Vector2(-100, 100)))
	assert_eq(workshop.strokes[0].position, Vector2(-100, 100))
	assert_false(workshop.move(0, PLACES[1] + Vector2(10, 0)), "not onto another")
	assert_false(workshop.move(0, Vector2(400, 0)), "nor off the circle")
	assert_true(workshop.move(0, Vector2(-100, 102)), "but it can be nudged where it is")
	assert_false(workshop.move(7, Vector2.ZERO))


func test_the_rhythm_is_the_time_before_each_stroke() -> void:
	var workshop := _open()
	for i in 4:
		workshop.place(D, PLACES[i])
	assert_eq(workshop.spell().ticks(), [0, 1, 2, 3])
	workshop.set_gap(2, 3)
	assert_eq(workshop.spell().ticks(), [0, 1, 4, 5], "those after it follow it")
	assert_eq(workshop.gap_before(2), 3)
	workshop.set_gap(2, 9)
	assert_eq(workshop.gap_before(2), RuneGrammar.MAX_GAP)
	workshop.set_gap(2, 0)
	assert_eq(workshop.gap_before(2), 1)
	workshop.set_gap(0, 3)
	assert_eq(workshop.spell().ticks()[0], 0, "the first stroke is on tick 0")


func test_sooner_and_later_move_the_stroke_that_is_chosen() -> void:
	var workshop := _open()
	for i in 3:
		workshop.place(D, PLACES[i])
	workshop.chosen = 1
	workshop._show()
	assert_true(workshop.sooner.disabled, "it is a tick after the last already")
	workshop.later.pressed.emit()
	workshop.later.pressed.emit()
	assert_eq(workshop.spell().ticks(), [0, 3, 4])
	assert_eq(workshop.chosen_stroke.text, "2  δ   3 ticks after 1")
	workshop.sooner.pressed.emit()
	assert_eq(workshop.spell().ticks(), [0, 2, 3])
	workshop.chosen = 0
	workshop._show()
	assert_true(workshop.sooner.disabled)
	assert_true(workshop.later.disabled, "the first stroke is when the spell begins")
	assert_eq(workshop.chosen_stroke.text, "1  δ   the first stroke")


func test_taking_out_a_stroke_keeps_the_rhythm_of_the_rest() -> void:
	var workshop := _open()
	for i in 4:
		workshop.place(D, PLACES[i])
	workshop.set_gap(1, 2)
	workshop.set_gap(3, 3)
	assert_eq(workshop.spell().ticks(), [0, 2, 3, 6])
	workshop.chosen = 1
	workshop.take_out.pressed.emit()
	assert_eq(workshop.strokes.size(), 3)
	assert_eq(workshop.spell().ticks(), [0, 1, 4])


func test_what_the_spell_does_is_told_as_it_changes() -> void:
	var workshop := _open()
	workshop.place(R, PLACES[0])
	workshop.place(D, PLACES[1])
	assert_eq(workshop.does.text, "8 damage")
	assert_true(workshop.notes.text.begins_with("A spell wants at least 3 strokes"))
	assert_true(workshop.keep_button.disabled)
	workshop.place(D, PLACES[2])
	assert_eq(workshop.does.text, "12 damage")
	assert_true("ρ + δ ×2" in workshop.formula.text)
	assert_true("3 strokes over 2 ticks, as 1 1" in workshop.formula.text)
	assert_true(workshop.cost.text.begins_with("%s · Novice" % [SpellInfo.cost_text(workshop.spell())]))
	assert_eq(workshop.notes.text, "")
	assert_false(workshop.keep_button.disabled)
	workshop.place(K, PLACES[3])
	assert_true(workshop.notes.text.begins_with("κ has nothing to make last"), "a rune that does nothing where it is, is said to")
	assert_false(workshop.keep_button.disabled, "and the spell is still a spell")


func test_a_rune_is_said_to_be_for_something_when_it_is_chosen() -> void:
	var workshop := _open()
	workshop.choose_rune(T)
	assert_eq(workshop.purpose.text, "θ  Refraction. %s" % [RuneGrammar.what_it_is_for(T)])


func test_the_spell_is_kept_and_is_on_the_shelf() -> void:
	var workshop := _open()
	assert_eq(workshop.shelf.get_child_count(), 1, "with only a new spell to begin")
	workshop.name_box.text = "Hammer"
	for i in 3:
		workshop.place(R if i == 0 else D, PLACES[i])
	assert_true(workshop.keep())
	assert_eq(workshop.editing_id, &"made_1")
	assert_eq(workshop.notes.text, workshop.KEPT)
	assert_eq(workshop.shelf.get_child_count(), 2)
	assert_true((workshop.shelf.get_child(0) as Button).text.begins_with("Hammer"))
	assert_true((workshop.shelf.get_child(0) as Button).button_pressed)
	assert_eq(SpellLibrary.find(&"made_1").display_name, "Hammer")

	# Changed and kept again, it is the same spell.
	workshop.place(D, PLACES[3])
	assert_eq(workshop.notes.text, "", "it is not said to be kept when it has been changed since")
	assert_true(workshop.keep())
	assert_eq(SpellLibrary.made().size(), 1)
	assert_eq(SpellLibrary.find(&"made_1").strokes.size(), 4)


func test_a_spell_that_is_not_one_is_not_kept() -> void:
	var workshop := _open()
	workshop.place(R, PLACES[0])
	workshop.place(D, PLACES[1])
	assert_false(workshop.keep())
	assert_eq(SpellLibrary.made().size(), 0)


func test_the_workshop_says_when_there_is_no_room_for_another() -> void:
	for i in SpellForge.MOST:
		_kept("Spell %d" % [i], [R, D, D])
	var workshop := _open()
	for i in 3:
		workshop.place(D, PLACES[i])
	assert_false(workshop.keep())
	assert_eq(workshop.notes.text, workshop.NO_ROOM % [SpellForge.MOST, SpellForge.MOST])
	assert_eq(workshop.shelf.get_child_count(), SpellForge.MOST + 1)


func test_a_spell_on_the_shelf_can_be_taken_up_and_changed() -> void:
	var hammer := _kept("Hammer", [R, D, D, D], [1, 2, 1])
	_kept("Shield", [K, K, S])
	var workshop := _open()
	(workshop.shelf.get_child(0) as Button).pressed.emit()
	assert_eq(workshop.editing_id, hammer.id)
	assert_eq(workshop.name_box.text, "Hammer")
	assert_eq(workshop.spell().ticks(), [0, 1, 3, 4])
	workshop.strokes[0].position = Vector2(1, 1)
	assert_eq(SpellLibrary.find(hammer.id).strokes[0].position, PLACES[0], "what is kept is left alone until it is kept again")
	(workshop.shelf.get_child(1) as Button).pressed.emit()
	assert_eq(workshop.name_box.text, "Shield")
	(workshop.shelf.get_child(2) as Button).pressed.emit()
	assert_eq(workshop.strokes.size(), 0, "a new spell")
	assert_eq(workshop.editing_id, &"")


func test_a_spell_can_be_thrown_away() -> void:
	var hammer := _kept("Hammer", [R, D, D])
	var workshop := _open()
	workshop.open(hammer)
	assert_eq(workshop.discard_button.text, "Throw away")
	workshop.discard_button.pressed.emit()
	assert_null(SpellLibrary.find(hammer.id))
	assert_eq(workshop.strokes.size(), 0)
	assert_eq(workshop.shelf.get_child_count(), 1)
	workshop.place(D, PLACES[0])
	assert_eq(workshop.discard_button.text, "Start again")
	workshop.discard_button.pressed.emit()
	assert_eq(workshop.strokes.size(), 0)


func test_the_spell_can_be_heard() -> void:
	var workshop := _open()
	assert_false(workshop.hear())
	for i in 3:
		workshop.place(D, PLACES[i])
	assert_true(workshop.hear())
	assert_true(workshop.circle.is_demonstrating())


func test_the_spell_can_be_tried() -> void:
	var workshop := _open()
	for i in 4:
		workshop.place(R if i == 0 else D, PLACES[i])
	workshop.set_gap(2, 2)
	assert_true(workshop.try_it())
	assert_true(workshop.is_trying)
	assert_true(workshop.circle.accepts_input)
	assert_eq(GameCursor.look, GameCursor.Look.RETICLE)
	assert_eq(workshop.try_button.text, "Go back to making it")
	assert_true(workshop.keep_button.disabled)
	assert_false(workshop.place(D, PLACES[5]), "it is not changed while it is tried")
	assert_false(workshop.move(0, Vector2.ZERO))

	_cast(workshop.circle, workshop.spell())
	assert_true(workshop.notes.text.begins_with("Quality 100%, cast at 100% potency."))
	assert_true("Perfect 4" in workshop.notes.text)

	workshop.try_button.pressed.emit()
	assert_false(workshop.is_trying)
	assert_false(workshop.circle.accepts_input)
	assert_eq(GameCursor.look, GameCursor.Look.POINTER)
	assert_true(workshop.place(D, PLACES[5]))


func test_a_spell_that_is_not_one_cannot_be_tried() -> void:
	var workshop := _open()
	workshop.place(R, PLACES[0])
	assert_false(workshop.try_it())
	assert_false(workshop.is_trying)


func test_a_rune_is_put_down_with_its_key() -> void:
	var workshop := _open()
	var motion := InputEventMouseMotion.new()
	motion.position = workshop.circle.position + PLACES[2]
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	await get_tree().process_frame
	Input.warp_mouse(motion.position)
	var event := InputEventAction.new()
	event.action = Rune.RuneToActionID[L]
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await get_tree().process_frame
	assert_eq(workshop.chosen_rune, L, "the key chooses the rune")
	if workshop.strokes.size() == 1:
		assert_eq(workshop.strokes[0].rune, L)
	else:
		# Where the cursor is, is the machine's to say, and in a test
		# there may be no cursor. That the rune was chosen is what is held to.
		assert_eq(workshop.strokes.size(), 0)


func test_the_runes_are_the_colours_that_were_chosen() -> void:
	Settings.choose_palette(RunePalette.Choice.DISTINCT)
	var workshop := _open()
	var first := workshop.rune_row.get_child(0) as Button
	assert_eq(first.icon, RunePalette.texture_of(Rune.Type.values()[0], RunePalette.Choice.DISTINCT))


func test_going_back_goes_to_the_practice_range_with_the_spell() -> void:
	var hammer := _kept("Hammer", [R, D, D])
	var workshop := _open()
	workshop.open(hammer)
	workshop._on_back_pressed()
	assert_eq(workshop._destination, Session.PRACTICE_SCENE)
	assert_eq(Session.spell_to_practise.id, hammer.id)


func test_everything_in_the_workshop_is_on_the_screen() -> void:
	for i in SpellForge.MOST:
		_kept("Spell number %d" % [i], [R, D, D])
	var workshop := _open()
	for i in 9:
		workshop.place([R, L, K, F, T, D, S, S, S][i], PLACES[i])
	await get_tree().process_frame
	await get_tree().process_frame
	var panel: Control = workshop.get_node("HUD/Panel")
	assert_lt(panel.get_global_rect().end.y, 566.0, "the panel is clear of the shelf under it")
	assert_lt(panel.get_global_rect().end.x, 1152.0)
	for button: Control in workshop.shelf.get_children():
		assert_gt(button.get_global_rect().position.x, -0.5, "the shelf fits across the screen")
		assert_lt(button.get_global_rect().end.x, 1152.5)
