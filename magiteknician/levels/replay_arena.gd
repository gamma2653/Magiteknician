extends Transitionable
## Where a recording of a duel is watched. It looks like the arena the
## duel was fought in, with nothing to cast and a strip of buttons where
## the spells were.

const PAUSE_TEXT := "Pause"
const PLAY_TEXT := "Play"

@onready var player_circle: SpellCircle = $PlayerCircle
@onready var opponent_circle: SpellCircle = $OpponentCircle
@onready var spell_show: SpellShow = $SpellShow
@onready var player: ReplayPlayer = $Player
@onready var hud: DuelHud = $HUD
@onready var strip: HBoxContainer = %Strip
@onready var pause_button: Button = %Pause
@onready var slower_button: Button = %Slower
@onready var faster_button: Button = %Faster
@onready var again_button: Button = %Again
@onready var progress: Label = %Progress

var recording: DuelRecording
var _destination: String = ""


func _ready() -> void:
	recording = Session.replay
	hud.fade_finished.connect(_on_fade_transition_timeout)
	hud.overlay.confirmed.connect(_on_again_pressed)
	hud.overlay.declined.connect(leave)
	# There is nothing to choose, and the number keys choose nothing.
	hud.spell_bar.hide()
	hud.spell_bar.set_process_unhandled_input(false)
	hud.get_node("InputLegend").hide()
	player_circle.accepts_input = false
	player_circle.prepared.connect(_name_players_spell)
	opponent_circle.prepared.connect(hud.name_opponent_spell)
	opponent_circle.cast_finished.connect(func (_spell, _result): hud.name_opponent_spell(null))
	opponent_circle.cast_abandoned.connect(func (_spell): hud.name_opponent_spell(null))
	player.finished.connect(_on_finished)

	if recording == null or not recording.problems().is_empty():
		hud.overlay.show_notice("Nothing to watch", "", "There is no recording here that can be played.", true)
		strip.hide()
		player.set_process(false)
		hud.fade_in()
		return
	player.setup(recording, player_circle, opponent_circle)
	_begin()
	hud.fade_in()


func _process(_delta: float) -> void:
	if player.duel != null:
		progress.text = progress_text()


## How fast it is being played and how far it has got, e.g. "1× · 0:12 of 0:48".
func progress_text() -> String:
	return "%s× · %s of %s" % [
		String.num(player.speed, 2).trim_suffix(".0"),
		_clock(player.duel.elapsed_seconds), _clock(recording.seconds),
	]


func _begin() -> void:
	var duel := player.duel
	hud.combat_log.clear()
	hud.show_duelists(duel.player, duel.opponent, recording.title_of(DuelRecording.OPPONENT))
	hud.spell_bar.hide()
	hud.chosen_spell.text = ""
	hud.name_opponent_spell(null)
	hud.overlay.hide()
	spell_show.marks.clear()
	spell_show.place(duel.player, player_circle)
	spell_show.place(duel.opponent, opponent_circle)
	duel.spell_resolved.connect(spell_show.show_outcome)
	duel.spell_resolved.connect(func (outcome): hud.add_line(outcome.describe()))
	duel.escalated.connect(func (): hud.add_line(DuelHud.ESCALATION_LINE))
	player.is_paused = false
	pause_button.text = PAUSE_TEXT
	player.begin()


func _name_players_spell(spell: Spell) -> void:
	hud.chosen_spell.text = "%s\n%s" % [spell.display_name, spell.describe_effects()]


func _on_finished() -> void:
	var text := "The duel lasted %d seconds.\n%s ended with %d health of %d, and %s with %d of %d." % [
		roundi(player.duel.elapsed_seconds),
		player.duel.player.display_name, ceili(player.duel.player.health), roundi(player.duel.player.max_health),
		player.duel.opponent.display_name, ceili(player.duel.opponent.health), roundi(player.duel.opponent.max_health),
	]
	hud.overlay.show_result(player.duel.player_won(), player.duel.opponent.display_name, text, "Watch again")


func _on_pause_pressed() -> void:
	player.is_paused = not player.is_paused
	pause_button.text = PLAY_TEXT if player.is_paused else PAUSE_TEXT


func _on_slower_pressed() -> void:
	player.change_speed(false)


func _on_faster_pressed() -> void:
	player.change_speed(true)


func _on_again_pressed() -> void:
	player.restart()
	_begin()


func _on_back_pressed() -> void:
	leave()


## Goes back to the list of recordings.
func leave() -> void:
	_go_to(Session.REPLAYS_SCENE)


func _go_to(scene_path: String) -> void:
	if not _destination.is_empty():
		return
	_destination = scene_path
	player.is_paused = true
	hud.fade_out()


func _on_fade_transition_timeout() -> void:
	# The same signal fires when the fade that opens the scene ends.
	if not _destination.is_empty():
		get_tree().change_scene_to_file(_destination)


static func _clock(seconds: float) -> String:
	var whole := maxi(floori(seconds), 0)
	return "%d:%02d" % [whole / 60, whole % 60]
