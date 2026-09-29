extends TestCase
## Recording a duel, and playing the recording.

const ARENA := preload("res://magiteknician/levels/duel_arena.tscn")
const REPLAY_ARENA := preload("res://magiteknician/levels/replay_arena.tscn")
const REPLAYS_MENU := preload("res://magiteknician/menus/replays_menu.tscn")
const MAIN_MENU := preload("res://magiteknician/menus/main_menu.tscn")
const PATH := "user://test_recording.json"
const BEAT := 250_000
const START := 5_000_000


func before_each() -> void:
	forget_progress()
	forget_settings()
	forget_replays()


func after_each() -> void:
	forget_progress()
	forget_settings()
	forget_replays()
	DirAccess.remove_absolute(PATH)


func _spell(id: StringName) -> Spell:
	return SpellLibrary.find(id)


## A duel between two NPCs, played out with nobody watching but a
## recorder. Returns the duel, which the caller frees, and the recording.
func _fight(rng_seed: int, seconds: float = 240.0) -> Array:
	var duel: Duel = add_managed(Duel.new())
	duel.set_process(false)
	var circles: Array[SpellCircle] = []
	var casters: Array[NpcCaster] = []
	var sides: Array[Opponent] = [
		load("res://magiteknician/opponents/mary_farwell.tres"),
		load("res://magiteknician/opponents/morellis_kingston.tres"),
	]
	for side in sides:
		var circle := SpellCircle.new()
		duel.add_child(circle)
		circle.set_process(false)
		circle.hide()
		circles.append(circle)
		var caster := NpcCaster.new()
		duel.add_child(caster)
		caster.profile = side.profile
		caster.rng.seed = hash([rng_seed, casters.size()])
		casters.append(caster)
	duel.setup(sides[0].make_duelist(), sides[1].make_duelist(), circles[0], circles[1], casters[1], casters[0])
	var recorder := DuelRecorder.new()
	recorder.watch(duel, "duel", sides[1].title)
	duel.begin()
	var steps := ceili(seconds * 30.0)
	for step in steps:
		if duel.is_over():
			break
		duel.advance(1.0 / 30.0)
		if step % 300 == 299:
			await get_tree().process_frame
	return [duel, recorder.so_far()]


## Plays `recording` to its end, `step` seconds at a time, and returns
## the player that played it.
func _play(recording: DuelRecording, step: float = 1.0 / 60.0) -> ReplayPlayer:
	var player: ReplayPlayer = add_managed(ReplayPlayer.new())
	player.set_process(false)
	var circles: Array[SpellCircle] = []
	for i in 2:
		var circle := SpellCircle.new()
		player.add_child(circle)
		circle.set_process(false)
		circle.hide()
		circles.append(circle)
	player.setup(recording, circles[0], circles[1])
	player.begin()
	var turns := 0
	while not player.is_over() and turns < 200_000:
		player.advance(step)
		turns += 1
		if turns % 600 == 0:
			await get_tree().process_frame
	return player


func _lines(duel: Duel) -> Array:
	return duel.outcomes.map(func (outcome): return outcome.describe())


# Playing a recording

func test_a_recording_plays_out_as_the_duel_did() -> void:
	var fought: Array = await _fight(3)
	var duel: Duel = fought[0]
	var recording: DuelRecording = fought[1]
	assert_true(duel.is_over(), "the duel was fought to its end")
	assert_gt(duel.outcomes.size(), 10)

	var player: ReplayPlayer = await _play(recording)
	assert_true(player.duel.is_over())
	assert_eq(_lines(player.duel), _lines(duel), "cast for cast")
	assert_eq(player.duel.player_won(), duel.player_won())
	assert_almost_eq(player.duel.elapsed_seconds, duel.elapsed_seconds, 0.001)
	assert_almost_eq(player.duel.player.health, duel.player.health, 0.001)
	assert_almost_eq(player.duel.opponent.health, duel.opponent.health, 0.001)
	assert_almost_eq(player.duel.player.chi, duel.player.chi, 0.01)


