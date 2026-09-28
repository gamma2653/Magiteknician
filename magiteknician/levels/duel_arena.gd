extends Transitionable
## Where duels are fought: the player's circle, the opponent's, and the
## HUD that reports on both.

const TRAINING_SPHERE := preload("res://magiteknician/opponents/training_sphere.tres")
const PLAYER_NAME := Duelist.SECOND_PERSON

## Who to duel when nobody has said. Session.opponent takes precedence.
@export var default_opponent: Opponent = TRAINING_SPHERE
## Seed for the opponent's random numbers. Zero picks one at random.
@export var opponent_seed: int = 0

@onready var duel: Duel = $Duel
@onready var npc: NpcCaster = $Npc
@onready var player_circle: SpellCircle = $PlayerCircle
@onready var opponent_circle: SpellCircle = $OpponentCircle
@onready var player_panel: DuelistPanel = %PlayerPanel
@onready var opponent_panel: DuelistPanel = %OpponentPanel
@onready var opponent_spell: Label = %OpponentSpell
@onready var chosen_spell: Label = %ChosenSpell
@onready var combat_log: CombatLog = %CombatLog
@onready var spell_bar: SpellBar = %SpellBar
@onready var overlay: DuelOverlay = %Overlay
@onready var fade: ColorRect = $HUD/FadeTransition

var opponent: Opponent
var _destination: String = ""


func _ready() -> void:
	opponent = Session.opponent if Session.opponent != null else default_opponent

	var player := Duelist.new(PLAYER_NAME)
	player.spellbook = _player_spellbook()
	var foe := opponent.make_duelist()

	npc.profile = opponent.profile
	if opponent_seed != 0:
		npc.rng.seed = opponent_seed
	else:
		npc.rng.randomize()
	duel.setup(player, foe, player_circle, opponent_circle, npc)

	player_panel.bind(player)
	opponent_panel.bind(foe, opponent.title)
	spell_bar.show_costs = true
	spell_bar.spellbook = player.spellbook
	spell_bar.spell_chosen.connect(_on_spell_chosen)
	spell_bar.choose(0)
	player.chi_changed.connect(func (chi, _max): spell_bar.show_affordable(chi))
	player.interrupted.connect(_on_player_interrupted)

	npc.spell_chosen.connect(_on_opponent_chose)
	opponent_circle.cast_finished.connect(func (_spell, _result): opponent_spell.text = "")
	duel.spell_resolved.connect(func (outcome): combat_log.add(outcome.describe()))
	duel.cast_refused.connect(_on_cast_refused)
	duel.escalated.connect(func (): combat_log.add("The duel escalates: every blow lands harder from here."))
	duel.finished.connect(_on_duel_finished)

	overlay.confirmed.connect(_on_overlay_confirmed)
	overlay.declined.connect(leave)
	overlay.show_introduction(opponent)
	fade.end_transition()


func _player_spellbook() -> Spellbook:
	if not Session.spell_ids.is_empty():
		return Spellbook.of(Session.spell_ids)
	var book := Spellbook.new()
	for spell in SpellLibrary.all():
		if spell.rank == Spell.Rank.NOVICE:
			book.learn(spell)
	return book


func _on_spell_chosen(spell: Spell) -> void:
	player_circle.prepare(spell)
	chosen_spell.text = "%s\n%s" % [spell.display_name, spell.describe_effects()]


func _on_opponent_chose(spell: Spell) -> void:
	opponent_spell.text = spell.display_name


func _on_player_interrupted(spell: Spell) -> void:
	combat_log.add("Your %s was broken." % [spell.display_name])


func _on_cast_refused(caster: Duelist, spell: Spell) -> void:
	if caster != duel.player:
		return
	player_panel.flash_chi()
	combat_log.add("Not enough chi for %s." % [spell.display_name])


func _on_duel_finished(_winner: Duelist, _loser: Duelist) -> void:
	opponent_spell.text = ""
	opponent_circle.prepare(null)
	var stage := Session.campaign.stage(Session.stage_index)
	if stage == null or not duel.player_won():
		overlay.show_verdict(duel)
		return
	# A campaign duel, won: progress moves on, and the way on is back to
	# the campaign rather than round again.
	var remarks: PackedStringArray = []
	if not stage.victory_text.is_empty():
		remarks.append(stage.victory_text)
	for spell in Session.report_duel(duel):
		remarks.append("You have learned %s." % [spell.display_name])
	overlay.show_verdict(duel, "Continue", remarks)


func _on_overlay_confirmed() -> void:
	if not duel.is_over():
		overlay.hide()
		duel.begin()
	elif duel.player_won() and Session.stage_index >= 0:
		leave()
	else:
		_go_to(scene_file_path)


## Goes back to wherever the player came from.
func leave() -> void:
	_go_to(Session.return_scene)


func _go_to(scene_path: String) -> void:
	if not _destination.is_empty():
		return
	_destination = scene_path
	player_circle.accepts_input = false
	fade.start_transition()


func _on_fade_transition_timeout() -> void:
	# The same signal fires when the fade that opens the scene ends.
	if not _destination.is_empty():
		get_tree().change_scene_to_file(_destination)
