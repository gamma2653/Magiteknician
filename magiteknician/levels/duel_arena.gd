extends Transitionable
## Where duels against NPCs are fought: the player's circle, the
## opponent's, and the HUD that reports on both.

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
@onready var hud: DuelHud = $HUD

# The parts of the HUD, by the names they had when they were part of this
# scene.
var player_panel: DuelistPanel:
	get:
		return hud.player_panel
var opponent_panel: DuelistPanel:
	get:
		return hud.opponent_panel
var opponent_spell: Label:
	get:
		return hud.opponent_spell
var chosen_spell: Label:
	get:
		return hud.chosen_spell
var combat_log: CombatLog:
	get:
		return hud.combat_log
var spell_bar: SpellBar:
	get:
		return hud.spell_bar
var overlay: DuelOverlay:
	get:
		return hud.overlay

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

	hud.spell_chosen.connect(player_circle.prepare)
	hud.fade_finished.connect(_on_fade_transition_timeout)
	hud.show_duelists(player, foe, opponent.title)
	hud.spell_bar.choose(0)

	npc.spell_chosen.connect(hud.name_opponent_spell)
	opponent_circle.cast_finished.connect(func (_spell, _result): hud.name_opponent_spell(null))
	duel.spell_resolved.connect(func (outcome): hud.add_line(outcome.describe()))
	duel.cast_refused.connect(_on_cast_refused)
	duel.escalated.connect(func (): hud.add_line(DuelHud.ESCALATION_LINE))
	duel.finished.connect(_on_duel_finished)

	overlay.confirmed.connect(_on_overlay_confirmed)
	overlay.declined.connect(leave)
	overlay.show_introduction(opponent)
	hud.fade_in()


func _player_spellbook() -> Spellbook:
	if not Session.spell_ids.is_empty():
		return Spellbook.of(Session.spell_ids)
	var book := Spellbook.new()
	for spell in SpellLibrary.all():
		if spell.rank == Spell.Rank.NOVICE:
			book.learn(spell)
	return book


func _on_cast_refused(caster: Duelist, spell: Spell) -> void:
	if caster == duel.player:
		hud.refuse(spell)


func _on_duel_finished(_winner: Duelist, _loser: Duelist) -> void:
	hud.name_opponent_spell(null)
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
	hud.fade_out()


func _on_fade_transition_timeout() -> void:
	# The same signal fires when the fade that opens the scene ends.
	if not _destination.is_empty():
		get_tree().change_scene_to_file(_destination)