func test_it_does_not_matter_how_long_a_frame_is() -> void:
	var fought: Array = await _fight(5)
	var duel: Duel = fought[0]
	for step in [1.0 / 240.0, 1.0 / 23.0, 0.37]:
		var player: ReplayPlayer = await _play(fought[1], step)
		assert_eq(_lines(player.duel), _lines(duel), "%.3f s a frame" % [step])
		assert_almost_eq(player.duel.player.health, duel.player.health, 0.001)
		remove_child(player)
		player.free()


func test_the_casts_are_judged_as_they_were() -> void:
	var fought: Array = await _fight(7)
	var duel: Duel = fought[0]
	var player: ReplayPlayer = await _play(fought[1])
	assert_eq(player.duel.outcomes.size(), duel.outcomes.size())
	for i in duel.outcomes.size():
		var was: CastResult = duel.outcomes[i].result
		var now: CastResult = player.duel.outcomes[i].result
		assert_eq(now.grade, was.grade)
		assert_almost_eq(now.quality, was.quality, 1e-6)
		assert_almost_eq(now.usec_per_tick, was.usec_per_tick, 0.01)
		assert_eq(now.cadence_links, was.cadence_links, "and followed one another as they did")


func test_a_recording_that_has_been_written_and_read_plays_the_same() -> void:
	var fought: Array = await _fight(11)
	var duel: Duel = fought[0]
	assert_eq(fought[1].write(PATH), OK)
	var read := DuelRecording.read(PATH)
	assert_not_null(read)
	assert_eq(read.events.size(), fought[1].events.size())
	var player: ReplayPlayer = await _play(read)
	assert_eq(_lines(player.duel), _lines(duel))
	assert_almost_eq(player.duel.opponent.health, duel.opponent.health, 0.001)


func test_a_recording_can_be_played_again_from_the_beginning() -> void:
	var fought: Array = await _fight(13)
	var duel: Duel = fought[0]
	var player: ReplayPlayer = await _play(fought[1])
	var first := _lines(player.duel)
	player.restart()
	assert_false(player.is_over())
	assert_almost_eq(player.duel.elapsed_seconds, 0.0)
	assert_almost_eq(player.progress(), 0.0)
	while not player.is_over():
		player.advance(1.0 / 30.0)
	assert_eq(_lines(player.duel), first)
	assert_eq(first, _lines(duel))
	assert_almost_eq(player.progress(), 1.0, 0.01)


func test_a_duel_that_was_left_part_way_plays_as_far_as_it_got() -> void:
	var fought: Array = await _fight(17, 6.0)
	var duel: Duel = fought[0]
	var recording: DuelRecording = fought[1]
	assert_false(duel.is_over())
	assert_eq(recording.winner, -1)
	assert_almost_eq(recording.seconds, duel.elapsed_seconds)
	var player: ReplayPlayer = await _play(recording)
	assert_true(player.is_over(), "there is no more of it")
	assert_false(player.duel.is_over(), "and nobody had won")
	assert_eq(_lines(player.duel), _lines(duel))


func test_the_speed_can_be_changed_and_the_duel_is_the_same() -> void:
	var fought: Array = await _fight(19)
	var duel: Duel = fought[0]
	var player: ReplayPlayer = add_managed(ReplayPlayer.new())
	player.set_process(false)
	var mine: SpellCircle = add_managed(SpellCircle.new())
	var theirs: SpellCircle = add_managed(SpellCircle.new())
	player.setup(fought[1], mine, theirs)
	player.begin()
	assert_almost_eq(player.speed, 1.0)
	assert_almost_eq(player.change_speed(true), 2.0)
	assert_almost_eq(player.change_speed(true), 4.0)
	assert_almost_eq(player.change_speed(true), 4.0, 1e-6, "there is a fastest")
	for i in 6:
		player.change_speed(false)
	assert_almost_eq(player.speed, 0.25, 1e-6, "and a slowest")
	player.speed = 4.0
	while not player.is_over():
		player._process(1.0 / 60.0)
	assert_eq(_lines(player.duel), _lines(duel))


func test_a_recording_that_is_paused_does_not_go_on() -> void:
	var fought: Array = await _fight(23, 8.0)
	var player: ReplayPlayer = add_managed(ReplayPlayer.new())
	player.set_process(false)
	player.setup(fought[1], add_managed(SpellCircle.new()), add_managed(SpellCircle.new()))
	player.begin()
	player._process(1.0)
	assert_almost_eq(player.duel.elapsed_seconds, 1.0)
	player.is_paused = true
	player._process(1.0)
	assert_almost_eq(player.duel.elapsed_seconds, 1.0)


