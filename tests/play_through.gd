extends Node
## Plays the game from the main menu, through real changes of scene, and
## exits with a status code.
##
##   godot --headless --path . res://tests/play_through.tscn
##
## The tests in test_*.gd check each screen on its own and ask where it
## means to go next. None of them can follow it there, because changing
## scene would replace the test runner. This does follow: it sits at the
## root of the tree, above the scenes that come and go, and drives them.
##
## Main menu, New Game, the campaign, a duel won, back to the campaign,
## Continue, the practice range, the versus menu, the options, and back.

const SAVE_PATH := "user://play_through_save.json"
## How long to wait for a scene to arrive, in milliseconds.
const PATIENCE_MSEC := 8000
## A fade takes a second. Wait it out before touching the scene under it.
const FADE_SECONDS := 1.1
## Seconds a tick lasts when this script casts.
const SECONDS_PER_TICK := 0.1

var failures: int = 0


func _ready() -> void:
	# Scenes save as they would in play, and must not write over a real save.
	Session.save_path = SAVE_PATH
	DirAccess.remove_absolute(SAVE_PATH)
	# Move to the root, to outlive the scenes that are about to come and go.
	get_parent().remove_child.call_deferred(self)
	get_tree().root.add_child.call_deferred(self)
	_play.call_deferred()


func _play() -> void:
	await get_tree().process_frame
	get_tree().change_scene_to_file(Session.MAIN_MENU_SCENE)
	var menu := await _arrive_at("MainMenu")
	_check(menu.get_node("ButtonManager/Continue").disabled, "Continue is greyed out when there is no save")

	menu._on_new_game_pressed()
	var campaign := await _arrive_at("CampaignMenu")
	_check(Session.save != null and Session.save.stages_cleared == 0, "a new game starts at the beginning")
	_check(campaign.selected == 0, "the campaign opens on the first duel")

	campaign._on_duel_pressed()
	var arena := await _arrive_at("DuelArena")
	var first := Session.campaign.stage(0)
	_check(arena.opponent == first.opponent, "the first duel is against the first opponent")
	_check(arena.duel.player.spellbook.ids() == Session.campaign.starting_spell_ids, "the player brings the starting spells")
	arena.overlay.confirm.pressed.emit()
	_check(arena.duel.state == Duel.State.RUNNING, "Begin starts the duel")

	await _win(arena)
	_check(arena.duel.player_won(), "the player won the duel")
	_check(arena.overlay.confirm.text == "Continue", "a win in the campaign offers Continue")
	for spell in first.rewards():
		_check("You have learned %s." % [spell.display_name] in arena.overlay.body.text, "the verdict says %s was learned" % [spell.display_name])

	arena.overlay.confirm.pressed.emit()
	campaign = await _arrive_at("CampaignMenu")
	_check(Session.save.stages_cleared == 1, "progress has moved on")
	_check(campaign.selected == 1, "the campaign opens on the second duel")
	_check(campaign.CLEARED_MARK in campaign.stage_list.get_child(0).text, "the first duel is marked as won")
	var on_disk := SaveGame.read(SAVE_PATH)
	_check(on_disk != null and on_disk.stages_cleared == 1, "and the save on disk says so")

	campaign._on_back_pressed()
	menu = await _arrive_at("MainMenu")
	_check(not menu.get_node("ButtonManager/Continue").disabled, "Continue is offered once there is a save")

	menu._on_continue_pressed()
	campaign = await _arrive_at("CampaignMenu")
	_check(campaign.selected == 1, "Continue comes back to the second duel")
	campaign._on_back_pressed()
	menu = await _arrive_at("MainMenu")

	menu._on_practice_pressed()
	var practice := await _arrive_at("PracticeRange")
	_check(practice.spell_bar.slot_count() == mini(SpellLibrary.all().size(), Spellbook.MAX_SLOTS), "the practice range offers every spell")
	practice._on_back_pressed()
	menu = await _arrive_at("MainMenu")

	menu._on_versus_pressed()
	var versus := await _arrive_at("VersusMenu")
	_check(versus.link == Net, "the versus menu uses the game's own link")
	versus._on_back_pressed()
	menu = await _arrive_at("MainMenu")

	menu._on_options_pressed()
	var options := await _arrive_at("Options")
	options._on_back_pressed()
	await _arrive_at("MainMenu")

	DirAccess.remove_absolute(SAVE_PATH)
	print("")
	print("play-through: %s" % ["passed" if failures == 0 else "%d failed" % [failures]])
	get_tree().quit(0 if failures == 0 else 1)


## Casts Fire Bolt at the arena's opponent, in time, until the duel ends.
func _win(arena: Node) -> void:
	var fire_bolt := SpellLibrary.find(&"fire_bolt")
	for attempt in 40:
		if arena.duel.is_over():
			return
		if arena.duel.player.can_afford(fire_bolt):
			arena.spell_bar.choose_spell(fire_bolt)
			for i in fire_bolt.strokes.size():
				var stroke := fire_bolt.strokes[i]
				if i > 0:
					var gap := stroke.tick - fire_bolt.strokes[i - 1].tick
					await get_tree().create_timer(gap * SECONDS_PER_TICK).timeout
				arena.player_circle.strike(stroke.rune, stroke.position, Time.get_ticks_usec())
		await get_tree().create_timer(0.3).timeout


## Waits for the scene called `scene_name` to be the current one and for
## the fade that opens it to finish. If it never comes, that is a failure,
## and whatever scene is current is returned in its place.
func _arrive_at(scene_name: String) -> Node:
	var deadline := Time.get_ticks_msec() + PATIENCE_MSEC
	while Time.get_ticks_msec() < deadline:
		var current := get_tree().current_scene
		if current != null and current.name == scene_name and current.is_node_ready():
			await get_tree().create_timer(FADE_SECONDS).timeout
			print("  at    %s" % [scene_name])
			return current
		await get_tree().process_frame
	var current := get_tree().current_scene
	_check(false, "arrived at %s (still at %s)" % [scene_name, "nothing" if current == null else String(current.name)])
	return current


func _check(passed: bool, what: String) -> void:
	if not passed:
		failures += 1
	print("  %s  %s" % ["pass" if passed else "FAIL", what])