# What is recorded

func test_a_recording_says_who_fought_and_with_what() -> void:
	var fought: Array = await _fight(3, 5.0)
	var recording: DuelRecording = fought[1]
	assert_eq(recording.name_of(DuelRecording.PLAYER), "Mary Farwell")
	assert_eq(recording.name_of(DuelRecording.OPPONENT), "Morellis Kingston")
	assert_false(recording.title_of(DuelRecording.OPPONENT).is_empty())
	assert_eq(recording.game_version, SelfCheck.version())
	assert_eq(recording.occasion, "duel")
	var mary := recording.duelist(DuelRecording.PLAYER)
	assert_almost_eq(mary.max_health, 110.0)
	assert_almost_eq(mary.health, 110.0, 1e-6, "as she began, and not as she ended")
	assert_true(mary.spellbook.knows(&"exchange"))
	assert_eq(recording.problems(), PackedStringArray())


func test_a_recording_is_what_was_done_and_not_what_came_of_it() -> void:
	var fought: Array = await _fight(3, 20.0)
	var recording: DuelRecording = fought[1]
	var kinds := {}
	var before := 0.0
	for event in recording.events:
		kinds[event["kind"]] = true
		assert_gt(float(event["t"]), before - 0.0001, "in the order it was done")
		before = event["t"]
		assert_false(event.has("damage"))
		assert_false(event.has("grade"))
	assert_true(kinds.has(int(DuelRecording.Kind.PREPARE)))
	assert_true(kinds.has(int(DuelRecording.Kind.STRIKE)))


func test_strokes_are_timed_from_where_the_recording_begins() -> void:
	var fought: Array = await _fight(3, 20.0)
	var earliest := {}
	for event in fought[1].events:
		if int(event["kind"]) == DuelRecording.Kind.STRIKE and not earliest.has(event["side"]):
			earliest[event["side"]] = event["usec"]
	assert_eq(earliest.size(), 2)
	for side in earliest:
		assert_eq(earliest[side], DuelRecording.CLOCK_STARTS)


func test_a_stroke_is_written_down_before_anything_comes_of_it() -> void:
	# Or the stroke that ends a duel would be missing from the recording.
	var circle: SpellCircle = add_managed(SpellCircle.new())
	circle.accepts_input = false
	var order: Array = []
	circle.struck.connect(func (_rune, _where, _when): order.append("struck"))
	circle.cast_started.connect(func (_spell): order.append("started"))
	circle.cast_finished.connect(func (_spell, _result): order.append("finished"))
	var spark := _spell(&"spark")
	circle.prepare(spark)
	for stroke in spark.strokes:
		circle.strike(stroke.rune, stroke.position, START + stroke.tick * BEAT)
	assert_eq(order, ["struck", "started", "struck", "struck", "finished"])


func test_a_stroke_on_a_circle_with_nothing_on_it_is_not_a_stroke() -> void:
	var circle: SpellCircle = add_managed(SpellCircle.new())
	circle.accepts_input = false
	var struck := [0]
	circle.struck.connect(func (_rune, _where, _when): struck[0] += 1)
	circle.strike(Rune.Type.FLOW, Vector2.ZERO, START)
	assert_eq(struck[0], 0)


func test_a_recording_that_cannot_be_read_is_not_one() -> void:
	assert_null(DuelRecording.read("user://no_such_recording.json"))
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("{ not json")
	file.close()
	assert_null(DuelRecording.read(PATH))
	assert_null(DuelRecording.from_dict({}))
	assert_null(DuelRecording.from_dict({"version": 99, "sides": [{}, {}], "events": []}), "from a version that is not this one")
	assert_null(DuelRecording.from_dict({"version": 1, "sides": [{}], "events": []}))
	assert_null(DuelRecording.from_dict({"version": 1, "sides": [{}, {}], "events": [{"kind": 9, "side": 0, "t": 0.0}]}))
	assert_null(DuelRecording.from_dict({"version": 1, "sides": [{}, {}], "events": [{"kind": 1, "side": 0, "t": 0.0, "rune": 40}]}))


func test_a_recording_knows_what_is_wrong_with_it() -> void:
	var empty := DuelRecording.new()
	assert_gt(empty.problems().size(), 0)
	var fought: Array = await _fight(3, 5.0)
	var recording: DuelRecording = fought[1]
	var unknown := DuelRecording.from_dict(recording.to_dict())
	unknown.events[0]["spell"] = "fireball"
	assert_gt(unknown.problems().size(), 0)
	var disordered := DuelRecording.from_dict(recording.to_dict())
	disordered.events.reverse()
	assert_gt(disordered.problems().size(), 0)


func test_a_recording_has_a_title() -> void:
	var recording := DuelRecording.new()
	recording.sides[DuelRecording.OPPONENT] = {"name": "Rizzle Dram"}
	recording.recorded_at = "2026-09-28T21:30:05"
	recording.seconds = 48.2
	recording.mean_quality = 0.91
	assert_eq(recording.title(), "A duel against Rizzle Dram, not finished")
	recording.winner = DuelRecording.PLAYER
	assert_eq(recording.title(), "Victory against Rizzle Dram")
	recording.winner = DuelRecording.OPPONENT
	assert_eq(recording.title(), "Defeat against Rizzle Dram")
	assert_eq(recording.subtitle(), "28 September 2026 at 21:30 · 48 s · 91% mean quality")


# Keeping recordings

func _recording(at: String, against: String = "Rizzle Dram") -> DuelRecording:
	var recording := DuelRecording.new()
	recording.recorded_at = at
	recording.sides[DuelRecording.PLAYER] = {"name": "You", "spells": ["spark"]}
	recording.sides[DuelRecording.OPPONENT] = {"name": against, "spells": ["spark"]}
	recording.events.append({"t": 0.0, "side": 0, "kind": int(DuelRecording.Kind.PREPARE), "spell": "spark"})
	recording.winner = DuelRecording.PLAYER
	recording.seconds = 10.0
	return recording


func test_the_tests_keep_their_recordings_apart_from_the_players() -> void:
	assert_ne(Session.replay_dir, Session.DEFAULT_REPLAY_DIR)


func test_a_recording_is_kept_under_when_it_was_fought_and_against_whom() -> void:
	var path := _recording("2026-09-28T21:30:05").keep_in(Session.replay_dir)
	assert_eq(path, Session.replay_dir.path_join("2026-09-28T21-30-05_rizzle_dram.json"))
	assert_true(FileAccess.file_exists(path))
	assert_eq(DuelRecording.read(path).title(), "Victory against Rizzle Dram")


func test_recordings_are_listed_the_newest_first() -> void:
	_recording("2026-09-27T10:00:00", "Mary Farwell").keep_in(Session.replay_dir)
	_recording("2026-09-28T21:30:05", "Rizzle Dram").keep_in(Session.replay_dir)
	_recording("2026-09-28T09:15:00", "Femble Downey").keep_in(Session.replay_dir)
	var names := DuelRecording.all_in(Session.replay_dir).map(func (recording): return recording.name_of(DuelRecording.OPPONENT))
	assert_eq(names, ["Rizzle Dram", "Femble Downey", "Mary Farwell"])


func test_only_the_last_few_recordings_are_kept() -> void:
	for i in DuelRecording.KEEP + 4:
		_recording("2026-09-28T10:%02d:00" % [i]).keep_in(Session.replay_dir)
	var kept := DuelRecording.all_in(Session.replay_dir)
	assert_eq(kept.size(), DuelRecording.KEEP)
	assert_eq(kept[0].recorded_at, "2026-09-28T10:%02d:00" % [DuelRecording.KEEP + 3], "the newest is there")
	assert_eq(kept[-1].recorded_at, "2026-09-28T10:04:00", "and the four oldest are gone")


func test_a_file_that_is_not_a_recording_is_passed_over() -> void:
	_recording("2026-09-28T21:30:05").keep_in(Session.replay_dir)
	var file := FileAccess.open(Session.replay_dir.path_join("2026-09-29T00-00-00_nonsense.json"), FileAccess.WRITE)
	file.store_string("nonsense")
	file.close()
	assert_eq(DuelRecording.all_in(Session.replay_dir).size(), 1)
	assert_eq(DuelRecording.all_in("user://no_such_directory").size(), 0)


# In the game

func _win(arena: Node) -> void:
	arena.duel.set_process(false)
	arena.overlay.confirm.pressed.emit()
	arena.npc.halt()
	arena.duel.advance(3.0)
	arena.duel.opponent.health = 20.0
	var fire_bolt := _spell(&"fire_bolt")
	arena.spell_bar.choose_spell(fire_bolt)
	for cast in 2:
		arena.duel.player.chi = 100.0
		for stroke in fire_bolt.strokes:
			arena.player_circle.strike(stroke.rune, stroke.position, START + cast * 12 * BEAT + stroke.tick * BEAT)
		arena.duel.advance(2.0)


func test_a_duel_that_is_finished_is_recorded() -> void:
	var arena: Node = add_managed(ARENA.instantiate())
	_win(arena)
	assert_true(arena.duel.player_won())
	var kept := DuelRecording.all_in(Session.replay_dir)
	assert_eq(kept.size(), 1)
	assert_eq(kept[0].title(), "Victory against %s" % [arena.opponent.display_name])
	assert_eq(kept[0].title_of(DuelRecording.OPPONENT), arena.opponent.title)
	assert_almost_eq(kept[0].seconds, arena.duel.elapsed_seconds, 0.001)
	assert_eq(kept[0].duelist(DuelRecording.PLAYER).spellbook.ids(), arena.duel.player.spellbook.ids())


func test_a_duel_that_is_left_is_not_recorded() -> void:
	var arena: Node = add_managed(ARENA.instantiate())
	arena.duel.set_process(false)
	arena.overlay.confirm.pressed.emit()
	arena.npc.halt()
	arena.leave()
	assert_eq(DuelRecording.all_in(Session.replay_dir).size(), 0)


func test_the_recording_of_a_duel_in_the_arena_plays_out_as_it_did() -> void:
	var arena: Node = add_managed(ARENA.instantiate())
	_win(arena)
	# The arena set the opponent's health by hand, which no recording
	# knows of. What can be held to is what was cast, and how well.
	var recording := DuelRecording.all_in(Session.replay_dir)[0]
	var player: ReplayPlayer = await _play(recording)
	assert_eq(player.duel.outcomes.size(), arena.duel.outcomes.size())
	for i in arena.duel.outcomes.size():
		assert_eq(player.duel.outcomes[i].spell, arena.duel.outcomes[i].spell)
		assert_eq(player.duel.outcomes[i].result.grade, arena.duel.outcomes[i].result.grade)
		assert_almost_eq(player.duel.outcomes[i].damage_dealt(), arena.duel.outcomes[i].damage_dealt(), 0.001)


func test_the_replays_menu_lists_what_was_recorded() -> void:
	_recording("2026-09-27T10:00:00", "Mary Farwell").keep_in(Session.replay_dir)
	_recording("2026-09-28T21:30:05", "Rizzle Dram").keep_in(Session.replay_dir)
	var menu: Node = add_managed(REPLAYS_MENU.instantiate())
	assert_eq(menu.list.get_child_count(), 2)
	assert_eq(menu.selected, 0, "it opens on the newest")
	assert_eq(menu.heading.text, "Victory against Rizzle Dram")
	assert_true("28 September 2026" in menu.subtitle.text)
	assert_true("You brought Spark." in menu.brought.text)
	assert_false(menu.watch_button.disabled)
	menu.select(1)
	assert_eq(menu.heading.text, "Victory against Mary Farwell")
	menu._on_watch_pressed()
	assert_eq(Session.replay.name_of(DuelRecording.OPPONENT), "Mary Farwell")


func test_the_replays_menu_says_when_there_is_nothing_to_watch() -> void:
	var menu: Node = add_managed(REPLAYS_MENU.instantiate())
	assert_eq(menu.list.get_child_count(), 0)
	assert_eq(menu.explanation.text, menu.NONE_YET)
	assert_true(menu.watch_button.disabled)
	menu._on_watch_pressed()
	assert_null(Session.replay)


func test_the_main_menu_leads_to_the_replays() -> void:
	var menu: Node = add_managed(MAIN_MENU.instantiate())
	var button: Button = menu.get_node("ButtonManager/Replays")
	assert_eq(button.text, "Replays")
	menu._on_replays_pressed()
	assert_eq(menu.btn_pressed, menu.MenuItem.REPLAYS)
	menu.btn_pressed = menu.MenuItem.NONE


func test_every_button_of_the_main_menu_is_on_the_screen() -> void:
	var menu: Node = add_managed(MAIN_MENU.instantiate())
	await get_tree().process_frame
	var manager: Control = menu.get_node("ButtonManager")
	assert_eq(manager.get_child_count(), 7)
	var last_bottom := -INF
	for button: Button in manager.get_children():
		var rect := button.get_global_rect()
		assert_gt(rect.position.y, last_bottom, "%s is clear of the one above" % [button.name])
		assert_lt(rect.end.y, 648.0, "%s is on the screen" % [button.name])
		last_bottom = rect.end.y


func test_the_replay_arena_plays_the_recording_it_is_given() -> void:
	var fought: Array = await _fight(3)
	var duel: Duel = fought[0]
	Session.replay = fought[1]
	var arena: Node = add_managed(REPLAY_ARENA.instantiate())
	arena.player.set_process(false)
	assert_false(arena.hud.spell_bar.visible, "there is nothing to choose")
	assert_false(arena.player_circle.accepts_input)
	assert_eq(arena.hud.player_panel.title.text, "Mary Farwell")
	assert_eq(arena.hud.opponent_panel.title.text, "Morellis Kingston")
	while not arena.player.is_over():
		arena.player.advance(1.0 / 30.0)
	assert_eq(_lines(arena.player.duel), _lines(duel))
	assert_true(arena.hud.overlay.visible)
	assert_eq(arena.hud.overlay.confirm.text, "Watch again")
	assert_eq(arena.hud.combat_log.lines[-1], _lines(duel)[-1])
	assert_gt(arena.spell_show.marks.size(), 0, "and it is shown as a duel is")
	assert_eq(DuelRecording.all_in(Session.replay_dir).size(), 0, "watching a duel does not record it again")


func test_the_replay_arena_says_how_far_it_has_got() -> void:
	var fought: Array = await _fight(3, 30.0)
	fought[1].seconds = 75.0
	Session.replay = fought[1]
	var arena: Node = add_managed(REPLAY_ARENA.instantiate())
	arena.player.set_process(false)
	arena.player.advance(12.4)
	assert_eq(arena.progress_text(), "1× · 0:12 of 1:15")
	arena._on_faster_pressed()
	assert_eq(arena.progress_text(), "2× · 0:12 of 1:15")
	arena._on_slower_pressed()
	arena._on_slower_pressed()
	assert_eq(arena.progress_text(), "0.5× · 0:12 of 1:15")


func test_the_replay_arena_can_be_paused_and_begun_again() -> void:
	var fought: Array = await _fight(3, 30.0)
	Session.replay = fought[1]
	var arena: Node = add_managed(REPLAY_ARENA.instantiate())
	arena.player.set_process(false)
	arena._on_pause_pressed()
	assert_true(arena.player.is_paused)
	assert_eq(arena.pause_button.text, "Play")
	arena._on_pause_pressed()
	assert_false(arena.player.is_paused)
	assert_eq(arena.pause_button.text, "Pause")
	arena.player.advance(10.0)
	assert_gt(arena.hud.combat_log.lines.size(), 0)
	arena._on_again_pressed()
	assert_almost_eq(arena.player.duel.elapsed_seconds, 0.0)
	assert_eq(arena.hud.combat_log.lines.size(), 0)
	assert_eq(arena.hud.player_panel.duelist, arena.player.duel.player, "the panels follow the duel that is now being fought")


func test_the_replay_arena_with_nothing_to_watch_says_so() -> void:
	Session.replay = null
	var arena: Node = add_managed(REPLAY_ARENA.instantiate())
	assert_true(arena.hud.overlay.visible)
	assert_eq(arena.hud.overlay.heading.text, "Nothing to watch")
	assert_false(arena.strip.visible)
